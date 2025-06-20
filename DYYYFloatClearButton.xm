#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <signal.h>
#import "DYYYManager.h"
#import "DYYYUtils.h"

// 添加缺失的函数声明
void updateClearButtonVisibility(void);
void showClearButton(void);
void hideClearButton(void);

// 添加缺失的状态变量
static BOOL isInPlayInteractionVC = NO;
static BOOL isCommentViewVisible = NO;
static BOOL isForceHidden = NO;
static BOOL isAppActive = YES;
static BOOL isInteractionViewVisible = NO;

// 添加缺失的透明度获取函数
static CGFloat DYGetGlobalAlpha(void) {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
    CGFloat a = value.length ? value.floatValue : 1.0;
    return (a >= 0.0 && a <= 1.0) ? a : 1.0;
}

// HideUIButton 接口声明
@interface HideUIButton : UIButton
// 状态属性
@property(nonatomic, assign) BOOL isElementsHidden;
@property(nonatomic, assign) BOOL isLocked;
// UI 相关属性
@property(nonatomic, strong) NSMutableArray *hiddenViewsList;
@property(nonatomic, strong) UIImage *showIcon;
@property(nonatomic, strong) UIImage *hideIcon;
@property(nonatomic, assign) CGFloat originalAlpha;
// 计时器属性
@property(nonatomic, strong) NSTimer *checkTimer;
@property(nonatomic, strong) NSTimer *fadeTimer;
// 方法声明
- (void)resetFadeTimer;
- (void)hideUIElements;
- (void)findAndHideViews:(NSArray *)classNames;
- (void)safeResetState;
- (void)startPeriodicCheck;
- (UIViewController *)findViewController:(UIView *)view;
- (void)loadIcons;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
- (void)handleTap;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)handleTouchDown;
- (void)handleTouchUpInside;
- (void)handleTouchUpOutside;
- (void)saveLockState;
- (void)loadLockState;
- (void)refreshCustomIconAndSize;
@end

// 全局变量
static HideUIButton *hideButton;
static BOOL isAppInTransition = NO;
static NSArray *targetClassNames;

// 添加缺失的函数实现
void updateClearButtonVisibility() {
    if (!hideButton || !isAppActive)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!isInteractionViewVisible) {
            hideButton.hidden = YES;
            return;
        }
        
        BOOL shouldHide = isCommentViewVisible || isForceHidden;
        if (hideButton.hidden != shouldHide) {
            hideButton.hidden = shouldHide;
        }
    });
}

void showClearButton(void) {
    isForceHidden = NO;
    updateClearButtonVisibility();
}

void hideClearButton(void) {
    isForceHidden = YES;
    if (hideButton) {
        dispatch_async(dispatch_get_main_queue(), ^{
            hideButton.hidden = YES;
        });
    }
}

static void findViewsOfClassHelper(UIView *view, Class viewClass, NSMutableArray *result) {
    if ([view isKindOfClass:viewClass]) {
        [result addObject:view];
    }
    for (UIView *subview in view.subviews) {
        findViewsOfClassHelper(subview, viewClass, result);
    }
}

static UIWindow *getKeyWindow(void) {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
}

static void forceResetAllUIElements(void) {
    UIWindow *window = getKeyWindow();
    if (!window)
        return;
    
    // 添加对StackView的特殊处理
    Class StackViewClass = NSClassFromString(@"AWEElementStackView");
    for (NSString *className in targetClassNames) {
        Class viewClass = NSClassFromString(className);
        if (!viewClass)
            continue;
        NSMutableArray *views = [NSMutableArray array];
        findViewsOfClassHelper(window, viewClass, views);
        for (UIView *view in views) {
            if([view isKindOfClass:StackViewClass]) {
                view.tag = 0;
                view.alpha = DYGetGlobalAlpha();
            } else {
                view.alpha = 1.0;
            }
        }
    }
}

static void reapplyHidingToAllElements(HideUIButton *button) {
    if (!button || !button.isElementsHidden)
        return;
    [button hideUIElements];
}

