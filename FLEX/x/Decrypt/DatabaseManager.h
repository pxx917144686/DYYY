#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseManager : NSObject

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

- (void)insertLogText:(NSString *)logText;
- (NSArray<NSString *> *)queryLogs:(NSInteger)limit;

@end

NS_ASSUME_NONNULL_END
