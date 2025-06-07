#import "FLEXDoKitFloatingWindow.h"
#import "FLEXBugViewController.h"

@interface FLEXDoKitFloatingWindow ()
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation FLEXDoKitFloatingWindow

- (instancetype)init {
    // iOS 13+ 兼容性处理
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = scene;
                break;
            }
        }
        self = [super initWithWindowScene:windowScene];
    } else {
        self = [super initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    if (self) {
        [self setupWindow];
        [self setupFloatingButton];
    }
    return self;
}

- (void)setupWindow {
    self.windowLevel = UIWindowLevelAlert + 100;
    self.backgroundColor = [UIColor clearColor];
    self.hidden = YES;
    
    // 设置窗口大小为悬浮按钮大小
    CGFloat buttonSize = 60;
    self.frame = CGRectMake(
        [UIScreen mainScreen].bounds.size.width - buttonSize - 20,
        [UIScreen mainScreen].bounds.size.height / 2,
        buttonSize,
        buttonSize
    );
}

- (void)setupFloatingButton {
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(0, 0, 60, 60);
    self.floatingButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
    self.floatingButton.layer.cornerRadius = 30;
    self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.floatingButton.layer.shadowOpacity = 0.3;
    self.floatingButton.layer.shadowRadius = 4;
    
    // 设置按钮图标
    [self.floatingButton setTitle:@"🐛" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:24];
    
    [self.floatingButton addTarget:self 
                            action:@selector(floatingButtonTapped:) 
                  forControlEvents:UIControlEventTouchUpInside];
    
    // 添加拖拽手势
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:self.panGesture];
    
    [self addSubview:self.floatingButton];
}

- (void)floatingButtonTapped:(UIButton *)sender {
    // 打开FLEX Bug调试界面
    FLEXBugViewController *bugVC = [[FLEXBugViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bugVC];
    
    // 获取当前最顶层的视图控制器
    UIViewController *topViewController = [self topViewController];
    if (topViewController) {
        [topViewController presentViewController:navController animated:YES completion:nil];
    }
}

- (UIViewController *)topViewController {
    UIWindow *keyWindow = nil;
    
    // iOS 13+ 兼容性
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow && window != self) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    
    // Fallback for iOS 12 and below
    if (!keyWindow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    
    UIViewController *rootViewController = keyWindow.rootViewController;
    return [self topViewControllerFromRoot:rootViewController];
}

- (UIViewController *)topViewControllerFromRoot:(UIViewController *)root {
    if ([root isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController *)root;
        return [self topViewControllerFromRoot:navController.visibleViewController];
    }
    
    if ([root isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)root;
        return [self topViewControllerFromRoot:tabController.selectedViewController];
    }
    
    if (root.presentedViewController) {
        return [self topViewControllerFromRoot:root.presentedViewController];
    }
    
    return root;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview ?: self];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.isDragging = YES;
            self.lastPanPoint = self.center;
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint newCenter = CGPointMake(
                self.lastPanPoint.x + translation.x,
                self.lastPanPoint.y + translation.y
            );
            
            // 限制在屏幕边界内
            CGFloat buttonRadius = 30;
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            
            newCenter.x = MAX(buttonRadius, MIN(screenBounds.size.width - buttonRadius, newCenter.x));
            newCenter.y = MAX(buttonRadius + 40, MIN(screenBounds.size.height - buttonRadius - 40, newCenter.y)); // 40为状态栏和底部安全区域
            
            self.center = newCenter;
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isDragging = NO;
            
            // 自动吸附到屏幕边缘
            [UIView animateWithDuration:0.3 animations:^{
                CGRect screenBounds = [UIScreen mainScreen].bounds;
                CGFloat buttonRadius = 30;
                
                if (self.center.x < screenBounds.size.width / 2) {
                    // 吸附到左边
                    self.center = CGPointMake(buttonRadius + 10, self.center.y);
                } else {
                    // 吸附到右边
                    self.center = CGPointMake(screenBounds.size.width - buttonRadius - 10, self.center.y);
                }
            }];
            break;
        }
            
        default:
            break;
    }
}

- (void)show {
    self.hidden = NO;
    
    // 显示动画
    self.floatingButton.alpha = 0;
    self.floatingButton.transform = CGAffineTransformMakeScale(0.5, 0.5);
    
    [UIView animateWithDuration:0.3 
                          delay:0 
         usingSpringWithDamping:0.7 
          initialSpringVelocity:0.5 
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        self.floatingButton.alpha = 1.0;
        self.floatingButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hide {
    [UIView animateWithDuration:0.2 animations:^{
        self.floatingButton.alpha = 0;
        self.floatingButton.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        self.hidden = YES;
        self.floatingButton.alpha = 1.0;
        self.floatingButton.transform = CGAffineTransformIdentity;
    }];
}

@end