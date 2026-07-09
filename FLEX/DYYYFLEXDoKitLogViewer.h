#import <Foundation/Foundation.h>
#import "DYYYFLEXDoKitLogEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface DYYYFLEXDoKitLogViewer : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<DYYYFLEXDoKitLogEntry *> *logEntries;

@property (nonatomic, assign) NSUInteger maxLogEntries;
@property (nonatomic, assign) FLEXDoKitLogLevel minimumLogLevel;

+ (instancetype)sharedInstance;

- (void)addLogEntry:(DYYYFLEXDoKitLogEntry *)entry;
- (void)addLogWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level;
- (void)clearLogs;

// ✅ 添加日志记录方法
- (void)logWithLevel:(FLEXDoKitLogLevel)level
             message:(NSString *)message
                 tag:(NSString *)tag
                file:(NSString *)file
                line:(NSUInteger)line;

// ✅ 添加过滤方法
- (NSArray<DYYYFLEXDoKitLogEntry *> *)filteredLogsWithLevel:(FLEXDoKitLogLevel)level;
- (NSArray<DYYYFLEXDoKitLogEntry *> *)filteredLogsWithTag:(NSString *)tag;
- (NSArray<DYYYFLEXDoKitLogEntry *> *)filteredLogsWithSearchText:(NSString *)searchText;

// ✅ 添加导出方法
- (NSString *)exportLogsAsString;
- (BOOL)exportLogsToFile:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END