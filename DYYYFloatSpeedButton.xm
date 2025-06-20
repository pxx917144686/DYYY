#import "AwemeHeaders.h"
#import "DYYYFloatSpeedButton.h"
#import "DYYYUtils.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@class AWEFeedCellViewController;

FloatingSpeedButton *speedButton = nil;
static BOOL isCommentViewVisible = NO;
static BOOL showSpeedX = NO;
static CGFloat speedButtonSize = 32.0;
static BOOL isFloatSpeedButtonEnabled = NO;
static BOOL isForceHidden = NO;
static BOOL isInteractionViewVisible = NO;

// 前置声明函数
NSArray *findViewControllersInHierarchy(UIViewController *rootViewController);

NSArray *getSpeedOptions() {
    NSString *speedConfig = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYSpeedSettings"];
    
    // 如果用户没有设置或设置为空，使用默认值
    if (!speedConfig || speedConfig.length == 0) {
        speedConfig = @"1.0,1.25,1.5,2.0";
        // 保存默认值
        [[NSUserDefaults standardUserDefaults] setObject:speedConfig forKey:@"DYYYSpeedSettings"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSArray *speedArray = [speedConfig componentsSeparatedByString:@","];
    NSMutableArray *validSpeeds = [NSMutableArray array];
    
    // 验证和过滤有效的倍速值
    for (NSString *speedStr in speedArray) {
        NSString *trimmedSpeed = [speedStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedSpeed.length > 0) {
            float speed = [trimmedSpeed floatValue];
            if (speed > 0 && speed <= 10.0) { // 限制倍速范围
                [validSpeeds addObject:trimmedSpeed];
            }
        }
    }
    
    // 如果没有有效的倍速值，返回默认值
    if (validSpeeds.count == 0) {
        return @[@"1.0", @"1.25", @"1.5", @"2.0"];
    }
    
    return validSpeeds;
}

NSInteger getCurrentSpeedIndex() {
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYCurrentSpeedIndex"];
    NSArray *speeds = getSpeedOptions();

    if (index >= speeds.count || index < 0) {
        index = 0;
        [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"DYYYCurrentSpeedIndex"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    return index;
}

float getCurrentSpeed() {
    NSArray *speeds = getSpeedOptions();
    NSInteger index = getCurrentSpeedIndex();

    if (speeds.count == 0)
        return 1.0;
    float speed = [speeds[index] floatValue];
    return speed > 0 ? speed : 1.0;
}

void setCurrentSpeedIndex(NSInteger index) {
    NSArray *speeds = getSpeedOptions();

    if (speeds.count == 0)
        return;
    index = index % speeds.count;

    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"DYYYCurrentSpeedIndex"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

void updateSpeedButtonUI() {
    if (!speedButton)
        return;

    float currentSpeed = getCurrentSpeed();

    NSString *formattedSpeed;
    if (fmodf(currentSpeed, 1.0) == 0) {
        formattedSpeed = [NSString stringWithFormat:@"%.0f", currentSpeed];
    } else if (fmodf(currentSpeed * 10, 1.0) == 0) {
        formattedSpeed = [NSString stringWithFormat:@"%.1f", currentSpeed];
    } else {
        formattedSpeed = [NSString stringWithFormat:@"%.2f", currentSpeed];
    }

    if (showSpeedX) {
        formattedSpeed = [formattedSpeed stringByAppendingString:@"x"];
    }

    [speedButton setTitle:formattedSpeed forState:UIControlStateNormal];
}

// 实现 findViewControllersInHierarchy 函数
NSArray *findViewControllersInHierarchy(UIViewController *rootViewController) {
    NSMutableArray *viewControllers = [NSMutableArray array];
    [viewControllers addObject:rootViewController];

    for (UIViewController *childVC in rootViewController.childViewControllers) {
        [viewControllers addObjectsFromArray:findViewControllersInHierarchy(childVC)];
    }

    return viewControllers;
}

// 应用倍速到当前视频的函数
void applyCurrentSpeedToVideo() {
    float speed = getCurrentSpeed();
    if (speed == 1.0) return; // 正常倍速不需要特殊处理
    
    // 延迟一点应用倍速，确保视频已经开始播放
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        NSArray *viewControllers = findViewControllersInHierarchy(rootVC);
        
        for (UIViewController *vc in viewControllers) {
            if ([vc isKindOfClass:%c(AWEAwemePlayVideoViewController)]) {
                [(AWEAwemePlayVideoViewController *)vc setVideoControllerPlaybackRate:speed];
            }
            if ([vc isKindOfClass:%c(AWEDPlayerFeedPlayerViewController)]) {
                [(AWEDPlayerFeedPlayerViewController *)vc setVideoControllerPlaybackRate:speed];
            }
        }
    });
}

FloatingSpeedButton *getSpeedButton(void) { return speedButton; }

void showSpeedButton(void) { 
    isForceHidden = NO; 
    updateSpeedButtonVisibility();
}

void hideSpeedButton(void) {
    isForceHidden = YES;
    if (speedButton) {
        dispatch_async(dispatch_get_main_queue(), ^{
            speedButton.hidden = YES;
        });
    }
}

void updateSpeedButtonVisibility() {
    if (!speedButton || !isFloatSpeedButtonEnabled)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!isInteractionViewVisible) {
            speedButton.hidden = YES;
            return;
        }
        
        BOOL shouldHide = isCommentViewVisible || isForceHidden;
        if (speedButton.hidden != shouldHide) {
            speedButton.hidden = shouldHide;
        }
    });
}

