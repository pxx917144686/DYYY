//
//  FLEXColor.h
//  FLEX
//
//  创建者：Benny Wong，日期：6/18/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXColor : NSObject

@property (readonly, class) UIColor *primaryBackgroundColor;
+ (UIColor *)primaryBackgroundColorWithAlpha:(CGFloat)alpha;

@property (readonly, class) UIColor *secondaryBackgroundColor;
+ (UIColor *)secondaryBackgroundColorWithAlpha:(CGFloat)alpha;

@property (readonly, class) UIColor *tertiaryBackgroundColor;
+ (UIColor *)tertiaryBackgroundColorWithAlpha:(CGFloat)alpha;

@property (readonly, class) UIColor *groupedBackgroundColor;
+ (UIColor *)groupedBackgroundColorWithAlpha:(CGFloat)alpha;

@property (readonly, class) UIColor *secondaryGroupedBackgroundColor;
+ (UIColor *)secondaryGroupedBackgroundColorWithAlpha:(CGFloat)alpha;

// 文本颜色
@property (readonly, class) UIColor *primaryTextColor;
@property (readonly, class) UIColor *deemphasizedTextColor;

// UI 元素颜色
@property (readonly, class) UIColor *tintColor;
@property (readonly, class) UIColor *scrollViewBackgroundColor;
@property (readonly, class) UIColor *iconColor;
@property (readonly, class) UIColor *borderColor;
@property (readonly, class) UIColor *toolbarItemHighlightedColor;
@property (readonly, class) UIColor *toolbarItemSelectedColor;
@property (readonly, class) UIColor *hairlineColor;
@property (readonly, class) UIColor *destructiveColor;

@end

NS_ASSUME_NONNULL_END
