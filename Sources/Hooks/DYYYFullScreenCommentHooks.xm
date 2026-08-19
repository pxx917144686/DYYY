//
//  DYYYFullScreenCommentHooks.xm
//  DYYY
//
//  全屏播放与评论区布局 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

%hook AWECommentContainerViewController

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	dyyyCommentViewVisible = YES;
	[dyyyCurrentFullScreenInteractionVC.viewIfLoaded setNeedsLayout];
}

- (void)viewDidDisappear:(BOOL)animated {
	%orig;
	dyyyCommentViewVisible = NO;
	[dyyyCurrentFullScreenInteractionVC.viewIfLoaded setNeedsLayout];
}

%end

%hook TTMetalView
- (void)setCenter:(CGPoint)center {
    if (DYYYFullScreenCommentOriginalLayoutActive()) {
        %orig(center);
        return;
    }
    BOOL shouldAdjust = NO;
    UIView *view = (UIView *)self;
    if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
        CGFloat viewWidth = CGRectGetWidth(view.bounds);
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        if (viewWidth + 0.5f >= screenWidth) {
            UIViewController *vc = [DYYYUtils findViewControllerFromView:view];
            Class playClass = %c(AWEPlayVideoViewController);
            if (playClass && [vc isKindOfClass:playClass]) {
                AWEPlayVideoViewController *playVC = (AWEPlayVideoViewController *)vc;
                AWEAwemeModel *model = playVC.model;
                if ([model respondsToSelector:@selector(isShowLandscapeEntryView)] && model.isShowLandscapeEntryView) {
                    shouldAdjust = YES;
                }
            }
        }
    }

    if (shouldAdjust && tabHeight > 0) {
        center.y -= tabHeight * 0.5;
    }

    %orig(center);
}
%end

%hook TTMetalViewNew
- (void)setCenter:(CGPoint)center {
    if (DYYYFullScreenCommentOriginalLayoutActive()) {
        %orig(center);
        return;
    }
    BOOL shouldAdjust = NO;
    UIView *view = (UIView *)self;
    if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
        CGFloat viewWidth = CGRectGetWidth(view.bounds);
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        if (viewWidth + 0.5f >= screenWidth) {
            UIViewController *vc = [DYYYUtils findViewControllerFromView:view];
            Class playClass = %c(AWEPlayVideoViewController);
            if (playClass && [vc isKindOfClass:playClass]) {
                AWEPlayVideoViewController *playVC = (AWEPlayVideoViewController *)vc;
                AWEAwemeModel *model = playVC.model;
                if ([model respondsToSelector:@selector(isShowLandscapeEntryView)] && model.isShowLandscapeEntryView) {
                    shouldAdjust = YES;
                }
            }
        }
    }

    if (shouldAdjust && tabHeight > 0) {
        center.y -= tabHeight * 0.5;
    }

    %orig(center);
}
%end

%hook TTMetalViewVP
- (void)setCenter:(CGPoint)center {
    if (DYYYFullScreenCommentOriginalLayoutActive()) {
        %orig(center);
        return;
    }
    BOOL shouldAdjust = NO;
    UIView *view = (UIView *)self;
    if (DYYYGetBool(@"DYYYisEnableFullScreen")) {
        CGFloat viewWidth = CGRectGetWidth(view.bounds);
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        if (viewWidth + 0.5f >= screenWidth) {
            UIViewController *vc = [DYYYUtils findViewControllerFromView:view];
            Class playClass = %c(AWEPlayVideoViewController);
            if (playClass && [vc isKindOfClass:playClass]) {
                AWEPlayVideoViewController *playVC = (AWEPlayVideoViewController *)vc;
                AWEAwemeModel *model = playVC.model;
                if ([model respondsToSelector:@selector(isShowLandscapeEntryView)] && model.isShowLandscapeEntryView) {
                    shouldAdjust = YES;
                }
            }
        }
    }

    if (shouldAdjust && tabHeight > 0) {
        center.y -= tabHeight * 0.5;
    }

    %orig(center);
}
%end

// 全屏模式下纯模式页进度指示器位置调整（移植自 DYYY12345/DYYY.xm:12597-12604）
%hook AWEStoryProgressContainerView
- (void)setCenter:(CGPoint)center {
    UIViewController *vc = [DYYYUtils findViewControllerFromView:self];
    if ([vc isKindOfClass:NSClassFromString(@"AWEFeedPlayControlImpl.PureModePageCellViewController")] && DYYYGetBool(@"DYYYisEnableFullScreen")) {
        center.y -= tabHeight;
    }
    %orig(center);
}
%end

