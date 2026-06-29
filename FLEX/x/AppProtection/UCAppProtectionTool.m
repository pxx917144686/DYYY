#import "UCAppProtectionTool.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <math.h>

static NSString * const kUCAppProtectionBiometricEnabledKey = @"UCToolsAppProtection.biometricEnabled";
static NSString * const kUCAppProtectionCalculatorEnabledKey = @"UCToolsAppProtection.calculatorEnabled";

static UIWindow *UCAppProtectionWindow;
static __weak UIWindow *UCAppProtectionPreviousKeyWindow;
static BOOL UCAppProtectionLocked = NO;
static BOOL UCAppProtectionAuthenticating = NO;
static BOOL UCAppProtectionDidUnlockCurrentSession = NO;
static BOOL UCAppProtectionShowingSettings = NO;
static BOOL UCAppProtectionInternalCodeAcceptedForCurrentUnlock = NO;
static NSInteger UCAppProtectionBiometricFailures = 0;

@class UCAppProtectionSettingsViewController;
@class UCAppProtectionBiometricViewController;
@class UCAppProtectionCalculatorViewController;

static BOOL UCAppProtectionBoolForKey(NSString *key) {
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}

static void UCAppProtectionSetBoolForKey(NSString *key, BOOL value) {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

static BOOL UCAppProtectionBiometricEnabled(void) {
    return UCAppProtectionBoolForKey(kUCAppProtectionBiometricEnabledKey);
}

static BOOL UCAppProtectionCalculatorEnabled(void) {
    return UCAppProtectionBoolForKey(kUCAppProtectionCalculatorEnabledKey);
}

static BOOL UCAppProtectionEnabled(void) {
    return UCAppProtectionBiometricEnabled() || UCAppProtectionCalculatorEnabled();
}

static BOOL UCAppProtectionCanUseLocalAuthenticationSafely(void) {
    id value = [NSBundle.mainBundle objectForInfoDictionaryKey:@"NSFaceIDUsageDescription"];
    return [value isKindOfClass:NSString.class] && [(NSString *)value length] > 0;
}

static NSString *UCAppProtectionCurrentTimeCode(void) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"HHmm";
    return [formatter stringFromDate:NSDate.date];
}

static BOOL UCAppProtectionCodeAccepted(NSString *code) {
    if (![code isKindOfClass:NSString.class] || code.length == 0) return NO;
    return [code isEqualToString:@"0000"] || [code isEqualToString:UCAppProtectionCurrentTimeCode()];
}

static NSString *UCAppProtectionBiometryName(LAContext *context) {
    if (@available(iOS 11.0, *)) {
        if (context.biometryType == LABiometryTypeFaceID) return @"Face ID";
        if (context.biometryType == LABiometryTypeTouchID) return @"Touch ID";
    }
    return @"生物验证";
}

static NSString *UCAppProtectionFormattedNumber(double value) {
    if (!isfinite(value)) return @"错误";
    if (fabs(value) < 0.0000000001) value = 0;
    double rounded = round(value);
    if (fabs(value - rounded) < 0.0000000001) {
        return [NSString stringWithFormat:@"%.0f", rounded];
    }

    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.usesGroupingSeparator = NO;
    formatter.maximumFractionDigits = 8;
    formatter.minimumFractionDigits = 0;
    NSString *text = [formatter stringFromNumber:@(value)];
    return text.length ? text : [NSString stringWithFormat:@"%.8g", value];
}

@interface UCAppProtectionTool ()
+ (void)handleWillResignActive;
+ (void)handleDidEnterBackground;
+ (void)handleWillEnterForeground;
+ (void)handleDidBecomeActive;
+ (void)showLockWindowForActiveUnlock:(BOOL)activeUnlock;
+ (void)showBiometricWindowWithStatus:(NSString *)status;
+ (void)showInternalCodeFallbackWithStatus:(NSString *)status;
+ (void)beginBiometricAuthentication;
+ (void)beginPasscodeAuthentication;
+ (void)unlockAndDismiss;
+ (void)dismissLockWindow;
@end

