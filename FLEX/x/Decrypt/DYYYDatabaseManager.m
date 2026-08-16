#import "DYYYDatabaseManager.h"
#import <sqlite3.h>

@interface DYYYDatabaseManager ()
@property (nonatomic, copy) NSString *dbPath;
@property (nonatomic) sqlite3 *db;
@property (nonatomic) dispatch_queue_t dbQueue;
// 开关内存缓存：避免高频 hash/hmac hook 每次做同步 SQL 查询拖慢主流程
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *switchCache;
- (BOOL)isAllowedSwitch:(NSString *)switchName;
@end

@implementation DYYYDatabaseManager

+ (instancetype)sharedManager {
    static DYYYDatabaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DYYYDatabaseManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dbQueue = dispatch_queue_create("com.database.queue", DISPATCH_QUEUE_SERIAL);
        _switchCache = [NSMutableDictionary dictionary];
        [self setupDatabase];
    }
    return self;
}

- (void)setupDatabase {
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    _dbPath = [docPath stringByAppendingPathComponent:@"iosnixiangzhushoutest.sqlite"];
    [self openDatabase];
    [self createTables];
}

- (BOOL)openDatabase {
    if (_db) return YES;
    int result = sqlite3_open(self.dbPath.UTF8String, &_db);
    if (result != SQLITE_OK) {
        NSLog(@"Failed to open database: %d", result);
        return NO;
    }
    return YES;
}

- (void)closeDatabase {
    if (_db) {
        sqlite3_close(_db);
        _db = NULL;
    }
}

- (void)execSQL:(NSString *)sql {
    dispatch_sync(self.dbQueue, ^{
        if (![self openDatabase]) return;
        char *error = NULL;
        sqlite3_exec(self.db, sql.UTF8String, NULL, NULL, &error);
        if (error) {
            NSLog(@"SQL Error: %s", error);
            sqlite3_free(error);
        }
    });
}

- (void)createTables {
    NSArray *sqls = @[
        @"CREATE TABLE IF NOT EXISTS zhaiyao (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS hanmiyao (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS jiamisuanfa (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS yunxingrizhi (id INTEGER PRIMARY KEY AUTOINCREMENT, logText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS ssl_certificates (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS ssl_challenges (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS ssl_psk (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS proxy_settings (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS rsa_data (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS decrypt_data (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS url_responses (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS crypto_keys (bundleID TEXT, longText TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)",
        @"CREATE TABLE IF NOT EXISTS kaiguan (bundleID TEXT PRIMARY KEY, zongkaiguan INTEGER DEFAULT 0, zhaiyaokaiguan INTEGER DEFAULT 0, hanmiyaokaiguan INTEGER DEFAULT 0, jiamisuanfakaiguan INTEGER DEFAULT 0, ssl3kaiguan INTEGER DEFAULT 0, proxy_bypass INTEGER DEFAULT 0, rsa_encrypt INTEGER DEFAULT 0, rsa_decrypt INTEGER DEFAULT 0, rsa_sign INTEGER DEFAULT 0)"
    ];

    for (NSString *sql in sqls) {
        [self execSQL:sql];
    }

    // 启动时异步裁剪历史超限数据（仅影响本模块数据库，不影响插件主功能）
    [self trimOversizedTablesAsync];
}

- (BOOL)isAllowedTable:(NSString *)table {
    static NSSet *allowedTables = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedTables = [NSSet setWithArray:@[@"zhaiyao", @"hanmiyao", @"jiamisuanfa", @"yunxingrizhi",
                                               @"kaiguan", @"ssl_certificates", @"ssl_challenges",
                                               @"ssl_psk", @"proxy_settings", @"rsa_data", @"decrypt_data",
                                               @"url_responses", @"crypto_keys"]];
    });
    return [allowedTables containsObject:table];
}

// 每个数据表保留的最大记录数（防止刷视频时无限增长）
static const int kMaxRecordsPerTable = 500;
// 运行日志表保留的最大条数
static const int kMaxLogRecords = 200;

// 数据表清单（kaiguan 除外——开关设置必须保留）
static NSArray<NSString *> *DYYYDataTables(void) {
    static NSArray *tables = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tables = @[@"zhaiyao", @"hanmiyao", @"jiamisuanfa", @"yunxingrizhi",
                   @"ssl_certificates", @"ssl_challenges", @"ssl_psk", @"proxy_settings",
                   @"rsa_data", @"decrypt_data", @"url_responses", @"crypto_keys"];
    });
    return tables;
}

