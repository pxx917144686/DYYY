#import <Foundation/Foundation.h>
#import "FLEXDoKitLogEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitLogViewer : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<FLEXDoKitLogEntry *> *logEntries;

@property (nonatomic, assign) NSUInteger maxLogEntries;
@property (nonatomic, assign) FLEXDoKitLogLevel minimumLogLevel;

+ (instancetype)sharedInstance;

- (void)addLogEntry:(FLEXDoKitLogEntry *)entry;
- (void)addLogWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level;
- (void)clearLogs;

// ✅ 添加日志记录方法
- (void)logWithLevel:(FLEXDoKitLogLevel)level
             message:(NSString *)message
                 tag:(NSString *)tag
                file:(NSString *)file
                line:(NSUInteger)line;

// ✅ 添加过滤方法
- (NSArray<FLEXDoKitLogEntry *> *)filteredLogsWithLevel:(FLEXDoKitLogLevel)level;
- (NSArray<FLEXDoKitLogEntry *> *)filteredLogsWithTag:(NSString *)tag;
- (NSArray<FLEXDoKitLogEntry *> *)filteredLogsWithSearchText:(NSString *)searchText;

// ✅ 添加导出方法
- (NSString *)exportLogsAsString;
- (BOOL)exportLogsToFile:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END