// 全屏模式下关注页末尾视图上移（移植自 DYYY12345/DYYY.xm:11125-11137）
%hook AWEConcernCellLastView
- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYisEnableFullScreen") && tabHeight > 0) {
        for (UIView *subview in self.subviews) {
            CGRect frame = subview.frame;
            frame.origin.y -= tabHeight;
            subview.frame = frame;
        }
    }
}
%end

// findViewControllerFromView 直接查询：静态 weak 缓存会在对象 dealloc 时触发 objc_storeWeak 致命崩溃
static UIViewController *DYYYFindVCWithCache(UIView *view) {
    return [DYYYUtils findViewControllerFromView:view];
}

%hook UIView

- (void)setFrame:(CGRect)frame {

    if ([self isKindOfClass:%c(AWEIMSkylightListView)] && DYYYCachedBool(@"DYYYisHiddenAvatarList")) {
        frame = CGRectZero;
    }

    if (!DYYYLegacyCommentBlurActive() && !DYYYCachedBool(@"DYYYisEnableFullScreen")) {
        %orig;
        return;
    }

    UIViewController *vc = DYYYFindVCWithCache(self);
    Class PlayVCClass1 = %c(AWEAwemePlayVideoViewController);
    Class PlayVCClass2 = NSClassFromString(@"AWEDPlayerFeedPlayerViewController");
    Class PlayVCClass3 = NSClassFromString(@"AWEDPlayerViewController_Merge");
    
    BOOL isPlayVC = ((PlayVCClass1 && [vc isKindOfClass:PlayVCClass1]) ||
                     (PlayVCClass2 && [vc isKindOfClass:PlayVCClass2]) ||
                     (PlayVCClass3 && [vc isKindOfClass:PlayVCClass3]));

    if (isPlayVC && DYYYFullScreenCommentOriginalLayoutActive()) {
        %orig(frame);
        return;
    }
    
    if (isPlayVC) {

        if (DYYYLegacyCommentBlurActive() && frame.origin.x != 0) {
            return;
        } else if (DYYYCachedBool(@"DYYYisEnableFullScreen") && frame.origin.x != 0 && frame.origin.y != 0) {
            %orig;
            return;
        } else {
            CGRect superviewFrame = self.superview.frame;

            if (superviewFrame.size.height > 0 && frame.size.height > 0 && frame.size.height < superviewFrame.size.height && frame.origin.x == 0 && frame.origin.y == 0) {

                CGFloat heightDifference = superviewFrame.size.height - frame.size.height;
                if (fabs(heightDifference - tabHeight) < 1.0) {
                    frame.size.height = superviewFrame.size.height;
                    %orig(frame);
                    return;
                }
            }
        }
    }
    %orig;
}

- (void)setAlpha:(CGFloat)alpha {
    if (alpha > 0) {
        NSString *transparentValue = DYYYCachedString(@"DYYYGlobalTransparency");
        if (transparentValue.length > 0) {
            CGFloat alphaValue = transparentValue.floatValue;
            if (alphaValue >= 0.0 && alphaValue <= 1.0) {
                UIViewController *vc = DYYYFindVCWithCache(self);
                if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                    %orig(alphaValue);
                    return;
                }
            }
        }
    }
    %orig;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    // 保留主线程防护：后台线程直碰 UIKit 有崩溃风险，重派发到主线程执行(重派发后主线程走 %orig，无递归)
    if (![NSThread isMainThread]) {
        __weak UIView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setBackgroundColor:backgroundColor];
        });
        return;
    }

    if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
        UIViewController *vc = DYYYFindVCWithCache(self);
        if ([vc isKindOfClass:%c(AWEAwemeDetailTableViewController)] ||
            [vc isKindOfClass:%c(AWEAwemeDetailCellViewController)]) {
            %orig([UIColor clearColor]);
            return;
        }
    }

    %orig(backgroundColor);
}

- (void)layoutSubviews {
    %orig;

    if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
        if (self.frame.size.height == tabHeight && tabHeight > 0) {
            UIViewController *vc = DYYYFindVCWithCache(self);
            if ([vc isKindOfClass:NSClassFromString(@"AWEMixVideoPanelDetailTableViewController")] || [vc isKindOfClass:NSClassFromString(@"AWECommentInputViewController")] ||
                [vc isKindOfClass:NSClassFromString(@"AWEAwemeDetailTableViewController")]) {
                self.backgroundColor = [UIColor clearColor];
            }
        }
    }

    if (DYYYCachedBool(@"DYYYisEnableFullScreen") || DYYYLegacyCommentBlurActive()) {
        UIViewController *vc = DYYYFindVCWithCache(self);
        if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor && CGColorEqualToColor(subview.backgroundColor.CGColor, [UIColor blackColor].CGColor)) {
                    subview.hidden = YES;
                }
            }
        }
    }
}

