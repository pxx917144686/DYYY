#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitLeakInfo : NSObject

@property (nonatomic, strong) NSString *className;
@property (nonatomic, assign) NSUInteger instanceCount;
@property (nonatomic, strong) NSDate *detectedTime;
@property (nonatomic, strong, nullable) NSArray *suspiciousInstances;

- (NSString *)formattedDetectionTime;
- (NSString *)severityLevel;

@end

@interface FLEXDoKitMemoryLeakDetector : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<FLEXDoKitLeakInfo *> *leakInfos;
@property (nonatomic, assign) BOOL isDetecting;

+ (instancetype)sharedInstance;

// 内存泄漏检测
- (void)startLeakDetection;
- (void)stopLeakDetection;

// 手动检测
- (void)performLeakDetection;

// 泄漏信息管理
- (void)clearLeakInfos;

@end

NS_ASSUME_NONNULL_END