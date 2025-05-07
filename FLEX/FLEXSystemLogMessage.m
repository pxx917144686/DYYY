//
//  FLEXSystemLogMessage.m
//  FLEX
//
//  Created by Ryan Olson on 1/25/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXSystemLogMessage.h"
#import <os/log.h>


@implementation FLEXSystemLogMessage

+ (instancetype)logMessageFromASLMessage:(aslmsg)aslMessage {
    if (!aslMessage) return nil;
    
    // 使用更现代的日志 API
    if (@available(iOS 10.0, *)) {
        NSDate *date = [NSDate date];
        NSString *text = @"[Log Message]"; // 此处可以自定义日志消息
        return [self logMessageFromDate:date text:text];
    }
    
    return nil;
}

+ (instancetype)logMessageFromDate:(NSDate *)date text:(NSString *)text {
    return [[self alloc] initWithDate:date sender:nil text:text messageID:0];
}

- (id)initWithDate:(NSDate *)date sender:(NSString *)sender text:(NSString *)text messageID:(long long)identifier {
    self = [super init];
    if (self) {
        _date = date;
        _sender = sender; 
        _messageText = text;
        _messageID = identifier;
    }
    return self;
}

@end
