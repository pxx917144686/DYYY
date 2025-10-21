//
//  FLEXOSLogController.m
//  FLEX
//
//  Created by Tanner on 12/19/18.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXOSLogController.h"
#import "NSUserDefaults+FLEX.h"
#include <dlfcn.h>
#include "ActivityStreamAPI.h"

static os_activity_stream_for_pid_t OSActivityStreamForPID;
static os_activity_stream_resume_t OSActivityStreamResume;
static os_activity_stream_cancel_t OSActivityStreamCancel;
static os_log_copy_formatted_message_t OSLogCopyFormattedMessage;
static os_activity_stream_set_event_handler_t OSActivityStreamSetEventHandler;
static int (*proc_name)(int, char *, unsigned int);
static int (*proc_listpids)(uint32_t, uint32_t, void*, int);
static uint8_t (*OSLogGetType)(void *);

@interface FLEXOSLogController ()

+ (FLEXOSLogController *)sharedLogController;

@property (nonatomic) void (^updateHandler)(NSArray<FLEXSystemLogMessage *> *);

@property (nonatomic) BOOL canPrint;
@property (nonatomic) int filterPid;
@property (nonatomic) BOOL levelInfo;
@property (nonatomic) BOOL subsystemInfo;

@property (nonatomic) os_activity_stream_t stream;

@end

@implementation FLEXOSLogController

+ (void)load {
    // 如果开启了持久化日志，在iOS 10上启动应用时保存日志
    if (FLEXOSLogAvailable()) {
        if (NSUserDefaults.standardUserDefaults.flex_cacheOSLogMessages) {
            [self sharedLogController].persistent = YES;
            [[self sharedLogController] startMonitoring];
        }
    }
}

+ (instancetype)sharedLogController {
    static FLEXOSLogController *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [self new];
    });
    
    return shared;
}

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler {
    FLEXOSLogController *shared = [self sharedLogController];
    shared.updateHandler = newMessagesHandler;
    return shared;
}

- (id)init {
    NSAssert(FLEXOSLogAvailable(), @"os_log 仅适用于iOS 10及以上版本");

    self = [super init];
    if (self) {
        _filterPid = NSProcessInfo.processInfo.processIdentifier;
        _levelInfo = NO;
        _subsystemInfo = NO;
    }
    
    return self;
}

- (void)dealloc {
    OSActivityStreamCancel(self.stream);
    _stream = nil;
}

- (void)setPersistent:(BOOL)persistent {
    if (_persistent == persistent) return;
    
    _persistent = persistent;
    self.messages = persistent ? [NSMutableArray new] : nil;
}

- (BOOL)startMonitoring {
    if (![self lookupSPICalls]) {
        // 需要iOS 10及以上版本
        return NO;
    }
    
    // 是否已经在监控中？
    if (self.stream) {
        // 是否应该发送"持久化"的消息？
        if (self.updateHandler && self.messages.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.updateHandler(self.messages);
            });
        }
        
        return YES;
    }

    // 数据流入口处理器
    os_activity_stream_block_t block = ^bool(os_activity_stream_entry_t entry, int error) {
        return [self handleStreamEntry:entry error:error];
    };

    // 控制我们看到的消息类型
    // 'Historical'似乎仅显示NSLog相关内容
    uint32_t activity_stream_flags = OS_ACTIVITY_STREAM_HISTORICAL;
    activity_stream_flags |= OS_ACTIVITY_STREAM_PROCESS_ONLY;
//    activity_stream_flags |= OS_ACTIVITY_STREAM_PROCESS_ONLY;

    self.stream = OSActivityStreamForPID(self.filterPid, activity_stream_flags, block);

    // 指定流相关的事件处理器
    OSActivityStreamSetEventHandler(self.stream, [self streamEventHandlerBlock]);
    // 启动数据流
    OSActivityStreamResume(self.stream);

    return YES;
}

- (BOOL)lookupSPICalls {
    static BOOL hasSPI = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/LoggingSupport.framework/LoggingSupport", RTLD_NOW);

        OSActivityStreamForPID = (os_activity_stream_for_pid_t)dlsym(handle, "os_activity_stream_for_pid");
        OSActivityStreamResume = (os_activity_stream_resume_t)dlsym(handle, "os_activity_stream_resume");
        OSActivityStreamCancel = (os_activity_stream_cancel_t)dlsym(handle, "os_activity_stream_cancel");
        OSLogCopyFormattedMessage = (os_log_copy_formatted_message_t)dlsym(handle, "os_log_copy_formatted_message");
        OSActivityStreamSetEventHandler = (os_activity_stream_set_event_handler_t)dlsym(handle, "os_activity_stream_set_event_handler");
        proc_name = (int(*)(int, char *, unsigned int))dlsym(handle, "proc_name");
        proc_listpids = (int(*)(uint32_t, uint32_t, void*, int))dlsym(handle, "proc_listpids");
        OSLogGetType = (uint8_t(*)(void *))dlsym(handle, "os_log_get_type");

        hasSPI = (OSActivityStreamForPID != NULL) &&
                (OSActivityStreamResume != NULL) &&
                (OSActivityStreamCancel != NULL) &&
                (OSLogCopyFormattedMessage != NULL) &&
                (OSActivityStreamSetEventHandler != NULL) &&
                (OSLogGetType != NULL) &&
                (proc_name != NULL);
    });
    
    return hasSPI;
}

- (BOOL)handleStreamEntry:(os_activity_stream_entry_t)entry error:(int)error {
    if (!self.canPrint || (self.filterPid != -1 && entry->pid != self.filterPid)) {
        return YES;
    }

    if (!error && entry) {
        if (entry->type == OS_ACTIVITY_STREAM_TYPE_LOG_MESSAGE ||
            entry->type == OS_ACTIVITY_STREAM_TYPE_LEGACY_LOG_MESSAGE) {
            os_log_message_t log_message = &entry->log_message;
            
            // 获取日期
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:log_message->tv_gmt.tv_sec];
            
            // 获取日志消息文本
            // https://github.com/limneos/oslog/issues/1
            // https://github.com/FLEXTool/FLEX/issues/564
            const char *messageText = OSLogCopyFormattedMessage(log_message) ?: "";

            // 将messageText从栈移动到堆
            NSString *msg = [NSString stringWithUTF8String:messageText];

            dispatch_async(dispatch_get_main_queue(), ^{
                FLEXSystemLogMessage *message = [FLEXSystemLogMessage logMessageFromDate:date text:msg];
                if (self.persistent) {
                    [self.messages addObject:message];
                }
                if (self.updateHandler) {
                    self.updateHandler(@[message]);
                }
            });
        }
    }
    
    return YES;
}

- (os_activity_stream_event_block_t)streamEventHandlerBlock {
    return [^void(os_activity_stream_t stream, os_activity_stream_event_t event) {
        switch (event) {
            case OS_ACTIVITY_STREAM_EVENT_STARTED:
                self.canPrint = YES;
                break;
            case OS_ACTIVITY_STREAM_EVENT_STOPPED:
                break;
            case OS_ACTIVITY_STREAM_EVENT_FAILED:
                break;
            case OS_ACTIVITY_STREAM_EVENT_CHUNK_STARTED:
                break;
            case OS_ACTIVITY_STREAM_EVENT_CHUNK_FINISHED:
                break;
            default:
                printf("=== 未处理的情况 ===\n");
                break;
        }
    } copy];
}

@end
