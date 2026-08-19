//
//  DYYYSharePanelGlass.xm
//  分享面板液态玻璃：卡片底色、关闭键与第三行圆钮。第二行通讯录与文字不接管。
//

#import "AwemeHeaders.h"
#import "DYYYGlass.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/runtime.h>

static NSString *const kDYYYShareEffectClass = @"DUXVisualEffectView";
static const CGFloat kDYYYShareRadiusFloor = 20.0;
static const float kDYYYSharePlateLuma = 0.76f;
static const float kDYYYSharePlateSat = 0.14f;

static char kSlotColorKey;
static char kSlotGlassKey;
static char kGlassMaterializingKey;
static char kCloseOriginalConfigKey;
static char kCloseOriginalImageKey;
static char kCloseModeKey;
static char kCloseGlassKey;
static char kCellOriginalImageKey;
static char kCellOriginalColorKey;
static char kCellGlassKey;
static char kDestainedCacheKey;
static char kDestainedFlagKey;

static NSHashTable *gGlassCarriers;
static NSHashTable<AWESharePanelContainerViewController *> *gContainers;
static NSHashTable<AWESharePanelFunctionCell *> *gCells;
static BOOL gEverAttached = NO;
static __weak UIWindowScene *gObservedScene = nil;
static UIUserInterfaceStyle gGlassStyle = UIUserInterfaceStyleUnspecified;

typedef NS_ENUM(NSInteger, DYYYShareCloseMode) {
    DYYYShareCloseModeNone = 0,
    DYYYShareCloseModeOfficial,
    DYYYShareCloseModeOverlay,
};

#pragma mark - 开关与材质

static BOOL DYYYShareEnabled(void) {
    return DYYYGlassOSAvailable() && DYYYPrefBool(DYYYKeySharePanelGlass);
}

static BOOL DYYYShareUsesClear(void) {
    return DYYYGlassOSAvailable() && DYYYPrefBool(DYYYKeySharePanelGlassClear);
}

static BOOL DYYYShareColorOpaque(UIColor *color) {
    return color && CGColorGetAlpha(color.CGColor) >= 0.99;
}

