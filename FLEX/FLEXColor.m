//
//  FLEXColor.m
//  FLEX
//
//  创建者：Benny Wong，日期：6/18/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXColor.h"
#import "FLEXUtility.h"

#define FLEXDynamicColor(dynamic, static) ({ \
    UIColor *c; \
    if (@available(iOS 13.0, *)) { \
        c = [UIColor dynamic]; \
    } else { \
        c = [UIColor static]; \
    } \
    c; \
});

@implementation FLEXColor

#pragma mark - Background Colors // 背景颜色

+ (UIColor *)primaryBackgroundColor {
    return FLEXDynamicColor(systemBackgroundColor, whiteColor);
}

+ (UIColor *)primaryBackgroundColorWithAlpha:(CGFloat)alpha {
    return [[self primaryBackgroundColor] colorWithAlphaComponent:alpha];
}

+ (UIColor *)secondaryBackgroundColor {
    return FLEXDynamicColor(
        secondarySystemBackgroundColor,
        colorWithHue:2.0/3.0 saturation:0.02 brightness:0.97 alpha:1
    );
}

+ (UIColor *)secondaryBackgroundColorWithAlpha:(CGFloat)alpha {
    return [[self secondaryBackgroundColor] colorWithAlphaComponent:alpha];
}

+ (UIColor *)tertiaryBackgroundColor {
    // 所有的背景/填充颜色都是不同色度的
    // 白色和黑色，具有非常低的 alpha 水平。
    // 我们改用 systemGray4Color 以避免 alpha 问题。
    return FLEXDynamicColor(systemGray4Color, lightGrayColor);
}

+ (UIColor *)tertiaryBackgroundColorWithAlpha:(CGFloat)alpha {
    return [[self tertiaryBackgroundColor] colorWithAlphaComponent:alpha];
}

+ (UIColor *)groupedBackgroundColor {
    return FLEXDynamicColor(
        systemGroupedBackgroundColor,
        colorWithHue:2.0/3.0 saturation:0.02 brightness:0.97 alpha:1
    );
}

+ (UIColor *)groupedBackgroundColorWithAlpha:(CGFloat)alpha {
    return [[self groupedBackgroundColor] colorWithAlphaComponent:alpha];
}

+ (UIColor *)secondaryGroupedBackgroundColor {
    return FLEXDynamicColor(secondarySystemGroupedBackgroundColor, whiteColor);
}

+ (UIColor *)secondaryGroupedBackgroundColorWithAlpha:(CGFloat)alpha {
    return [[self secondaryGroupedBackgroundColor] colorWithAlphaComponent:alpha];
}

#pragma mark - Text colors // 文本颜色

+ (UIColor *)primaryTextColor {
    return FLEXDynamicColor(labelColor, blackColor);
}

+ (UIColor *)deemphasizedTextColor {
    return FLEXDynamicColor(secondaryLabelColor, lightGrayColor);
}

#pragma mark - UI Element Colors // UI 元素颜色

+ (UIColor *)tintColor {
    #if FLEX_AT_LEAST_IOS13_SDK
    // 移除旧的 iOS 13 判断
    return UIColor.systemBlueColor;
    #else 
    // 使用 FLEXUtility 提供的 activeScene 方法
    UIWindowScene *scene = FLEXUtility.activeScene;
    if (scene && scene.windows.firstObject) {
        return scene.windows.firstObject.tintColor;
    }
    return UIColor.systemBlueColor;
    #endif
}

- (UIColor *)systemTintColor {
    // 使用 FLEXUtility 提供的方法获取 activeScene
    UIWindowScene *scene = FLEXUtility.activeScene;
    if (scene) {
        return scene.windows.firstObject.tintColor;
    }
    return nil;
}

+ (UIColor *)scrollViewBackgroundColor {
    return FLEXDynamicColor(
        systemGroupedBackgroundColor,
        colorWithHue:2.0/3.0 saturation:0.02 brightness:0.95 alpha:1
    );
}

+ (UIColor *)iconColor {
    return FLEXDynamicColor(labelColor, blackColor);
}

+ (UIColor *)borderColor {
    return [self primaryBackgroundColor];
}

+ (UIColor *)toolbarItemHighlightedColor {
    return FLEXDynamicColor(
        quaternaryLabelColor,
        colorWithHue:2.0/3.0 saturation:0.1 brightness:0.25 alpha:0.6
    );
}

+ (UIColor *)toolbarItemSelectedColor {
    return FLEXDynamicColor(
        secondaryLabelColor,
        colorWithHue:2.0/3.0 saturation:0.1 brightness:0.25 alpha:0.68
    );
}

+ (UIColor *)hairlineColor {
    return FLEXDynamicColor(systemGray3Color, colorWithWhite:0.75 alpha:1);
}

+ (UIColor *)destructiveColor {
    return FLEXDynamicColor(systemRedColor, redColor);
}

@end
