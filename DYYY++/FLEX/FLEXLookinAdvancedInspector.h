#import <Foundation/Foundation.h>
#import "FLEXLookinInspector.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXLookinAdvancedInspector : FLEXLookinInspector

// 高级分析功能
- (NSArray *)analyzeViewPerformance:(UIView *)view;
- (NSDictionary *)detectUIIssues:(UIView *)view;
- (NSArray *)suggestOptimizations:(UIView *)view;

// 布局分析
- (NSArray *)analyzeAutoLayoutConstraints:(UIView *)view;
- (NSArray *)detectConstraintConflicts:(UIView *)view;
- (NSDictionary *)calculateLayoutMetrics:(UIView *)view;

// 渲染分析
- (NSDictionary *)analyzeRenderingPerformance:(UIView *)view;
- (NSArray *)detectOffscreenRendering:(UIView *)view;
- (NSArray *)detectBlendingIssues:(UIView *)view;

@end

NS_ASSUME_NONNULL_END