// 启动时异步裁剪超限旧数据，并在文件过大时 VACUUM 压缩物理大小
- (void)trimOversizedTablesAsync {
    dispatch_async(self.dbQueue, ^{
        if (![self openDatabase]) return;
        BOOL deletedAny = NO;
        for (NSString *table in DYYYDataTables()) {
            int keep = [table isEqualToString:@"yunxingrizhi"] ? kMaxLogRecords : kMaxRecordsPerTable;
            NSString *sql = [NSString stringWithFormat:
                @"DELETE FROM %@ WHERE ROWID NOT IN (SELECT ROWID FROM %@ ORDER BY ROWID DESC LIMIT %d)",
                table, table, keep];
            char *err = NULL;
            if (sqlite3_exec(self.db, sql.UTF8String, NULL, NULL, &err) == SQLITE_OK) {
                if (sqlite3_changes(self.db) > 0) deletedAny = YES;
            } else {
                NSLog(@"[DYYYDatabaseManager] trim failed for table %@: %s", table, err ?: "?");
                if (err) sqlite3_free(err);
            }
        }
        // 裁剪后若数据库物理文件仍然较大，执行 VACUUM 回收空间
        if (deletedAny && self.dbPath) {
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:self.dbPath error:NULL];
            long long fileSize = [attrs[NSFileSize] longLongValue];
            if (fileSize > 1024 * 1024) { // 超过 1MB 才压缩，避免每次启动都做昂贵的 VACUUM
                char *vacErr = NULL;
                if (sqlite3_exec(self.db, "VACUUM", NULL, NULL, &vacErr) != SQLITE_OK) {
                    NSLog(@"[DYYYDatabaseManager] VACUUM failed: %s", vacErr ?: "?");
                    if (vacErr) sqlite3_free(vacErr);
                }
            }
        }
    });
}

- (void)insertDataIntoTable:(NSString *)table bundleID:(NSString *)bundleID text:(NSString *)text {
    if (![self isAllowedTable:table] || !bundleID || !text) return;

    dispatch_async(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@ (bundleID, longText) VALUES (?, ?)", table];
        sqlite3_stmt *stmt = NULL;
        int rc = sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL);
        if (rc == SQLITE_OK) {
            int bind1 = sqlite3_bind_text(stmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            int bind2 = sqlite3_bind_text(stmt, 2, text.UTF8String, -1, SQLITE_TRANSIENT);
            if (bind1 != SQLITE_OK || bind2 != SQLITE_OK) {
                NSLog(@"[DYYYDatabaseManager] bind failed for table %@: %s", table, sqlite3_errmsg(self.db));
            }
            int step = sqlite3_step(stmt);
            if (step != SQLITE_DONE) {
                NSLog(@"[DYYYDatabaseManager] insert step failed for table %@: %d (%s)", table, step, sqlite3_errmsg(self.db));
            }
        } else {
            NSLog(@"[DYYYDatabaseManager] prepare failed for table %@: %d (%s)", table, rc, sqlite3_errmsg(self.db));
        }
        sqlite3_finalize(stmt);

        // 每表只保留最近 kMaxRecordsPerTable 条，超出部分自动删除，防止文件无限膨胀
        NSString *cleanup = [NSString stringWithFormat:
            @"DELETE FROM %@ WHERE ROWID NOT IN (SELECT ROWID FROM %@ ORDER BY ROWID DESC LIMIT %d)",
            table, table, kMaxRecordsPerTable];
        char *cleanupErr = NULL;
        sqlite3_exec(self.db, cleanup.UTF8String, NULL, NULL, &cleanupErr);
        if (cleanupErr) {
            NSLog(@"[DYYYDatabaseManager] cleanup failed for table %@: %s", table, cleanupErr);
            sqlite3_free(cleanupErr);
        }
    });
}

- (NSArray<NSString *> *)queryTextsFromTable:(NSString *)table bundleID:(NSString *)bundleID {
    if (![self isAllowedTable:table] || !bundleID) return @[];

    __block NSMutableArray *results = [NSMutableArray array];
    dispatch_sync(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"SELECT longText FROM %@ WHERE bundleID = ? ORDER BY ROWID DESC", table];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                const unsigned char *text = sqlite3_column_text(stmt, 0);
                if (text) {
                    [results addObject:[NSString stringWithUTF8String:(const char *)text]];
                }
            }
        }
        sqlite3_finalize(stmt);
    });
    return results;
}

