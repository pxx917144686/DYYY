#import "DYYYFLEXDoKitFloatingWindow.h"
#import "DYYYFLEXManager.h"

@interface DYYYFLEXDoKitFloatingWindow ()
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation DYYYFLEXDoKitFloatingWindow

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
    // 打开FLEX界面
    [[DYYYFLEXManager sharedManager] showExplorer];
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
            newCenter.y = MAX(buttonRadius + 40, MIN(screenBounds.size.height - buttonRadius - 40, newCenter.y));
            
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
                    self.center = CGPointMake(buttonRadius + 10, self.center.y);
                } else {
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
