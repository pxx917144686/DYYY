//
//  UIMenu+FLEX.h
//  FLEX
//
//  Created by Tanner on 1/28/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@interface UIMenu (FLEX)

+ (instancetype)flex_inlineMenuWithTitle:(NSString *)title // 内联菜单 (带标题)
                                   image:(UIImage *)image
                                children:(NSArray<UIMenuElement *> *)children;

- (instancetype)flex_collapsed; // 折叠菜单

@end
