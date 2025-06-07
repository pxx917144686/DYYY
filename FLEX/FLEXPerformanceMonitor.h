//
//  FLEXPerformanceMonitor.h
//  FLEX
//
//  Created based on DoKit performance tools.
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXPerformanceMonitor : NSObject

/**
 * 返回共享的性能监控器实例
 */
+ (instancetype)sharedInstance;

/**
 * 当前FPS值
 */
@property (nonatomic, assign, readonly) float currentFPS;

/**
 * CPU使用率（百分比）
 */
@property (nonatomic, assign, readonly) float cpuUsage;

/**
 * 内存使用量（MB）
 */
@property (nonatomic, assign, readonly) double memoryUsage;

/**
 * 上传流量（字节/秒）
 */
@property (nonatomic, assign, readonly) uint64_t uploadFlowBytes;

/**
 * 下载流量（字节/秒）
 */
@property (nonatomic, assign, readonly) uint64_t downloadFlowBytes;

/**
 * 启动所有监控
 */
- (void)startAllMonitoring;

/**
 * 停止所有监控
 */
- (void)stopAllMonitoring;

/**
 * 开始FPS监控
 */
- (void)startFPSMonitoring;

/**
 * 停止FPS监控
 */
- (void)stopFPSMonitoring;

/**
 * 开始CPU监控
 */
- (void)startCPUMonitoring;

/**
 * 停止CPU监控
 */
- (void)stopCPUMonitoring;

/**
 * 开始内存监控
 */
- (void)startMemoryMonitoring;

/**
 * 停止内存监控
 */
- (void)stopMemoryMonitoring;

/**
 * 开始网络流量监控
 */
- (void)startNetworkMonitoring;

/**
 * 停止网络流量监控
 */
- (void)stopNetworkMonitoring;

/**
 * 开始跟踪类加载时间
 */
- (void)startTrackingClassLoadTime;

/**
 * 获取类加载时间信息
 */
- (NSArray *)getClassLoadTimeInfo;

/**
 * 开始方法性能分析
 */
- (void)startMethodProfiling;

/**
 * 停止方法性能分析
 */
- (void)stopMethodProfiling;

/**
 * 获取分析结果
 */
- (NSArray *)getProfilingResults;

@end

NS_ASSUME_NONNULL_END