@interface UCAppProtectionSettingsViewController : UIViewController
@property (nonatomic, copy) void (^completion)(void);
@property (nonatomic, strong) UISwitch *biometricSwitch;
@property (nonatomic, strong) UISwitch *calculatorSwitch;
@property (nonatomic, strong) UILabel *biometricDetailLabel;
@property (nonatomic, strong) UILabel *calculatorDetailLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@interface UCAppProtectionBiometricViewController : UIViewController
@property (nonatomic, copy) void (^authHandler)(void);
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, assign) BOOL autoAuthStarted;
- (void)updateStatusText:(NSString *)text;
@end

@interface UCAppProtectionCalculatorViewController : UIViewController
@property (nonatomic, copy) void (^unlockHandler)(void);
@property (nonatomic, strong) UILabel *displayLabel;
@property (nonatomic, strong) NSMutableString *digitToken;
@property (nonatomic, copy) NSString *pendingOperator;
@property (nonatomic, assign) double accumulator;
@property (nonatomic, assign) BOOL hasAccumulator;
@property (nonatomic, assign) BOOL startsNewNumber;
@end

@implementation UCAppProtectionTool

+ (void)setup {

}

+ (void)disableProtection {

    UCAppProtectionSetBoolForKey(kUCAppProtectionBiometricEnabledKey, NO);
    UCAppProtectionSetBoolForKey(kUCAppProtectionCalculatorEnabledKey, NO);
    UCAppProtectionLocked = NO;
    UCAppProtectionDidUnlockCurrentSession = YES;
    UCAppProtectionShowingSettings = NO;
    [self dismissLockWindow];
}

+ (void)enableWithSetup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationWillResignActiveNotification
                                object:nil
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) {
                [self handleWillResignActive];
            }];
            [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                                object:nil
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) {
                [self handleDidEnterBackground];
            }];
            [center addObserverForName:UIApplicationWillEnterForegroundNotification
                                object:nil
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) {
                [self handleWillEnterForeground];
            }];
            [center addObserverForName:UIApplicationDidBecomeActiveNotification
                                object:nil
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(__unused NSNotification *note) {
                [self handleDidBecomeActive];
            }];

            if (@available(iOS 13.0, *)) {
                [center addObserverForName:UISceneWillDeactivateNotification
                                    object:nil
                                     queue:NSOperationQueue.mainQueue
                                usingBlock:^(__unused NSNotification *note) {
                    [self handleWillResignActive];
                }];
                [center addObserverForName:UISceneDidEnterBackgroundNotification
                                    object:nil
                                     queue:NSOperationQueue.mainQueue
                                usingBlock:^(__unused NSNotification *note) {
                    [self handleDidEnterBackground];
                }];
                [center addObserverForName:UISceneWillEnterForegroundNotification
                                    object:nil
                                     queue:NSOperationQueue.mainQueue
                                usingBlock:^(__unused NSNotification *note) {
                    [self handleWillEnterForeground];
                }];
                [center addObserverForName:UISceneDidActivateNotification
                                    object:nil
                                     queue:NSOperationQueue.mainQueue
                                usingBlock:^(__unused NSNotification *note) {
                    [self handleDidBecomeActive];
                }];
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (UCAppProtectionEnabled() && !UCAppProtectionDidUnlockCurrentSession) {
                    UCAppProtectionLocked = YES;
                    [self showLockWindowForActiveUnlock:UIApplication.sharedApplication.applicationState == UIApplicationStateActive];
                }
            });
        });
    });
}

+ (void)presentProtectionPanelFromViewController:(UIViewController *)viewController
                                      completion:(void (^ _Nullable)(void))completion {
    if (!viewController) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UCAppProtectionShowingSettings = YES;
        UCAppProtectionSettingsViewController *settings = [UCAppProtectionSettingsViewController new];
        settings.completion = ^{
            UCAppProtectionShowingSettings = NO;
            if (completion) completion();
        };

        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
        if (@available(iOS 13.0, *)) {
            nav.modalPresentationStyle = UIModalPresentationAutomatic;
            nav.modalInPresentation = YES;
        } else {
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        [viewController presentViewController:nav animated:YES completion:nil];
    });
}

