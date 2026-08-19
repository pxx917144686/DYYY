#import "DYYYGlass.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>

static char kDYYYGlassClearKey;
static char kDYYYGlassStyleKey;

static const CGFloat kDYYYGlassAnimationDuration = 0.25;
static const CGFloat kDYYYGlassDarkTintAlpha = 0.30;

UIColor *DYYYGlassTintForStyle(UIUserInterfaceStyle style) {
    if (style != UIUserInterfaceStyleDark) return nil;
    return [UIColor colorWithWhite:0.0 alpha:kDYYYGlassDarkTintAlpha];
}

UIGlassEffect *DYYYGlassMakeEffect(BOOL clear,
                                   UIUserInterfaceStyle style,
                                   BOOL interactive)
    API_AVAILABLE(ios(26.0)) {
    UIGlassEffect *effect = [UIGlassEffect effectWithStyle:
        clear ? UIGlassEffectStyleClear : UIGlassEffectStyleRegular];
    if (clear) effect.tintColor = DYYYGlassTintForStyle(style);
    effect.interactive = interactive;
    return effect;
}

BOOL DYYYGlassNeedsUpdate(UIVisualEffectView *glass,
                          BOOL clear,
                          UIUserInterfaceStyle style)
    API_AVAILABLE(ios(26.0)) {
    if (!glass) return NO;
    if (glass.overrideUserInterfaceStyle != DYYYGlassOverrideStyle(clear, style)) {
        return YES;
    }

    UIGlassEffect *current = [glass.effect isKindOfClass:UIGlassEffect.class]
        ? (UIGlassEffect *)glass.effect : nil;
    if (!current) return glass.effect != nil;

    NSNumber *installedClear = objc_getAssociatedObject(glass, &kDYYYGlassClearKey);
    NSNumber *installedStyle = objc_getAssociatedObject(glass, &kDYYYGlassStyleKey);
    if (!installedClear || installedClear.boolValue != clear) return YES;
    if (!installedStyle || installedStyle.integerValue != style) return YES;
    if (!current.interactive) return YES;

    UIColor *wanted = DYYYGlassTintForStyle(clear ? style : UIUserInterfaceStyleUnspecified);
    UIColor *actual = current.tintColor;
    return !(actual == wanted || [actual isEqual:wanted]);
}

void DYYYGlassInstallEffect(UIVisualEffectView *glass,
                            UIGlassEffect *effect,
                            BOOL clear,
                            UIUserInterfaceStyle style)
    API_AVAILABLE(ios(26.0)) {
    if (!glass) return;
    glass.effect = effect;
    objc_setAssociatedObject(glass, &kDYYYGlassClearKey, @(clear),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(glass, &kDYYYGlassStyleKey, @(style),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void DYYYGlassRunAnimation(UIViewController *controller,
                           BOOL animated,
                           dispatch_block_t changes) {
    if (!changes) return;
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        [UIView performWithoutAnimation:changes];
        return;
    }

    id<UIViewControllerTransitionCoordinator> coordinator = controller.transitionCoordinator;
    if (coordinator && coordinator.isAnimated) {
        BOOL accepted = [coordinator
            animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
                changes();
            }
            completion:nil];
        if (accepted) return;
    }

    [UIView animateWithDuration:kDYYYGlassAnimationDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                              | UIViewAnimationOptionAllowUserInteraction
                              | UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:nil];
}

UIVisualEffectView *DYYYGlassMakeShell(void) {
    DYYYGlassFlexView *glass = [[DYYYGlassFlexView alloc] initWithEffect:nil];
    glass.userInteractionEnabled = NO;
    glass.alpha = 1.0;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return glass;
}

void DYYYGlassEnsureBackmost(UIView *slot, UIView *glass) {
    if (!slot || !glass) return;
    if (slot.subviews.firstObject == glass) return;
    [slot insertSubview:glass atIndex:0];
}

void DYYYGlassPlaceShell(UIVisualEffectView *glass, UIView *slot) {
    if (!glass || !slot) return;
    if (!CGRectEqualToRect(glass.frame, slot.bounds)) {
        glass.frame = slot.bounds;
    }
    DYYYGlassEnsureBackmost(slot, glass);
}

UIUserInterfaceStyle DYYYGlassStyleForView(UIView *view) {
    if (!view) return UIUserInterfaceStyleLight;

    UIUserInterfaceStyle style = view.window.windowScene.traitCollection.userInterfaceStyle;
    if (style == UIUserInterfaceStyleUnspecified) {
        style = view.traitCollection.userInterfaceStyle;
    }
    if (style == UIUserInterfaceStyleUnspecified) {
        style = UITraitCollection.currentTraitCollection.userInterfaceStyle;
    }
    return style == UIUserInterfaceStyleUnspecified ? UIUserInterfaceStyleLight : style;
}

UIUserInterfaceStyle DYYYGlassOverrideStyle(BOOL clear,
                                             UIUserInterfaceStyle style) {
    return clear ? UIUserInterfaceStyleUnspecified : style;
}
