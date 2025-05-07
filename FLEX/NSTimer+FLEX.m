//
//  NSTimer+Blocks.m
//  FLEX
//
//  Created by Tanner on 3/23/17.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "NSTimer+FLEX.h"

// 遇到问题联系中文翻译作者：pxx917144686

@interface Block : NSObject
- (void)invoke;
@end

#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation NSTimer (Blocks)

+ (instancetype)flex_fireSecondsFromNow:(NSTimeInterval)delay block:(VoidBlock)block {
    if (@available(iOS 10, *)) {
        return [self scheduledTimerWithTimeInterval:delay repeats:NO block:(id)block];
    } else {
        return [self scheduledTimerWithTimeInterval:delay target:block selector:@selector(invoke) userInfo:nil repeats:NO];
    }
}

@end
