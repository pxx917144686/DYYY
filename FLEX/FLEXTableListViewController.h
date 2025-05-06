//
//  PTTableListViewController.h
//  PTDatabaseReader
//
//  Created by Peng Tao on 15/11/23.
//  Copyright © 2015年 Peng Tao. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686


#import "FLEXFilteringTableViewController.h"

@interface FLEXTableListViewController : FLEXFilteringTableViewController

+ (BOOL)supportsExtension:(NSString *)extension;
- (instancetype)initWithPath:(NSString *)path;

@end