@interface UIView (SpeedHelper)
- (UIViewController *)firstAvailableUIViewController;
@end

@implementation FloatingSpeedButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.accessibilityLabel = @"DYYYSpeedSwitchButton";
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
        
        [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.3] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowOpacity = 0.5;
        
        self.userInteractionEnabled = YES;
        self.isResponding = YES;
        
        // 状态检查定时器
        self.statusCheckTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                                 target:self
                                                               selector:@selector(checkAndRecoverButtonStatus)
                                                               userInfo:nil
                                                                repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.statusCheckTimer forMode:NSRunLoopCommonModes];
        
        [self setupGestureRecognizers];
        [self loadSavedPosition];
        
        self.justToggledLock = NO;
    }
    return self;
}

- (void)setupGestureRecognizers {
    for (UIGestureRecognizer *recognizer in [self.gestureRecognizers copy]) {
        [self removeGestureRecognizer:recognizer];
    }

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:panGesture];

    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPressGesture.minimumPressDuration = 0.5;
    [self addGestureRecognizer:longPressGesture];

    [self addTarget:self action:@selector(handleTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(handleTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(handleTouchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];

    panGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
    longPressGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

- (void)handleTouchDown:(UIButton *)sender {
    self.isResponding = YES;
}

- (void)handleTouchUpInside:(UIButton *)sender {
    if (self.justToggledLock) {
        self.justToggledLock = NO;
        return;
    }

    [UIView animateWithDuration:0.1
        animations:^{
            self.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }
        completion:^(BOOL finished) {
            [UIView animateWithDuration:0.1 animations:^{
                self.transform = CGAffineTransformIdentity;
            }];
        }];

    if (self.interactionController) {
        @try {
            [self.interactionController speedButtonTapped:self];
        }
        @catch (NSException *exception) {
            self.isResponding = NO;
        }
    } else {
        self.isResponding = NO;
    }
}

- (void)handleTouchUpOutside:(UIButton *)sender {
    self.justToggledLock = NO;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    self.isResponding = YES;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (self.firstStageTimer && [self.firstStageTimer isValid]) {
            [self.firstStageTimer invalidate];
            self.firstStageTimer = nil;
        }
        
        self.originalLockState = self.isLocked;
        [self toggleLockState];
    }
}

- (void)toggleLockState {
    self.isLocked = !self.isLocked;
    self.justToggledLock = YES;

    NSString *toastMessage = self.isLocked ? @"按钮已锁定" : @"按钮已解锁";
    [DYYYUtils showToast:toastMessage];

    if (self.isLocked) {
        [self saveButtonPosition];
    }

    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.justToggledLock = NO;
    });
}

- (void)resetToggleLockFlag {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.justToggledLock = NO;
    });
}

- (void)resetButtonState {
    self.justToggledLock = NO;
    self.isResponding = YES;
    self.userInteractionEnabled = YES;
    self.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;

    [self setupGestureRecognizers];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (self.isLocked) return;
    
    self.justToggledLock = NO;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.lastLocation = self.center;
    } 
    else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:self.superview];
        CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
        
        // 边界检查
        newCenter.x = MAX(self.frame.size.width / 2, MIN(newCenter.x, self.superview.frame.size.width - self.frame.size.width / 2));
        newCenter.y = MAX(self.frame.size.height / 2, MIN(newCenter.y, self.superview.frame.size.height - self.frame.size.height / 2));
        
        self.center = newCenter;
        [pan setTranslation:CGPointZero inView:self.superview];
        
        self.alpha = 0.8;
    } 
    else if (pan.state == UIGestureRecognizerStateEnded || 
             pan.state == UIGestureRecognizerStateCancelled) {
        self.alpha = 1.0;
        [self saveButtonPosition];
    }
}