static void initTargetClassNames(void) {
    NSMutableArray<NSString *> *list = [@[
        @"AWEHPTopBarCTAContainer", @"AWEHPDiscoverFeedEntranceView", @"AWELeftSideBarEntranceView",
        @"DUXBadge", @"AWEBaseElementView", @"AWEElementStackView",
        @"AWEPlayInteractionDescriptionLabel", @"AWEUserNameLabel",
        @"ACCEditTagStickerView", @"AWEFeedTemplateAnchorView",
        @"AWESearchFeedTagView", @"AWEPlayInteractionSearchAnchorView",
        @"AFDRecommendToFriendTagView", @"AWELandscapeFeedEntryView",
        @"AWEFeedAnchorContainerView", @"AFDAIbumFolioView", @"DUXPopover",
        @"AWEMixVideoPanelMoreView", @"AWEHotSearchInnerBottomView"
    ] mutableCopy];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideTabBar"]) {
        [list addObject:@"AWENormalModeTabBar"];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDanmaku"]) {
        [list addObject:@"AWEVideoPlayDanmakuContainerView"];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSlider"]) {
        [list addObject:@"AWEStoryProgressSlideView"];
        [list addObject:@"AWEStoryProgressContainerView"];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideChapter"]) {
        [list addObject:@"AWEDemaciaChapterProgressSlider"];
    }

    targetClassNames = [list copy];
}

@implementation HideUIButton

- (void)loadIcons {
    // 优先加载自定义图片
    NSString *customImagePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCustomAlbumImagePath"];
    BOOL enableCustom = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableCustomAlbum"];
    if (enableCustom && customImagePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:customImagePath]) {
        UIImage *customIcon = [UIImage imageWithContentsOfFile:customImagePath];
        if (customIcon) {
            self.showIcon = customIcon;
            self.hideIcon = customIcon;
            [self setImage:customIcon forState:UIControlStateNormal];
            [self setImage:customIcon forState:UIControlStateSelected];
            [self setTitle:nil forState:UIControlStateNormal];
            [self setTitle:nil forState:UIControlStateSelected];
            return;
        }
    }
    
    // 支持GIF动画
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *gifPath = [documentsPath stringByAppendingPathComponent:@"DYYY/qingping.gif"];
    NSData *gifData = [NSData dataWithContentsOfFile:gifPath];
    
    if (gifData) {
        // GIF处理逻辑
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)gifData, NULL);
        if (source) {
            size_t imageCount = CGImageSourceGetCount(source);
            
            NSMutableArray<UIImage *> *imageArray = [NSMutableArray arrayWithCapacity:imageCount];
            NSTimeInterval totalDuration = 0.0;
            
            // 处理每一帧
            for (size_t i = 0; i < imageCount; i++) {
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
                if (imageRef) {
                    UIImage *image = [UIImage imageWithCGImage:imageRef];
                    [imageArray addObject:image];
                    CFRelease(imageRef);
                    
                    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
                    if (properties) {
                        // 修复类型转换错误
                        CFDictionaryRef gifProperties = (CFDictionaryRef)CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                        if (gifProperties) {
                            CFNumberRef delayTimeRef = (CFNumberRef)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                            if (delayTimeRef) {
                                float delayTime;
                                CFNumberGetValue(delayTimeRef, kCFNumberFloatType, &delayTime);
                                totalDuration += delayTime;
                            }
                        }
                        CFRelease(properties);
                    }
                }
            }
            CFRelease(source);
            
            if (imageArray.count > 0) {
                // 创建UIImageView并设置动画
                UIImageView *animatedImageView = [[UIImageView alloc] initWithFrame:self.bounds];
                animatedImageView.animationImages = imageArray;
                animatedImageView.animationDuration = totalDuration > 0 ? totalDuration : 1.0;
                animatedImageView.animationRepeatCount = 0;
                [self addSubview:animatedImageView];
                
                // 设置约束
                animatedImageView.translatesAutoresizingMaskIntoConstraints = NO;
                [NSLayoutConstraint activateConstraints:@[
                    [animatedImageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
                    [animatedImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                    [animatedImageView.widthAnchor constraintEqualToAnchor:self.widthAnchor],
                    [animatedImageView.heightAnchor constraintEqualToAnchor:self.heightAnchor]
                ]];
                
                [animatedImageView startAnimating];
                return;
            }
        }
    }
    
    // 兼容旧逻辑 - PNG图片
    NSString *iconPath = [documentsPath stringByAppendingPathComponent:@"DYYY/qingping.png"];
    UIImage *customIcon = [UIImage imageWithContentsOfFile:iconPath];
    if (customIcon) {
        self.showIcon = customIcon;
        self.hideIcon = customIcon;
        [self setImage:customIcon forState:UIControlStateNormal];
        [self setImage:customIcon forState:UIControlStateSelected];
        [self setTitle:nil forState:UIControlStateNormal];
        [self setTitle:nil forState:UIControlStateSelected];
    } else {
        // 没有图片时显示文字
        [self setImage:nil forState:UIControlStateNormal];
        [self setImage:nil forState:UIControlStateSelected];
        [self setTitle:@"隐藏" forState:UIControlStateNormal];
        [self setTitle:@"显示" forState:UIControlStateSelected];
        self.titleLabel.font = [UIFont systemFontOfSize:10];
    }
}

