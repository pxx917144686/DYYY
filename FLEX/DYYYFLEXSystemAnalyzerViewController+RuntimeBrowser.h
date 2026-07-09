#import "DYYYFLEXSystemAnalyzerViewController.h"

@interface DYYYFLEXSystemAnalyzerViewController (RuntimeBrowser)

// 移植 RTB 的高级分析功能
- (NSDictionary *)getAdvancedSystemAnalysis;
- (NSArray *)getLoadedFrameworksInfo;
- (NSDictionary *)getBundleAnalysis;
- (NSArray *)getClassHierarchyTree;

@end