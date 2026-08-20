//
//  DYYYTabBarHooks.xm
//  DYYY
//
//  底栏布局与按钮显隐 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

%hook AWENormalModeTabBar

static Class barBackgroundClass = nil;
static Class generalButtonClass = nil;
static Class plusContainerButtonClass = nil;
static Class plusButtonClass = nil;
static Class plusInnerButtonClass = nil;
static Class tabBarButtonClass = nil;

+ (void)initialize {
    if (self == [%c(AWENormalModeTabBar) class]) {
        barBackgroundClass = NSClassFromString(@"_UIBarBackground");
        generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
        plusContainerButtonClass = %c(AWENormalModeTabBarPlusButton);
        plusButtonClass = %c(AWENormalModeTabBarGeneralPlusButton);
        plusInnerButtonClass = NSClassFromString(@"AWENormalModeTabBarGeneralPlusInnerButton");
        tabBarButtonClass = %c(UITabBarButton);
    }
}

%new
- (void)dyyy_initializeOriginalTabBarHeight {
    if (originalTabHeight > 0) {
        if (tabHeight <= 0) {
            tabHeight = originalTabHeight;
        }
        return;
    }

    UIWindow *targetWindow = self.window ?: [DYYYManager getActiveWindow];
    if (self.frame.size.height >= 30) {
        originalTabHeight = self.frame.size.height;
    } else if (targetWindow) {
        CGFloat bottomInset = 0;
        if (@available(iOS 11.0, *)) {
            bottomInset = targetWindow.safeAreaInsets.bottom;
        }
        originalTabHeight = 49 + bottomInset;
    }
    if (originalTabHeight > 0 && tabHeight <= 0) {
        tabHeight = originalTabHeight;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [self performSelector:@selector(dyyy_initializeOriginalTabBarHeight)];
    }
}

