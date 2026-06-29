#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FLEXLookinViewMode) {
    FLEXLookinViewModeHierarchy = 0,    // 层次模式
    FLEXLookinViewMode3D,               // 3D模式
    FLEXLookinViewModeSnapshot,         // 快照模式
    FLEXLookinViewModeComparison        // 对比模式
};

@protocol FLEXLookinInspectorDelegate <NSObject>
@optional
- (void)lookinInspector:(id)inspector didSelectView:(UIView *)view;
- (void)lookinInspector:(id)inspector didUpdateHierarchy:(NSArray *)hierarchy;
@end

@interface FLEXLookinViewNode : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSArray<FLEXLookinViewNode *> *children;
@property (nonatomic, weak) FLEXLookinViewNode *parent;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) CATransform3D transform;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) NSString *className;
@property (nonatomic, assign) NSInteger depth;
@end

@interface FLEXLookinInspector : NSObject

@property (nonatomic, weak) id<FLEXLookinInspectorDelegate> delegate;
@property (nonatomic, assign) FLEXLookinViewMode viewMode;
@property (nonatomic, strong, readonly) NSArray<FLEXLookinViewNode *> *viewHierarchy;
@property (nonatomic, weak, readonly) UIView *selectedView;
@property (nonatomic, assign, readonly) BOOL isInspecting;

+ (instancetype)sharedInstance;

// 检查控制
- (void)startInspecting;
- (void)stopInspecting;

// 视图选择
- (void)selectView:(UIView *)view;
- (void)clearSelection;

// 层次分析
- (void)refreshViewHierarchy;
- (FLEXLookinViewNode *)nodeForView:(UIView *)view;
- (NSArray<FLEXLookinViewNode *> *)flattenedHierarchy;

// 3D视图层次显示
- (void)show3DViewHierarchy;
- (void)hide3DViewHierarchy;

// 快照功能
- (UIImage *)captureViewSnapshot:(UIView *)view;
- (void)saveHierarchySnapshot:(NSString *)name;
- (NSArray *)loadSavedSnapshots;

// 对比功能
- (void)compareWithSnapshot:(NSString *)snapshotName;
- (NSArray *)findChangedViewsBetweenSnapshot:(NSString *)snapshotName;

@end

NS_ASSUME_NONNULL_END