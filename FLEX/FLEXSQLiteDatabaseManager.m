// 遇到问题联系中文翻译作者：pxx917144686
//
//  PTDatabaseManager.m
//  PTDatabaseReader
//
//  由 Peng Tao 创建于 15/11/23.
//  版权所有 © 2015年 Peng Tao。保留所有权利。

#import "FLEXSQLiteDatabaseManager.h"
#import "FLEXManager.h"
#import "NSArray+FLEX.h"
#import "FLEXRuntimeConstants.h"
#import <sqlite3.h>

#define kQuery(name, str) static NSString * const QUERY_##name = str

kQuery(TABLENAMES, @"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
kQuery(ROWIDS, @"SELECT rowid FROM \"%@\" ORDER BY rowid ASC");

@interface FLEXSQLiteDatabaseManager ()
@property (nonatomic) sqlite3 *db;
@property (nonatomic, copy) NSString *path;
@end

@implementation FLEXSQLiteDatabaseManager

#pragma mark - FLEX数据库管理器

+ (instancetype)managerForDatabase:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        self.path = path;
    }
    
    return self;
}

- (void)dealloc {
    [self close];
}

- (BOOL)open {
    if (self.db) {
        return YES;
    }
    
    int err = sqlite3_open(self.path.UTF8String, &_db);

#if SQLITE_HAS_CODEC
    NSString *defaultSqliteDatabasePassword = FLEXManager.sharedManager.defaultSqliteDatabasePassword;
    if (defaultSqliteDatabasePassword) {
        const char *key = defaultSqliteDatabasePassword.UTF8String;
        sqlite3_key(_db, key, (int)strlen(key));
    }
#endif

    if (err != SQLITE_OK) {
        return [self storeErrorForLastTask:@"打开"];
    }
    
    return YES;
}
    
- (BOOL)close {
    if (!self.db) {
        return YES;
    }
    
    int  rc;
    BOOL retry, triedFinalizingOpenStatements = NO;
    
    do {
        retry = NO;
        rc    = sqlite3_close(_db);
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            if (!triedFinalizingOpenStatements) {
                triedFinalizingOpenStatements = YES;
                sqlite3_stmt *pStmt;
                while ((pStmt = sqlite3_next_stmt(_db, nil)) !=0) {
                    NSLog(@"正在关闭泄漏的语句");
                    sqlite3_finalize(pStmt);
                    retry = YES;
                }
            }
        } else if (SQLITE_OK != rc) {
            [self storeErrorForLastTask:@"关闭"];
            self.db = nil;
            return NO;
        }
    } while (retry);
    
    self.db = nil;
    return YES;
}

- (NSInteger)lastRowID {
    return (NSInteger)sqlite3_last_insert_rowid(self.db);
}

- (NSArray<NSString *> *)queryAllTables {
    return [[self executeStatement:QUERY_TABLENAMES].rows flex_mapped:^id(NSArray *table, NSUInteger idx) {
        return table.firstObject;
    }] ?: @[];
}

- (NSArray<NSString *> *)queryAllColumnsOfTable:(NSString *)tableName {
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info('%@')",tableName];
    FLEXSQLResult *results = [self executeStatement:sql];
    
    // https://github.com/FLEXTool/FLEX/issues/554
    if (!results.keyedRows.count) {
        sql = [NSString stringWithFormat:@"SELECT * FROM pragma_table_info('%@')", tableName];
        results = [self executeStatement:sql];
        
        // 回退到空查询
        if (!results.keyedRows.count) {
            sql = [NSString stringWithFormat:@"SELECT * FROM \"%@\" where 0=1", tableName];
            return [self executeStatement:sql].columns ?: @[];
        }
    }
    
    return [results.keyedRows flex_mapped:^id(NSDictionary *column, NSUInteger idx) {
        return column[@"name"];
    }] ?: @[];
}

- (NSArray<NSArray *> *)queryAllDataInTable:(NSString *)tableName {
    NSString *command = [NSString stringWithFormat:@"SELECT * FROM \"%@\"", tableName];
    return [self executeStatement:command].rows ?: @[];
}

- (NSArray<NSString *> *)queryRowIDsInTable:(NSString *)tableName {
    NSString *command = [NSString stringWithFormat:QUERY_ROWIDS, tableName];
    NSArray<NSArray<NSString *> *> *data = [self executeStatement:command].rows ?: @[];
    
    return [data flex_mapped:^id(NSArray<NSString *> *obj, NSUInteger idx) {
        return obj.firstObject;
    }];
}

- (FLEXSQLResult *)executeStatement:(NSString *)sql {
    return [self executeStatement:sql arguments:nil];
}

- (FLEXSQLResult *)executeStatement:(NSString *)sql arguments:(NSDictionary *)args {
    [self open];
    
    FLEXSQLResult *result = nil;
    
    sqlite3_stmt *pstmt;
    int status;
    if ((status = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &pstmt, 0)) == SQLITE_OK) {
        NSMutableArray<NSArray *> *rows = [NSMutableArray new];
        
        // 绑定参数（如果存在）
        if (![self bindParameters:args toStatement:pstmt]) {
            return self.lastResult;
        }
        
        // 获取列（对于 insert/update/delete，columnCount 将为 0）
        int columnCount = sqlite3_column_count(pstmt);
        NSArray<NSString *> *columns = [NSArray flex_forEachUpTo:columnCount map:^id(NSUInteger i) {
            return @(sqlite3_column_name(pstmt, (int)i));
        }];
        
        // 执行语句
        while ((status = sqlite3_step(pstmt)) == SQLITE_ROW) {
            // 如果是选择查询，则获取行
            int dataCount = sqlite3_data_count(pstmt);
            if (dataCount > 0) {
                [rows addObject:[NSArray flex_forEachUpTo:columnCount map:^id(NSUInteger i) {
                    return [self objectForColumnIndex:(int)i stmt:pstmt];
                }]];
            }
        }
        
        if (status == SQLITE_DONE) {
            // 对于 insert/update/delete，columnCount 将为 0
            if (rows.count || columnCount > 0) {
                // 我们执行了一个 SELECT 查询
                result = _lastResult = [FLEXSQLResult columns:columns rows:rows];
            } else {
                // 我们执行了一个类似 INSERT、UPDATE 或 DELETE 的查询
                int rowsAffected = sqlite3_changes(_db);
                NSString *message = [NSString stringWithFormat:@"%d 行受影响", rowsAffected];
                result = _lastResult = [FLEXSQLResult message:message];
            }
        } else {
            // 执行查询时发生错误
            result = _lastResult = [self errorResult:@"执行"];
        }
    } else {
        // 创建预处理语句时发生错误
        result = _lastResult = [self errorResult:@"预处理语句"];
    }
    
    sqlite3_finalize(pstmt);
    return result;
}


