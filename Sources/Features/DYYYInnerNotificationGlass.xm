//
//  DYYYInnerNotificationGlass.xm
//  应用内通知横幅：白卡片换成系统液态玻璃，回复键走官方玻璃按钮，角标改成正圆玻璃。
//  只藏私信副标题里的「私信了你:」；其它文字不接管。
//

#import "AwemeHeaders.h"
#import "DYYYGlass.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"

#import <objc/runtime.h>

static const CGFloat kDYYYNotiNativeCorner = 12.0;
static const NSInteger kDYYYNotiCornerDefault = 100;
static NSString *const kDYYYNotiHintPrefix = @"私信了你";

static char kSlotColorKey;
static char kSlotGlassKey;
static char kSlotMarkedKey;
static char kGlassMaterializingKey;
static char kCornerRadiusKey;
static char kCornerConfigKey;
static char kActionConfigKey;
static char kActionColorKey;
static char kActionTitleKey;
static char kActionAttrTitleKey;
static char kActionForegroundKey;
static char kActionClearKey;
static char kBadgeColorKey;
static char kBadgeGlassKey;
static char kHintHiddenKey;

static NSHashTable *gGlassCarriers;
static NSHashTable<AWEInnerNotificationContainerView *> *gContainers;
static NSHashTable<AWEInnerPushCommonView *> *gCommonViews;
static BOOL gEverAttached = NO;
static __weak UIWindowScene *gObservedScene = nil;
static UIUserInterfaceStyle gGlassStyle = UIUserInterfaceStyleUnspecified;

#pragma mark - 开关与材质

static BOOL DYYYNotiEnabled(void) {
    return DYYYGlassOSAvailable() && DYYYPrefBool(DYYYKeyInnerNotiGlass);
}

static BOOL DYYYNotiUsesClear(void) {
    return DYYYGlassOSAvailable() && DYYYPrefBool(DYYYKeyInnerNotiGlassClear);
}

// 未写过键时保持胶囊（100），与 beta7 观感一致。
static CGFloat DYYYNotiCornerProgress(void) {
    NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:DYYYKeyInnerNotiCorner];
    NSInteger percent = stored ? stored.integerValue : kDYYYNotiCornerDefault;
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    return percent / 100.0;
}

static BOOL DYYYNotiColorOpaque(UIColor *color) {
    return color && CGColorGetAlpha(color.CGColor) >= 0.99;
}

static void DYYYNotiApplyStyle(UIUserInterfaceStyle style, BOOL animated) API_AVAILABLE(ios(26.0)) {
    if (style == UIUserInterfaceStyleUnspecified) return;
    gGlassStyle = style;
    BOOL clear = DYYYNotiUsesClear();
    BOOL needs = NO;
    for (UIVisualEffectView *glass in gGlassCarriers.allObjects) {
        if (DYYYGlassNeedsUpdate(glass, clear, style)) {
            needs = YES;
            break;
        }
    }
    if (!needs) return;

    DYYYGlassRunAnimation(nil, animated, ^{
        for (UIVisualEffectView *glass in gGlassCarriers.allObjects) {
            glass.overrideUserInterfaceStyle = DYYYGlassOverrideStyle(clear, style);
            if (!glass.effect || !DYYYGlassNeedsUpdate(glass, clear, style)) continue;
            DYYYGlassInstallEffect(glass, DYYYGlassMakeEffect(clear, style, YES), clear, style);
        }
    });
}

static void DYYYNotiObserveStyle(UIView *host) API_AVAILABLE(ios(26.0)) {
    UIWindowScene *scene = host.window.windowScene;
    if (!scene || scene == gObservedScene) return;
    gObservedScene = scene;
    [scene registerForTraitChanges:@[ UITraitUserInterfaceStyle.class ]
                       withHandler:^(UIWindowScene *changed, __unused UITraitCollection *previous) {
        DYYYNotiApplyStyle(changed.traitCollection.userInterfaceStyle, YES);
    }];
}