- (NSArray<NSString *> *)allBundleIDsFromTable:(NSString *)table {
    if (![self isAllowedTable:table]) return @[];

    __block NSMutableArray *results = [NSMutableArray array];
    dispatch_sync(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"SELECT DISTINCT bundleID FROM %@", table];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                const unsigned char *text = sqlite3_column_text(stmt, 0);
                if (text) {
                    [results addObject:[NSString stringWithUTF8String:(const char *)text]];
                }
            }
        }
        sqlite3_finalize(stmt);
    });
    return results;
}

- (NSArray<NSDictionary *> *)queryAllRecordsFromTable:(NSString *)table limit:(NSInteger)limit {
    if (![self isAllowedTable:table]) return @[];
    if (limit <= 0) limit = 100;

    __block NSMutableArray *results = [NSMutableArray array];
    dispatch_sync(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY ROWID DESC LIMIT %ld", table, (long)limit];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            int colCount = sqlite3_column_count(stmt);
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                NSMutableDictionary *row = [NSMutableDictionary dictionary];
                for (int i = 0; i < colCount; i++) {
                    const char *colName = sqlite3_column_name(stmt, i);
                    const unsigned char *text = sqlite3_column_text(stmt, i);
                    if (colName && text) {
                        row[@(colName)] = [NSString stringWithUTF8String:(const char *)text];
                    }
                }
                [results addObject:row];
            }
        }
        sqlite3_finalize(stmt);
    });
    return results;
}

- (void)clearTable:(NSString *)table {
    if (![self isAllowedTable:table]) return;
    [self execSQL:[NSString stringWithFormat:@"DELETE FROM %@", table]];
}

- (BOOL)getSwitch:(NSString *)switchName bundleID:(NSString *)bundleID defaultValue:(BOOL)defaultValue {
    if (![self isAllowedSwitch:switchName] || !bundleID) return defaultValue;

    // 内存缓存优先，避免高频 hook 每次同步查库
    NSNumber *cached = nil;
    @synchronized (self.switchCache) {
        cached = self.switchCache[switchName];
    }
    if (cached) return cached.boolValue;

    __block BOOL value = defaultValue;
    dispatch_sync(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM kaiguan WHERE bundleID = ?", switchName];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                value = sqlite3_column_int(stmt, 0) != 0;
            }
        }
        sqlite3_finalize(stmt);
    });
    @synchronized (self.switchCache) {
        self.switchCache[switchName] = @(value);
    }
    return value;
}

- (void)setSwitch:(NSString *)switchName bundleID:(NSString *)bundleID value:(BOOL)value {
    if (![self isAllowedSwitch:switchName] || !bundleID) return;

    // 失效全部缓存（部分开关默认值回落到其他开关，如 jiamisuanfakaiguan → zongkaiguan），
    // 下次读取统一重新查库。kaiguan 表仅一行，全量失效开销可忽略
    @synchronized (self.switchCache) {
        [self.switchCache removeAllObjects];
    }

    dispatch_async(self.dbQueue, ^{
        if (![self openDatabase]) return;

        sqlite3_stmt *insertStmt = NULL;
        int rc = sqlite3_prepare_v2(self.db,
                               "INSERT OR IGNORE INTO kaiguan (bundleID) VALUES (?)",
                               -1, &insertStmt, NULL);
        if (rc == SQLITE_OK) {
            sqlite3_bind_text(insertStmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            int step = sqlite3_step(insertStmt);
            if (step != SQLITE_DONE) {
                NSLog(@"[DYYYDatabaseManager] insert switch step failed: %d (%s)", step, sqlite3_errmsg(self.db));
            }
        } else {
            NSLog(@"[DYYYDatabaseManager] insert switch prepare failed: %d (%s)", rc, sqlite3_errmsg(self.db));
        }
        sqlite3_finalize(insertStmt);

        NSString *sql = [NSString stringWithFormat:@"UPDATE kaiguan SET %@ = ? WHERE bundleID = ?", switchName];
        sqlite3_stmt *stmt = NULL;
        rc = sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL);
        if (rc == SQLITE_OK) {
            sqlite3_bind_int(stmt, 1, value ? 1 : 0);
            sqlite3_bind_text(stmt, 2, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            int step = sqlite3_step(stmt);
            if (step != SQLITE_DONE) {
                NSLog(@"[DYYYDatabaseManager] update switch step failed: %d (%s)", step, sqlite3_errmsg(self.db));
            }
        } else {
            NSLog(@"[DYYYDatabaseManager] update switch prepare failed: %d (%s)", rc, sqlite3_errmsg(self.db));
        }
        sqlite3_finalize(stmt);
    });
}

- (BOOL)isAllowedSwitch:(NSString *)switchName {
    static NSSet *allowedSwitches = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedSwitches = [NSSet setWithArray:@[@"zongkaiguan", @"zhaiyaokaiguan",
                                                  @"hanmiyaokaiguan", @"jiamisuanfakaiguan",
                                                  @"ssl3kaiguan", @"proxy_bypass", @"rsa_encrypt",
                                                  @"rsa_decrypt", @"rsa_sign"]];
    });
    return [allowedSwitches containsObject:switchName];
}