- (void)saveButtonPosition {
    if (self.superview) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:self.center.x / self.superview.bounds.size.width forKey:@"DYYYSpeedButtonCenterXPercent"];
        [defaults setFloat:self.center.y / self.superview.bounds.size.height forKey:@"DYYYSpeedButtonCenterYPercent"];
        [defaults setBool:self.isLocked forKey:@"DYYYSpeedButtonLocked"];
        [defaults synchronize];
    }
}

- (void)loadSavedPosition {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float centerXPercent = [defaults floatForKey:@"DYYYSpeedButtonCenterXPercent"];
    float centerYPercent = [defaults floatForKey:@"DYYYSpeedButtonCenterYPercent"];
    
    self.isLocked = [defaults boolForKey:@"DYYYSpeedButtonLocked"];
    
    if (centerXPercent > 0 && centerYPercent > 0 && self.superview) {
        self.center = CGPointMake(centerXPercent * self.superview.bounds.size.width,
                                  centerYPercent * self.superview.bounds.size.height);
    }
}

- (void)checkAndRecoverButtonStatus {
    if (!self.isResponding) {
        [self resetButtonState];
        [self setupGestureRecognizers];
        self.isResponding = YES;
    }
    
    // 重新获取控制器引用
    if (!self.interactionController) {
        UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        
        for (UIViewController *vc in [self findViewControllersInHierarchy:topVC]) {
            if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                self.interactionController = (AWEPlayInteractionViewController *)vc;
                break;
            }
        }
    }
}

- (NSArray *)findViewControllersInHierarchy:(UIViewController *)rootViewController {
    NSMutableArray *viewControllers = [NSMutableArray array];
    [viewControllers addObject:rootViewController];
    
    for (UIViewController *childVC in rootViewController.childViewControllers) {
        [viewControllers addObjectsFromArray:[self findViewControllersInHierarchy:childVC]];
    }
    
    return viewControllers;
}

- (void)dealloc {
    if (self.firstStageTimer && [self.firstStageTimer isValid]) {
        [self.firstStageTimer invalidate];
    }
    if (self.statusCheckTimer && [self.statusCheckTimer isValid]) {
        [self.statusCheckTimer invalidate];
    }
}
@end

%hook AWEElementStackView

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    
    if (speedButton && isFloatSpeedButtonEnabled) {
        if (alpha == 0) {
            isCommentViewVisible = YES;
        } else if (alpha == 1) {
            isCommentViewVisible = NO;
        }
        updateSpeedButtonVisibility();
    }
}

%end

@interface AWEAwemePlayVideoViewController (SpeedControl)
- (void)adjustPlaybackSpeed:(float)speed;
@end

@interface AWEDPlayerFeedPlayerViewController (SpeedControl)
- (void)adjustPlaybackSpeed:(float)speed;
@end

%hook AWEAwemePlayVideoViewController

- (void)setIsAutoPlay:(BOOL)arg0 {
    %orig(arg0);
    
    // 在自动播放时应用当前倍速
    if (arg0) {
        float speed = getCurrentSpeed();
        if (speed != 1.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self adjustPlaybackSpeed:speed];
            });
        }
    }
}

- (void)prepareForDisplay {
    %orig;
    
    // 自动恢复默认倍速功能
    BOOL autoRestoreSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYAutoRestoreSpeed"];
    if (autoRestoreSpeed) {
        // 将倍速重置为第一个选项（通常是1.0）
        setCurrentSpeedIndex(0);
        updateSpeedButtonUI();
    }
    
    // 应用当前倍速到新视频
    applyCurrentSpeedToVideo();
    updateSpeedButtonUI();
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    
    // 视图出现时确保倍速正确应用
    float speed = getCurrentSpeed();
    if (speed != 1.0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self adjustPlaybackSpeed:speed];
        });
    }
}

%new
- (void)adjustPlaybackSpeed:(float)speed {
    [self setVideoControllerPlaybackRate:speed];
}

%end

%hook AWEDPlayerFeedPlayerViewController

- (void)setIsAutoPlay:(BOOL)arg0 {
    %orig(arg0);
    
    // 在自动播放时应用当前倍速
    if (arg0) {
        float speed = getCurrentSpeed();
        if (speed != 1.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self adjustPlaybackSpeed:speed];
            });
        }
    }
}

