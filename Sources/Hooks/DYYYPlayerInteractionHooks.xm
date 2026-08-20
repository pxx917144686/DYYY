//
//  DYYYPlayerInteractionHooks.xm
//  DYYY
//
//  播放页交互与视频文案 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

%hook AWEDPlayerFeedPlayerViewController

- (void)viewDidLayoutSubviews {
	%orig;
	if (DYYYFullScreenCommentOriginalLayoutActive()) {
		return;
	}
	if (DYYYViewControllerChainLooksLikeChat(self)) {
		return;
	}
	// 检查是否启用了全屏模式
	if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
		UIView *contentView = self.contentView;
		if (contentView && contentView.superview) {
			CGRect frame = contentView.frame;
			CGFloat parentHeight = contentView.superview.frame.size.height;

			// 调整内容视图高度以实现全屏效果
			// 如果高度等于父视图高度减去标签栏高度，则扩展至完全全屏
			if (frame.size.height == parentHeight - tabHeight) {
				frame.size.height = parentHeight;
				contentView.frame = frame;
			} 
			// 处理特殊情况：当高度为父视图高度减去两倍标签栏高度时，调整为减去一倍标签栏高度
			else if (frame.size.height == parentHeight - (tabHeight * 2)) {
				frame.size.height = parentHeight - tabHeight;
				contentView.frame = frame;
			}
		}
	}
}

- (void)setIsAutoPlay:(BOOL)arg0 {
    %orig(arg0);
    DYYYApplyPreparedPlaybackSpeedToPlayer(self);
}

- (void)prepareForDisplay {
    %orig;
    if (!DYYYShouldHandleSpeedFeatures()) {
        return;
    }
    DYYYApplyPreparedPlaybackSpeedToPlayer(self);
    updateSpeedButtonUI();
}

%new
- (void)adjustPlaybackSpeed:(float)speed {
    [self setVideoControllerPlaybackRate:speed];
}

%end

// 全屏模式下 Merge 播放器内容视图高度调整（移植自 DYYY12345/DYYY.xm:11746-11793）
%hook AWEDPlayerViewController_Merge

- (void)viewDidLayoutSubviews {
    %orig;
    if (DYYYFullScreenCommentOriginalLayoutActive()) {
        return;
    }
    if (DYYYViewControllerChainLooksLikeChat(self)) {
        return;
    }
    if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
        UIView *contentView = self.contentView;
        if (contentView && contentView.superview) {
            CGRect frame = contentView.frame;
            CGFloat parentHeight = contentView.superview.frame.size.height;

            if (frame.size.height == parentHeight - tabHeight) {
                frame.size.height = parentHeight;
                contentView.frame = frame;
            } else if (frame.size.height == parentHeight - (tabHeight * 2)) {
                frame.size.height = parentHeight - tabHeight;
                contentView.frame = frame;
            }
        }
    }
}

%end

static void DYYYCollectSubviewsOfClasses(UIView *view, Class classA, Class classB,
                                          NSMutableArray<UIView *> *outA, NSMutableArray<UIView *> *outB) {
    if (classA && [view isKindOfClass:classA]) {
        [outA addObject:view];
    }
    if (classB && [view isKindOfClass:classB]) {
        [outB addObject:view];
    }
    for (UIView *subview in view.subviews) {
        DYYYCollectSubviewsOfClasses(subview, classA, classB, outA, outB);
    }
}

%hook AWEPlayInteractionViewController

// 当视频播放器视图被双击时调用此方法
- (void)onVideoPlayerViewDoubleClicked:(id)arg1 {
	// 获取用户设置中是否禁用双击操作的开关状态
	BOOL isSwitchOn = DYYYCachedBool(@"DYYYDouble");
	// 如果开关未启用（值为NO），则执行原始的双击处理逻辑
	// 如果开关已启用（值为YES），则不执行任何操作，从而禁用双击功能
	if (!isSwitchOn) {
		%orig;
	}
}

