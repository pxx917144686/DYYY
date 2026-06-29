//
//  NSDateFormatter+FLEX.h
//  libflex:FLEX
//
//  由 Tanner Bennett 创建于 7/24/22.
//  版权所有 © 2022 Flipboard. 保留所有权利。
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FLEXDateFormat) {
    // 时:分 [上午|下午]
    FLEXDateFormatClock,
    // 时:分:秒 [上午|下午]
    FLEXDateFormatPreciseClock,
    // 年-月-日 时:分:秒.毫秒
    FLEXDateFormatVerbose,
};

@interface NSDateFormatter (FLEX)

+ (NSString *)flex_stringFrom:(NSDate *)date format:(FLEXDateFormat)format;

@end
