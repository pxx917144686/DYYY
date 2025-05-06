//
//  UIBarButtonItem+FLEX.h
//  FLEX
//
//  Created by Tanner on 2/4/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>


#define FLEXBarButtonItem(title, tgt, sel) \
    [UIBarButtonItem flex_itemWithTitle:title target:tgt action:sel]
#define FLEXBarButtonItemSystem(item, tgt, sel) \
    [UIBarButtonItem flex_systemItem:UIBarButtonSystemItem##item target:tgt action:sel]

@interface UIBarButtonItem (FLEX)

@property (nonatomic, readonly, class) UIBarButtonItem *flex_flexibleSpace; // 弹性间隔
@property (nonatomic, readonly, class) UIBarButtonItem *flex_fixedSpace; // 固定间隔

+ (instancetype)flex_itemWithCustomView:(UIView *)customView; // 自定义视图项目
+ (instancetype)flex_backItemWithTitle:(NSString *)title; // 返回项目 (带标题)

+ (instancetype)flex_systemItem:(UIBarButtonSystemItem)item target:(id)target action:(SEL)action; // 系统项目

+ (instancetype)flex_itemWithTitle:(NSString *)title target:(id)target action:(SEL)action; // 项目 (带标题)
+ (instancetype)flex_doneStyleitemWithTitle:(NSString *)title target:(id)target action:(SEL)action; // 完成样式项目 (带标题)

+ (instancetype)flex_itemWithImage:(UIImage *)image target:(id)target action:(SEL)action; // 项目 (带图像)

+ (instancetype)flex_disabledSystemItem:(UIBarButtonSystemItem)item; // 禁用的系统项目
+ (instancetype)flex_disabledItemWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style; // 禁用的项目 (带标题)
+ (instancetype)flex_disabledItemWithImage:(UIImage *)image; // 禁用的项目 (带图像)

/// @return the receiver
- (UIBarButtonItem *)flex_withTintColor:(UIColor *)tint; // 设置着色

- (void)_setWidth:(CGFloat)width;

@end