static void DYYYShareApplyStyle(UIUserInterfaceStyle style, BOOL animated) API_AVAILABLE(ios(26.0)) {
    if (style == UIUserInterfaceStyleUnspecified) return;
    gGlassStyle = style;
    BOOL clear = DYYYShareUsesClear();
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

static void DYYYShareObserveStyle(UIView *host) API_AVAILABLE(ios(26.0)) {
    UIWindowScene *scene = host.window.windowScene;
    if (!scene || scene == gObservedScene) return;
    gObservedScene = scene;
    [scene registerForTraitChanges:@[ UITraitUserInterfaceStyle.class ]
                       withHandler:^(UIWindowScene *changed, __unused UITraitCollection *previous) {
        DYYYShareApplyStyle(changed.traitCollection.userInterfaceStyle, YES);
    }];
}

static BOOL DYYYShareRectUsable(CGRect rect) {
    return CGRectGetWidth(rect) >= 8.0 && CGRectGetHeight(rect) >= 8.0;
}

// 0 尺寸时写入 UIGlassEffect，系统不会建材质层；之后只改 frame 补不回来。
static void DYYYSharePlaceGlass(UIVisualEffectView *glass, CGRect frame, UIView *host, UIView *below) {
    if (!glass || !host) return;
    BOOL wasEmpty = !DYYYShareRectUsable(glass.bounds);
    if (!CGRectEqualToRect(glass.frame, frame)) glass.frame = frame;
    if (below.superview == host) {
        if (glass.superview != host) [host insertSubview:glass belowSubview:below];
    } else if (glass.superview != host) {
        [host insertSubview:glass atIndex:0];
    }
    if (wasEmpty && DYYYShareRectUsable(glass.bounds) && glass.effect) {
        glass.effect = nil;
        objc_setAssociatedObject(glass, &kGlassMaterializingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void DYYYShareMaterialize(UIVisualEffectView *glass, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    if (!glass || !DYYYShareRectUsable(glass.bounds) || glass.effect
        || [objc_getAssociatedObject(glass, &kGlassMaterializingKey) boolValue]) {
        return;
    }
    objc_setAssociatedObject(glass, &kGlassMaterializingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DYYYGlassRunAnimation(controller, YES, ^{
        if (!glass.superview || !DYYYShareEnabled()) {
            objc_setAssociatedObject(glass, &kGlassMaterializingKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        UIUserInterfaceStyle style = gGlassStyle;
        if (style == UIUserInterfaceStyleUnspecified) style = DYYYGlassStyleForView(glass);
        BOOL clear = DYYYShareUsesClear();
        glass.overrideUserInterfaceStyle = DYYYGlassOverrideStyle(clear, style);
        DYYYGlassInstallEffect(glass, DYYYGlassMakeEffect(clear, style, YES), clear, style);
        objc_setAssociatedObject(glass, &kGlassMaterializingKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

#pragma mark - 去白底

static UIImage *DYYYShareDestainPlate(UIImage *image) {
    if (!image || [objc_getAssociatedObject(image, &kDestainedFlagKey) boolValue]) return image;
    UIImage *cached = objc_getAssociatedObject(image, &kDestainedCacheKey);
    if (cached) return cached;

    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return image;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return image;

    size_t stride = width * 4;
    uint8_t *pixels = (uint8_t *)calloc(height * stride, 1);
    if (!pixels) return image;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        pixels, width, height, 8, stride, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) {
        free(pixels);
        return image;
    }
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), cgImage);

    NSUInteger kept = 0;
    size_t count = width * height;
    for (size_t i = 0; i < count; i++) {
        uint8_t *pixel = pixels + i * 4;
        float red = pixel[0] / 255.0f;
        float green = pixel[1] / 255.0f;
        float blue = pixel[2] / 255.0f;
        float alpha = pixel[3] / 255.0f;
        if (alpha < 0.02f) continue;
        float maximum = fmaxf(red, fmaxf(green, blue));
        float minimum = fminf(red, fminf(green, blue));
        float saturation = maximum > 0.001f ? (maximum - minimum) / maximum : 0.0f;
        if (maximum >= kDYYYSharePlateLuma && saturation <= kDYYYSharePlateSat) {
            pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0;
        } else {
            kept += 1;
        }
    }

    UIImage *result = image;
    if (kept > 0) {
        CGImageRef output = CGBitmapContextCreateImage(context);
        if (output) {
            result = [UIImage imageWithCGImage:output
                                         scale:image.scale
                                   orientation:image.imageOrientation];
            CGImageRelease(output);
            objc_setAssociatedObject(result, &kDestainedFlagKey, @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    CGContextRelease(context);
    free(pixels);
    objc_setAssociatedObject(image, &kDestainedCacheKey, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return result;
}

#pragma mark - 查找

static UIView *DYYYShareEffectView(AWESharePanelContainerViewController *controller) {
    Class cls = NSClassFromString(kDYYYShareEffectClass);
    if (!cls || !controller.isViewLoaded) return nil;
    for (UIView *subview in controller.view.subviews) {
        if ([subview isKindOfClass:cls]) return subview;
    }
    return nil;
}

static AWESharePanelViewController *DYYYShareContentController(UIViewController *controller) {
    if (!controller) return nil;
    if ([controller isKindOfClass:%c(AWESharePanelViewController)]) {
        return (AWESharePanelViewController *)controller;
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        return DYYYShareContentController(((UINavigationController *)controller).topViewController);
    }
    for (UIViewController *child in controller.childViewControllers) {
        AWESharePanelViewController *found = DYYYShareContentController(child);
        if (found) return found;
    }
    return nil;
}

static UIButton *DYYYShareCloseButton(AWESharePanelViewController *controller) {
    if (!controller.isViewLoaded) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:controller.view];
    while (stack.count > 0) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:UIButton.class]
            && [((UIButton *)view).accessibilityLabel isEqualToString:@"关闭"]) {
            return (UIButton *)view;
        }
        for (UIView *subview in view.subviews) [stack addObject:subview];
    }
    return nil;
}

static UIViewController *DYYYShareControllerForView(UIView *view) {
    for (UIResponder *responder = view.nextResponder; responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:UIViewController.class]) return (UIViewController *)responder;
    }
    return nil;
}

// 圆底板：约 56×56、圆角裁成圆。图标可能画在这张图里，也可能只在 smallImageView 上。
static BOOL DYYYShareIsCirclePlate(UIImageView *imageView) {
    if (!imageView) return NO;
    CGFloat width = CGRectGetWidth(imageView.bounds);
    CGFloat height = CGRectGetHeight(imageView.bounds);
    if (width >= 40.0 && fabs(width - height) <= 1.0) return YES;
    return width < 1.0 && imageView.layer.cornerRadius >= 8.0;
}

static UIImageView *DYYYShareFindCircleImage(UIView *view, NSUInteger depth) {
    if (!view || depth > 8) return nil;
    if ([view isKindOfClass:UIImageView.class]
        && DYYYShareIsCirclePlate((UIImageView *)view)) {
        return (UIImageView *)view;
    }
    UIImageView *fallback = nil;
    for (UIView *subview in view.subviews) {
        UIImageView *found = DYYYShareFindCircleImage(subview, depth + 1);
        if (!found) continue;
        if (CGRectGetWidth(found.bounds) >= 40.0) return found;
        if (!fallback) fallback = found;
    }
    return fallback;
}

static UIImageView *DYYYShareCircleImageView(AWESharePanelFunctionCell *cell) {
    if ([cell respondsToSelector:@selector(imageView)] && cell.imageView
        && (DYYYShareIsCirclePlate(cell.imageView)
            || cell.imageView.image
            || DYYYShareColorOpaque(cell.imageView.backgroundColor))) {
        return cell.imageView;
    }
    return DYYYShareFindCircleImage(cell, 0);
}

#pragma mark - 面板

static BOOL DYYYShareClearSlot(UIView *slot) {
    UIColor *current = slot.backgroundColor;
    if (DYYYShareColorOpaque(current)) {
        if (!objc_getAssociatedObject(slot, &kSlotColorKey)) {
            objc_setAssociatedObject(slot, &kSlotColorKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        slot.backgroundColor = UIColor.clearColor;
        gEverAttached = YES;
        return YES;
    }
    return objc_getAssociatedObject(slot, &kSlotColorKey) != nil;
}

static UIVisualEffectView *DYYYShareAttachPanel(UIView *slot, UIView *shell)
    API_AVAILABLE(ios(26.0)) {
    if (!DYYYShareClearSlot(slot)) return nil;
    UIVisualEffectView *glass = objc_getAssociatedObject(slot, &kSlotGlassKey);
    if (!glass) {
        if ([slot.subviews.firstObject isKindOfClass:UIVisualEffectView.class]) return nil;
        glass = DYYYGlassMakeShell();
        CGFloat radius = shell.layer.cornerRadius;
        if (radius <= 0.0) radius = kDYYYShareRadiusFloor;
        UICornerRadius *top = [UICornerRadius containerConcentricRadiusWithMinimum:radius];
        glass.cornerConfiguration =
            [UICornerConfiguration configurationWithUniformTopRadius:top
                                                    bottomLeftRadius:nil
                                                   bottomRightRadius:nil];
        ((DYYYGlassFlexView *)glass).flexSourceView = slot;
        objc_setAssociatedObject(slot, &kSlotGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
        gEverAttached = YES;
    }
    if (!CGRectEqualToRect(glass.frame, slot.bounds)) glass.frame = slot.bounds;
    DYYYGlassEnsureBackmost(slot, glass);
    return glass;
}

static void DYYYShareDetachPanel(UIView *slot) {
    UIColor *original = objc_getAssociatedObject(slot, &kSlotColorKey);
    if (!original) return;
    [(UIView *)objc_getAssociatedObject(slot, &kSlotGlassKey) removeFromSuperview];
    slot.backgroundColor = original;
    objc_setAssociatedObject(slot, &kSlotColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slot, &kSlotGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 关闭键

static void DYYYShareRememberClose(UIButton *button) {
    if (objc_getAssociatedObject(button, &kCloseOriginalImageKey)
        || objc_getAssociatedObject(button, &kCloseOriginalConfigKey)) {
        return;
    }
    if (button.configuration) {
        objc_setAssociatedObject(button, &kCloseOriginalConfigKey,
                                 button.configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIImage *image = button.currentImage ?: button.imageView.image;
    if (image) {
        objc_setAssociatedObject(button, &kCloseOriginalImageKey,
                                 image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void DYYYShareRemoveCloseOverlay(UIButton *button) {
    UIView *glass = objc_getAssociatedObject(button, &kCloseGlassKey);
    [glass removeFromSuperview];
    [gGlassCarriers removeObject:glass];
    objc_setAssociatedObject(button, &kCloseGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DYYYShareRestoreClose(UIButton *button) {
    if (!button) return;
    DYYYShareRemoveCloseOverlay(button);
    UIButtonConfiguration *config = objc_getAssociatedObject(button, &kCloseOriginalConfigKey);
    UIImage *image = objc_getAssociatedObject(button, &kCloseOriginalImageKey);
    if (config) {
        button.configuration = config;
    } else if (objc_getAssociatedObject(button, &kCloseModeKey)) {
        button.configuration = nil;
        if (image) [button setImage:image forState:UIControlStateNormal];
    }
    objc_setAssociatedObject(button, &kCloseOriginalConfigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kCloseOriginalImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kCloseModeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DYYYShareApplyCloseOverlay(UIButton *button, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    UIImage *original = objc_getAssociatedObject(button, &kCloseOriginalImageKey);
    if (original) {
        UIImage *icon = DYYYShareDestainPlate(original);
        if (button.configuration) button.configuration = nil;
        [button setImage:icon forState:UIControlStateNormal];
    }

    UIView *host = button.superview;
    if (!host) return;
    UIVisualEffectView *glass = objc_getAssociatedObject(button, &kCloseGlassKey);
    if (!glass) {
        glass = DYYYGlassMakeShell();
        glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
        ((DYYYGlassFlexView *)glass).flexSourceView = button;
        objc_setAssociatedObject(button, &kCloseGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
    }
    glass.autoresizingMask = UIViewAutoresizingNone;
    DYYYSharePlaceGlass(glass, button.frame, host, button);
    objc_setAssociatedObject(button, &kCloseModeKey,
                             @(DYYYShareCloseModeOverlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DYYYShareMaterialize(glass, controller);
}

static BOOL DYYYShareApplyCloseOfficial(UIButton *button) API_AVAILABLE(ios(26.0)) {
    if (![UIButtonConfiguration respondsToSelector:@selector(glassButtonConfiguration)]) return NO;
    DYYYShareRemoveCloseOverlay(button);

    UIImage *original = objc_getAssociatedObject(button, &kCloseOriginalImageKey);
    UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.contentInsets = NSDirectionalEdgeInsetsZero;
    if (original) config.image = DYYYShareDestainPlate(original);
    button.configuration = config;
    objc_setAssociatedObject(button, &kCloseModeKey,
                             @(DYYYShareCloseModeOfficial), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void DYYYShareApplyClose(UIButton *button, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    if (!button) return;
    DYYYShareRememberClose(button);
    if (DYYYShareUsesClear()) {
        DYYYShareApplyCloseOverlay(button, controller);
        return;
    }
    if (!DYYYShareApplyCloseOfficial(button)) DYYYShareApplyCloseOverlay(button, controller);
}

#pragma mark - 第三行圆钮

static void DYYYShareRestoreCell(AWESharePanelFunctionCell *cell) {
    UIImageView *imageView = DYYYShareCircleImageView(cell);
    UIImage *original = objc_getAssociatedObject(cell, &kCellOriginalImageKey);
    UIColor *color = objc_getAssociatedObject(cell, &kCellOriginalColorKey);
    if (imageView && original) imageView.image = original;
    if (imageView && color) imageView.backgroundColor = color;
    UIView *glass = objc_getAssociatedObject(cell, &kCellGlassKey);
    [glass removeFromSuperview];
    [gGlassCarriers removeObject:glass];
    objc_setAssociatedObject(cell, &kCellOriginalImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &kCellOriginalColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &kCellGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [gCells removeObject:cell];
}

static void DYYYShareApplyCell(AWESharePanelFunctionCell *cell, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    UIImageView *imageView = DYYYShareCircleImageView(cell);
    if (!imageView) return;

    // 底板两种画法：56×56 合成图，或白底 + smallImageView 图标。后一种没有 image。
    if (DYYYShareColorOpaque(imageView.backgroundColor)) {
        if (!objc_getAssociatedObject(cell, &kCellOriginalColorKey)) {
            objc_setAssociatedObject(cell, &kCellOriginalColorKey,
                                     imageView.backgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        imageView.backgroundColor = UIColor.clearColor;
    }

    UIImage *current = imageView.image;
    if (current && ![objc_getAssociatedObject(current, &kDestainedFlagKey) boolValue]) {
        objc_setAssociatedObject(cell, &kCellOriginalImageKey,
                                 current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIImage *icon = DYYYShareDestainPlate(current);
        if (icon != current) imageView.image = icon;
    }

    UIView *host = imageView.superview;
    if (!host) return;
    UIVisualEffectView *glass = objc_getAssociatedObject(cell, &kCellGlassKey);
    if (!glass) {
        glass = DYYYGlassMakeShell();
        glass.autoresizingMask = UIViewAutoresizingNone;
        glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
        ((DYYYGlassFlexView *)glass).flexSourceView = cell;
        objc_setAssociatedObject(cell, &kCellGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
        [gCells addObject:cell];
        gEverAttached = YES;
    }
    DYYYSharePlaceGlass(glass, imageView.frame, host, imageView);
    DYYYShareMaterialize(glass, controller);
}

static void DYYYShareCollectFunctionCells(UIView *view,
                                        NSMutableArray<AWESharePanelFunctionCell *> *output,
                                        NSUInteger depth) {
    if (!view || depth > 12) return;
    if ([view isKindOfClass:%c(AWESharePanelFunctionCell)]) {
        [output addObject:(AWESharePanelFunctionCell *)view];
        return;
    }
    for (UIView *subview in view.subviews) {
        DYYYShareCollectFunctionCells(subview, output, depth + 1);
    }
}

static void DYYYShareApplyVisibleCells(AWESharePanelViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    if (!controller.isViewLoaded) return;
    NSMutableArray<AWESharePanelFunctionCell *> *cells = [NSMutableArray array];
    DYYYShareCollectFunctionCells(controller.view, cells, 0);
    for (AWESharePanelFunctionCell *cell in cells) DYYYShareApplyCell(cell, controller);
}

#pragma mark - 同步

static void DYYYShareRestoreController(AWESharePanelContainerViewController *container) {
    AWESharePanelViewController *content = DYYYShareContentController(container);
    if (content.isViewLoaded) {
        DYYYShareRestoreClose(DYYYShareCloseButton(content));
        DYYYShareDetachPanel(content.view);
    }
    for (AWESharePanelFunctionCell *cell in gCells.allObjects) {
        if (!content.view || [cell isDescendantOfView:content.view]) DYYYShareRestoreCell(cell);
    }
    [gContainers removeObject:container];
}

static void DYYYShareRestoreAll(void) {
    for (AWESharePanelFunctionCell *cell in gCells.allObjects) DYYYShareRestoreCell(cell);
    for (AWESharePanelContainerViewController *container in gContainers.allObjects) {
        AWESharePanelViewController *content = DYYYShareContentController(container);
        if (content.isViewLoaded) {
            DYYYShareRestoreClose(DYYYShareCloseButton(content));
            DYYYShareDetachPanel(content.view);
        }
    }
    [gContainers removeAllObjects];
}

static void DYYYShareSync(AWESharePanelContainerViewController *container) API_AVAILABLE(ios(26.0)) {
    if (!container.isViewLoaded) return;
    BOOL enabled = DYYYShareEnabled();
    if (!enabled && !gEverAttached) return;

    AWESharePanelViewController *content = DYYYShareContentController(container);
    if (!content.isViewLoaded) return;

    if (!enabled) {
        DYYYShareRestoreController(container);
        return;
    }

    [gContainers addObject:container];
    DYYYShareObserveStyle(content.view);
    UIUserInterfaceStyle style = DYYYGlassStyleForView(content.view);
    UIView *shell = DYYYShareEffectView(container);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIVisualEffectView *panel = DYYYShareAttachPanel(content.view, shell ?: content.view);
    DYYYShareApplyClose(DYYYShareCloseButton(content), content);
    DYYYShareApplyVisibleCells(content);
    [CATransaction commit];

    if (panel) {
        DYYYShareApplyStyle(style, YES);
        DYYYShareMaterialize(panel, content);
    }
}

static void DYYYShareRefreshVisible(void) {
    BOOL enabled = DYYYShareEnabled();
    if (!enabled) DYYYShareRestoreAll();
    for (AWESharePanelContainerViewController *container in gContainers.allObjects) {
        [container.viewIfLoaded setNeedsLayout];
    }
    for (AWESharePanelFunctionCell *cell in gCells.allObjects) {
        if (!enabled) continue;
        if (@available(iOS 26.0, *)) DYYYShareApplyCell(cell, DYYYShareControllerForView(cell));
    }
}

#pragma mark - Hook

%group DYYYSharePanelGlassHooks

%hook AWESharePanelContainerViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (@available(iOS 26.0, *)) DYYYShareSync(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (@available(iOS 26.0, *)) DYYYShareSync(self);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (self.viewIfLoaded.window) return;
    DYYYShareRestoreController(self);
}

%end

%hook AWESharePanelViewController

- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *parent = self.parentViewController;
    while (parent && ![parent isKindOfClass:%c(AWESharePanelContainerViewController)]) {
        parent = parent.parentViewController;
    }
    if ([parent isKindOfClass:%c(AWESharePanelContainerViewController)]
        && @available(iOS 26.0, *)) {
        DYYYShareSync((AWESharePanelContainerViewController *)parent);
    }
}

- (void)awe_themeReload {
    %orig;
    UIViewController *parent = self.parentViewController;
    while (parent && ![parent isKindOfClass:%c(AWESharePanelContainerViewController)]) {
        parent = parent.parentViewController;
    }
    if ([parent isKindOfClass:%c(AWESharePanelContainerViewController)]
        && @available(iOS 26.0, *)) {
        DYYYShareSync((AWESharePanelContainerViewController *)parent);
    }
}

%end

%hook AWESharePanelFunctionCell

- (void)layoutSubviews {
    %orig;
    if (!DYYYShareEnabled()) {
        if (objc_getAssociatedObject(self, &kCellGlassKey)) DYYYShareRestoreCell(self);
        return;
    }
    if (@available(iOS 26.0, *)) DYYYShareApplyCell(self, DYYYShareControllerForView(self));
}

- (void)updateWithViewModel:(id)viewModel bigFontAdapter:(id)adapter {
    %orig;
    if (!DYYYShareEnabled()) return;
    if (@available(iOS 26.0, *)) DYYYShareApplyCell(self, DYYYShareControllerForView(self));
}

- (void)updateImageViewWithViewModel:(id)viewModel {
    %orig;
    if (!DYYYShareEnabled()) return;
    if (@available(iOS 26.0, *)) DYYYShareApplyCell(self, nil);
}

- (void)prepareForReuse {
    %orig;
    if (!DYYYShareEnabled()) DYYYShareRestoreCell(self);
}

%end

%end

#pragma mark - 设置

%ctor {
    gGlassCarriers = [NSHashTable weakObjectsHashTable];
    gContainers = [NSHashTable weakObjectsHashTable];
    gCells = [NSHashTable weakObjectsHashTable];

    if (DYYYGlassOSAvailable()) {
        %init(DYYYSharePanelGlassHooks);
    }
}