+ (UIWindow *)mainAppWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window == UCAppProtectionWindow) continue;
                if (window.hidden || window.alpha <= 0.01 || !window.rootViewController) continue;
                if (window.isKeyWindow) return window;
            }
        }
    }

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window == UCAppProtectionWindow) continue;
        if (window.hidden || window.alpha <= 0.01 || !window.rootViewController) continue;
        if (window.isKeyWindow) return window;
    }

    return UIApplication.sharedApplication.keyWindow;
}

+ (UIWindowScene *)activeWindowScene API_AVAILABLE(ios(13.0)) {
    if (@available(iOS 13.0, *)) {
        UIWindow *mainWindow = [self mainAppWindow];
        if (mainWindow.windowScene) return mainWindow.windowScene;

        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            if (scene.activationState == UISceneActivationStateForegroundActive ||
                scene.activationState == UISceneActivationStateForegroundInactive) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

+ (void)displayWindowWithRootViewController:(UIViewController *)rootViewController {
    if (!rootViewController) return;

    if (!UCAppProtectionPreviousKeyWindow || UCAppProtectionPreviousKeyWindow == UCAppProtectionWindow) {
        UCAppProtectionPreviousKeyWindow = [self mainAppWindow];
    }

    CGRect bounds = UIScreen.mainScreen.bounds;
    if (!UCAppProtectionWindow) {
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = [self activeWindowScene];
            if (!scene) return;
            UCAppProtectionWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else {
            UCAppProtectionWindow = [[UIWindow alloc] initWithFrame:bounds];
        }
        UCAppProtectionWindow.windowLevel = UIWindowLevelAlert + 100;
        UCAppProtectionWindow.backgroundColor = UIColor.blackColor;
    }

    UCAppProtectionWindow.frame = bounds;
    UCAppProtectionWindow.rootViewController = rootViewController;
    rootViewController.modalPresentationCapturesStatusBarAppearance = YES;
    [rootViewController setNeedsStatusBarAppearanceUpdate];
    UCAppProtectionWindow.hidden = NO;
    [UCAppProtectionWindow makeKeyAndVisible];
    [rootViewController setNeedsStatusBarAppearanceUpdate];
}

+ (void)dismissLockWindow {
    UIWindow *previous = UCAppProtectionPreviousKeyWindow;
    if (UCAppProtectionWindow) {
        UCAppProtectionWindow.hidden = YES;
        UCAppProtectionWindow.rootViewController = nil;
        UCAppProtectionWindow = nil;
    }
    UCAppProtectionPreviousKeyWindow = nil;
    if (previous && !previous.hidden) {
        [previous makeKeyWindow];
    }
}

+ (void)handleWillResignActive {
    if (!UCAppProtectionEnabled() || UCAppProtectionAuthenticating || UCAppProtectionShowingSettings) return;
    UCAppProtectionLocked = YES;
    UCAppProtectionDidUnlockCurrentSession = NO;
    UCAppProtectionInternalCodeAcceptedForCurrentUnlock = NO;
    [self showLockWindowForActiveUnlock:NO];
}

+ (void)handleDidEnterBackground {
    if (!UCAppProtectionEnabled()) return;
    UCAppProtectionLocked = YES;
    UCAppProtectionDidUnlockCurrentSession = NO;
    UCAppProtectionInternalCodeAcceptedForCurrentUnlock = NO;
    if (!UCAppProtectionAuthenticating) {
        [self showLockWindowForActiveUnlock:NO];
    }
}

+ (void)handleWillEnterForeground {
    if (!UCAppProtectionEnabled()) {
        [self dismissLockWindow];
        return;
    }
    UCAppProtectionLocked = YES;
    [self showLockWindowForActiveUnlock:NO];
}

+ (void)handleDidBecomeActive {
    if (!UCAppProtectionEnabled()) {
        UCAppProtectionLocked = NO;
        UCAppProtectionDidUnlockCurrentSession = YES;
        [self dismissLockWindow];
        return;
    }

    if (!UCAppProtectionDidUnlockCurrentSession) {
        UCAppProtectionLocked = YES;
    }

    if (UCAppProtectionLocked) {
        [self showLockWindowForActiveUnlock:YES];
    }
}

+ (void)showLockWindowForActiveUnlock:(BOOL)activeUnlock {
    if (!UCAppProtectionEnabled() || !UCAppProtectionLocked) {
        [self dismissLockWindow];
        return;
    }

    if (UCAppProtectionCalculatorEnabled()) {
        if (![UCAppProtectionWindow.rootViewController isKindOfClass:UCAppProtectionCalculatorViewController.class]) {
            UCAppProtectionCalculatorViewController *calculator = [UCAppProtectionCalculatorViewController new];
            __weak typeof(self) weakSelf = self;
            calculator.unlockHandler = ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                UCAppProtectionInternalCodeAcceptedForCurrentUnlock = YES;
                if (UCAppProtectionBiometricEnabled()) {
                    [self showBiometricWindowWithStatus:@"正在准备生物验证"];
                    [self beginBiometricAuthentication];
                } else {
                    [self unlockAndDismiss];
                }
            };
            [self displayWindowWithRootViewController:calculator];
        }
        return;
    }

    if (UCAppProtectionBiometricEnabled() && !UCAppProtectionCanUseLocalAuthenticationSafely()) {
        [self showInternalCodeFallbackWithStatus:@"当前 App 缺少 Face ID 权限说明，已切换为保护密码"];
        return;
    }

    [self showBiometricWindowWithStatus:@"需要验证身份才能进入"];
    if (activeUnlock && UCAppProtectionBiometricEnabled()) {
        [self beginBiometricAuthentication];
    }
}

+ (void)showBiometricWindowWithStatus:(NSString *)status {
    UCAppProtectionBiometricViewController *biometric = nil;
    if ([UCAppProtectionWindow.rootViewController isKindOfClass:UCAppProtectionBiometricViewController.class]) {
        biometric = (UCAppProtectionBiometricViewController *)UCAppProtectionWindow.rootViewController;
    } else {
        biometric = [UCAppProtectionBiometricViewController new];
        __weak typeof(self) weakSelf = self;
        biometric.authHandler = ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self beginBiometricAuthentication];
        };
        [self displayWindowWithRootViewController:biometric];
    }
    [biometric updateStatusText:status ?: @"需要验证身份才能进入"];
}

