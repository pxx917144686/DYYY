//
//  UIBarButtonItem+FLEX.m
//  FLEX
//
//  Created by Tanner on 2/4/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
//  遇到问题联系中文翻译作者：pxx917144686

#import "UIBarButtonItem+FLEX.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIBarButtonItem (FLEX)

+ (UIBarButtonItem *)flex_flexibleSpace {
    return [self flex_systemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

+ (UIBarButtonItem *)flex_fixedSpace {
    UIBarButtonItem *fixed = [self flex_systemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixed.width = 60;
    return fixed;
}

+ (instancetype)flex_systemItem:(UIBarButtonSystemItem)item target:(id)target action:(SEL)action {
    return [[self alloc] initWithBarButtonSystemItem:item target:target action:action];
}

+ (instancetype)flex_itemWithCustomView:(UIView *)customView {
    return [[self alloc] initWithCustomView:customView];
}

+ (instancetype)flex_backItemWithTitle:(NSString *)title {
    return [self flex_itemWithTitle:title target:nil action:nil];
}

@end
