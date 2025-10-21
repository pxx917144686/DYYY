#import "FLEXMemoryAnalyzer.h"

@interface FLEXMemoryAnalyzer (RuntimeBrowser)

// 移植 RTB 的内存分析功能
- (NSDictionary *)getDetailedHeapSnapshot;
- (NSArray *)findMemoryLeaks;
- (NSArray *)getDetailedMemoryZoneInfo;  // ✅ 重命名以避免冲突
- (NSDictionary *)getClassInstanceDistribution;

@end