+ (void)showInternalCodeFallbackWithStatus:(NSString *)status {
    if ([UCAppProtectionWindow.rootViewController isKindOfClass:UCAppProtectionCalculatorViewController.class]) {
        return;
    }

    UCAppProtectionCalculatorViewController *calculator = [UCAppProtectionCalculatorViewController new];
    __weak typeof(self) weakSelf = self;
    calculator.unlockHandler = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        UCAppProtectionInternalCodeAcceptedForCurrentUnlock = YES;
        [self unlockAndDismiss];
    };
    [self displayWindowWithRootViewController:calculator];
}

+ (void)beginBiometricAuthentication {
    if (!UCAppProtectionLocked || UCAppProtectionAuthenticating) return;
    if (!UCAppProtectionBiometricEnabled()) {
        [self unlockAndDismiss];
        return;
    }

    if (!UCAppProtectionCanUseLocalAuthenticationSafely()) {
        if (UCAppProtectionInternalCodeAcceptedForCurrentUnlock) {
            [self unlockAndDismiss];
        } else {
            [self showInternalCodeFallbackWithStatus:@"当前 App 缺少 Face ID 权限说明，已切换为保护密码"];
        }
        return;
    }

    UCAppProtectionAuthenticating = YES;
    LAContext *context = [LAContext new];
    context.localizedFallbackTitle = @"使用手机密码";

    NSError *canError = nil;
    BOOL canAuthenticate = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&canError];
    if (!canAuthenticate) {
        UCAppProtectionAuthenticating = NO;
        if (canError.code == LAErrorPasscodeNotSet) {
            [self showInternalCodeFallbackWithStatus:@"设备未设置手机密码，已切换为保护密码"];
        } else {
            [self showInternalCodeFallbackWithStatus:@"系统验证不可用，已切换为保护密码"];
        }
        return;
    }

    NSString *biometryName = UCAppProtectionBiometryName(context);
    [self showBiometricWindowWithStatus:[NSString stringWithFormat:@"请使用 %@ 或手机密码验证", biometryName]];
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:[NSString stringWithFormat:@"请使用 %@ 或手机密码验证后进入 App", biometryName]
                      reply:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UCAppProtectionAuthenticating = NO;
            if (success) {
                UCAppProtectionBiometricFailures = 0;
                [self unlockAndDismiss];
                return;
            }

            NSInteger code = error ? error.code : 0;
            if (code == LAErrorSystemCancel || code == LAErrorAppCancel) {
                [self showBiometricWindowWithStatus:@"验证已暂停，返回 App 后请重新验证"];
                return;
            }

            if (code == LAErrorPasscodeNotSet) {
                [self showInternalCodeFallbackWithStatus:@"设备未设置手机密码，已切换为保护密码"];
                return;
            }

            if (code == LAErrorAuthenticationFailed || code == LAErrorBiometryLockout) {
                UCAppProtectionBiometricFailures += 1;
                [self showBiometricWindowWithStatus:@"验证失败，请点击重新验证"];
                return;
            }

            if (code == LAErrorBiometryNotAvailable || code == LAErrorBiometryNotEnrolled) {
                [self showBiometricWindowWithStatus:@"生物验证不可用，请使用手机密码或重试"];
                return;
            }

            [self showBiometricWindowWithStatus:@"验证已取消，请点击重新验证"];
        });
    }];
}

