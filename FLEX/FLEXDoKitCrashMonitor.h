#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FLEXDoKitCrashType) {
    FLEXDoKitCrashTypeSignal,
    FLEXDoKitCrashTypeException,
    FLEXDoKitCrashTypeKVO,
    FLEXDoKitCrashTypeUnrecognizedSelector
};

@interface FLEXDoKitCrashInfo : NSObject
@property (nonatomic, assign) FLEXDoKitCrashType type;
@property (nonatomic, strong) NSString *reason;
@property (nonatomic, strong) NSArray *callStack;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSDictionary *deviceInfo;

// ✅ 只声明方法，不实现
- (NSDictionary *)dictionaryRepresentation;

@end

@interface FLEXDoKitCrashMonitor : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<FLEXDoKitCrashInfo *> *crashLogs;

+ (instancetype)sharedInstance;

// 崩溃监控
- (void)startCrashMonitoring;
- (void)stopCrashMonitoring;

// 崩溃日志管理
- (void)clearCrashLogs;
- (NSString *)exportCrashLogsAsString;

@end

NS_ASSUME_NONNULL_END