- (void)layoutSubviews {
    %orig;

    if (originalTabHeight <= 0) {
        [self performSelector:@selector(dyyy_initializeOriginalTabBarHeight)];
    }

    if (tabHeight <= 0 && originalTabHeight > 0) {
        tabHeight = originalTabHeight;
    }

    CGFloat customHeight = DYYYGetFloat(@"DYYYTabBarHeight");
    if (customHeight > 0) {
        tabHeight = customHeight;
    } else if (originalTabHeight > 0) {
        tabHeight = originalTabHeight;
    } else {
        tabHeight = self.frame.size.height;
    }

    if (tabHeight <= 0)
        return;

    if ([self respondsToSelector:@selector(setDesiredHeight:)]) {
        ((void (*)(id, SEL, double))objc_msgSend)(self, @selector(setDesiredHeight:), tabHeight);
    }

    if (fabs(self.frame.size.height - tabHeight) > 0.1) {
        CGRect frame = self.frame;
        frame.size.height = tabHeight;
        if (self.superview) {
            frame.origin.y = self.superview.bounds.size.height - tabHeight;
        }
        self.frame = frame;
    }

    BOOL hideShop = DYYYCachedBool(@"DYYYHideShopButton");
    BOOL hideMsg = DYYYCachedBool(@"DYYYHideMessageButton");
    BOOL hideFri = DYYYCachedBool(@"DYYYHideFriendsButton");
    BOOL hideMe = DYYYCachedBool(@"DYYYHideMyButton");
    BOOL hidePlus = DYYYCachedBool(@"DYYYisHiddenJia");
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    // 可见性断言每次执行：外部改动按钮显隐/label 后仍能恢复
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:generalButtonClass] || [subview isKindOfClass:plusContainerButtonClass] || [subview isKindOfClass:plusButtonClass] ||
            (plusInnerButtonClass && [subview isKindOfClass:plusInnerButtonClass])) {
            NSString *label = subview.accessibilityLabel;
            BOOL isPlusButton = [subview isKindOfClass:plusContainerButtonClass] || [subview isKindOfClass:plusButtonClass] ||
                                (plusInnerButtonClass && [subview isKindOfClass:plusInnerButtonClass]) ||
                                [label isEqualToString:@"拍摄"];
            BOOL shouldHide = (isPlusButton && hidePlus) || ([label containsString:@"商城"] && hideShop) || ([label containsString:@"消息"] && hideMsg) || ([label containsString:@"朋友"] && hideFri) ||
                              ([label isEqualToString:@"我"] && hideMe);
            subview.userInteractionEnabled = !shouldHide;
            subview.hidden = shouldHide;
        } else if ([subview isKindOfClass:tabBarButtonClass]) {
            subview.userInteractionEnabled = NO;
            subview.hidden = YES;
        }
    }

    // 脏标记：开关/宽度/subviews 集合未变化时跳过收集、排序与重排
    static NSArray *gTabBarLayoutKey = nil;
    NSArray *layoutKey = @[@(hideShop), @(hideMsg), @(hideFri), @(hideMe), @(hidePlus),
                           @(isPad), @(self.bounds.size.width), self.subviews];
    if (![layoutKey isEqualToArray:gTabBarLayoutKey]) {
        gTabBarLayoutKey = [layoutKey copy];

        NSMutableArray *visibleButtons = [NSMutableArray array];
        UIView *ipadContainerView = nil;

        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:generalButtonClass] || [subview isKindOfClass:plusContainerButtonClass] || [subview isKindOfClass:plusButtonClass] ||
                (plusInnerButtonClass && [subview isKindOfClass:plusInnerButtonClass])) {
                if (!subview.hidden) {
                    [visibleButtons addObject:subview];
                }
            } else if (isPad && !ipadContainerView && [subview isMemberOfClass:UIView.class] && fabs(subview.frame.size.width - self.bounds.size.width) > 0.1) {
                ipadContainerView = subview;
            }
        }

        [visibleButtons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
          return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
        }];

        CGFloat offsetX, totalWidth;
        if (ipadContainerView) {
            offsetX = ipadContainerView.frame.origin.x;
            totalWidth = ipadContainerView.bounds.size.width;
        } else {
            offsetX = 0;
            totalWidth = self.bounds.size.width;
        }
        CGFloat buttonWidth = (visibleButtons.count > 0) ? (totalWidth / visibleButtons.count) : 0;

        // 均匀布局按钮
        for (NSInteger i = 0; i < visibleButtons.count; i++) {
            UIView *button = visibleButtons[i];
            button.frame = CGRectMake(offsetX + i * buttonWidth, button.frame.origin.y, buttonWidth, button.frame.size.height);
        }
    }

    // 禁用首页刷新功能
    if (DYYYCachedBool(@"DYYYDisableHomeRefresh")) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:generalButtonClass]) {
                AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
                if ([button.accessibilityLabel isEqualToString:@"首页"]) {
                    // status == 2 表示选中状态
                    button.userInteractionEnabled = (button.status != 2);
                }
            }
        }
    }

    // 背景和分隔线处理
    BOOL hideBottomBg = DYYYGetBool(@"DYYYisHiddenBottomBg");
    BOOL enableFullScreen = DYYYCachedBool(@"DYYYisEnableFullScreen");

    if (hideBottomBg || enableFullScreen) {
        if (self.skinContainerView) {
            self.skinContainerView.hidden = YES;
        }

        BOOL isHomeSelected = NO;
        BOOL isFriendsSelected = NO;

        if (enableFullScreen && !hideBottomBg) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:generalButtonClass]) {
                    AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
                    if (button.status == 2) {
                        if ([button.accessibilityLabel isEqualToString:@"首页"])
                            isHomeSelected = YES;
                        else if ([button.accessibilityLabel containsString:@"朋友"])
                            isFriendsSelected = YES;
                    }
                }
            }
        }

        BOOL hideFriendsButton = DYYYCachedBool(@"DYYYHideFriendsButton");
        BOOL shouldHideBackgrounds = hideBottomBg || (enableFullScreen && (isHomeSelected || (isFriendsSelected && !hideFriendsButton)));

        // 单次遍历处理所有背景和分割线
        for (UIView *subview in self.subviews) {
            // 跳过底栏按钮
            if ([subview isKindOfClass:generalButtonClass] || [subview isKindOfClass:plusContainerButtonClass] || [subview isKindOfClass:plusButtonClass] ||
                (plusInnerButtonClass && [subview isKindOfClass:plusInnerButtonClass])) {
                continue;
            }
            // 隐藏底栏背景
            if ([subview isKindOfClass:barBackgroundClass] || ([subview isMemberOfClass:[UIView class]] && originalTabHeight > 0 && fabs(subview.frame.size.height - tabHeight) < 0.1)) {
                subview.hidden = shouldHideBackgrounds;
            }
            // 隐藏细分割线
            if (subview.frame.size.height > 0 && subview.frame.size.height < 1 && subview.frame.size.width > 300) {
                subview.hidden = enableFullScreen;
            }
        }
    } else {
        if (self.skinContainerView) {
            self.skinContainerView.hidden = NO;
        }

        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:barBackgroundClass] || [subview isMemberOfClass:[UIView class]]) {
                subview.hidden = NO;
            }
        }
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);

    BOOL disableHomeRefresh = DYYYCachedBool(@"DYYYDisableHomeRefresh");
    BOOL enableFullScreen = DYYYCachedBool(@"DYYYisEnableFullScreen");
    BOOL hideBottomBg = DYYYCachedBool(@"DYYYisHiddenBottomBg");
    BOOL hideFriendsButton = DYYYCachedBool(@"DYYYHideFriendsButton");

    BOOL isHomeSelected = NO;
    BOOL isFriendsSelected = NO;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:generalButtonClass]) {
            AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;

            // 禁用首页刷新功能
            if (disableHomeRefresh && [button.accessibilityLabel isEqualToString:@"首页"]) {
                button.userInteractionEnabled = (button.status != 2);
            }

            // 检查当前选中的页
            if (enableFullScreen && button.status == 2) {
                if ([button.accessibilityLabel isEqualToString:@"首页"]) {
                    isHomeSelected = YES;
                } else if ([button.accessibilityLabel containsString:@"朋友"]) {
                    isFriendsSelected = YES;
                }
            }
        }
    }

    if (hideBottomBg || enableFullScreen) {
        if (self.skinContainerView) {
            self.skinContainerView.hidden = YES;
        }

        BOOL shouldHideBackgrounds = NO;
        if (hideBottomBg) {
            shouldHideBackgrounds = YES;
        } else if (enableFullScreen) {
            shouldHideBackgrounds = isHomeSelected || (isFriendsSelected && !hideFriendsButton);
        }

        // 处理所有背景和分割线
        for (UIView *subview in self.subviews) {
            CGFloat subviewHeight = subview.frame.size.height;
            // 跳过底栏按钮
            if ([subview isKindOfClass:generalButtonClass] || [subview isKindOfClass:plusContainerButtonClass] || [subview isKindOfClass:plusButtonClass] ||
                (plusInnerButtonClass && [subview isKindOfClass:plusInnerButtonClass])) {
                continue;
            }
            // 隐藏底栏背景
            if ([subview isKindOfClass:barBackgroundClass] || ([subview isMemberOfClass:[UIView class]] && originalTabHeight > 0 && fabs(subviewHeight - tabHeight) < 0.1)) {
                subview.hidden = shouldHideBackgrounds;
            }
            // 隐藏细分割线
            if (subviewHeight > 0 && subviewHeight < 1 && subview.frame.size.width > 300) {
                subview.hidden = enableFullScreen;
            }
        }
    } else {
        if (self.skinContainerView) {
            self.skinContainerView.hidden = NO;
        }
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:barBackgroundClass] || [subview isMemberOfClass:[UIView class]]) {
                subview.hidden = NO;
            }
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig(previousTraitCollection);
}

%end

%ctor {
    %init;
}