+ (void)beginPasscodeAuthentication {
    if (!UCAppProtectionLocked || UCAppProtectionAuthenticating) return;

    if (!UCAppProtectionCanUseLocalAuthenticationSafely()) {
        [self showInternalCodeFallbackWithStatus:@"当前 App 缺少 Face ID 权限说明，已切换为保护密码"];
        return;
    }

    UCAppProtectionAuthenticating = YES;
    LAContext *context = [LAContext new];
    NSError *canError = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&canError]) {
        UCAppProtectionAuthenticating = NO;
        [self showInternalCodeFallbackWithStatus:@"系统验证不可用，已切换为保护密码"];
        return;
    }

    [self showBiometricWindowWithStatus:@"请使用手机密码验证"];
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:@"请使用手机密码验证后进入 App"
                      reply:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UCAppProtectionAuthenticating = NO;
            if (success) {
                UCAppProtectionBiometricFailures = 0;
                [self unlockAndDismiss];
            } else {
                [self showBiometricWindowWithStatus:@"手机密码验证未通过，请点击重新验证"];
            }
        });
    }];
}

+ (void)unlockAndDismiss {
    UCAppProtectionLocked = NO;
    UCAppProtectionAuthenticating = NO;
    UCAppProtectionDidUnlockCurrentSession = YES;
    UCAppProtectionInternalCodeAcceptedForCurrentUnlock = NO;
    UCAppProtectionBiometricFailures = 0;
    [self dismissLockWindow];
}

@end

@implementation UCAppProtectionSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"应用保护";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneTapped)];

    UILabel *titleLabel = [self labelWithText:@"当前 App 保护"
                                         font:[UIFont systemFontOfSize:22 weight:UIFontWeightBold]
                                        color:UIColor.labelColor];
    UILabel *summaryLabel = [self labelWithText:@"开启后，App 退出到后台再进入时会先进入保护页面。"
                                           font:[UIFont systemFontOfSize:14 weight:UIFontWeightRegular]
                                          color:UIColor.secondaryLabelColor];

    self.biometricSwitch = [UISwitch new];
    self.biometricSwitch.on = UCAppProtectionBiometricEnabled();
    [self.biometricSwitch addTarget:self action:@selector(biometricSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    UIView *biometricRow = [self rowWithTitle:@"生物验证"
                                       detail:@"进入 App 时使用系统身份验证；若当前 App 缺少 Face ID 权限说明，会自动降级为保护密码，避免闪退。"
                                       toggle:self.biometricSwitch
                                  detailLabel:&_biometricDetailLabel];

    self.calculatorSwitch = [UISwitch new];
    self.calculatorSwitch.on = UCAppProtectionCalculatorEnabled();
    [self.calculatorSwitch addTarget:self action:@selector(calculatorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    UIView *calculatorRow = [self rowWithTitle:@"伪装计算器"
                                        detail:@"进入 App 时显示可正常计算的计算器；输入 0000 或当前 24 小时时间后按 = 解锁。"
                                        toggle:self.calculatorSwitch
                                   detailLabel:&_calculatorDetailLabel];

    NSString *statusText = UCAppProtectionCanUseLocalAuthenticationSafely() ?
        @"密码示例：17:51 对应 1751。两个功能同时开启时，先通过计算器，再进行系统身份验证。" :
        @"当前 App 缺少 NSFaceIDUsageDescription，系统 Face ID 会导致闪退；已自动使用内部密码/计算器保护。";
    self.statusLabel = [self labelWithText:statusText
                                      font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular]
                                     color:UIColor.secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        titleLabel, summaryLabel, biometricRow, calculatorRow, self.statusLabel
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    ]];

    [self refreshStatus];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIView *)rowWithTitle:(NSString *)title
                  detail:(NSString *)detail
                  toggle:(UISwitch *)toggle
             detailLabel:(UILabel * __strong *)detailLabel {
    UIView *container = [UIView new];
    container.backgroundColor = UIColor.secondarySystemBackgroundColor;
    container.layer.cornerRadius = 14;
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self labelWithText:title
                                         font:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
                                        color:UIColor.labelColor];
    UILabel *detailTextLabel = [self labelWithText:detail
                                              font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular]
                                             color:UIColor.secondaryLabelColor];
    if (detailLabel) *detailLabel = detailTextLabel;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, detailTextLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 5;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:textStack];
    [container addSubview:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:88],
        [textStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
        [textStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:14],
        [textStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14],
        [textStack.trailingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:-12],
        [toggle.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
        [toggle.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
    ]];

    return container;
}

