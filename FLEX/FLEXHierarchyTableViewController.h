//
//  FLEXHierarchyTableViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-01.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewController.h"

@interface FLEXHierarchyTableViewController : FLEXTableViewController

+ (instancetype)windows:(NSArray<UIWindow *> *)allWindows
             viewsAtTap:(NSArray<UIView *> *)viewsAtTap
           selectedView:(UIView *)selectedView;

@property (nonatomic) UIView *selectedView;
@property (nonatomic) void(^didSelectRowAction)(UIView *selectedView);

@end
