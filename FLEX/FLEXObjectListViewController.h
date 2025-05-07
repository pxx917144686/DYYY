// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjectListViewController.h
//  Flipboard
//
//  由 Ryan Olson 创建于 5/28/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXFilteringTableViewController.h"

@interface FLEXObjectListViewController : FLEXFilteringTableViewController

/// 这将返回实例列表，或者如果只有一个实例，
/// 则直接带您进入浏览器本身。
+ (UIViewController *)instancesOfClassWithName:(NSString *)className retained:(BOOL)retain;
+ (instancetype)subclassesOfClassWithName:(NSString *)className;
+ (instancetype)objectsWithReferencesToObject:(id)object retained:(BOOL)retain;

@end
