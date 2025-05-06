//
//  UIView+FLEX_Layout.m
//  FLEX
//
//  Created by Tanner Bennett on 7/18/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "UIView+FLEX_Layout.h"

@implementation UIView (FLEX_Layout)

- (void)flex_centerInView:(UIView *)view {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [self.centerYAnchor constraintEqualToAnchor:view.centerYAnchor]
    ]];
}

- (void)flex_pinEdgesTo:(UIView *)view {
    [self flex_pinEdgesTo:view withInsets:UIEdgeInsetsZero];
}

- (void)flex_pinEdgesTo:(UIView *)view withInsets:(UIEdgeInsets)insets {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:view.topAnchor constant:insets.top],
        [self.leftAnchor constraintEqualToAnchor:view.leftAnchor constant:insets.left],
        [self.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-insets.bottom],
        [self.rightAnchor constraintEqualToAnchor:view.rightAnchor constant:-insets.right]
    ]];
}

- (void)flex_pinEdgesToSuperview {
    [self flex_pinEdgesToSuperviewWithInsets:UIEdgeInsetsZero];
}

- (void)flex_pinEdgesToSuperviewWithInsets:(UIEdgeInsets)insets {
    [self flex_pinEdgesTo:self.superview withInsets:insets];
}

- (void)flex_pinEdgesToSuperviewWithInsets:(UIEdgeInsets)insets aboveView:(UIView *)sibling {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *superview = self.superview;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:superview.topAnchor constant:insets.top],
        [self.leftAnchor constraintEqualToAnchor:superview.leftAnchor constant:insets.left],
        [self.rightAnchor constraintEqualToAnchor:superview.rightAnchor constant:-insets.right],
        [self.bottomAnchor constraintEqualToAnchor:sibling.topAnchor constant:-insets.bottom]
    ]];
}

- (void)flex_pinEdgesToSuperviewWithInsets:(UIEdgeInsets)insets belowView:(UIView *)sibling {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *superview = self.superview;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.topAnchor constraintEqualToAnchor:sibling.bottomAnchor constant:insets.top],
        [self.leftAnchor constraintEqualToAnchor:superview.leftAnchor constant:insets.left],
        [self.rightAnchor constraintEqualToAnchor:superview.rightAnchor constant:-insets.right],
        [self.bottomAnchor constraintEqualToAnchor:superview.bottomAnchor constant:-insets.bottom]
    ]];
}

@end
