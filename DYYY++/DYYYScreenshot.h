#import <UIKit/UIKit.h>
#import "AwemeHeaders.h" 

// 工具函数声明
#ifdef __cplusplus
extern "C" {
#endif

UIWindow * _Nullable DYYY_findKeyWindow(void);

#ifdef __cplusplus
}
#endif

// 截图工具类声明
@interface DYYYScreenshot : NSObject

/**
 * 截取当前屏幕并保存到相册或者显示分享菜单
 * 此方法会自动显示选择区域界面
 */
+ (void)takeScreenshot;

/**
 * 截取指定视图并保存到相册
 * @param view 要截取的视图
 */
+ (void)takeScreenshotOfView:(UIView *)view;

/**
 * 捕获全屏截图
 */
+ (UIImage *)captureFullScreenshot:(UIWindow *)window;

/**
 * 裁剪图片
 */
+ (UIImage *)cropImage:(UIImage *)image toRect:(CGRect)cropRect;

/**
 * 显示分享菜单
 */
+ (void)presentShareSheetWithImage:(UIImage *)image fromView:(UIView *)sourceView;

@end

// 截图选择区域视图声明
@interface DYYYScreenshotSelectionView : UIView

@property (nonatomic, copy) void (^completionBlock)(CGRect selectedRect, BOOL cancelled);
@property (nonatomic, assign) CGPoint selectionStartPoint;
@property (nonatomic, assign) CGRect currentSelectionRect;
@property (nonatomic, strong) CAShapeLayer *selectionBorderLayer;
@property (nonatomic, strong) UIView *dimOverlayView;
@property (nonatomic, strong) CAShapeLayer *dimMaskLayer;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;

- (instancetype)initWithFrame:(CGRect)frame completion:(void (^)(CGRect selectedRect, BOOL cancelled))completion;
- (void)updateSelectionAppearance;

@end

// AWEPlayInteractionViewController 分类声明
@interface AWEPlayInteractionViewController (DYYYScreenshot)
- (void)dyyy_startCustomScreenshotProcess;
- (UIImage *)screenshotEntireScreen;
- (UIImage *)dyyy_cropImage:(UIImage *)image toRect:(CGRect)cropRect;
- (void)dyyy_presentShareSheetWithImage:(UIImage *)image fromView:(UIView *)sourceView;
@end

UIWindow *DYYY_findKeyWindow(void);