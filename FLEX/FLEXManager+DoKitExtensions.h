//
//  FLEXManager+DoKitExtensions.h
//  FLEX
//
//  DoKit 功能增强扩展
//

#import "FLEXManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXManager (DoKitExtensions)

// DoKit 功能注册
- (void)registerDoKitEnhancements;

// 分类注册方法
- (void)registerPerformanceMonitoring;
- (void)registerNetworkDebugging;
- (void)registerUIDebugging;
- (void)registerMemoryDebugging;
- (void)registerAdvancedDebugging;
- (void)registerCommonTools;
- (void)registerLookinEnhancements;

@end

NS_ASSUME_NONNULL_END