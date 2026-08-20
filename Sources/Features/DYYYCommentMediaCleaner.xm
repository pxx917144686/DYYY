//
//  DYYYCommentMediaCleaner.xm
//  功能：清理评论图片大图页底栏、返回键与渐变，并让图片在完整窗口内按原比例居中显示。
//

#import "AwemeHeaders.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import <math.h>
#import <objc/runtime.h>

static NSString *const kDYYYMediaInputClass =
    @"AWECommentInputViewSwiftImpl.CommentInputContainerView";
static NSString *const kDYYYMediaCommonControllerClass =
    @"AWECommentMediaFeedSwfitImpl.CommentMediaFeedCommonImageCellViewController";
static NSString *const kDYYYMediaInteractionControllerClass =
    @"AWECommentMediaFeedSwfitImpl.CommentMediaFeedPlayInteractionViewController";
static NSString *const kDYYYMediaInteractionViewClass =
    @"AWECommentMediaFeedSwfitImpl.CommentMediaFeedPlayInteractionView";
static NSString *const kDYYYMediaUserNameViewClass =
    @"AWECommentMediaFeedSwfitImpl.CommentMediaFeedUserNameContainerView";
static NSString *const kDYYYMediaInteractionTagClass =
    @"AWECommentMediaFeedSwfitImpl.CommentMediaFeedPlayInteractionTag";
static NSString *const kDYYYMediaPreviewClass =
    @"AWECommentMediaFeedSwfitImpl.CommentMediaFeedImagePreviewView";
static NSString *const kDYYYMediaBackButtonIdentifier = @"CommentMediaFeedBackButton";

static char kDYYYMediaVisibilityManagedKey;
static char kDYYYMediaOriginalAlphaKey;
static char kDYYYMediaOriginalHiddenKey;
static char kDYYYMediaOriginalInteractionKey;
static char kDYYYMediaOriginalAccessibilityKey;
static char kDYYYMediaOriginalContentModeKey;
static char kDYYYMediaCollectionExpandedKey;
static char kDYYYMediaCollectionSizeKey;
static char kDYYYMediaNativeReanchorKey;

static NSHashTable<UIView *> *gDYYYMediaManagedViews;
static NSHashTable<AWECommentMediaFeedViewController *> *gDYYYMediaControllers;

static BOOL DYYYCommentMediaCleanerEnabled(void) {
    return DYYYPrefBool(DYYYKeyCommentMediaCleanBottomBar);
}

#pragma mark - 可逆视图状态