- (void)prepareForDisplay {
    %orig;
    
    // 修复：自动恢复默认倍速功能
    BOOL autoRestoreSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYAutoRestoreSpeed"];
    if (autoRestoreSpeed) {
        // 将倍速重置为第一个选项（通常是1.0）
        setCurrentSpeedIndex(0);
        updateSpeedButtonUI();
    }
    
    // 应用当前倍速到新视频
    applyCurrentSpeedToVideo();
    updateSpeedButtonUI();
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    
    // 视图出现时确保倍速正确应用
    float speed = getCurrentSpeed();
    if (speed != 1.0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self adjustPlaybackSpeed:speed];
        });
    }
}

%new
- (void)adjustPlaybackSpeed:(float)speed {
    [self setVideoControllerPlaybackRate:speed];
}

%end

%hook AWECommentContainerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    isCommentViewVisible = YES;
    updateSpeedButtonVisibility();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    isCommentViewVisible = NO;
    updateSpeedButtonVisibility();
}

%end

// 添加对滑动切换视频的hook，确保每次切换视频都应用倍速
%hook AWEPlayVideoPlayerController

- (void)preparePlayerWithModel:(id)model {
    %orig(model);
    
    // 视频准备时应用倍速
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        applyCurrentSpeedToVideo();
    });
}

- (void)play {
    %orig;
    
    // 播放时应用倍速
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        applyCurrentSpeedToVideo();
    });
}

%end

%hook AWEPlayInteractionViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    isInteractionViewVisible = YES;
    updateSpeedButtonVisibility();
}

- (void)viewDidLayoutSubviews {
    %orig;
    
    if (!isFloatSpeedButtonEnabled) return;
    
    if (speedButton == nil) {
        // 从设置中正确读取按钮大小
        NSString *sizeStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYSpeedButtonSize"];
        if (sizeStr && sizeStr.length > 0) {
            speedButtonSize = [sizeStr floatValue];
            if (speedButtonSize <= 0) {
                speedButtonSize = 40.0; // 默认大小
            }
        } else {
            speedButtonSize = 40.0; // 默认大小
        }
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGRect initialFrame = CGRectMake((screenBounds.size.width - speedButtonSize) / 2, 
                                         (screenBounds.size.height - speedButtonSize) / 2, 
                                         speedButtonSize, speedButtonSize);
        
        speedButton = [[FloatingSpeedButton alloc] initWithFrame:initialFrame];
        speedButton.interactionController = self;
        
        // 正确读取显示后缀设置
        showSpeedX = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSpeedButtonShowX"];
        updateSpeedButtonUI();
    } else {
        [speedButton resetButtonState];
        
        if (speedButton.interactionController == nil || speedButton.interactionController != self) {
            speedButton.interactionController = self;
        }
        
        // 动态更新按钮大小
        NSString *sizeStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYSpeedButtonSize"];
        CGFloat newSize = 40.0;
        if (sizeStr && sizeStr.length > 0) {
            newSize = [sizeStr floatValue];
            if (newSize <= 0) {
                newSize = 40.0;
            }
        }
        
        if (speedButton.frame.size.width != newSize) {
            CGPoint center = speedButton.center;
            CGRect newFrame = CGRectMake(0, 0, newSize, newSize);
            speedButton.frame = newFrame;
            speedButton.center = center;
            speedButton.layer.cornerRadius = newSize / 2;
            speedButtonSize = newSize;
        }
        
        // 更新显示后缀设置
        showSpeedX = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSpeedButtonShowX"];
        updateSpeedButtonUI();
    }
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow && ![speedButton isDescendantOfView:keyWindow]) {
        [keyWindow addSubview:speedButton];
        [speedButton loadSavedPosition];
    }
    
    updateSpeedButtonVisibility();
    
    // 确保新视频也应用倍速
    applyCurrentSpeedToVideo();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    isInteractionViewVisible = NO;
    updateSpeedButtonVisibility();
}

