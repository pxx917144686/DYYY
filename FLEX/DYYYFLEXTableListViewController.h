//
//  PTTableListViewController.h
//  PTDatabaseReader
//
//  Created by Peng Tao on 15/11/23.
//  Copyright © 2015年 Peng Tao. All rights reserved.
//

#import "DYYYFLEXFilteringTableViewController.h"

@interface DYYYFLEXTableListViewController : DYYYFLEXFilteringTableViewController

+ (BOOL)supportsExtension:(NSString *)extension;
- (instancetype)initWithPath:(NSString *)path;

@end
