//
//  PTDatabaseManager.h
//  派生自：
//
//  FMDatabase.h
//  FMDB( https://github.com/ccgus/fmdb )
//
//  创建者：Peng Tao，日期：15/11/23.
//
//  授权给 Flying Meat Inc.，依据一个或多个贡献者许可协议。
//  有关 Flying Meat Inc. 授权给您的条款，请参阅随此工作分发的 LICENSE 文件。

// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>
#import "FLEXSQLResult.h"

/// 遵循此协议的类应自动打开和关闭数据库
@protocol FLEXDatabaseManager <NSObject>

@required

/// @return 如果无法打开数据库，则返回 \c nil
+ (instancetype)managerForDatabase:(NSString *)path;

/// @return 所有表名的列表
- (NSArray<NSString *> *)queryAllTables;
- (NSArray<NSString *> *)queryAllColumnsOfTable:(NSString *)tableName;
- (NSArray<NSArray *> *)queryAllDataInTable:(NSString *)tableName;

@optional

- (NSArray<NSString *> *)queryRowIDsInTable:(NSString *)tableName;
- (FLEXSQLResult *)executeStatement:(NSString *)SQLStatement;

@end