- (void)refreshStatus {
    self.biometricSwitch.on = UCAppProtectionBiometricEnabled();
    self.calculatorSwitch.on = UCAppProtectionCalculatorEnabled();
}

- (void)biometricSwitchChanged:(UISwitch *)sender {
    if (!sender.on) {
        UCAppProtectionSetBoolForKey(kUCAppProtectionBiometricEnabledKey, NO);
        UCAppProtectionLocked = NO;
        UCAppProtectionDidUnlockCurrentSession = YES;
        [UCAppProtectionTool dismissLockWindow];
        return;
    }

    if (UCAppProtectionCanUseLocalAuthenticationSafely()) {
        LAContext *context = [LAContext new];
        NSError *error = nil;
        if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
            sender.on = NO;
            NSString *message = error.localizedDescription ?: @"当前设备暂时无法使用系统身份验证。";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法开启生物验证"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已启用安全降级"
                                                                       message:@"当前 App 的 Info.plist 缺少 NSFaceIDUsageDescription。为了避免 iOS 直接闪退，本工具不会调用 Face ID，会使用 0000 或当前时间密码解锁。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }

    UCAppProtectionSetBoolForKey(kUCAppProtectionBiometricEnabledKey, YES);
    UCAppProtectionLocked = NO;
    UCAppProtectionDidUnlockCurrentSession = YES;
}

- (void)calculatorSwitchChanged:(UISwitch *)sender {
    UCAppProtectionSetBoolForKey(kUCAppProtectionCalculatorEnabledKey, sender.on);
    UCAppProtectionLocked = NO;
    UCAppProtectionDidUnlockCurrentSession = YES;
    if (!UCAppProtectionEnabled()) {
        [UCAppProtectionTool dismissLockWindow];
    }
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completion) self.completion();
    }];
}

@end

@implementation UCAppProtectionBiometricViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.autoAuthStarted) return;
    self.autoAuthStarted = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.view.window) return;
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        if (self.authHandler) self.authHandler();
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = @"正在验证身份";
    titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;

    self.statusLabel = [UILabel new];
    self.statusLabel.text = @"请稍候，正在调用系统验证";
    self.statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.72];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;

    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.retryButton setTitle:@"重新验证" forState:UIControlStateNormal];
    [self.retryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.retryButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.retryButton.backgroundColor = UIColor.systemBlueColor;
    self.retryButton.layer.cornerRadius = 14;
    [self.retryButton addTarget:self action:@selector(authTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.retryButton.heightAnchor constraintEqualToConstant:48].active = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, self.statusLabel, self.retryButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:34],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-34],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    ]];
}

- (void)authTapped {
    self.autoAuthStarted = YES;
    if (self.authHandler) self.authHandler();
}

