//
//  FLEXViewControllersViewController.h
//  FLEX
//
//  Created by Tanner Bennett on 2/13/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewController.h"

@interface FLEXViewControllersViewController : FLEXTableViewController

+ (instancetype)controllersForViews:(NSArray<UIView *> *)views;

@property (nonatomic, copy) NSArray *sections;
@property (nonatomic, readonly) NSArray *allSections;

@end
