//
//  UIFont+FLEX.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/20/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利.
//

#import "UIFont+FLEX.h"

#define kFLEXDefaultCellFontSize 12.0

@implementation UIFont (FLEX)

+ (UIFont *)flex_defaultTableCellFont {
    static UIFont *defaultTableCellFont = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultTableCellFont = [UIFont systemFontOfSize:kFLEXDefaultCellFontSize];
    });

    return defaultTableCellFont;
}

+ (UIFont *)flex_codeFont {
    // 仅在 iOS 13 中可用
    if (@available(iOS 13, *)) {
        return [self monospacedSystemFontOfSize:kFLEXDefaultCellFontSize weight:UIFontWeightRegular];
    } else {
        return [self fontWithName:@"Menlo-Regular" size:kFLEXDefaultCellFontSize];
    }
}

+ (UIFont *)flex_smallCodeFont {
    // 仅在 iOS 13 中可用
    if (@available(iOS 13, *)) {
        return [self monospacedSystemFontOfSize:self.smallSystemFontSize weight:UIFontWeightRegular];
    } else {
        return [self fontWithName:@"Menlo-Regular" size:self.smallSystemFontSize];
    }
}

@end