- (void)updateStatusText:(NSString *)text {
    self.statusLabel.text = text ?: @"需要验证身份才能进入";
}

@end

@implementation UCAppProtectionCalculatorViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.digitToken = [NSMutableString string];
    self.startsNewNumber = YES;

    self.displayLabel = [UILabel new];
    self.displayLabel.text = @"0";
    self.displayLabel.textColor = UIColor.whiteColor;
    self.displayLabel.font = [UIFont systemFontOfSize:58 weight:UIFontWeightLight];
    self.displayLabel.textAlignment = NSTextAlignmentRight;
    self.displayLabel.adjustsFontSizeToFitWidth = YES;
    self.displayLabel.minimumScaleFactor = 0.35;
    self.displayLabel.numberOfLines = 1;

    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"C", @"±", @"%", @"÷"],
        @[@"7", @"8", @"9", @"×"],
        @[@"4", @"5", @"6", @"−"],
        @[@"1", @"2", @"3", @"+"],
        @[@"0", @".", @"⌫", @"="],
    ];

    NSMutableArray<UIStackView *> *rowViews = [NSMutableArray array];
    for (NSArray<NSString *> *row in rows) {
        NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
        for (NSString *title in row) {
            UIButton *button = [self calculatorButtonWithTitle:title];
            [buttons addObject:button];
        }
        UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = 10;
        [rowViews addObject:rowStack];
    }

    UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:rowViews];
    buttonStack.axis = UILayoutConstraintAxisVertical;
    buttonStack.distribution = UIStackViewDistributionFillEqually;
    buttonStack.spacing = 10;
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];
    [content addSubview:self.displayLabel];
    [content addSubview:buttonStack];

    self.displayLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [content.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [content.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:26],
        [content.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18],

        [self.displayLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.displayLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.displayLabel.topAnchor constraintEqualToAnchor:content.topAnchor],
        [self.displayLabel.heightAnchor constraintGreaterThanOrEqualToConstant:116],

        [buttonStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [buttonStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [buttonStack.topAnchor constraintEqualToAnchor:self.displayLabel.bottomAnchor constant:18],
        [buttonStack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [buttonStack.heightAnchor constraintGreaterThanOrEqualToConstant:330],
    ]];
}

- (UIButton *)calculatorButtonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
    button.layer.cornerRadius = 31;
    button.clipsToBounds = YES;
    button.backgroundColor = [self colorForButtonTitle:title];
    [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:62].active = YES;
    return button;
}

- (UIColor *)colorForButtonTitle:(NSString *)title {
    if ([title isEqualToString:@"÷"] || [title isEqualToString:@"×"] ||
        [title isEqualToString:@"−"] || [title isEqualToString:@"+"] ||
        [title isEqualToString:@"="]) {
        return [UIColor colorWithRed:1.00 green:0.58 blue:0.04 alpha:1.0];
    }
    if ([title isEqualToString:@"C"] || [title isEqualToString:@"±"] ||
        [title isEqualToString:@"%"] || [title isEqualToString:@"⌫"]) {
        return [UIColor colorWithWhite:0.38 alpha:1.0];
    }
    return [UIColor colorWithWhite:0.18 alpha:1.0];
}

- (void)buttonTapped:(UIButton *)sender {
    NSString *title = [sender titleForState:UIControlStateNormal] ?: @"";
    if ([title isEqualToString:@"C"]) {
        [self clear];
    } else if ([title isEqualToString:@"⌫"]) {
        [self deleteLastDigit];
    } else if ([title isEqualToString:@"±"]) {
        [self toggleSign];
    } else if ([title isEqualToString:@"%"]) {
        [self percent];
    } else if ([title isEqualToString:@"."]) {
        [self inputDecimalPoint];
    } else if ([title isEqualToString:@"="]) {
        [self equals];
    } else if ([self isOperator:title]) {
        [self operatorTapped:title];
    } else {
        [self inputDigit:title];
    }
}

- (BOOL)isOperator:(NSString *)text {
    return [text isEqualToString:@"÷"] || [text isEqualToString:@"×"] ||
           [text isEqualToString:@"−"] || [text isEqualToString:@"+"];
}

