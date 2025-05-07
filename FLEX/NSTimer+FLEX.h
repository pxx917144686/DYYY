// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSTimer+Blocks.h
//  FLEX
//
//  由 Tanner 创建于 3/23/17.
//

#import <Foundation/Foundation.h>

typedef void (^VoidBlock)(void);

@interface NSTimer (Blocks)

+ (instancetype)flex_fireSecondsFromNow:(NSTimeInterval)delay block:(VoidBlock)block;

// 前向声明
//+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;

@end
