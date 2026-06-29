//
//  FLEXDoKitNetworkMonitor.h
//  FLEX++
//
//  基于 FLEX 原生网络监听能力的增强型网络监控器
//  提供网络请求监控、Mock 数据、弱网模拟等功能
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 网络请求记录变更通知
extern NSString *const FLEXDoKitNetworkRequestRecordedNotification;
extern NSString *const FLEXDoKitNetworkResponseRecordedNotification;

@interface FLEXDoKitNetworkMonitor : NSObject

/// 所有网络请求记录（字典数组格式，兼容原有接口）
@property (nonatomic, strong, readonly) NSMutableArray *networkRequests;

/// 单例
+ (instancetype)sharedInstance;

#pragma mark - 网络监控

/// 启动网络监控
- (void)startNetworkMonitoring;

/// 停止网络监控
- (void)stopNetworkMonitoring;

/// 清除所有网络请求记录
- (void)clearAllNetworkRequests;

/// 是否正在监控
@property (nonatomic, assign, readonly) BOOL isMonitoring;

#pragma mark - Mock功能

/// Mock 模式是否启用
- (BOOL)isMockEnabled;

/// 启用 Mock 模式
- (void)enableMockMode;

/// 禁用 Mock 模式
- (void)disableMockMode;

/// 添加 Mock 规则
/// @param rule 规则字典，需包含 url、method、responseData、statusCode 等字段
- (void)addMockRule:(NSDictionary *)rule;

/// 移除 Mock 规则
- (void)removeMockRule:(NSDictionary *)rule;

/// 获取所有 Mock 规则
- (NSDictionary *)allMockRules;

#pragma mark - 弱网模拟

/// 模拟慢网络
/// @param delay 延迟时间（秒）
- (void)simulateSlowNetwork:(NSTimeInterval)delay;

/// 模拟网络错误
- (void)simulateNetworkError;

/// 重置网络模拟
- (void)resetNetworkSimulation;

/// 当前网络延迟
@property (nonatomic, assign, readonly) NSTimeInterval networkDelay;

/// 是否模拟网络错误
@property (nonatomic, assign, readonly) BOOL shouldSimulateError;

@end

NS_ASSUME_NONNULL_END