@end

// 添加缺失的Hook
%hook AWEElementStackView
- (void)setAlpha:(CGFloat)alpha {
    %orig;
    if (hideButton) {
        if (alpha == 0) {
            isCommentViewVisible = YES;
        } else if (alpha == 1) {
            isCommentViewVisible = NO;
        }
        updateClearButtonVisibility();
    }
}
%end

%hook AWECommentContainerViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isCommentViewVisible = YES;
    updateClearButtonVisibility();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    isCommentViewVisible = NO;
    updateClearButtonVisibility();
}
%end

%hook AWEPlayInteractionViewController
- (void)loadView {
    %orig;
    if (hideButton) {
        hideButton.hidden = NO;
        hideButton.alpha = 0.5;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isInPlayInteractionVC = YES;
    isInteractionViewVisible = YES;
    if (hideButton) {
        hideButton.hidden = NO;
        hideButton.alpha = 0.5;
    }
    updateClearButtonVisibility();
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    isInPlayInteractionVC = NO;
    isInteractionViewVisible = NO;
    updateClearButtonVisibility();
}
%end

// ...existing code...

%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    initTargetClassNames();
    
    BOOL isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFloatClearButton"];
    if (isEnabled) {
        if (hideButton) {
            [hideButton removeFromSuperview];
            hideButton = nil;
        }

        // 图标大小优先级：大>中>小，默认40
        CGFloat buttonSize = 40.0;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCustomAlbumSizeLarge"]) {
            buttonSize = 64.0;
        } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCustomAlbumSizeMedium"]) {
            buttonSize = 48.0;
        } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCustomAlbumSizeSmall"]) {
            buttonSize = 32.0;
        } else {
            CGFloat userSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYEnableFloatClearButtonSize"];
            if (userSize > 0) buttonSize = userSize;
        }

        hideButton = [[HideUIButton alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
        hideButton.alpha = 0.5;

        NSString *savedPositionString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideUIButtonPosition"];
        if (savedPositionString) {
            hideButton.center = CGPointFromString(savedPositionString);
        } else {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            hideButton.center = CGPointMake(screenWidth - buttonSize/2 - 5, screenHeight / 2);
        }

        hideButton.hidden = YES;
        [getKeyWindow() addSubview:hideButton];

        // 添加通知监听
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                         object:nil
                                                          queue:[NSOperationQueue mainQueue]
                                                     usingBlock:^(NSNotification * _Nonnull notification) {
            isAppActive = YES;
            updateClearButtonVisibility();
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                         object:nil
                                                          queue:[NSOperationQueue mainQueue]
                                                     usingBlock:^(NSNotification * _Nonnull notification) {
            isAppActive = NO;
            updateClearButtonVisibility();
        }];
    }
    
    return result;
}
%end

%ctor {
    signal(SIGSEGV, SIG_IGN);
}