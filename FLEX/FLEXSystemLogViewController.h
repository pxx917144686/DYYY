//
//  FLEXSystemLogViewController.h
//  FLEX
//
//  Created by Ryan Olson on 1/19/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewController.h"
#import "FLEXGlobalsEntry.h"  // 导入包含 FLEXGlobalsRow 枚举定义的头文件

@class FLEXMutableListSection;
@class FLEXSystemLogMessage;

@interface FLEXSystemLogViewController : FLEXTableViewController <FLEXGlobalsEntry>

@property (nonatomic, strong) NSString *filterText;
@property (nonatomic, readonly) FLEXMutableListSection *logMessages;

@end
