//
//  FLEXASLLogController.m
//  FLEX
//
//  创建者：Tanner，日期：3/14/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXASLLogController.h"
#import <os/log.h>

// 在模拟器中查询 ASL 的速度要慢得多。我们需要更长的轮询间隔以保持响应性。
#if TARGET_IPHONE_SIMULATOR
    #define updateInterval 5.0 // 更新间隔
#else
    #define updateInterval 0.5 // 更新间隔
#endif

@interface FLEXASLLogController ()

@property (nonatomic, readonly) void (^updateHandler)(NSArray<FLEXSystemLogMessage *> *);
@property (nonatomic) NSTimer *logUpdateTimer;
@property (nonatomic, readonly) NSMutableIndexSet *logMessageIdentifiers;
@property (nonatomic) os_log_t logger;

@end

@implementation FLEXASLLogController

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler {
    return [[self alloc] initWithUpdateHandler:newMessagesHandler];
}

- (instancetype)initWithUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))handler {
    NSParameterAssert(handler);

    self = [super init];
    if (self) {
        _updateHandler = handler;
        _logMessageIdentifiers = [NSMutableIndexSet new];
        _logger = os_log_create("com.flex.logger", "system");

        self.logUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:updateInterval
                                                               target:self
                                                             selector:@selector(updateLogMessages)
                                                             userInfo:nil
                                                              repeats:YES];
    }

    return self;
}

- (void)dealloc {
    [self.logUpdateTimer invalidate];
}

- (BOOL)startMonitoring {
    [self.logUpdateTimer fire];
    return YES;
}

- (void)updateLogMessages {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<FLEXSystemLogMessage *> *messages = [self collectNewLogMessages];
        if (messages.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.updateHandler(messages);
            });
        }
    });
}

- (NSArray<FLEXSystemLogMessage *> *)collectNewLogMessages {
    // 使用 os_log 获取日志
    NSMutableArray *messages = [NSMutableArray new];
    os_log_with_type(self.logger, OS_LOG_TYPE_INFO, "Collecting logs"); // "正在收集日志" - os_log 的消息通常是英文，用于调试，可以不翻译
    // TODO: 实现新的日志收集逻辑
    return messages;
}

@end