- (void)viewDidLayoutSubviews {
    %orig;

    AWEAwemeModel *model = self.model;
    dyyyCurrentLandscapeVideo = [model respondsToSelector:@selector(isShowLandscapeEntryView)]
        && model.isShowLandscapeEntryView;

    // 隐藏黑色背景视图，让毛玻璃效果显示视频内容
    if (DYYYCachedBool(@"DYYYisEnableFullScreen") || DYYYLegacyCommentBlurActive()) {
        for (UIView *subview in self.view.subviews) {
            if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor && CGColorEqualToColor(subview.backgroundColor.CGColor, [UIColor blackColor].CGColor)) {
                subview.hidden = YES;
            }
        }
    }

    if (DYYYLegacyCommentBlurActive()) {
        Class containerViewClass = NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputContainerView");
        Class middleContainerClass = NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer");

        // 合并遍历：一次递归同时收集两类命中视图
        NSMutableArray<UIView *> *containerViews = [NSMutableArray array];
        NSMutableArray<UIView *> *middleContainers = [NSMutableArray array];
        DYYYCollectSubviewsOfClasses(self.view, containerViewClass, middleContainerClass, containerViews, middleContainers);

        for (UIView *containerView in containerViews) {
            for (UIView *subview in containerView.subviews) {
                if (subview.hidden == NO && subview.backgroundColor && CGColorGetAlpha(subview.backgroundColor.CGColor) == 1) {
                    float userTransparency = [DYYYCachedString(@"DYYYCommentBlurTransparent") floatValue];
                    if (userTransparency <= 0 || userTransparency > 1) {
                        userTransparency = 0.8;
                    }
                    [DYYYUtils applyBlurEffectToView:subview transparency:userTransparency blurViewTag:999];
                }
            }
        }

        for (UIView *middleContainer in middleContainers) {
            BOOL containsDanmu = NO;
            for (UIView *innerSubviewCheck in middleContainer.subviews) {
                if ([innerSubviewCheck isKindOfClass:[UILabel class]] && [((UILabel *)innerSubviewCheck).text containsString:@"弹幕"]) {
                    containsDanmu = YES;
                    break;
                }
            }

            if (containsDanmu) {
                UIView *parentView = middleContainer.superview;
                for (UIView *innerSubview in parentView.subviews) {
                    if ([innerSubview isKindOfClass:[UIView class]]) {
                        if (innerSubview.subviews.count > 0) {
                            innerSubview.subviews[0].hidden = YES;
                        }

                        UIView *whiteBackgroundView = [[UIView alloc] initWithFrame:innerSubview.bounds];
                        whiteBackgroundView.backgroundColor = [UIColor whiteColor];
                        whiteBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                        [innerSubview addSubview:whiteBackgroundView];
                        break;
                    }
                }
            } else {
                for (UIView *subview in middleContainer.subviews) {
                    if (subview.hidden == NO && subview.backgroundColor && CGColorGetAlpha(subview.backgroundColor.CGColor) == 1) {
                        [DYYYUtils applyBlurEffectToView:subview transparency:0.2f blurViewTag:999];
                    }
                }
            }
        }
    }

    // 评论打开且为 16:9 时交给抖音原生布局，关闭后恢复全屏调整
    if (DYYYFullScreenCommentOriginalLayoutActive()) {
        return;
    }

    // 私信共享视频底部由抖音的快捷回复控制器占位；继续执行首页全屏高度改写
    // 会把播放器/交互层扩到整页，而快捷回复仍贴底，二者之间就会留下空行。
    if (DYYYViewControllerChainLooksLikeChat(self)) {
        return;
    }

    // 全屏模式：调整交互视图高度（移植自 DYYY12345/DYYY.xm:11517-11591）
    if (!DYYYCachedBool(@"DYYYisEnableFullScreen")) {
        return;
    }

    UIWindow *keyWindow = [DYYYManager getActiveWindow];
    if (keyWindow && keyWindow.safeAreaInsets.bottom == 0) {
        return;
    }

    // 远程投屏播放页不调整
    UIViewController *directParentVC = self.parentViewController;
    UIViewController *parentVC = directParentVC;
    int maxIterations = 3;
    int count = 0;
    while (parentVC && count < maxIterations) {
        if ([parentVC isKindOfClass:%c(AFDPlayRemoteFeedTableViewController)]) {
            return;
        }
        parentVC = parentVC.parentViewController;
        count++;
    }

    if (!self.view.superview) {
        return;
    }

    CGRect frame = self.view.frame;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat superviewHeight = self.view.superview.frame.size.height;

    if (frame.size.width != screenWidth && frame.size.height < superviewHeight) {
        return;
    }

    NSString *currentReferString = self.referString;
    BOOL useFullHeight = [currentReferString isEqualToString:@"general_search"] || [currentReferString isEqualToString:@"search_result"] || [currentReferString isEqualToString:@"search_ecommerce"] ||
                         [currentReferString isEqualToString:@"close_friends_moment"] || [currentReferString isEqualToString:@"offline_mode"] || [currentReferString isEqualToString:@"challenge"] ||
                         [currentReferString isEqualToString:@"general_search_scan"] || currentReferString == nil;

    if (useFullHeight) {
        frame.size.height = superviewHeight;
    } else {
        frame.size.height = superviewHeight - tabHeight;
    }

    if (fabs(frame.size.height - self.view.frame.size.height) > 0.5) {
        self.view.frame = frame;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    @try {
        // 确保所有UI更新操作安全执行
        if (DYYYCachedBool(@"DYYYisEnableArea")) {
            // 延迟更新UI，避免生命周期冲突
            dispatch_async(dispatch_get_main_queue(), ^{
                // UI更新代码
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY视图生命周期异常: %@", exception);
    }
}

// 倍速管理：生命周期补全（移植自 DYYY12345/DYYY.xm:11497-11504）
// isInPlayInteractionVC 已由 DYYYFloatClearButton.xm 的 viewWillAppear 处理，此处不再重复
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    dyyyCurrentFullScreenInteractionVC = self;
    AWEAwemeModel *model = self.model;
    dyyyCurrentLandscapeVideo = [model respondsToSelector:@selector(isShowLandscapeEntryView)]
        && model.isShowLandscapeEntryView;
    dyyyCurrentSpeedAweme = self.model;
    DYYYRestoreFloatSpeedButtonForAwemeIfNeeded(self.model);
    DYYYEnsureFloatSpeedButton(self);
    reloadClearButtonConfiguration();
    updateClearButtonVisibility();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (dyyyCurrentFullScreenInteractionVC == self) {
        dyyyCurrentFullScreenInteractionVC = nil;
    }
    dyyyCurrentLandscapeVideo = NO;
}

%end

%hook AWEPlayInteractionDescriptionLabel

static char kLongPressGestureKey;
static NSString *const kDYYYLongPressCopyEnabledKey = @"DYYYLongPressCopyTextEnabled";

- (void)didMoveToWindow {
    %orig;
    
    BOOL longPressCopyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDYYYLongPressCopyEnabledKey];
	
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kDYYYLongPressCopyEnabledKey]) {
        longPressCopyEnabled = NO;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kDYYYLongPressCopyEnabledKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    UIGestureRecognizer *existingGesture = objc_getAssociatedObject(self, &kLongPressGestureKey);
    if (existingGesture && !longPressCopyEnabled) {
        [self removeGestureRecognizer:existingGesture];
        objc_setAssociatedObject(self, &kLongPressGestureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    
    if (longPressCopyEnabled && !objc_getAssociatedObject(self, &kLongPressGestureKey)) {
        UILongPressGestureRecognizer *highPriorityLongPress = [[UILongPressGestureRecognizer alloc] 
            initWithTarget:self action:@selector(handleHighPriorityLongPress:)];
        highPriorityLongPress.minimumPressDuration = 0.3;
        
        [self addGestureRecognizer:highPriorityLongPress];
        
        UIView *currentView = self;
        while (currentView.superview) {
            currentView = currentView.superview;
            
            for (UIGestureRecognizer *recognizer in currentView.gestureRecognizers) {
                if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]] ||
                    [recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
                    [recognizer requireGestureRecognizerToFail:highPriorityLongPress];
                }
            }
        }
        
        objc_setAssociatedObject(self, &kLongPressGestureKey, highPriorityLongPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer.view isEqual:self] && [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return NO;
    }
    return YES;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer.view isEqual:self] && [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

%new
- (void)handleHighPriorityLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        NSString *description = self.text;
        
        if (description.length > 0) {
            [[UIPasteboard generalPasteboard] setString:description];
            [DYYYToast showSuccessToastWithMessage:@"视频文案已复制"];
        }
    }
}

- (void)layoutSubviews {
    %orig;
    self.transform = CGAffineTransformIdentity;

    NSString *descriptionOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDescriptionVerticalOffset"];
    CGFloat verticalOffset = 0;
    if (descriptionOffsetValue.length > 0) {
        verticalOffset = [descriptionOffsetValue floatValue];
    }

    UIView *parentView = self.superview;
    UIView *grandParentView = nil;

    if (parentView) {
        grandParentView = parentView.superview;
    }

    if (grandParentView && verticalOffset != 0) {
        CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(0, verticalOffset);
        grandParentView.transform = translationTransform;
    }
}

%end

%ctor {
    %init;
}