- (BOOL)isSSLEnabledForBundle:(NSString *)bundleID {
    return [self getSwitch:@"ssl3kaiguan" bundleID:bundleID defaultValue:NO];
}

- (BOOL)isCryptoCaptureEnabledForBundle:(NSString *)bundleID {
    return [self getSwitch:@"jiamisuanfakaiguan" bundleID:bundleID defaultValue:[self getSwitch:@"zongkaiguan" bundleID:bundleID defaultValue:NO]];
}

- (BOOL)isDigestCaptureEnabledForBundle:(NSString *)bundleID {
    return [self getSwitch:@"zhaiyaokaiguan" bundleID:bundleID defaultValue:[self getSwitch:@"zongkaiguan" bundleID:bundleID defaultValue:NO]];
}

- (BOOL)isHMACCaptureEnabledForBundle:(NSString *)bundleID {
    return [self getSwitch:@"hanmiyaokaiguan" bundleID:bundleID defaultValue:[self getSwitch:@"zongkaiguan" bundleID:bundleID defaultValue:NO]];
}

- (void)insertLogText:(NSString *)logText {
    if (!logText) return;

    dispatch_async(self.dbQueue, ^{
        if (![self openDatabase]) return;

        sqlite3_stmt *stmt = NULL;
        int rc = sqlite3_prepare_v2(self.db, "INSERT INTO yunxingrizhi (logText) VALUES (?)", -1, &stmt, NULL);
        if (rc == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, logText.UTF8String, -1, SQLITE_TRANSIENT);
            int step = sqlite3_step(stmt);
            if (step != SQLITE_DONE) {
                NSLog(@"[DYYYDatabaseManager] insert log step failed: %d (%s)", step, sqlite3_errmsg(self.db));
            }
        } else {
            NSLog(@"[DYYYDatabaseManager] insert log prepare failed: %d (%s)", rc, sqlite3_errmsg(self.db));
        }
        sqlite3_finalize(stmt);

        // 运行日志只保留最近 kMaxLogRecords 条，防止无限增长
        char *cleanupErr = NULL;
        const char *cleanup = "DELETE FROM yunxingrizhi WHERE ROWID NOT IN (SELECT ROWID FROM yunxingrizhi ORDER BY ROWID DESC LIMIT 200)";
        sqlite3_exec(self.db, cleanup, NULL, NULL, &cleanupErr);
        if (cleanupErr) {
            NSLog(@"[DYYYDatabaseManager] log cleanup failed: %s", cleanupErr);
            sqlite3_free(cleanupErr);
        }
    });
}

- (NSArray<NSString *> *)queryLogs:(NSInteger)limit {
    if (limit <= 0) limit = 100;

    __block NSMutableArray *results = [NSMutableArray array];
    dispatch_sync(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"SELECT logText FROM yunxingrizhi ORDER BY ROWID DESC LIMIT %ld", (long)limit];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                const unsigned char *text = sqlite3_column_text(stmt, 0);
                if (text) {
                    [results addObject:[NSString stringWithUTF8String:(const char *)text]];
                }
            }
        }
        sqlite3_finalize(stmt);
    });
    return results;
}

- (void)dealloc {
    [self closeDatabase];
}

@end
