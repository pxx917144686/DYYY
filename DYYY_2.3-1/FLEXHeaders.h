#ifndef FLEXHeaders_h
#define FLEXHeaders_h

// 原始的FLEX头文件
#import <FLEX/FLEX.h>

@interface FLEXObjectExplorerViewController (DYYY_Additions)
- (void)DYYY_showAnalysisResults:(id)results forClass:(Class)cls;
- (void)DYYY_analyzeUIHierarchy;
@end

@interface FLEXManager (DYYY_Additions)
@end

@interface DYYYObjectExplorerFactory : NSObject
+ (FLEXObjectExplorerViewController *)createExplorerForObject:(id)object;
@end

#endif /* FLEXHeaders_h */