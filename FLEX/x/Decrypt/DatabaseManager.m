#import "DatabaseManager.h"
#import <sqlite3.h>

@interface DatabaseManager ()
@property (nonatomic, copy) NSString *dbPath;
@property (nonatomic) sqlite3 *db;
@property (nonatomic) dispatch_queue_t dbQueue;
- (BOOL)isAllowedSwitch:(NSString *)switchName;
@end

@implementation DatabaseManager

+ (instancetype)sharedManager {
    static DatabaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DatabaseManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dbQueue = dispatch_queue_create("com.database.queue", DISPATCH_QUEUE_SERIAL);
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

- (void)insertDataIntoTable:(NSString *)table bundleID:(NSString *)bundleID text:(NSString *)text {
    if (![self isAllowedTable:table] || !bundleID || !text) return;

    dispatch_async(self.dbQueue, ^{
        if (![self openDatabase]) return;

        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@ (bundleID, longText) VALUES (?, ?)", table];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, 2, text.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_step(stmt);
        }
        sqlite3_finalize(stmt);
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
    return value;
}

- (void)setSwitch:(NSString *)switchName bundleID:(NSString *)bundleID value:(BOOL)value {
    if (![self isAllowedSwitch:switchName] || !bundleID) return;

    dispatch_async(self.dbQueue, ^{
        if (![self openDatabase]) return;

        sqlite3_stmt *insertStmt = NULL;
        if (sqlite3_prepare_v2(self.db,
                               "INSERT OR IGNORE INTO kaiguan (bundleID) VALUES (?)",
                               -1, &insertStmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(insertStmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_step(insertStmt);
        }
        sqlite3_finalize(insertStmt);

        NSString *sql = [NSString stringWithFormat:@"UPDATE kaiguan SET %@ = ? WHERE bundleID = ?", switchName];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int(stmt, 1, value ? 1 : 0);
            sqlite3_bind_text(stmt, 2, bundleID.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_step(stmt);
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
        if (sqlite3_prepare_v2(self.db, "INSERT INTO yunxingrizhi (logText) VALUES (?)", -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, logText.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_step(stmt);
        }
        sqlite3_finalize(stmt);
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