%new
- (UIViewController *)firstAvailableUIViewController {
    UIResponder *responder = [self.view nextResponder];
    while (responder != nil) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

%new
- (void)speedButtonTapped:(UIButton *)sender {
    NSArray *speeds = getSpeedOptions();
    if (speeds.count == 0) return;
    
    NSInteger currentIndex = getCurrentSpeedIndex();
    NSInteger newIndex = (currentIndex + 1) % speeds.count;
    
    setCurrentSpeedIndex(newIndex);
    
    float newSpeed = [speeds[newIndex] floatValue];
    
    NSString *formattedSpeed;
    if (fmodf(newSpeed, 1.0) == 0) {
        formattedSpeed = [NSString stringWithFormat:@"%.0f", newSpeed];
    } else if (fmodf(newSpeed * 10, 1.0) == 0) {
        formattedSpeed = [NSString stringWithFormat:@"%.1f", newSpeed];
    } else {
        formattedSpeed = [NSString stringWithFormat:@"%.2f", newSpeed];
    }
    
    if (showSpeedX) {
        formattedSpeed = [formattedSpeed stringByAppendingString:@"x"];
    }
    
    [sender setTitle:formattedSpeed forState:UIControlStateNormal];
    
    [UIView animateWithDuration:0.15
        animations:^{
            sender.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }
        completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15 animations:^{
                sender.transform = CGAffineTransformIdentity;
            }];
        }];
    
    // 应用速度到所有视频控制器
    BOOL speedApplied = NO;
    
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    NSArray *viewControllers = findViewControllersInHierarchy(rootVC);
    
    for (UIViewController *vc in viewControllers) {
        if ([vc isKindOfClass:%c(AWEAwemePlayVideoViewController)]) {
            [(AWEAwemePlayVideoViewController *)vc setVideoControllerPlaybackRate:newSpeed];
            speedApplied = YES;
        }
        if ([vc isKindOfClass:%c(AWEDPlayerFeedPlayerViewController)]) {
            [(AWEDPlayerFeedPlayerViewController *)vc setVideoControllerPlaybackRate:newSpeed];
            speedApplied = YES;
        }
    }
    
    if (!speedApplied) {
        [DYYYUtils showToast:@"无法找到视频控制器"];
    }
}

%new
- (void)buttonTouchDown:(UIButton *)sender {
    // 实现按钮按下效果
}

%new
- (void)buttonTouchUp:(UIButton *)sender {
    // 实现按钮释放效果
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    
    if (!isFloatSpeedButtonEnabled) return;
    
    if (speedButton && ![speedButton isDescendantOfView:self]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addSubview:speedButton];
            [speedButton loadSavedPosition];
        });
    }
}

%end

// 添加设置变化处理函数
static void handleSettingChanged(NSNotification *notification) {
    NSDictionary *userInfo = notification.userInfo;
    NSString *key = userInfo[@"key"];
    
    if ([key isEqualToString:@"DYYYEnableFloatSpeedButton"]) {
        isFloatSpeedButtonEnabled = [userInfo[@"value"] boolValue];
        
        if (isFloatSpeedButtonEnabled) {
            // 开启倍速按钮
            updateSpeedButtonVisibility();
        } else {
            // 关闭倍速按钮
            if (speedButton) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    speedButton.hidden = YES;
                    [speedButton removeFromSuperview];
                    speedButton = nil;
                });
            }
        }
    }
    else if ([key isEqualToString:@"DYYYSpeedSettings"]) {
        // 倍速数值变化时更新UI
        updateSpeedButtonUI();
    }
    else if ([key isEqualToString:@"DYYYSpeedButtonShowX"]) {
        // 显示后缀变化
        showSpeedX = [userInfo[@"value"] boolValue];
        updateSpeedButtonUI();
    }
    else if ([key isEqualToString:@"DYYYSpeedButtonSize"]) {
        // 按钮大小变化
        NSString *sizeStr = userInfo[@"value"];
        if (sizeStr && sizeStr.length > 0) {
            speedButtonSize = [sizeStr floatValue];
            if (speedButtonSize <= 0) {
                speedButtonSize = 40.0; // 默认大小
            }
        } else {
            speedButtonSize = 40.0;
        }
        
        // 更新现有按钮大小
        if (speedButton) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CGPoint center = speedButton.center;
                speedButton.frame = CGRectMake(0, 0, speedButtonSize, speedButtonSize);
                speedButton.center = center;
                speedButton.layer.cornerRadius = speedButtonSize / 2;
            });
        }
    }
}

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    isFloatSpeedButtonEnabled = [defaults boolForKey:@"DYYYEnableFloatSpeedButton"];
    
    // 监听设置变化
    [[NSNotificationCenter defaultCenter] addObserver:[NSNotificationCenter defaultCenter] 
                                               selector:@selector(handleSettingChanged:) 
                                                   name:@"DYYYSettingChanged" 
                                                 object:nil];
    
    %init;
}