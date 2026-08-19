//
//  DYYYChatVideoBottomBar.xm
//  功能：作品详情页底栏移除（好友页 / 搜索页 / 用户作品页统一），
//        以及全屏开启时底栏背景透明化，让视频与原生背景透出来。
//
//  好友页固定底栏走抖音自身的状态接口；搜索页 / 用户作品页的评论输入栏是另一套，
//  其显隐由 DYYYCommentBottomBar 统一接管（同一视图两处各记基线会互相污染），
//  本文件只负责背景，仅写 backgroundColor/opaque。
//

#import "AwemeHeaders.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>
#import <math.h>

static char kBarOrigBGKey;   // 底栏原始背景色缓存，便于关闭时还原
static char kBarOrigOpaqueKey;

// 结构签名容差：覆盖 @3x 像素对齐误差。
static const CGFloat kDYYYBarTolerance = 0.5;

static BOOL DYYYShouldHideDetailBottomBar(void) {
    return DYYYPrefBool(DYYYKeyDetailHideBottomBar);
}

static AWEAwemeIMDetailTableViewController *DYYYFindIMDetailController(UIViewController *vc) {
    static Class imDetailCls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        imDetailCls = NSClassFromString(@"AWEAwemeIMDetailTableViewController");
    });
    for (int i = 0; vc && i < 10; i++) {
        if (imDetailCls && [vc isKindOfClass:imDetailCls]) return (AWEAwemeIMDetailTableViewController *)vc;
        vc = vc.parentViewController;
    }
    return nil;
}

static void DYYYApplyBarBackground(UIView *view, BOOL clear) {
    if (!view) return;
    id orig = objc_getAssociatedObject(view, &kBarOrigBGKey);

    if (clear) {
        if (!orig) {
            objc_setAssociatedObject(view, &kBarOrigBGKey,
                                     view.backgroundColor ?: (id)[NSNull null],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kBarOrigOpaqueKey,
                                     @(view.opaque),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (![view.backgroundColor isEqual:[UIColor clearColor]]) {
            view.backgroundColor = [UIColor clearColor];
        }
        if (view.opaque) view.opaque = NO;
        return;
    }

    if (orig) {
        view.backgroundColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
        NSNumber *opaque = objc_getAssociatedObject(view, &kBarOrigOpaqueKey);
        if (opaque) view.opaque = opaque.boolValue;
        objc_setAssociatedObject(view, &kBarOrigBGKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kBarOrigOpaqueKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - 底栏移除

%hook AWEAwemeDetailTableViewController

- (BOOL)canShowFixedBottomBar {
    if (DYYYShouldHideDetailBottomBar()) return NO;
    return %orig;
}

- (void)setBottomBarHidden:(BOOL)hidden {
    if (DYYYShouldHideDetailBottomBar()) hidden = YES;
    %orig(hidden);
}

%end

%hook AWEAwemeIMDetailTableViewController

- (void)setBottomBarHidden:(BOOL)hidden {
    if (DYYYShouldHideDetailBottomBar()) hidden = YES;
    %orig(hidden);
}

%end

#pragma mark - 好友页快捷回复栏

%hook AWEIMFeedVideoQuickReplayInputViewController

- (void)viewDidLayoutSubviews {
    %orig;

    // 对话页共享视频：只有底栏移除开关才动快捷回复栏；全屏开关不再清背景，避免空白条
    BOOL clear = DYYYShouldHideDetailBottomBar();
    DYYYApplyBarBackground(self.view, clear);

    if (DYYYShouldHideDetailBottomBar()) {
        AWEAwemeIMDetailTableViewController *detail = DYYYFindIMDetailController(self);
        if (detail) [detail setBottomBarHidden:YES];
    }
}

%end

#pragma mark - 搜索页评论输入栏（仅背景，显隐归 DYYYCommentBottomBar 统一接管）

static BOOL DYYYColorIsOpaque(UIColor *color) {
    return color && CGColorGetAlpha(color.CGColor) >= 0.98;
}

static BOOL DYYYViewFillsSuperview(UIView *view) {
    UIView *parent = view.superview;
    if (!parent) return NO;

    CGRect frame = view.frame;
    CGRect bounds = parent.bounds;
    return fabs(CGRectGetMinX(frame) - CGRectGetMinX(bounds)) <= kDYYYBarTolerance
        && fabs(CGRectGetMinY(frame) - CGRectGetMinY(bounds)) <= kDYYYBarTolerance
        && fabs(CGRectGetWidth(frame) - CGRectGetWidth(bounds)) <= kDYYYBarTolerance
        && fabs(CGRectGetHeight(frame) - CGRectGetHeight(bounds)) <= kDYYYBarTolerance;
}

// 不透明底色画在容器内层的普通 UIView 上，背景视图自身是透明的。
// 已接管的视图背景已被清空、认不出签名，故优先按标记复用。
static UIView *DYYYBarFillView(UIView *root, NSUInteger depth) {
    for (UIView *subview in root.subviews) {
        if (objc_getAssociatedObject(subview, &kBarOrigBGKey)) return subview;
        if (!subview.hidden
            && object_getClass(subview) == [UIView class]
            && DYYYViewFillsSuperview(subview)
            && DYYYColorIsOpaque(subview.backgroundColor)) {
            return subview;
        }
        if (depth > 0) {
            UIView *match = DYYYBarFillView(subview, depth - 1);
            if (match) return match;
        }
    }
    return nil;
}

// 移除开关不参与判定：那种情况下整条底栏已被置为不可见，背景是什么已无意义。
// 全屏收敛成单一开关后不再按页限定：视频在哪一页都铺满，底栏底色就在哪一页都该让开。
// 聊天/私信上下文（对话页、好友页、私信页）除外：不清底栏背景，
// 避免视频进度条与输入栏之间出现空白条。
static void DYYYApplyDetailBarTransparency(AWECommentInputBackgroundView *bar) {
    UIViewController *vc = [DYYYUtils findViewControllerFromView:bar];
    if (DYYYViewControllerChainLooksLikeChat(vc)) return;
    BOOL clear = DYYYCachedBool(@"DYYYisEnableFullScreen");
    UIView *fill = DYYYBarFillView(bar, 1);
    if (fill) DYYYApplyBarBackground(fill, clear);
}

%hook AWECommentInputBackgroundView

// 该视图布局次数很少，只挂 layoutSubviews 会停在「详情页还没进导航栈、判不出页面」的那一次。
- (void)didMoveToWindow {
    %orig;
    DYYYApplyDetailBarTransparency(self);
}

- (void)layoutSubviews {
    %orig;
    DYYYApplyDetailBarTransparency(self);
}

%end
