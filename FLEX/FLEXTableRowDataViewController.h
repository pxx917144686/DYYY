//
//  FLEXTableRowDataViewController.h
//  FLEX
//
//  Created by Chaoshuai Lu on 7/8/20.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXFilteringTableViewController.h"

@interface FLEXTableRowDataViewController : FLEXFilteringTableViewController

+ (instancetype)rows:(NSDictionary<NSString *, id> *)rowData;

@end
