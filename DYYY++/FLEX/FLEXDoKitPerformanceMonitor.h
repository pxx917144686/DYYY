#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitPerformanceMonitor : NSObject

@property (nonatomic, assign, readonly) CGFloat currentFPS;
@property (nonatomic, assign, readonly) CGFloat currentCPUUsage;
@property (nonatomic, assign, readonly) CGFloat currentMemoryUsage;
@property (nonatomic, assign, readonly) NSTimeInterval appLaunchTime;

+ (instancetype)sharedInstance;

// FPS监控
- (void)startFPSMonitoring;
- (void)stopFPSMonitoring;

// CPU监控
- (void)startCPUMonitoring;
- (void)stopCPUMonitoring;

// 内存监控
- (void)startMemoryMonitoring;
- (void)stopMemoryMonitoring;

// 卡顿检测
- (void)startLagDetection;
- (void)stopLagDetection;

// 启动耗时
- (void)calculateAppLaunchTime;

@end

NS_ASSUME_NONNULL_END