#pragma mark - 私有

/// @return 成功时返回 YES，如果遇到错误并存储在 \c lastResult 中则返回 NO
- (BOOL)bindParameters:(NSDictionary *)args toStatement:(sqlite3_stmt *)pstmt {
    for (NSString *param in args.allKeys) {
        int status = SQLITE_OK, idx = sqlite3_bind_parameter_index(pstmt, param.UTF8String);
        id value = args[param];
        
        if (idx == 0) {
            // 没有与该参数匹配的参数
            @throw NSInternalInconsistencyException;
        }
        
        // 空值
        if ([value isKindOfClass:[NSNull class]]) {
            status = sqlite3_bind_null(pstmt, idx);
        }
        // 字符串参数
        else if ([value isKindOfClass:[NSString class]]) {
            const char *str = [value UTF8String];
            status = sqlite3_bind_text(pstmt, idx, str, (int)strlen(str), SQLITE_TRANSIENT);
        }
        // 数据参数
        else if ([value isKindOfClass:[NSData class]]) {
            const void *blob = [value bytes];
            status = sqlite3_bind_blob64(pstmt, idx, blob, [value length], SQLITE_TRANSIENT);
        }
        // 基本类型参数
        else if ([value isKindOfClass:[NSNumber class]]) {
            FLEXTypeEncoding type = [value objCType][0];
            switch (type) {
                case FLEXTypeEncodingCBool:
                case FLEXTypeEncodingChar:
                case FLEXTypeEncodingUnsignedChar:
                case FLEXTypeEncodingShort:
                case FLEXTypeEncodingUnsignedShort:
                case FLEXTypeEncodingInt:
                case FLEXTypeEncodingUnsignedInt:
                case FLEXTypeEncodingLong:
                case FLEXTypeEncodingUnsignedLong:
                case FLEXTypeEncodingLongLong:
                case FLEXTypeEncodingUnsignedLongLong:
                    status = sqlite3_bind_int64(pstmt, idx, (sqlite3_int64)[value longValue]);
                    break;
                
                case FLEXTypeEncodingFloat:
                case FLEXTypeEncodingDouble:
                    status = sqlite3_bind_double(pstmt, idx, [value doubleValue]);
                    break;
                    
                default:
                    @throw NSInternalInconsistencyException;
                    break;
            }
        }
        // 不支持的类型
        else {
            @throw NSInternalInconsistencyException;
        }
        
        if (status != SQLITE_OK) {
            return [self storeErrorForLastTask:
                [NSString stringWithFormat:@"绑定名为“%@”的参数", param]
            ];
        }
    }
    
    return YES;
}

- (BOOL)storeErrorForLastTask:(NSString *)action {
    _lastResult = [self errorResult:action];
    return NO;
}

- (FLEXSQLResult *)errorResult:(NSString *)description {
    const char *error = sqlite3_errmsg(_db);
    NSString *message = error ? @(error) : [NSString
        stringWithFormat:@"(%@：空错误)", description
    ];
    
    return [FLEXSQLResult error:message];
}

- (id)objectForColumnIndex:(int)columnIdx stmt:(sqlite3_stmt*)stmt {
    int columnType = sqlite3_column_type(stmt, columnIdx);
    
    switch (columnType) {
        case SQLITE_INTEGER:
            return @(sqlite3_column_int64(stmt, columnIdx)).stringValue;
        case SQLITE_FLOAT:
            return  @(sqlite3_column_double(stmt, columnIdx)).stringValue;
        case SQLITE_BLOB:
            return [NSString stringWithFormat:@"数据 (%@ 字节)",
                @([self dataForColumnIndex:columnIdx stmt:stmt].length)
            ];
            
        default:
            // 其他所有情况默认使用字符串
            return [self stringForColumnIndex:columnIdx stmt:stmt] ?: NSNull.null;
    }
}
                
- (NSString *)stringForColumnIndex:(int)columnIdx stmt:(sqlite3_stmt *)stmt {
    if (sqlite3_column_type(stmt, columnIdx) == SQLITE_NULL || columnIdx < 0) {
        return nil;
    }
    
    const char *text = (const char *)sqlite3_column_text(stmt, columnIdx);
    return text ? @(text) : nil;
}

- (NSData *)dataForColumnIndex:(int)columnIdx stmt:(sqlite3_stmt *)stmt {
    if (sqlite3_column_type(stmt, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
        return nil;
    }
    
    const void *blob = sqlite3_column_blob(stmt, columnIdx);
    NSInteger size = (NSInteger)sqlite3_column_bytes(stmt, columnIdx);
    
    return blob ? [NSData dataWithBytes:blob length:size] : nil;
}

@end
