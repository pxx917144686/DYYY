#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FLEXRevealInspectorDelegate <NSObject>
@optional
- (void)revealInspector:(id)inspector didSelectView:(UIView *)view;
- (void)revealInspector:(id)inspector didDeselectView:(UIView *)view;
@end

@interface FLEXRevealLikeInspector : NSObject

@property (nonatomic, weak) id<FLEXRevealInspectorDelegate> delegate;
@property (nonatomic, assign) BOOL isInspecting;
@property (nonatomic, strong, readonly) UIView *selectedView;

+ (instancetype)sharedInstance;

// 3D视图层次结构
- (void)show3DViewHierarchy;
- (void)hide3DViewHierarchy;

// 视图约束检查
- (void)showViewConstraints:(UIView *)view;
- (void)hideViewConstraints;

// 视图测量
- (void)showViewMeasurements:(UIView *)view;
- (void)hideViewMeasurements;

// 实时编辑
- (void)enableLiveEditing;
- (void)disableLiveEditing;
- (void)modifyView:(UIView *)view properties:(NSDictionary *)properties;
- (void)showLiveEditingPanelForView:(UIView *)view;

// 视图捕获和截图
- (UIImage *)captureViewHierarchy3D;
- (void)exportViewHierarchyDescription;

@end

NS_ASSUME_NONNULL_END