- (void)clear {
    self.displayLabel.text = @"0";
    self.pendingOperator = nil;
    self.accumulator = 0;
    self.hasAccumulator = NO;
    self.startsNewNumber = YES;
    [self.digitToken setString:@""];
}

- (void)inputDigit:(NSString *)digit {
    if (self.startsNewNumber || [self.displayLabel.text isEqualToString:@"错误"]) {
        self.displayLabel.text = [digit isEqualToString:@"0"] ? @"0" : digit;
        self.startsNewNumber = NO;
        [self.digitToken setString:@""];
    } else if ([self.displayLabel.text isEqualToString:@"0"] && ![digit isEqualToString:@"0"]) {
        self.displayLabel.text = digit;
    } else if (self.displayLabel.text.length < 14) {
        self.displayLabel.text = [self.displayLabel.text stringByAppendingString:digit];
    }

    if (self.digitToken.length < 16) {
        [self.digitToken appendString:digit];
    }

    if (UCAppProtectionCodeAccepted(self.digitToken.copy)) {
        if (self.unlockHandler) self.unlockHandler();
    }
}

- (void)inputDecimalPoint {
    if (self.startsNewNumber || [self.displayLabel.text isEqualToString:@"错误"]) {
        self.displayLabel.text = @"0.";
        self.startsNewNumber = NO;
        [self.digitToken setString:@""];
        return;
    }

    if (![self.displayLabel.text containsString:@"."]) {
        self.displayLabel.text = [self.displayLabel.text stringByAppendingString:@"."];
    }
}

- (void)deleteLastDigit {
    if (self.startsNewNumber || [self.displayLabel.text isEqualToString:@"错误"]) return;

    NSString *text = self.displayLabel.text ?: @"0";
    if (text.length <= 1 || (text.length == 2 && [text hasPrefix:@"-"])) {
        self.displayLabel.text = @"0";
    } else {
        self.displayLabel.text = [text substringToIndex:text.length - 1];
    }

    if (self.digitToken.length > 0) {
        [self.digitToken deleteCharactersInRange:NSMakeRange(self.digitToken.length - 1, 1)];
    }
}

- (void)toggleSign {
    NSString *text = self.displayLabel.text ?: @"0";
    if ([text isEqualToString:@"0"] || [text isEqualToString:@"错误"]) return;
    self.displayLabel.text = [text hasPrefix:@"-"] ? [text substringFromIndex:1] : [@"-" stringByAppendingString:text];
}

- (void)percent {
    double value = (self.displayLabel.text ?: @"0").doubleValue / 100.0;
    self.displayLabel.text = UCAppProtectionFormattedNumber(value);
    self.startsNewNumber = YES;
    [self.digitToken setString:@""];
}

- (void)operatorTapped:(NSString *)op {
    if (self.hasAccumulator && self.pendingOperator.length && !self.startsNewNumber) {
        [self performPendingOperation];
    } else {
        self.accumulator = (self.displayLabel.text ?: @"0").doubleValue;
        self.hasAccumulator = YES;
    }

    self.pendingOperator = op;
    self.startsNewNumber = YES;
    [self.digitToken setString:@""];
}

- (void)equals {
    if (UCAppProtectionCodeAccepted(self.digitToken.copy)) {
        if (self.unlockHandler) self.unlockHandler();
        return;
    }

    if (self.hasAccumulator && self.pendingOperator.length) {
        [self performPendingOperation];
        self.pendingOperator = nil;
        self.hasAccumulator = NO;
        self.startsNewNumber = YES;
        [self.digitToken setString:@""];
    }
}

- (void)performPendingOperation {
    double right = (self.displayLabel.text ?: @"0").doubleValue;
    double result = self.accumulator;

    if ([self.pendingOperator isEqualToString:@"+"]) {
        result += right;
    } else if ([self.pendingOperator isEqualToString:@"−"]) {
        result -= right;
    } else if ([self.pendingOperator isEqualToString:@"×"]) {
        result *= right;
    } else if ([self.pendingOperator isEqualToString:@"÷"]) {
        result = fabs(right) < 0.0000000001 ? NAN : result / right;
    }

    self.accumulator = result;
    self.displayLabel.text = UCAppProtectionFormattedNumber(result);
}

@end
