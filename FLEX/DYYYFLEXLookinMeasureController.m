#import "DYYYFLEXLookinMeasureController.h"
#import "DYYYFLEXLookinMeasureResultView.h"

@interface DYYYFLEXLookinMeasureController ()
@property (nonatomic, strong) DYYYFLEXLookinMeasureResultView *resultView;
@property (nonatomic, strong) UIWindow *measureWindow;
@property (nonatomic, strong) UILabel *shortcutLabel;
@property (nonatomic, strong) UIButton *lockSwitchButton;
@end

@implementation DYYYFLEXLookinMeasureController

+ (instancetype)sharedInstance {
    static DYYYFLEXLookinMeasureController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _measureState = FLEXLookinMeasureState_no;
        [self setupMeasureWindow];
    }
    return self;
}

- (void)setupMeasureWindow {
    self.measureWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.measureWindow.windowLevel = UIWindowLevelAlert + 1000;
    self.measureWindow.backgroundColor = [UIColor clearColor];
    self.measureWindow.hidden = YES;
    
    // ✅ 使用弱引用避免循环引用
    __weak typeof(self) weakSelf = self;
    
    // 创建测量结果视图
    self.resultView = [[DYYYFLEXLookinMeasureResultView alloc] init];
    [self.measureWindow addSubview:self.resultView];
    
    // 修复手势识别器的循环引用
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] 
                                         initWithTarget:weakSelf
                                         action:@selector(handlePanGesture:)];
    [self.measureWindow addGestureRecognizer:panGesture];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] 
                                        initWithTarget:weakSelf
                                        action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.measureWindow addGestureRecognizer:doubleTap];
    
    // 修复按钮事件的循环引用
    [self.lockSwitchButton addTarget:weakSelf 
                              action:@selector(lockButtonTapped:) 
                    forControlEvents:UIControlEventTouchUpInside];
}

- (void)startMeasuring {
    self.measureState = FLEXLookinMeasureState_unlocked;
    self.measureWindow.hidden = NO;
    self.shortcutLabel.hidden = NO;
    
    // 显示提示
    [self layoutSubviews];
}

- (void)stopMeasuring {
    self.measureState = FLEXLookinMeasureState_no;
    self.measureWindow.hidden = YES;
    self.lockSwitchButton.hidden = YES;
    self.lockSwitchButton.selected = NO;
    self.shortcutLabel.hidden = YES;
}

- (void)lockMeasuring:(BOOL)locked {
    if (locked) {
        self.measureState = FLEXLookinMeasureState_locked;
        self.lockSwitchButton.hidden = NO;
        self.lockSwitchButton.selected = YES;
        self.shortcutLabel.hidden = YES;
    } else {
        self.measureState = FLEXLookinMeasureState_unlocked;
        self.lockSwitchButton.selected = NO;
        self.shortcutLabel.hidden = NO;
    }
    [self layoutSubviews];
}

- (void)lockButtonTapped:(UIButton *)sender {
    [self lockMeasuring:!sender.selected];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (self.measureState == FLEXLookinMeasureState_unlocked) {
        [self lockMeasuring:YES];
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.measureWindow];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            // 查找触摸点下的视图
            UIView *hitView = [self findViewAtPoint:location];
            if (self.mainView == nil) {
                self.mainView = hitView;
            } else {
                self.referenceView = hitView;
                [self updateMeasureResult];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.measureState == FLEXLookinMeasureState_unlocked) {
                UIView *hitView = [self findViewAtPoint:location];
                self.referenceView = hitView;
                [self updateMeasureResult];
            }
            break;
        }
        case UIGestureRecognizerStateEnded: {
            if (self.measureState == FLEXLookinMeasureState_unlocked) {
                [self stopMeasuring];
            }
            break;
        }
        default:
            break;
    }
}

- (UIWindow *)getKeyWindow {
    // ✅ iOS 13+ 兼容性处理
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIWindowScene *windowScene in connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        return window;
                    }
                }
            }
        }
        
        // 如果没找到keyWindow，返回第一个window
        for (UIWindowScene *windowScene in connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene.windows.firstObject;
            }
        }
    }
    
    // iOS 12及以下版本的fallback
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

- (UIView *)findViewAtPoint:(CGPoint)point {
    UIWindow *keyWindow = [self getKeyWindow];
    if (!keyWindow) {
        NSLog(@"⚠️ 无法获取keyWindow");
        return nil;
    }
    return [keyWindow hitTest:point withEvent:nil];
}

- (void)updateMeasureResult {
    if (self.mainView && self.referenceView) {
        [self.resultView showMeasureResultWithMainView:self.mainView referenceView:self.referenceView];
    }
}

- (void)layoutSubviews {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    // 布局结果视图
    self.resultView.frame = CGRectMake(0, 0, screenWidth, screenHeight);
    
    // 布局提示标签
    if (!self.shortcutLabel.hidden) {
        [self.shortcutLabel sizeToFit];
        self.shortcutLabel.frame = CGRectMake((screenWidth - self.shortcutLabel.frame.size.width) / 2, 100, self.shortcutLabel.frame.size.width + 20, 30);
    }
    
    // 布局锁定按钮
    if (!self.lockSwitchButton.hidden) {
        self.lockSwitchButton.frame = CGRectMake((screenWidth - 80) / 2, 100, 80, 30);
    }
}

// ✅ 完善dealloc方法
- (void)dealloc {
    [self stopMeasuring];
    
    // 清理手势识别器
    for (UIGestureRecognizer *gesture in self.measureWindow.gestureRecognizers) {
        [gesture removeTarget:self action:NULL];
        [self.measureWindow removeGestureRecognizer:gesture];
    }
    
    // 清理按钮事件
    [self.lockSwitchButton removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    
    self.measureWindow = nil;
    NSLog(@"🗑️ DYYYFLEXLookinMeasureController 已释放");
}

@end