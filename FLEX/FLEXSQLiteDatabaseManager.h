//
//  PTDatabaseManager.h
//  派生自:
//
//  FMDatabase.h
//  FMDB( https://github.com/ccgus/fmdb )
//
//  由 Peng Tao 创建于 15/11/23.
//
//  根据一个或多个贡献者许可协议授权给 Flying Meat Inc.。
//  有关 Flying Meat Inc. 许可此文件给您的条款，
//  请参阅随此作品分发的 LICENSE 文件。

#import <Foundation/Foundation.h>
#import "FLEXDatabaseManager.h"
#import "FLEXSQLResult.h"

@interface FLEXSQLiteDatabaseManager : NSObject <FLEXDatabaseManager>

/// 包含最后一次操作的结果，可能是一个错误
@property (nonatomic, readonly) FLEXSQLResult *lastResult;
/// 调用 \c sqlite3_last_insert_rowid()
@property (nonatomic, readonly) NSInteger lastRowID;

/// 给定一个语句，如 'SELECT * from @table where @col = @val' 和参数
/// 如 { @"table": @"Album", @"col": @"year", @"val" @1 }，此方法将
/// 执行该语句并正确地将给定的参数绑定到语句中。
///
/// 您可以传递 NSStrings、NSData、NSNumbers 或 NSNulls 作为值。
- (FLEXSQLResult *)executeStatement:(NSString *)statement arguments:(NSDictionary<NSString *, id> *)args;

@end