static BOOL DYYYNotiRectUsable(CGRect rect) {
    return CGRectGetWidth(rect) >= 8.0 && CGRectGetHeight(rect) >= 8.0;
}

// 0 尺寸写入 UIGlassEffect 不会建材质层，之后只改 frame 补不回来。
static void DYYYNotiPlaceGlass(UIVisualEffectView *glass, UIView *slot) {
    if (!glass || !slot) return;
    BOOL wasEmpty = !DYYYNotiRectUsable(glass.bounds);
    if (!CGRectEqualToRect(glass.frame, slot.bounds)) glass.frame = slot.bounds;
    DYYYGlassEnsureBackmost(slot, glass);
    if (wasEmpty && DYYYNotiRectUsable(glass.bounds) && glass.effect) {
        glass.effect = nil;
        objc_setAssociatedObject(glass, &kGlassMaterializingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void DYYYNotiMaterialize(UIVisualEffectView *glass) API_AVAILABLE(ios(26.0)) {
    if (!glass || !DYYYNotiRectUsable(glass.bounds) || glass.effect
        || [objc_getAssociatedObject(glass, &kGlassMaterializingKey) boolValue]) {
        return;
    }
    objc_setAssociatedObject(glass, &kGlassMaterializingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DYYYGlassRunAnimation(nil, YES, ^{
        if (!glass.superview || !DYYYNotiEnabled()) {
            objc_setAssociatedObject(glass, &kGlassMaterializingKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        UIUserInterfaceStyle style = gGlassStyle;
        if (style == UIUserInterfaceStyleUnspecified) style = DYYYGlassStyleForView(glass);
        BOOL clear = DYYYNotiUsesClear();
        glass.overrideUserInterfaceStyle = DYYYGlassOverrideStyle(clear, style);
        DYYYGlassInstallEffect(glass, DYYYGlassMakeEffect(clear, style, YES), clear, style);
        objc_setAssociatedObject(glass, &kGlassMaterializingKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

#pragma mark - 圆角

static void DYYYNotiRememberCorners(UIView *view) {
    if (!view || objc_getAssociatedObject(view, &kCornerRadiusKey)) return;
    objc_setAssociatedObject(view, &kCornerRadiusKey,
                             @(view.layer.cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([view respondsToSelector:@selector(cornerConfiguration)]) {
        objc_setAssociatedObject(view, &kCornerConfigKey,
                                 view.cornerConfiguration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static UICornerConfiguration *DYYYNotiCardCornerConfig(UIView *view) API_AVAILABLE(ios(26.0)) {
    DYYYNotiRememberCorners(view);
    CGFloat native = kDYYYNotiNativeCorner;
    NSNumber *remembered = objc_getAssociatedObject(view, &kCornerRadiusKey);
    if (remembered && remembered.doubleValue > 0.0) native = remembered.doubleValue;
    CGFloat capsule = MIN(CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds)) * 0.5;
    if (capsule < native) capsule = native;
    CGFloat radius = native + (capsule - native) * DYYYNotiCornerProgress();
    view.layer.cornerRadius = radius;
    return [UICornerConfiguration configurationWithUniformRadius:[UICornerRadius fixedRadius:radius]];
}

static void DYYYNotiApplyCardShape(UIView *view, UIVisualEffectView *glass) API_AVAILABLE(ios(26.0)) {
    if (!view) return;
    UICornerConfiguration *config = DYYYNotiCardCornerConfig(view);
    if ([view respondsToSelector:@selector(setCornerConfiguration:)]) {
        view.cornerConfiguration = config;
    }
    if (glass && [glass respondsToSelector:@selector(setCornerConfiguration:)]) {
        glass.cornerConfiguration = config;
    }
}

static void DYYYNotiApplyCapsule(UIView *view) API_AVAILABLE(ios(26.0)) {
    if (!view) return;
    DYYYNotiRememberCorners(view);
    if ([view respondsToSelector:@selector(setCornerConfiguration:)]) {
        view.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
    }
    CGFloat height = CGRectGetHeight(view.bounds);
    if (height >= 1.0) view.layer.cornerRadius = height * 0.5;
}

static void DYYYNotiRestoreCorners(UIView *view) {
    NSNumber *radius = objc_getAssociatedObject(view, &kCornerRadiusKey);
    if (!view || !radius) return;
    if ([view respondsToSelector:@selector(setCornerConfiguration:)]) {
        view.cornerConfiguration = objc_getAssociatedObject(view, &kCornerConfigKey);
    }
    view.layer.cornerRadius = radius.doubleValue;
    objc_setAssociatedObject(view, &kCornerRadiusKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kCornerConfigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 查找

static AWEInnerNotificationContainerView *DYYYNotiContainerOf(UIView *view) {
    while (view) {
        if ([view isKindOfClass:%c(AWEInnerNotificationContainerView)]) {
            return (AWEInnerNotificationContainerView *)view;
        }
        view = view.superview;
    }
    return nil;
}

static UIView *DYYYNotiSlot(AWEInnerNotificationContainerView *container) {
    UIView *marked = objc_getAssociatedObject(container, &kSlotMarkedKey);
    if (marked.superview == container) return marked;

    if ([container respondsToSelector:@selector(containerView)]) {
        UIView *candidate = container.containerView;
        if (candidate.superview == container
            && (DYYYNotiColorOpaque(candidate.backgroundColor)
                || objc_getAssociatedObject(candidate, &kSlotColorKey))) {
            return candidate;
        }
    }
    for (UIView *child in container.subviews) {
        if (child.hidden) continue;
        if (DYYYNotiColorOpaque(child.backgroundColor)
            || objc_getAssociatedObject(child, &kSlotColorKey)) {
            return child;
        }
    }
    return nil;
}

static AWEInnerPushCommonView *DYYYNotiCommonIn(UIView *view, NSUInteger depth) {
    if (!view || depth > 6) return nil;
    if ([view isKindOfClass:%c(AWEInnerPushCommonView)]) return (AWEInnerPushCommonView *)view;
    for (UIView *child in view.subviews) {
        AWEInnerPushCommonView *found = DYYYNotiCommonIn(child, depth + 1);
        if (found) return found;
    }
    return nil;
}

#pragma mark - 卡片

static BOOL DYYYNotiClearSlot(UIView *slot) {
    UIColor *current = slot.backgroundColor;
    if (DYYYNotiColorOpaque(current)) {
        if (!objc_getAssociatedObject(slot, &kSlotColorKey)) {
            objc_setAssociatedObject(slot, &kSlotColorKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        slot.backgroundColor = UIColor.clearColor;
        gEverAttached = YES;
        return YES;
    }
    return objc_getAssociatedObject(slot, &kSlotColorKey) != nil;
}

static UIVisualEffectView *DYYYNotiAttachCard(AWEInnerNotificationContainerView *container,
                                            UIView *slot)
    API_AVAILABLE(ios(26.0)) {
    if (!DYYYNotiClearSlot(slot)) return nil;

    UIVisualEffectView *glass = objc_getAssociatedObject(slot, &kSlotGlassKey);
    if (!glass) {
        UIView *first = slot.subviews.firstObject;
        if ([first isKindOfClass:UIVisualEffectView.class]
            && first != objc_getAssociatedObject(slot, &kSlotGlassKey)) {
            return nil;
        }
        glass = DYYYGlassMakeShell();
        ((DYYYGlassFlexView *)glass).flexSourceView = container;
        objc_setAssociatedObject(slot, &kSlotGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(container, &kSlotMarkedKey, slot, OBJC_ASSOCIATION_ASSIGN);
        [gGlassCarriers addObject:glass];
        gEverAttached = YES;
    }

    DYYYNotiApplyCardShape(container, glass);
    DYYYNotiApplyCardShape(slot, glass);
    DYYYNotiPlaceGlass(glass, slot);
    return glass;
}

static void DYYYNotiDetachCard(AWEInnerNotificationContainerView *container) {
    UIView *slot = DYYYNotiSlot(container);
    if (!slot) return;
    UIView *glass = objc_getAssociatedObject(slot, &kSlotGlassKey);
    [gGlassCarriers removeObject:glass];
    [glass removeFromSuperview];
    UIColor *original = objc_getAssociatedObject(slot, &kSlotColorKey);
    if (original) slot.backgroundColor = original;
    DYYYNotiRestoreCorners(slot);
    DYYYNotiRestoreCorners(container);
    objc_setAssociatedObject(slot, &kSlotColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slot, &kSlotGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(container, &kSlotMarkedKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - 回复键

static BOOL DYYYNotiActionHasGlass(UIButton *button) {
    return button.configuration && objc_getAssociatedObject(button, &kActionClearKey);
}

static void DYYYNotiRememberAction(UIButton *button) {
    if (!button || DYYYNotiActionHasGlass(button)) return;
    if (button.configuration && !objc_getAssociatedObject(button, &kActionConfigKey)) {
        objc_setAssociatedObject(button, &kActionConfigKey,
                                 button.configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (button.backgroundColor) {
        objc_setAssociatedObject(button, &kActionColorKey,
                                 button.backgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSAttributedString *attributed = button.currentAttributedTitle;
    if (attributed.length) {
        objc_setAssociatedObject(button, &kActionAttrTitleKey,
                                 attributed, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    NSString *title = button.currentTitle.length ? button.currentTitle : attributed.string;
    if (title.length) {
        objc_setAssociatedObject(button, &kActionTitleKey,
                                 title, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    UIColor *foreground = nil;
    if (attributed.length) {
        foreground = [attributed attribute:NSForegroundColorAttributeName
                                   atIndex:0
                            effectiveRange:NULL];
    }
    if (!foreground) foreground = [button titleColorForState:UIControlStateNormal];
    if (foreground) {
        objc_setAssociatedObject(button, &kActionForegroundKey,
                                 foreground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static UIButtonConfiguration *DYYYNotiMakeActionConfig(BOOL clear) API_AVAILABLE(ios(26.0)) {
    UIButtonConfiguration *config = nil;
    if (clear && [UIButtonConfiguration respondsToSelector:@selector(clearGlassButtonConfiguration)]) {
        config = [UIButtonConfiguration clearGlassButtonConfiguration];
    } else if ([UIButtonConfiguration respondsToSelector:@selector(glassButtonConfiguration)]) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    }
    if (!config) return nil;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    return config;
}

static void DYYYNotiWriteActionTitle(UIButton *button, UIButtonConfiguration *config) {
    NSAttributedString *attributed = objc_getAssociatedObject(button, &kActionAttrTitleKey);
    NSString *title = objc_getAssociatedObject(button, &kActionTitleKey);
    UIColor *foreground = objc_getAssociatedObject(button, &kActionForegroundKey);
    if (attributed.length) {
        config.attributedTitle = attributed;
    } else if (title.length) {
        config.title = title;
    }
    if (foreground) config.baseForegroundColor = foreground;
}

static void DYYYNotiRestoreAction(UIButton *button) {
    if (!button || !objc_getAssociatedObject(button, &kActionForegroundKey)) return;
    UIButtonConfiguration *original = objc_getAssociatedObject(button, &kActionConfigKey);
    button.configuration = original;
    UIColor *color = objc_getAssociatedObject(button, &kActionColorKey);
    if (color) button.backgroundColor = color;
    if (!original) {
        NSAttributedString *attributed = objc_getAssociatedObject(button, &kActionAttrTitleKey);
        NSString *title = objc_getAssociatedObject(button, &kActionTitleKey);
        UIColor *foreground = objc_getAssociatedObject(button, &kActionForegroundKey);
        if (attributed) {
            [button setAttributedTitle:attributed forState:UIControlStateNormal];
        } else if (title) {
            [button setTitle:title forState:UIControlStateNormal];
        }
        if (foreground) [button setTitleColor:foreground forState:UIControlStateNormal];
    }
    objc_setAssociatedObject(button, &kActionConfigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kActionColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kActionTitleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kActionAttrTitleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kActionForegroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kActionClearKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DYYYNotiApplyAction(UIButton *button) API_AVAILABLE(ios(26.0)) {
    if (!button || button.hidden || button.alpha < 0.01) {
        if (button) DYYYNotiRestoreAction(button);
        return;
    }

    DYYYNotiRememberAction(button);
    if (objc_getAssociatedObject(button, &kActionColorKey)) {
        button.backgroundColor = UIColor.clearColor;
    }

    BOOL clear = DYYYNotiUsesClear();
    NSNumber *installed = objc_getAssociatedObject(button, &kActionClearKey);
    if (DYYYNotiActionHasGlass(button) && installed.boolValue == clear) return;

    UIButtonConfiguration *config = DYYYNotiMakeActionConfig(clear);
    if (!config) return;
    DYYYNotiWriteActionTitle(button, config);
    button.configuration = config;
    objc_setAssociatedObject(button, &kActionClearKey, @(clear), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    gEverAttached = YES;
}

#pragma mark - 角标

static void DYYYNotiRestoreBadge(UIView *badge) {
    if (!badge) return;
    UIView *glass = objc_getAssociatedObject(badge, &kBadgeGlassKey);
    [gGlassCarriers removeObject:glass];
    [glass removeFromSuperview];
    UIColor *original = objc_getAssociatedObject(badge, &kBadgeColorKey);
    if (original) badge.backgroundColor = original;
    DYYYNotiRestoreCorners(badge);
    objc_setAssociatedObject(badge, &kBadgeColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(badge, &kBadgeGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DYYYNotiApplyBadge(UIView *badge) API_AVAILABLE(ios(26.0)) {
    if (!badge || badge.hidden || badge.alpha < 0.01) {
        if (badge) DYYYNotiRestoreBadge(badge);
        return;
    }

    UIColor *current = badge.backgroundColor;
    if (DYYYNotiColorOpaque(current)) {
        if (!objc_getAssociatedObject(badge, &kBadgeColorKey)) {
            objc_setAssociatedObject(badge, &kBadgeColorKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        badge.backgroundColor = UIColor.clearColor;
    } else if (!objc_getAssociatedObject(badge, &kBadgeColorKey)) {
        return;
    }

    UIVisualEffectView *glass = objc_getAssociatedObject(badge, &kBadgeGlassKey);
    if (!glass) {
        glass = DYYYGlassMakeShell();
        glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
        ((DYYYGlassFlexView *)glass).flexSourceView = badge;
        objc_setAssociatedObject(badge, &kBadgeGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
        gEverAttached = YES;
    }
    DYYYNotiApplyCapsule(badge);
    DYYYNotiPlaceGlass(glass, badge);
    DYYYNotiMaterialize(glass);
}

#pragma mark - 「私信了你」

static BOOL DYYYNotiIsHintText(NSString *text) {
    if (text.length < kDYYYNotiHintPrefix.length) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed hasPrefix:kDYYYNotiHintPrefix]) return NO;
    NSString *rest = [trimmed substringFromIndex:kDYYYNotiHintPrefix.length];
    static NSCharacterSet *junk;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        junk = [NSCharacterSet characterSetWithCharactersInString:@":： "];
    });
    return [rest stringByTrimmingCharactersInSet:junk].length == 0;
}

static void DYYYNotiWalkLabels(UIView *view, NSUInteger depth, void (^block)(UILabel *label)) {
    if (!view || depth > 8 || !block) return;
    if ([view isKindOfClass:UILabel.class]) block((UILabel *)view);
    for (UIView *child in view.subviews) DYYYNotiWalkLabels(child, depth + 1, block);
}

static void DYYYNotiRestoreHint(AWEInnerPushCommonView *common) {
    UIView *root = ([common respondsToSelector:@selector(middleContentTextStackView)]
                    && common.middleContentTextStackView)
        ? common.middleContentTextStackView : common;
    DYYYNotiWalkLabels(root, 0, ^(UILabel *label) {
        NSNumber *hidden = objc_getAssociatedObject(label, &kHintHiddenKey);
        if (!hidden) return;
        label.hidden = hidden.boolValue;
        objc_setAssociatedObject(label, &kHintHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

static AWEInnerPushCommonView *DYYYNotiCommonOf(UIView *view) {
    while (view) {
        if ([view isKindOfClass:%c(AWEInnerPushCommonView)]) return (AWEInnerPushCommonView *)view;
        view = view.superview;
    }
    return nil;
}

static void DYYYNotiHideHintLabel(UILabel *label) {
    if (!label) return;
    if (!objc_getAssociatedObject(label, &kHintHiddenKey)) {
        objc_setAssociatedObject(label, &kHintHiddenKey,
                                 @(label.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!label.hidden) label.hidden = YES;
    gEverAttached = YES;
}

static void DYYYNotiApplyHint(AWEInnerPushCommonView *common) {
    UIView *root = ([common respondsToSelector:@selector(middleContentTextStackView)]
                    && common.middleContentTextStackView)
        ? common.middleContentTextStackView : common;
    DYYYNotiWalkLabels(root, 0, ^(UILabel *label) {
        NSString *text = label.text.length ? label.text : label.attributedText.string;
        BOOL hint = DYYYNotiIsHintText(text);
        NSNumber *marked = objc_getAssociatedObject(label, &kHintHiddenKey);
        if (hint) {
            DYYYNotiHideHintLabel(label);
        } else if (marked) {
            label.hidden = marked.boolValue;
            objc_setAssociatedObject(label, &kHintHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    });
}

#pragma mark - 同步

static void DYYYNotiRestoreCommon(AWEInnerPushCommonView *common) {
    if ([common respondsToSelector:@selector(rightActionButton)]) {
        DYYYNotiRestoreAction(common.rightActionButton);
    }
    if ([common respondsToSelector:@selector(leftExtraIconBackgroundView)]) {
        DYYYNotiRestoreBadge(common.leftExtraIconBackgroundView);
    }
    DYYYNotiRestoreHint(common);
    [gCommonViews removeObject:common];
}

static void DYYYNotiRestoreContainer(AWEInnerNotificationContainerView *container) {
    AWEInnerPushCommonView *common = DYYYNotiCommonIn(container, 0);
    if (common) DYYYNotiRestoreCommon(common);
    DYYYNotiDetachCard(container);
    [gContainers removeObject:container];
}

static void DYYYNotiRestoreAll(void) {
    for (AWEInnerPushCommonView *common in gCommonViews.allObjects) {
        DYYYNotiRestoreCommon(common);
    }
    for (AWEInnerNotificationContainerView *container in gContainers.allObjects) {
        DYYYNotiDetachCard(container);
    }
    [gContainers removeAllObjects];
}

static void DYYYNotiSyncCommon(AWEInnerPushCommonView *common) API_AVAILABLE(ios(26.0)) {
    if (!common) return;
    BOOL enabled = DYYYNotiEnabled();
    if (!enabled && !gEverAttached) return;
    if (!enabled) {
        DYYYNotiRestoreCommon(common);
        return;
    }

    [gCommonViews addObject:common];
    DYYYNotiApplyHint(common);
    if ([common respondsToSelector:@selector(rightActionButton)]) {
        DYYYNotiApplyAction(common.rightActionButton);
    }
    if ([common respondsToSelector:@selector(leftExtraIconBackgroundView)]) {
        DYYYNotiApplyBadge(common.leftExtraIconBackgroundView);
    }
}

static void DYYYNotiSyncContainer(AWEInnerNotificationContainerView *container)
    API_AVAILABLE(ios(26.0)) {
    if (!container) return;
    BOOL enabled = DYYYNotiEnabled();
    if (!enabled && !gEverAttached) return;
    if (!enabled) {
        DYYYNotiRestoreContainer(container);
        return;
    }

    UIView *slot = DYYYNotiSlot(container);
    if (!slot) return;

    [gContainers addObject:container];
    DYYYNotiObserveStyle(container);
    UIUserInterfaceStyle style = DYYYGlassStyleForView(container);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIVisualEffectView *card = DYYYNotiAttachCard(container, slot);
    DYYYNotiSyncCommon(DYYYNotiCommonIn(container, 0));
    [CATransaction commit];

    if (card) {
        DYYYNotiApplyStyle(style, YES);
        DYYYNotiMaterialize(card);
    }
}

static void DYYYNotiRefreshVisible(void) {
    BOOL enabled = DYYYNotiEnabled();
    if (!enabled) {
        DYYYNotiRestoreAll();
        return;
    }
    if (@available(iOS 26.0, *)) {
        for (AWEInnerNotificationContainerView *container in gContainers.allObjects) {
            DYYYNotiSyncContainer(container);
        }
        for (AWEInnerPushCommonView *common in gCommonViews.allObjects) {
            DYYYNotiSyncCommon(common);
        }
    }
}

#pragma mark - Hook

%group DYYYInnerNotificationGlassHooks

%hook AWEInnerNotificationContainerView

- (void)renderModel:(id)model context:(id)context {
    %orig;
    if (@available(iOS 26.0, *)) DYYYNotiSyncContainer(self);
}

- (void)layoutSubviews {
    %orig;
    if (@available(iOS 26.0, *)) DYYYNotiSyncContainer(self);
}

- (void)viewDidDisappear:(BOOL)animated reason:(long long)reason {
    %orig;
    if (self.window) return;
    DYYYNotiRestoreContainer(self);
}

%end

%hook AWEInnerPushCommonView

- (void)updateViewWithRequest:(id)request notificationContent:(id)content viewModel:(id)viewModel {
    %orig;
    if (@available(iOS 26.0, *)) {
        DYYYNotiSyncCommon(self);
        AWEInnerNotificationContainerView *container = DYYYNotiContainerOf(self);
        if (container) DYYYNotiSyncContainer(container);
    }
}

- (void)layoutSubviews {
    %orig;
    if (@available(iOS 26.0, *)) DYYYNotiSyncCommon(self);
}

%end

// 文案在布局之后才写入；只靠 layoutSubviews 会首帧漏藏，拖一下才消失。
%hook UILabel

- (void)setText:(NSString *)text {
    %orig;
    if (!DYYYNotiEnabled() || !DYYYNotiIsHintText(text) || !DYYYNotiCommonOf(self)) return;
    DYYYNotiHideHintLabel(self);
}

- (void)setAttributedText:(NSAttributedString *)text {
    %orig;
    if (!DYYYNotiEnabled() || !DYYYNotiIsHintText(text.string) || !DYYYNotiCommonOf(self)) return;
    DYYYNotiHideHintLabel(self);
}

- (void)setHidden:(BOOL)hidden {
    if (!hidden && DYYYNotiEnabled() && objc_getAssociatedObject(self, &kHintHiddenKey)) {
        NSString *text = self.text.length ? self.text : self.attributedText.string;
        if (DYYYNotiIsHintText(text)) {
            %orig(YES);
            return;
        }
    }
    %orig;
}

%end

%end

#pragma mark - 设置

%ctor {
    gGlassCarriers = [NSHashTable weakObjectsHashTable];
    gContainers = [NSHashTable weakObjectsHashTable];
    gCommonViews = [NSHashTable weakObjectsHashTable];

    if (DYYYGlassOSAvailable()) {
        %init(DYYYInnerNotificationGlassHooks);
    }
}
