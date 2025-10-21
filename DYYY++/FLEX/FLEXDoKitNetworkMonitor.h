#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitNetworkMonitor : NSObject

@property (nonatomic, strong, readonly) NSMutableArray *networkRequests;

+ (instancetype)sharedInstance;

// 网络监控
- (void)startNetworkMonitoring;
- (void)stopNetworkMonitoring;

// Mock功能
- (BOOL)isMockEnabled;
- (void)enableMockMode;
- (void)disableMockMode;
- (void)addMockRule:(NSDictionary *)rule;
- (void)removeMockRule:(NSDictionary *)rule;

// 弱网模拟
- (void)simulateSlowNetwork:(NSTimeInterval)delay;
- (void)simulateNetworkError;
- (void)resetNetworkSimulation;

@end

NS_ASSUME_NONNULL_END