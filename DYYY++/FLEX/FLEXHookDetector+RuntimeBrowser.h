#import "FLEXHookDetector.h"

@interface FLEXHookDetector (RuntimeBrowser)

// 移植 RTB 的高级 Hook 检测
- (NSDictionary *)getDetailedHookAnalysis;
- (NSArray *)getSwizzledMethodsForClass:(Class)cls;
- (BOOL)isMethodSwizzled:(SEL)selector inClass:(Class)cls;
- (NSArray *)getKnownHookingFrameworks;

@end