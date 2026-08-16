#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYDatabaseManager : NSObject

+ (instancetype)sharedManager;

- (void)createTables;
- (void)insertDataIntoTable:(NSString *)table bundleID:(NSString *)bundleID text:(NSString *)text;
- (NSArray<NSString *> *)queryTextsFromTable:(NSString *)table bundleID:(NSString *)bundleID;
- (NSArray<NSString *> *)allBundleIDsFromTable:(NSString *)table;
- (NSArray<NSDictionary *> *)queryAllRecordsFromTable:(NSString *)table limit:(NSInteger)limit;
- (void)clearTable:(NSString *)table;

- (BOOL)getSwitch:(NSString *)switchName bundleID:(NSString *)bundleID defaultValue:(BOOL)defaultValue;
- (void)setSwitch:(NSString *)switchName bundleID:(NSString *)bundleID value:(BOOL)value;

- (BOOL)isSSLEnabledForBundle:(NSString *)bundleID;
- (BOOL)isCryptoCaptureEnabledForBundle:(NSString *)bundleID;
- (BOOL)isDigestCaptureEnabledForBundle:(NSString *)bundleID;
- (BOOL)isHMACCaptureEnabledForBundle:(NSString *)bundleID;

// 是否有任一捕获开关开启（供 hook 入口一行短路，含内存缓存）
- (BOOL)anyCaptureActiveForBundle:(NSString *)bundleID;

- (void)insertLogText:(NSString *)logText;
- (NSArray<NSString *> *)queryLogs:(NSInteger)limit;

@end

NS_ASSUME_NONNULL_END
