#import "DYYYHookShared.h"

%hook AWEFeedLiveMarkView
- (void)setHidden:(BOOL)hidden {
    if (DYYYCachedBool(@"DYYYHideAvatarButton")) {
        hidden = YES;
    }

    %orig(hidden);
}
%end

%hook IESLiveActivityBannnerView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideGiftPavilion")) {
		self.hidden = YES;
	}
}

%end

%hook IESLiveFeedDrawerEntranceView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideLivePlayground")) {
		self.hidden = YES;
	}
}

%end

%hook IESLiveAudienceViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYCachedBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(IESLiveAudienceViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

%hook AWELiveFeedStatusLabel
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideEnterLive")) {
		UIView *parentView = self.superview;
		UIView *grandparentView = parentView.superview;

		if (grandparentView) {
			grandparentView.hidden = YES;
		} else if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}
%end

%hook AWEIMCellLiveStatusContainerView

- (void)p_initUI {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYGroupLiving"])
		%orig;
}
%end

%hook AWELiveStatusIndicatorView

- (void)layoutSubviews {
	if (DYYYCachedBool(@"DYYYGroupLiving")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWELiveSkylightCatchView
- (void)layoutSubviews {

	if (DYYYCachedBool(@"DYYYHidenLiveCapsuleView")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}

%end

%hook IESLiveButton

- (void)layoutSubviews {
	%orig;

	// 处理清屏按钮
	if (DYYYCachedBool(@"DYYYHideLiveRoomClear")) {
		if ([self.accessibilityLabel isEqualToString:@"退出清屏"] && self.superview) {
			[self.superview removeFromSuperview];
		}
	}

	// 投屏按钮
	if (DYYYCachedBool(@"DYYYHideLiveRoomMirroring")) {
		if ([self.accessibilityLabel isEqualToString:@"投屏"] && self.superview) {
			[self.superview removeFromSuperview];
		}
	}

	// 横屏按钮,可点击
	if (DYYYCachedBool(@"DYYYHideLiveRoomFullscreen")) {
		if ([self.accessibilityLabel isEqualToString:@"横屏"] && self.superview) {
			for (UIView *subview in self.subviews) {
			subview.hidden = YES;
			}
		}
	}
}

%end

%hook IESLiveLayoutPlaceholderView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideLiveRoomClose")) {
		self.hidden = YES;
	}
}
%end

%hook AWELiveFlowAlertView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideCellularAlert")) {
		self.hidden = YES;
	}
}
%end

%hook IESECLivePluginLayoutView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideLiveGoodsMsg")) {
		[self removeFromSuperview];
	}
}
%end

%hook HTSLiveDiggView
- (void)setIconImageView:(UIImageView *)arg1 {
	if (DYYYGetBool(@"DYYYHideLiveLikeAnimation")) {
		%orig(nil);
	} else {
		%orig(arg1);
	}
}
%end

%hook AWEFeedLiveTabRevisitControlView

- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideLiveDiscovery")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
}
%end

%hook IESLiveKTVSongIndicatorView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideKTVSongIndicator")) {
		self.hidden = YES;
		[self removeFromSuperview];
	}
}
%end

%hook AWELiveGuideElement

- (BOOL)enableAutoEnterRoom {
	if (DYYYCachedBool(@"DYYYDisableAutoEnterLive")) {
		return NO;
	}
	return %orig;
}

- (BOOL)enableNewAutoEnter {
	if (DYYYCachedBool(@"DYYYDisableAutoEnterLive")) {
		return NO;
	}
	return %orig;
}

%end

%hook AWENewLiveSkylightViewController
// 隐藏顶部直播视图 - 添加条件判断
- (void)showSkylight:(BOOL)arg0 animated:(BOOL)arg1 actionMethod:(unsigned long long)arg2 {
	if (DYYYCachedBool(@"DYYYHidenLiveView")) {
		return;
	}
	%orig(arg0, arg1, arg2);
}

- (void)updateIsSkylightShowing:(BOOL)arg0 {
	if (DYYYCachedBool(@"DYYYHidenLiveView")) {
		%orig(NO);
	} else {
		%orig(arg0);
	}
}

%end

%hook AWELiveAutoEnterStyleAView

- (void)layoutSubviews {
	%orig;  // 调用原始方法

	// 检查是否启用隐藏直播视图功能
	if (DYYYCachedBool(@"DYYYHidenLiveView")) {
		// 从父视图中移除此视图，实现隐藏效果
		[self removeFromSuperview];
		return;
	}
}

%end

%hook HTSLiveStreamQualityFragment

- (void)setupStreamQuality:(id)arg1 {
	%orig;

	BOOL enableHighestQuality = DYYYCachedBool(@"DYYYEnableLiveHighestQuality");
	if (enableHighestQuality) {
		NSArray *qualities = self.streamQualityArray;
		if (!qualities || qualities.count == 0) {
			qualities = [self getQualities];
		}

		if (!qualities || qualities.count == 0) {
			return;
		}
		// 选择索引0作为最高清晰度
		[self setResolutionWithIndex:0 isManual:YES beginChange:nil completion:nil];
	}
}

%end

%hook HTSLiveStreamPcdnManager

+ (void)start {
	BOOL disablePCDN = DYYYCachedBool(@"DYYYDisableLivePCDN");
	if (!disablePCDN) {
		%orig;
	}
}

+ (void)configAndStartLiveIO {
	BOOL disablePCDN = DYYYCachedBool(@"DYYYDisableLivePCDN");
	if (!disablePCDN) {
		%orig;
	}
}

%end

