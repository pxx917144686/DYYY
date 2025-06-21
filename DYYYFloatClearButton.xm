#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <signal.h>
#import "DYYYManager.h"

// 添加变量跟踪是否在目标视图控制器中
static BOOL isInPlayInteractionVC = NO;
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
- (void)refreshCustomIconAndSize; // 新增方法声明
@end
// 全局变量
static void setupFloatClearButton(void);
static void updateFloatClearButton(NSString *changedKey);
static void initTargetClassNames(void);
static HideUIButton *hideButton;
static BOOL isAppInTransition = NO;
static NSArray *targetClassNames;
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
	for (NSString *className in targetClassNames) {
		Class viewClass = NSClassFromString(className);
		if (!viewClass)
			continue;
		NSMutableArray *views = [NSMutableArray array];
		findViewsOfClassHelper(window, viewClass, views);
		for (UIView *view in views) {
			view.alpha = 1.0;
		}
	}
}
static void reapplyHidingToAllElements(HideUIButton *button) {
	if (!button || !button.isElementsHidden)
		return;
	[button hideUIElements];
}

// 实现浮动按钮的创建和配置逻辑
static void setupFloatClearButton(void) {
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

        hideButton.hidden = !isInPlayInteractionVC;
        [getKeyWindow() addSubview:hideButton];
    } else {
        if (hideButton) {
            [hideButton removeFromSuperview];
            hideButton = nil;
        }
    }
}

