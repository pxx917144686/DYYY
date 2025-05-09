#import <UIKit/UIKit.h>

// 基本FLEX类声明
@interface FLEXObjectExplorerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (nonatomic, strong, readonly) id object;
- (NSArray *)customRightBarButtonItems;

// DYYY添加的方法
- (void)DYYY_performDeepClassAnalysis;
- (void)DYYY_analyzeUIHierarchy;
- (void)DYYY_analyzeViewControllerLifecycle;
- (void)DYYY_analyzeMemoryGraph;
- (void)DYYY_generateAdvancedLogos;
- (void)DYYY_setupRealtimeMonitoring;
- (void)DYYY_analyzeClass;
- (void)DYYY_advancedAnalyzeObject;
- (void)DYYY_injectMethodTracing;
- (void)DYYY_showAllMethodsForTracing:(NSArray *)methodNames;
- (void)DYYY_showAnalysisResults:(NSDictionary *)results forClass:(Class)cls;
- (CGFloat)DYYY_drawViewHierarchy:(UIView *)view inContainer:(UIView *)container startingAtY:(CGFloat)y indent:(CGFloat)indent maxDepth:(NSInteger)maxDepth;
- (void)DYYY_showViewDetails:(UIButton *)sender;
- (NSString *)DYYY_colorToString:(UIColor *)color;
- (void)DYYY_showMemoryAnalysisResults:(NSDictionary *)memoryInfo;
- (void)DYYY_showMethodMonitoringOptions;
- (void)DYYY_setupPropertyMonitoring;
- (void)DYYY_setupTouchEventMonitoring;
- (void)DYYY_viewTapped:(UITapGestureRecognizer *)recognizer;
- (void)DYYY_setupLifecycleMonitoring;
- (void)DYYY_viewControllerLifecycleNotification:(NSNotification *)notification;
- (void)DYYY_setupMemoryMonitoring;
- (void)DYYY_checkMemoryUsage;
- (void)DYYY_generateMonitoringCode;
@end

@interface FLEXManager : NSObject
+ (instancetype)sharedManager;
- (void)showExplorer;
@end