%end

%hook AWEBaseListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (DYYYLegacyCommentBlurActive() && [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {
        float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
        if (userTransparency <= 0 || userTransparency > 1) {
            userTransparency = 0.9;
        }
        [DYYYUtils applyBlurEffectToView:self.view transparency:userTransparency blurViewTag:999];
    }
}
%end

%hook AWEListKitMagicCollectionView

- (void)layoutSubviews {
    %orig;

    if (!DYYYLegacyCommentBlurActive()) {
        return;
    }

    UICollectionView *collectionView = (UICollectionView *)self;

    UIView *superview = collectionView.superview;
    CGRect targetFrame = superview.bounds;
    if (superview == nil || CGSizeEqualToSize(targetFrame.size, CGSizeZero) || CGRectEqualToRect(collectionView.frame, targetFrame)) {
        return;
    }

    collectionView.frame = targetFrame;

    CGFloat commentOffset = 166.0;

    UIEdgeInsets inset = collectionView.contentInset;
    inset.bottom = commentOffset;
    collectionView.contentInset = inset;
    collectionView.scrollIndicatorInsets = inset;
}

%end

%group BDMultiContentImageViewGroup
%hook BDMultiContentContainer_ImageContentView

- (void)setTransform:(CGAffineTransform)transform {
    if (DYYYLegacyCommentBlurActive()) {
        return;
    }
    %orig(transform);
}

%end
%end

%hook AWEAwemeDetailTableView

- (void)setFrame:(CGRect)frame {
	if (DYYYFullScreenCommentOriginalLayoutActive()) {
		%orig(frame);
		return;
	}
	// 检查是否启用了全屏模式（通过用户默认设置）
	if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
		// 获取设备屏幕的高度
		CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

		// 计算frame高度与屏幕高度的余数
		CGFloat remainder = fmod(frame.size.height, screenHeight);
		// 如果余数不为0，说明高度不是屏幕高度的整数倍
		if (remainder != 0) {
			// 调整frame高度，使其成为屏幕高度的整数倍，确保视图填满整个屏幕
			frame.size.height += (screenHeight - remainder);
		}
	}
	// 调用原始的setFrame:方法来设置调整后的frame
	%orig(frame);
}

%end

%hook AWEMixVideoPanelMoreView

// 调整视频面板的框架位置，实现全屏显示效果
- (void)setFrame:(CGRect)frame {
	if (DYYYFullScreenCommentOriginalLayoutActive()) {
		%orig(frame);
		return;
	}
	if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
		// 计算目标Y坐标，减去底部标签栏的高度
		CGFloat targetY = frame.origin.y - tabHeight;
		CGFloat screenHeightMinusGDiff = [UIScreen mainScreen].bounds.size.height - tabHeight;

		// 设置误差容忍度，防止精度问题
		CGFloat tolerance = 10.0;

		// 只有当接近屏幕底部时才调整位置
		if (fabs(targetY - screenHeightMinusGDiff) <= tolerance) {
			frame.origin.y = targetY;
		}
	}
	%orig(frame);
}

// 使视频面板背景透明，增强全屏体验
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
		self.backgroundColor = [UIColor clearColor];
	}
}

%end

%hook CommentInputContainerView

// 根据全屏设置调整评论输入框的显示
- (void)layoutSubviews {
	%orig;
	// 获取父视图控制器
	UIViewController *parentVC = nil;
	if ([self respondsToSelector:@selector(viewController)]) {
		id viewController = [self performSelector:@selector(viewController)];
		if ([viewController respondsToSelector:@selector(parentViewController)]) {
			parentVC = [viewController parentViewController];
		}
	}

	// 仅处理特定类型的视图控制器（聊天/私信上下文除外，避免底部空白条）
	if (parentVC && ([parentVC isKindOfClass:%c(AWEAwemeDetailTableViewController)] || [parentVC isKindOfClass:%c(AWEAwemeDetailCellViewController)])
	    && !DYYYViewControllerChainLooksLikeChat(parentVC)) {
		for (UIView *subview in [self subviews]) {
			if ([subview class] == [UIView class]) {
				// 根据高度判断是否隐藏子视图
				if ([(UIView *)self frame].size.height == tabHeight) {
					subview.hidden = YES;
				} else {
					subview.hidden = NO;
				}
				break;
			}
		}
	}
}

%end

%ctor {
    %init;

    // 初始化评论区毛玻璃视图缩放修复类组
    Class imageContentClass = objc_getClass("BDMultiContentContainer.ImageContentView");
    if (imageContentClass) {
        %init(BDMultiContentImageViewGroup, BDMultiContentContainer_ImageContentView = imageContentClass);
    }
}
