//
//  FLEXRuntimeClient+Optimization.h
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXRuntimeClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXRuntimeClient (Optimization)

// 检查运行时是否已就绪
+ (BOOL)isRuntimeReady;

// 确保运行时已初始化
+ (void)ensureRuntimeInitialized;

// 异步重新加载库列表
- (void)reloadLibrariesListAsync:(void(^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END