static void DYYYMediaRememberVisibility(UIView *view) {
    if (!view || [objc_getAssociatedObject(view, &kDYYYMediaVisibilityManagedKey) boolValue]) return;

    objc_setAssociatedObject(view, &kDYYYMediaOriginalAlphaKey,
                             @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kDYYYMediaOriginalHiddenKey,
                             @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kDYYYMediaOriginalInteractionKey,
                             @(view.userInteractionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kDYYYMediaOriginalAccessibilityKey,
                             @(view.accessibilityElementsHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kDYYYMediaVisibilityManagedKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [gDYYYMediaManagedViews addObject:view];
}

static void DYYYMediaSuppressView(UIView *view) {
    if (!view) return;
    DYYYMediaRememberVisibility(view);

    if (view.alpha != 0.0) view.alpha = 0.0;
    if (!view.hidden) view.hidden = YES;
    if (view.userInteractionEnabled) view.userInteractionEnabled = NO;
    if (!view.accessibilityElementsHidden) view.accessibilityElementsHidden = YES;
}

static void DYYYMediaApplyAspectFit(UIView *view) {
    if (!view) return;
    if (!objc_getAssociatedObject(view, &kDYYYMediaOriginalContentModeKey)) {
        objc_setAssociatedObject(view, &kDYYYMediaOriginalContentModeKey,
                                 @(view.contentMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gDYYYMediaManagedViews addObject:view];
    }
    if (view.contentMode != UIViewContentModeScaleAspectFit) {
        view.contentMode = UIViewContentModeScaleAspectFit;
    }
}

static void DYYYMediaRestoreView(UIView *view) {
    if (!view) return;

    if ([objc_getAssociatedObject(view, &kDYYYMediaVisibilityManagedKey) boolValue]) {
        NSNumber *alpha = objc_getAssociatedObject(view, &kDYYYMediaOriginalAlphaKey);
        NSNumber *hidden = objc_getAssociatedObject(view, &kDYYYMediaOriginalHiddenKey);
        NSNumber *interaction = objc_getAssociatedObject(view, &kDYYYMediaOriginalInteractionKey);
        NSNumber *accessibility = objc_getAssociatedObject(view, &kDYYYMediaOriginalAccessibilityKey);
        if (alpha) view.alpha = alpha.doubleValue;
        if (hidden) view.hidden = hidden.boolValue;
        if (interaction) view.userInteractionEnabled = interaction.boolValue;
        if (accessibility) view.accessibilityElementsHidden = accessibility.boolValue;

        objc_setAssociatedObject(view, &kDYYYMediaVisibilityManagedKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kDYYYMediaOriginalAlphaKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kDYYYMediaOriginalHiddenKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kDYYYMediaOriginalInteractionKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kDYYYMediaOriginalAccessibilityKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    NSNumber *contentMode = objc_getAssociatedObject(view, &kDYYYMediaOriginalContentModeKey);
    if (contentMode) {
        view.contentMode = (UIViewContentMode)contentMode.integerValue;
        objc_setAssociatedObject(view, &kDYYYMediaOriginalContentModeKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [gDYYYMediaManagedViews removeObject:view];
}

static void DYYYMediaRestoreViewsUnderRoot(UIView *root) {
    if (!root) return;
    for (UIView *view in gDYYYMediaManagedViews.allObjects) {
        if (view == root || [view isDescendantOfView:root]) DYYYMediaRestoreView(view);
    }
}

#pragma mark - 结构匹配

static Class DYYYMediaInputClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = NSClassFromString(kDYYYMediaInputClass); });
    return cls;
}

static BOOL DYYYMediaViewContainsClass(UIView *view, NSString *className, NSUInteger depth) {
    if (!view || depth > 12) return NO;
    if ([NSStringFromClass(view.class) isEqualToString:className]) return YES;
    for (UIView *subview in view.subviews) {
        if (DYYYMediaViewContainsClass(subview, className, depth + 1)) return YES;
    }
    return NO;
}

static UIView *DYYYMediaDescendantNamed(UIView *view, NSString *className, NSUInteger depth) {
    if (!view || depth > 12) return nil;
    if ([NSStringFromClass(view.class) isEqualToString:className]) return view;
    for (UIView *subview in view.subviews) {
        UIView *match = DYYYMediaDescendantNamed(subview, className, depth + 1);
        if (match) return match;
    }
    return nil;
}

static void DYYYMediaCollectControllersNamed(UIViewController *controller,
                                           NSString *className,
                                           NSMutableArray<UIViewController *> *output,
                                           NSUInteger depth) {
    if (!controller || depth > 12) return;
    for (UIViewController *child in controller.childViewControllers) {
        if ([NSStringFromClass(child.class) isEqualToString:className]) [output addObject:child];
        DYYYMediaCollectControllersNamed(child, className, output, depth + 1);
    }
}

static NSArray<UIViewController *> *DYYYMediaControllersNamed(UIViewController *controller,
                                                             NSString *className) {
    NSMutableArray<UIViewController *> *result = [NSMutableArray array];
    DYYYMediaCollectControllersNamed(controller, className, result, 0);
    return result;
}

static UICollectionView *DYYYMediaPageCollection(AWECommentMediaFeedViewController *controller) {
    if (!controller.isViewLoaded) return nil;
    UICollectionView *fallback = nil;
    for (UIView *subview in controller.view.subviews) {
        if (![subview isKindOfClass:UICollectionView.class]) continue;
        UICollectionView *collection = (UICollectionView *)subview;
        if (!fallback) fallback = collection;
        if (collection.delegate == (id<UICollectionViewDelegate>)controller
            || collection.dataSource == (id<UICollectionViewDataSource>)controller) {
            return collection;
        }
    }
    return fallback;
}

static UIView *DYYYMediaInputView(AWECommentMediaFeedViewController *controller) {
    Class inputClass = DYYYMediaInputClass();
    if (!inputClass || !controller.isViewLoaded) return nil;
    for (UIView *subview in controller.view.subviews) {
        if ([subview isKindOfClass:inputClass]) return subview;
    }
    return nil;
}

static BOOL DYYYMediaButtonHasAction(UIButton *button, SEL action) {
    if (!button || !action) return NO;
    for (id target in button.allTargets) {
        NSArray<NSString *> *actions =
            [button actionsForTarget:target forControlEvent:UIControlEventTouchUpInside];
        if ([actions containsObject:NSStringFromSelector(action)]) return YES;
    }
    return NO;
}

// 返回键是根视图直属 UIButton。优先取控制器的 backButton，其次认
// CommentMediaFeedBackButton，再认 previewDismissByClickBackBtn。不碰删除键。
static UIView *DYYYMediaBackButton(AWECommentMediaFeedViewController *controller) {
    if (!controller.isViewLoaded) return nil;

    if ([controller respondsToSelector:@selector(backButton)]) {
        UIView *button = controller.backButton;
        if (button) return button;
    }

    SEL action = @selector(previewDismissByClickBackBtn);
    for (UIView *subview in controller.view.subviews) {
        if (![subview isKindOfClass:UIButton.class]) continue;
        UIButton *button = (UIButton *)subview;
        if ([button.accessibilityIdentifier isEqualToString:kDYYYMediaBackButtonIdentifier]
            || DYYYMediaButtonHasAction(button, action)) {
            return button;
        }
    }
    return nil;
}

#pragma mark - 页面控件

static void DYYYMediaApplyInteractionControls(AWECommentMediaFeedViewController *controller) {
    for (UIViewController *interaction in
         DYYYMediaControllersNamed(controller, kDYYYMediaInteractionControllerClass)) {
        UIView *root = interaction.viewIfLoaded;
        for (UIView *container in root.subviews) {
            BOOL containsLike =
                DYYYMediaViewContainsClass(container, kDYYYMediaInteractionViewClass, 0);
            BOOL containsInfo =
                DYYYMediaViewContainsClass(container, kDYYYMediaUserNameViewClass, 0)
                || DYYYMediaViewContainsClass(container, kDYYYMediaInteractionTagClass, 0);
            if (containsLike || containsInfo) {
                DYYYMediaSuppressView(container);
            } else {
                DYYYMediaRestoreView(container);
            }
        }
    }
}

static BOOL DYYYMediaGradientMatchesEdge(UIView *view, BOOL top) {
    if (![NSStringFromClass(view.class) isEqualToString:@"AWEGradientView"]) return NO;
    UIView *parent = view.superview;
    if (!parent) return NO;

    CGRect frame = [view convertRect:view.bounds toView:parent];
    CGRect bounds = parent.bounds;
    CGFloat tolerance = MAX(1.0 / UIScreen.mainScreen.scale, 0.5);
    BOOL fullWidth = fabs(CGRectGetMinX(frame) - CGRectGetMinX(bounds)) <= tolerance
        && fabs(CGRectGetWidth(frame) - CGRectGetWidth(bounds)) <= tolerance;
    if (!fullWidth) return NO;

    if (top) {
        return fabs(CGRectGetMinY(frame) - CGRectGetMinY(bounds)) <= tolerance
            && CGRectGetMaxY(frame) < CGRectGetMaxY(bounds) - tolerance;
    }
    return fabs(CGRectGetMaxY(frame) - CGRectGetMaxY(bounds)) <= tolerance
        && CGRectGetMinY(frame) > CGRectGetMinY(bounds) + tolerance;
}

static void DYYYMediaApplyChromeGradients(UIView *view) {
    if (!view) return;
    for (UIView *subview in view.subviews) {
        if ([NSStringFromClass(subview.class) isEqualToString:@"AWEGradientView"]) {
            if (DYYYMediaGradientMatchesEdge(subview, YES) || DYYYMediaGradientMatchesEdge(subview, NO)) {
                DYYYMediaSuppressView(subview);
            } else {
                DYYYMediaRestoreView(subview);
            }
            continue;
        }
        DYYYMediaApplyChromeGradients(subview);
    }
}

static void DYYYMediaApplyCommonCellChrome(AWECommentMediaFeedViewController *controller) {
    for (UIViewController *common in
         DYYYMediaControllersNamed(controller, kDYYYMediaCommonControllerClass)) {
        DYYYMediaApplyChromeGradients(common.viewIfLoaded);
    }
}

// 输入栏上沿的分割线是根视图的直属子层，不是 CommentInputContainerView 的后代。
// 判据：普通 UIView、无子视图、全宽、高度不超过 1pt。不写死 y 或底栏高度。
static BOOL DYYYMediaIsHairlineSeparator(UIView *view, UIView *root) {
    if (!view || !root || view.class != UIView.class || view.subviews.count > 0) return NO;

    CGFloat height = CGRectGetHeight(view.frame);
    if (height <= 0.0 || height > 1.0) return NO;

    CGFloat tolerance = MAX(1.0 / UIScreen.mainScreen.scale, 0.5);
    return fabs(CGRectGetMinX(view.frame) - CGRectGetMinX(root.bounds)) <= tolerance
        && fabs(CGRectGetWidth(view.frame) - CGRectGetWidth(root.bounds)) <= tolerance;
}

static void DYYYMediaApplyHairlineSeparators(AWECommentMediaFeedViewController *controller) {
    UIView *root = controller.viewIfLoaded;
    if (!root) return;
    for (UIView *subview in root.subviews) {
        if (DYYYMediaIsHairlineSeparator(subview, root)) DYYYMediaSuppressView(subview);
    }
}

#pragma mark - 全窗口分页几何

static BOOL DYYYMediaSizesClose(CGSize lhs, CGSize rhs) {
    return fabs(lhs.width - rhs.width) <= 0.5 && fabs(lhs.height - rhs.height) <= 0.5;
}

static BOOL DYYYMediaRectsClose(CGRect lhs, CGRect rhs) {
    return fabs(CGRectGetMinX(lhs) - CGRectGetMinX(rhs)) <= 0.5
        && fabs(CGRectGetMinY(lhs) - CGRectGetMinY(rhs)) <= 0.5
        && DYYYMediaSizesClose(lhs.size, rhs.size);
}

static void DYYYMediaReanchorCurrentItem(AWECommentMediaFeedViewController *controller,
                                       UICollectionView *collection) {
    NSInteger index = (NSInteger)controller.currentIndex;
    if (index < 0 || collection.numberOfSections == 0
        || index >= [collection numberOfItemsInSection:0]) {
        return;
    }

    NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
    [collection scrollToItemAtIndexPath:path
                       atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                               animated:NO];
}

static void DYYYMediaResetCollectionState(AWECommentMediaFeedViewController *controller) {
    UICollectionView *collection = DYYYMediaPageCollection(controller);
    if (!collection || ![objc_getAssociatedObject(collection, &kDYYYMediaCollectionExpandedKey) boolValue]) {
        return;
    }

    objc_setAssociatedObject(collection, &kDYYYMediaCollectionExpandedKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(collection, &kDYYYMediaCollectionSizeKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &kDYYYMediaNativeReanchorKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [collection.collectionViewLayout invalidateLayout];
    [controller.view setNeedsLayout];
}

static void DYYYMediaApplyCollectionState(AWECommentMediaFeedViewController *controller, BOOL enabled) {
    UICollectionView *collection = DYYYMediaPageCollection(controller);
    if (!collection) return;

    if (!enabled) {
        DYYYMediaResetCollectionState(controller);
        if ([objc_getAssociatedObject(controller, &kDYYYMediaNativeReanchorKey) boolValue]) {
            [UIView performWithoutAnimation:^{
                [collection.collectionViewLayout invalidateLayout];
                [collection layoutIfNeeded];
                DYYYMediaReanchorCurrentItem(controller, collection);
            }];
            objc_setAssociatedObject(controller, &kDYYYMediaNativeReanchorKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    CGFloat width = CGRectGetWidth(controller.view.bounds);
    CGFloat height = CGRectGetHeight(controller.view.bounds);
    if (width <= 0.0 || height <= 0.0) return;

    CGSize targetSize = CGSizeMake(width, height);
    CGRect targetFrame = CGRectMake(0.0, 0.0, width, height);
    BOOL wasExpanded =
        [objc_getAssociatedObject(collection, &kDYYYMediaCollectionExpandedKey) boolValue];
    NSValue *lastSizeValue = objc_getAssociatedObject(collection, &kDYYYMediaCollectionSizeKey);
    BOOL sizeChanged = !wasExpanded || !lastSizeValue
        || !DYYYMediaSizesClose(lastSizeValue.CGSizeValue, targetSize);

    objc_setAssociatedObject(collection, &kDYYYMediaCollectionExpandedKey,
                             @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(collection, &kDYYYMediaCollectionSizeKey,
                             [NSValue valueWithCGSize:targetSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, &kDYYYMediaNativeReanchorKey,
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [UIView performWithoutAnimation:^{
        if (!DYYYMediaRectsClose(collection.frame, targetFrame)) collection.frame = targetFrame;
        if (sizeChanged) {
            [collection.collectionViewLayout invalidateLayout];
            [collection layoutIfNeeded];
            DYYYMediaReanchorCurrentItem(controller, collection);
        }
    }];
}

static void DYYYMediaApplyControllerState(AWECommentMediaFeedViewController *controller) {
    if (!controller || !controller.isViewLoaded) return;
    BOOL enabled = DYYYCommentMediaCleanerEnabled();

    if (!enabled) {
        DYYYMediaRestoreViewsUnderRoot(controller.view);
        DYYYMediaApplyCollectionState(controller, NO);
        return;
    }

    DYYYMediaApplyCollectionState(controller, YES);
    DYYYMediaSuppressView(DYYYMediaInputView(controller));
    DYYYMediaSuppressView(DYYYMediaBackButton(controller));
    DYYYMediaApplyHairlineSeparators(controller);
    DYYYMediaApplyInteractionControls(controller);
    DYYYMediaApplyCommonCellChrome(controller);
}

#pragma mark - 图片显示模式

static BOOL DYYYMediaIsPreviewCarrier(UIView *view) {
    if ([view isKindOfClass:UIImageView.class]) return YES;
    return [NSStringFromClass(view.class) isEqualToString:@"PHLivePhotoView"];
}

static void DYYYMediaApplyImageCellState(AWECommentMediaFeedImageCell *cell) {
    UIView *mediaRoot = nil;
    if ([cell respondsToSelector:@selector(mediaContainerView)]) mediaRoot = [cell mediaContainerView];
    UIView *preview = DYYYMediaDescendantNamed(mediaRoot ?: cell, kDYYYMediaPreviewClass, 0);
    if (!preview && mediaRoot != cell) {
        preview = DYYYMediaDescendantNamed(cell, kDYYYMediaPreviewClass, 0);
    }
    if (!preview) return;

    BOOL enabled = DYYYCommentMediaCleanerEnabled() && cell.window;
    for (UIView *carrier in preview.subviews) {
        if (!DYYYMediaIsPreviewCarrier(carrier)) continue;
        if (enabled) {
            DYYYMediaApplyAspectFit(carrier);
        } else {
            DYYYMediaRestoreView(carrier);
        }
    }
}

#pragma mark - 钩子

%hook AWECommentMediaFeedViewController

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize size = %orig;
    if (!DYYYCommentMediaCleanerEnabled() || collectionView != DYYYMediaPageCollection(self)) return size;

    CGSize target = self.view.bounds.size;
    return target.width > 0.0 && target.height > 0.0 ? target : size;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [gDYYYMediaControllers addObject:self];
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [gDYYYMediaControllers addObject:self];
    DYYYMediaApplyControllerState(self);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (self.viewIfLoaded.window) return;
    DYYYMediaRestoreViewsUnderRoot(self.viewIfLoaded);
    DYYYMediaResetCollectionState(self);
    [gDYYYMediaControllers removeObject:self];
}

%end

%hook AWECommentMediaFeedImageCell

- (void)layoutSubviews {
    %orig;
    DYYYMediaApplyImageCellState(self);
}

- (void)didMoveToWindow {
    %orig;
    DYYYMediaApplyImageCellState(self);
}

%end

#pragma mark - 设置

%ctor {
    gDYYYMediaManagedViews = [NSHashTable weakObjectsHashTable];
    gDYYYMediaControllers = [NSHashTable weakObjectsHashTable];
}
