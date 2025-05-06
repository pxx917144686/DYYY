// 遇到问题联系中文翻译作者：pxx917144686
//
//  PTDatabaseManager.h
//  派生自：
//
//  FMDatabase.h
//  FMDB( https://github.com/ccgus/fmdb )
//
//  由 Peng Tao 创建于 15/11/23.
//
//  根据一份或多份贡献者许可协议授权给 Flying Meat Inc.。
//  有关 Flying Meat Inc. 授权给您的条款，请参阅随此作品分发的 LICENSE 文件。

#import <Foundation/Foundation.h>
#import "FLEXDatabaseManager.h"
#import "FLEXSQLResult.h"

@interface FLEXSQLiteDatabaseManager : NSObject <FLEXDatabaseManager>

/// 包含上次操作的结果，可能是一个错误
@property (nonatomic, readonly) FLEXSQLResult *lastResult;
/// 调用 \c sqlite3_last_insert_rowid()
@property (nonatomic, readonly) NSInteger lastRowID;

/// 给定一个类似 'SELECT * from @table where @col = @val' 的语句和类似
/// { @"table": @"Album", @"col": @"year", @"val" @1 } 的参数，此方法将
/// 调用该语句并将给定的参数正确绑定到该语句。
///
/// 您可以传递 NSString、NSData、NSNumber 或 NSNull 作为值。
- (FLEXSQLResult *)executeStatement:(NSString *)statement arguments:(NSDictionary<NSString *, id> *)args;

@end
