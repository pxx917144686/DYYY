#import "DYYYHookShared.h"

%hook AWENormalModeTabBarGeneralPlusButton

- (void)didMoveToWindow {
    %orig;
    if (self.window && DYYYGetBool(@"DYYYisHiddenJia")) {
        self.userInteractionEnabled = NO;
        self.hidden = YES;
    }
}

- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYisHiddenJia")) {
        self.userInteractionEnabled = NO;
        self.hidden = YES;
    }
}

%end

%hook AWEHPTopTabItemTextContentView

- (void)layoutSubviews {
	%orig;

	NSString *topTitleConfig = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModifyTopTabText"];
	if (topTitleConfig.length == 0)
		return;

	NSArray *titlePairs = [topTitleConfig componentsSeparatedByString:@"#"];

	NSString *accessibilityLabel = nil;
	if ([self.superview respondsToSelector:@selector(accessibilityLabel)]) {
		accessibilityLabel = self.superview.accessibilityLabel;
	}
	if (accessibilityLabel.length == 0)
		return;

	for (NSString *pair in titlePairs) {
		NSArray *components = [pair componentsSeparatedByString:@"="];
		if (components.count != 2)
			continue;

		NSString *originalTitle = components[0];
		NSString *newTitle = components[1];

		if ([accessibilityLabel isEqualToString:originalTitle]) {
			if ([self respondsToSelector:@selector(setContentText:)]) {
				[self setContentText:newTitle];
			} else {
				[self setValue:newTitle forKey:@"contentText"];
			}
			break;
		}
	}
}

%end

%hook AWEDiscoverFeedEntranceView
- (id)init {
	if (DYYYCachedBool(@"DYYYHideInteractionSearch")) {
		return nil;
	}
	return %orig;
}
%end

%hook AWEProfileNavigationButton
- (void)setupUI {

	if (DYYYCachedBool(@"DYYYHideButton")) {
		return;
	}
	%orig;
}
%end

%hook AWENormalModeTabBarBadgeContainerView

- (void)layoutSubviews {
    %orig;
    if (DYYYCachedBool(@"DYYYisHiddenBottomDot")) {
        for (UIView *subview in [self subviews]) {
            if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
                [subview setHidden:YES];
            }
        }
    }
}

%end

%hook AWELeftSideBarEntranceView

- (void)layoutSubviews {

	__block BOOL isInTargetController = NO;
	UIResponder *currentResponder = self;

	while ((currentResponder = [currentResponder nextResponder])) {
		if ([currentResponder isKindOfClass:NSClassFromString(@"AWEUserHomeViewControllerV2")]) {
			isInTargetController = YES;
			break;
		}
	}

	if (!isInTargetController && DYYYCachedBool(@"DYYYisHiddenLeftSideBar")) {
		for (UIView *subview in self.subviews) {
			subview.hidden = YES;
		}
	}
}

- (void)setRedDot:(id)redDot {
    %orig(nil); 
}

- (void)setNumericalRedDot:(id)numericalRedDot {
    %orig(nil); 
}

%end

%hook AWENormalModeTabBarGeneralButton

- (void)layoutSubviews {
    %orig;
}

- (void)setStatus:(NSInteger)status {
    %orig(status);
}

%end

%hook AWELoadingAndVolumeView

- (void)layoutSubviews {
	%orig;

	if ([self respondsToSelector:@selector(removeFromSuperview)]) {
		[self removeFromSuperview];
	}
	self.hidden = YES;
	return;
}

%end

%hook AWEHPSearchBubbleEntranceView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideSearchBubble")) {
		[self removeFromSuperview];
		return;
	}
}

%end

