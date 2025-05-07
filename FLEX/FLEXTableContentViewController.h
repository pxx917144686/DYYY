// 遇到问题联系中文翻译作者：pxx917144686
//
//  PTTableContentViewController.h
//  PTDatabaseReader
//
//  由 Peng Tao 创建于 15/11/23.
//  版权所有 © 2015年 Peng Tao。保留所有权利。
//

#import <UIKit/UIKit.h>
#import "FLEXDatabaseManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXTableContentViewController : UIViewController

/// 显示一个包含给定列、行和名称的可变表格。
///
/// @param columnNames 不言自明。
/// @param rowData 行数组，其中每一行是列数据的数组。
/// @param rowIDs 字符串类型的行 ID 数组。删除行时必需。
/// @param tableName 正在查看的表的可选名称（如果存在）。启用添加行功能。
/// @param databaseManager 一个可选的管理器，允许修改表格。
///        删除行时必需。如果提供了 \c tableName，则添加行时也必需。
+ (instancetype)columns:(NSArray<NSString *> *)columnNames
                   rows:(NSArray<NSArray<NSString *> *> *)rowData
                 rowIDs:(NSArray<NSString *> *)rowIDs
              tableName:(NSString *)tableName
               database:(id<FLEXDatabaseManager>)databaseManager;

/// 显示一个包含给定列和行的不可变表格。
+ (instancetype)columns:(NSArray<NSString *> *)columnNames
                   rows:(NSArray<NSArray<NSString *> *> *)rowData;

@end

NS_ASSUME_NONNULL_END