// 处理设置更新的函数
static void updateFloatClearButton(NSString *changedKey) {
    NSArray *floatButtonKeys = @[
        @"DYYYEnableFloatClearButton",
        @"DYYYEnableFloatClearButtonSize",
        @"DYYYCustomAlbumSizeLarge",
        @"DYYYCustomAlbumSizeMedium",
        @"DYYYCustomAlbumSizeSmall",
        @"DYYYCustomAlbumImagePath",
        @"DYYYEnableCustomAlbum"
    ];
    NSArray *hideOptionKeys = @[
        @"DYYYHideTabBar",
        @"DYYYHideDanmaku",
        @"DYYYHideSlider",
        @"DYYYHideChapter"
    ];
    if ([floatButtonKeys containsObject:changedKey]) {
        setupFloatClearButton();
        if (hideButton) [hideButton refreshCustomIconAndSize];
    }
    if ([hideOptionKeys containsObject:changedKey] || [changedKey hasPrefix:@"DYYYHide"]) {
        initTargetClassNames();
        if (hideButton && hideButton.isElementsHidden) {
            [hideButton hideUIElements];
        }
    }
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
- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.layer.cornerRadius = frame.size.width / 2;
		self.layer.masksToBounds = YES;
		self.isElementsHidden = NO;
		self.hiddenViewsList = [NSMutableArray array];
        
        // 设置默认状态为半透明
        self.originalAlpha = 1.0;  // 交互时为完全不透明
        self.alpha = 0.5;  // 初始为半透明
		// 加载保存的锁定状态
		[self loadLockState];
		[self loadIcons];
		[self setImage:self.showIcon forState:UIControlStateNormal];
		UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
		[self addGestureRecognizer:panGesture];
		[self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
		[self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
		[self addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
		[self addTarget:self action:@selector(handleTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside];
		UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
		[self addGestureRecognizer:longPressGesture];
		[self startPeriodicCheck];
		[self resetFadeTimer];
        
        // 初始状态下隐藏按钮，直到进入正确的控制器
        self.hidden = YES;
	}
	return self;
}
- (void)startPeriodicCheck {
	[self.checkTimer invalidate];
	self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
							  repeats:YES
							    block:^(NSTimer *timer) {
							      if (self.isElementsHidden) {
								      [self hideUIElements];
							      }
							    }];
}
- (void)resetFadeTimer {
	[self.fadeTimer invalidate];
	self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
							 repeats:NO
							   block:^(NSTimer *timer) {
							     [UIView animateWithDuration:0.3
									      animations:^{
										self.alpha = 0.5;  // 变为半透明
									      }];
							   }];
	// 交互时变为完全不透明
    if (self.alpha != self.originalAlpha) {
        [UIView animateWithDuration:0.2
                         animations:^{
                             self.alpha = self.originalAlpha;  // 变为完全不透明
                         }];
    }
}
- (void)saveLockState {
	[[NSUserDefaults standardUserDefaults] setBool:self.isLocked forKey:@"DYYYHideUIButtonLockState"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)loadLockState {
	self.isLocked = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideUIButtonLockState"];
}
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
    // 兼容旧逻辑
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
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

// 新增：根据设置刷新图标和大小
- (void)refreshCustomIconAndSize {
    // 图标大小优先级：大>中>小，默认40
    CGFloat size = 40.0;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCustomAlbumSizeLarge"]) {
        size = 64.0;
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCustomAlbumSizeMedium"]) {
        size = 48.0;
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCustomAlbumSizeSmall"]) {
        size = 32.0;
    }
    CGRect newFrame = CGRectMake(self.frame.origin.x, self.frame.origin.y, size, size);
    self.frame = newFrame;
    self.layer.cornerRadius = size / 2;
    [self loadIcons];
}

- (void)handleTouchDown {
	[self resetFadeTimer];  // 这会使按钮变为完全不透明
}
- (void)handleTouchUpInside {
	[self resetFadeTimer];  // 这会使按钮变为完全不透明
}
- (void)handleTouchUpOutside {
	[self resetFadeTimer];  // 这会使按钮变为完全不透明
}
- (UIViewController *)findViewController:(UIView *)view {
	__weak UIResponder *responder = view;
	while (responder) {
		if ([responder isKindOfClass:[UIViewController class]]) {
			return (UIViewController *)responder;
		}
		responder = [responder nextResponder];
		if (!responder)
			break;
	}
	return nil;
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
	if (self.isLocked)
		return;
	[self resetFadeTimer];  // 这会使按钮变为完全不透明
	CGPoint translation = [gesture translationInView:self.superview];
	CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
	newCenter.x = MAX(self.frame.size.width / 2, MIN(newCenter.x, self.superview.frame.size.width - self.frame.size.width / 2));
	newCenter.y = MAX(self.frame.size.height / 2, MIN(newCenter.y, self.superview.frame.size.height - self.frame.size.height / 2));
	self.center = newCenter;
	[gesture setTranslation:CGPointZero inView:self.superview];
	if (gesture.state == UIGestureRecognizerStateEnded) {
		[[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGPoint(self.center) forKey:@"DYYYHideUIButtonPosition"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}
- (void)handleTap {
	if (isAppInTransition)
		return;
	[self resetFadeTimer];  // 这会使按钮变为完全不透明
	if (!self.isElementsHidden) {
		[self hideUIElements];
		self.isElementsHidden = YES;
		self.selected = YES;
	} else {
		forceResetAllUIElements();
		self.isElementsHidden = NO;
		[self.hiddenViewsList removeAllObjects];
		self.selected = NO;
	}
}
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state == UIGestureRecognizerStateBegan) {
		[self resetFadeTimer];  // 这会使按钮变为完全不透明
		self.isLocked = !self.isLocked;
		// 保存锁定状态
		[self saveLockState];
		NSString *toastMessage = self.isLocked ? @"按钮已锁定" : @"按钮已解锁";
		[DYYYManager showToast:toastMessage];
		if (@available(iOS 10.0, *)) {
			UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
			[generator prepare];
			[generator impactOccurred];
		}
	}
}
- (void)hideUIElements {
	[self.hiddenViewsList removeAllObjects];
	[self findAndHideViews:targetClassNames];
	self.isElementsHidden = YES;
}
- (void)findAndHideViews:(NSArray *)classNames {
	for (UIWindow *window in [UIApplication sharedApplication].windows) {
		for (NSString *className in classNames) {
			Class viewClass = NSClassFromString(className);
			if (!viewClass)
				continue;
			NSMutableArray *views = [NSMutableArray array];
			findViewsOfClassHelper(window, viewClass, views);
			for (UIView *view in views) {
				if ([view isKindOfClass:[UIView class]]) {
					if ([view isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
						UIViewController *controller = [self findViewController:view];
						if (![controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
							continue;
						}
					}
					[self.hiddenViewsList addObject:view];
					view.alpha = 0.0;
				}
			}
		}
	}
}
- (void)safeResetState {
	forceResetAllUIElements();
	self.isElementsHidden = NO;
	[self.hiddenViewsList removeAllObjects];
	self.selected = NO;
}
- (void)dealloc {
	[self.checkTimer invalidate];
	[self.fadeTimer invalidate];
	self.checkTimer = nil;
	self.fadeTimer = nil;
}
@end
// Hook 部分
%hook UIView
- (id)initWithFrame:(CGRect)frame {
	UIView *view = %orig;
	if (hideButton && hideButton.isElementsHidden) {
		for (NSString *className in targetClassNames) {
			if ([view isKindOfClass:NSClassFromString(className)]) {
				if ([view isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
					dispatch_async(dispatch_get_main_queue(), ^{
					  UIViewController *controller = [hideButton findViewController:view];
					  if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
						  view.alpha = 0.0;
					  }
					});
					break;
				}
				view.alpha = 0.0;
				break;
			}
		}
	}
	return view;
}
- (void)didAddSubview:(UIView *)subview {
	%orig;
	if (hideButton && hideButton.isElementsHidden) {
		for (NSString *className in targetClassNames) {
			if ([subview isKindOfClass:NSClassFromString(className)]) {
				if ([subview isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
					UIViewController *controller = [hideButton findViewController:subview];
					if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
						subview.alpha = 0.0;
					}
					break;
				}
				subview.alpha = 0.0;
				break;
			}
		}
	}
}
- (void)willMoveToSuperview:(UIView *)newSuperview {
	%orig;
	if (hideButton && hideButton.isElementsHidden) {
		for (NSString *className in targetClassNames) {
			if ([self isKindOfClass:NSClassFromString(className)]) {
				if ([self isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
					UIViewController *controller = [hideButton findViewController:self];
					if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
						self.alpha = 0.0;
					}
					break;
				}
				self.alpha = 0.0;
				break;
			}
		}
	}
}
%end
%hook AWEFeedTableViewCell
- (void)prepareForReuse {
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
	%orig;
}
- (void)layoutSubviews {
	%orig;
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
}
%end
%hook AWEFeedViewCell
- (void)layoutSubviews {
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
	%orig;
}
- (void)setModel:(id)model {
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
	%orig;
}
%end
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
	%orig;
	isAppInTransition = YES;
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	  isAppInTransition = NO;
	});
}
- (void)viewWillDisappear:(BOOL)animated {
	%orig;
	isAppInTransition = YES;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	  isAppInTransition = NO;
	});
}
%end
// 修改: 使用 viewWillAppear 和 loadView 来更早地显示按钮
%hook AWEPlayInteractionViewController
- (void)loadView {
    %orig;
    // 提前准备按钮显示
    if (hideButton) {
        hideButton.hidden = NO;
        hideButton.alpha = 0.5;
    }
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isInPlayInteractionVC = YES;
    // 立即显示按钮
    if (hideButton) {
        hideButton.hidden = NO;
        hideButton.alpha = 0.5;
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 再次确保按钮可见
    if (hideButton) {
        hideButton.hidden = NO;
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    isInPlayInteractionVC = NO;
    // 立即隐藏按钮
    if (hideButton) {
        hideButton.hidden = YES;
    }
}
%end
%hook AWEFeedContainerViewController
- (void)aweme:(id)arg1 currentIndexWillChange:(NSInteger)arg2 {
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
	%orig;
}
- (void)aweme:(id)arg1 currentIndexDidChange:(NSInteger)arg2 {
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
	%orig;
}
- (void)viewWillLayoutSubviews {
	%orig;
	if (hideButton && hideButton.isElementsHidden) {
		[hideButton hideUIElements];
	}
}
%end
%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    initTargetClassNames();
    
    // 使用抽取的函数初始化浮动清除按钮
    setupFloatClearButton();

    // 监听自定义相册设置变更
    [[NSNotificationCenter defaultCenter] addObserverForName:@"DYYYCustomAlbumSettingChanged"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (hideButton) [hideButton refreshCustomIconAndSize];
    }];

    // 监听窗口活动状态
    [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeKeyNotification
                                                     object:nil
                                                      queue:[NSOperationQueue mainQueue]
                                                 usingBlock:^(NSNotification * _Nonnull notification) {
        if (isInPlayInteractionVC && hideButton && hideButton.hidden) {
            hideButton.hidden = NO;
        }
    }];
    
    // 监听所有设置变更
    [[NSNotificationCenter defaultCenter] addObserverForName:@"DYYYSettingChanged"
                                                     object:nil
                                                      queue:[NSOperationQueue mainQueue]
                                                 usingBlock:^(NSNotification * _Nonnull note) {
        NSString *key = note.userInfo[@"key"];
        // 处理设置变更
        updateFloatClearButton(key);
    }];
    
    return result;
}
%end
%ctor {
	signal(SIGSEGV, SIG_IGN);
}