%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
    %orig;
    
    NSString *indexTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYIndexTitle"];
    NSString *friendsTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFriendsTitle"];
    NSString *msgTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYMsgTitle"];
    NSString *selfTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSelfTitle"];
    
    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"首页"]) {
                if (indexTitle.length > 0) {
                    [label setText:indexTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"朋友"]) {
                if (friendsTitle.length > 0) {
                    [label setText:friendsTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"消息"]) {
                if (msgTitle.length > 0) {
                    [label setText:msgTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"我"]) {
                if (selfTitle.length > 0) {
                    [label setText:selfTitle];
                    [self setNeedsLayout];
                }
            }
        }
    }
}
%end

%hook AWEHPTopTabItemBadgeContentView

- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideLiveCapsuleView")) {
		self.frame = CGRectMake(0, 0, 0, 0);
		self.hidden = YES;
	}
}

// 隐藏顶栏红点
- (id)showBadgeWithBadgeStyle:(NSUInteger)style badgeConfig:(id)config count:(NSInteger)count text:(id)text {
	BOOL hideEnabled = DYYYCachedBool(@"DYYYHideTopBarBadge");

	if (hideEnabled) {
		// 阻断徽章创建
		return nil; // 返回 nil 阻止视图生成
	} else {
		// 未启用隐藏功能时正常显示
		return %orig(style, config, count, text);
	}
}

%end

%hook AWEHPDiscoverFeedEntranceView
- (void)setAlpha:(CGFloat)alpha {
    if (DYYYCachedBool(@"DYYYHideDiscover")) {
        alpha = 0;
        %orig(alpha);
   }else {
       %orig;
    }
}

// 隐藏右上搜索，但可点击
- (void)layoutSubviews {
    %orig;

    if (DYYYCachedBool(@"DYYYHideDiscover")) {
        UIView *firstSubview = self.subviews.firstObject;
        if ([firstSubview isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)firstSubview).image = nil;
        }
    }
}

%end

%hook AWENormalModeTabBarFeedView
- (void)layoutSubviews {
    %orig;
    
    if (DYYYCachedBool(@"DYYYHideDoubleColumnEntry")) {
        for (UIView *subview in self.subviews) {
            if (![subview isKindOfClass:[UILabel class]]) {
                subview.hidden = YES;
            }
        }
    }
}
%end

%hook AWEHPTopBarCTAItemView

- (void)showRedDot {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYisHiddenSidebarDot"])
		%orig;
}

- (void)hideCountRedDot {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYisHiddenSidebarDot"])
		%orig;
}

- (void)layoutSubviews {
	%orig;
	for (UIView *subview in self.subviews) {
		if ([subview isKindOfClass:[%c(DUXBadge) class]]) {
				if (DYYYCachedBool(@"DYYYisHiddenSidebarDot")) {
				subview.hidden = YES;
			}
		}
	}
}
%end

%hook AWESearchEntranceView

- (void)layoutSubviews {

	if (DYYYCachedBool(@"DYYYHideSearchEntrance")) {
		self.hidden = YES;
		return;
	}

	if (DYYYCachedBool(@"DYYYHideSearchEntranceIndicator")) {
		for (UIView *subview in self.subviews) {
			if ([subview isKindOfClass:[UIImageView class]] && [NSStringFromClass([((UIImageView *)subview).image class]) isEqualToString:@"_UIResizableImage"]) {
				((UIImageView *)subview).hidden = YES;
			}
		}
	}

	%orig;
}

%end

%hook AFDRecommendToFriendEntranceLabel
- (void)layoutSubviews {
	%orig;  // 调用原始方法
	
	// 检查是否启用了"隐藏推荐提示"的设置
	if (DYYYCachedBool(@"DYYYHideRecommendTips")) {
		// 确认视图有可访问性标签后移除此视图
		if (self.accessibilityLabel) {
			[self removeFromSuperview];  // 从父视图中移除该推荐入口标签
		}
	}
}

%end

%hook AWENormalModeTabBarGeneralButton

- (BOOL)enableRefresh {
	if ([self.accessibilityLabel isEqualToString:@"首页"]) {
		if (DYYYCachedBool(@"DYYYDisableHomeRefresh")) {
			return NO;
		}
	}
	return %orig;
}

%end

