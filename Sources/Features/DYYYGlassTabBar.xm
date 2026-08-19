//
//  DYYYGlassTabBar.xm
//  自建 UITabBar（4 个 tab 的玻璃胶囊）+ 右侧独立玻璃圆键（拍摄），顶替抖音自绘底栏。
//  内容全部镜像自抖音自己的按钮：标题、顺序、拍摄图标、未读角标，抖音改什么这里跟着变。
//
//  两条不可回退的结论：
//
//  · 不能复活抖音自带的 AWEFakeTabBar。它与自建 UITabBar 的 appearance、platter 子树、
//    layer 属性完全一致，却只有自建的渲染出玻璃——它自创建起即隐藏，UIKit 从未为它建过
//    玻璃背景层，事后改可见性不会补建。
//
//  · 两块玻璃都做成抖音底栏的【子视图】。显隐、透明度、位置、生命周期由 UIKit 沿视图树
//    继承，无需任何同步代码，也就不会出现「抖音不布局就不更新」。驱动点放在抖音底栏自己的
//    layoutSubviews，冷启动首帧即可挂上。唯一继承不到的是深浅色，见 DYYYGlassApplyStyle。
//

#import "DYYYGlassTabBar.h"
#import "DYYYAudioVisualizer.h"
#import "AwemeHeaders.h"
#import "DYYYGlass.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>

// 依赖的抖音/UIKit 私有符号集中在此，抖音改名时只改这里。
static NSString *const kDYYYBadgeContainerClass = @"AWENormalModeTabBarBadgeContainerView";
static NSString *const kDYYYBadgeClass = @"DUXBadge";
static NSString *const kDYYYPlatterClass = @"_UITabBarItemPlatterView";
static NSString *const kDYYYPlusClickSelector = @"plusTabBarButtonDidClick:";
static NSString *const kDYYYTabClickSelector = @"tabBarButtonDidTouchUpInside:gestureRecognizer:";

// 抖音按钮的 type：拍摄入口。它不是页面，不参与 selectedIndex，单独做成右侧圆键。
static const long long kDYYYPlusButtonType = 2;
// 标题字号。抖音原生底栏是 10pt——那是留给「图标在上、10pt 标签在下」的层叠布局的，
// 标题独占整个按钮后 10pt 会显得空落，故按纯文字胶囊的比例取值。
static const CGFloat kDYYYTitleFontSize = 15.0;
// 胶囊与拍摄键之间的间距。
static const CGFloat kDYYYPlusKeyGap = 12.0;
// 拍摄图标在圆键内的四周留白。
static const CGFloat kDYYYPlusIconInset = 14.0;
// platter 还没建起来时的兜底几何（beta7 实测值），次帧即被真实值取代。
static const CGFloat kDYYYPlatterFallbackHeight = 62.0;
static const CGFloat kDYYYPlatterFallbackInset = 21.0;

#pragma mark - 状态

static UITabBar *gBar = nil;
static id gProxy = nil;
// 每个 item 对应的 tab 序号（validIndex）。与 items 同序等长。
static NSArray<NSNumber *> *gItemKinds = nil;
// 每个 item 对应的抖音按钮，转发点击与读取角标都用它。与 items 同序等长。
static NSArray *gItemButtons = nil;
// 上次构建 items 用的签名，变了才重建，避免每次布局都换 items。
static NSString *gSignature = nil;
// 最近一次见到的抖音底栏，供开关变化时立即生效。
static __weak AWENormalModeTabBar *gDouyinBar = nil;
// 已挂上深浅色监听的场景，避免重复注册。
static __weak UIWindowScene *gObservedScene = nil;

// 拍摄圆键及其内容。
static UIVisualEffectView *gPlusKey = nil;
static UIImageView *gPlusIcon = nil;
static UIButton *gPlusHit = nil;
// 抖音的拍摄按钮；被其他插件移除时为 nil，圆键随之隐藏。
static __weak UIView *gPlusButton = nil;
// 上次裁过的图标源图，按指针比对，变了才重裁。
static UIImage *gPlusSourceIcon = nil;

UITabBar *DYYYGlassTabBarCurrent(void) {
    return gBar;
}

UIVisualEffectView *DYYYGlassPlusKeyCurrent(void) {
    return gPlusKey;
}

// 每次布局由 DYYYGlassLayoutGlass 刷新。弱引用：UIKit 换掉 platter 时这里自动变 nil。
static __weak UIView *gPlatter = nil;

UIView *DYYYGlassPlatterCurrent(void) {
    return gPlatter;
}

#pragma mark - 小工具

static id DYYYGlassValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *DYYYGlassButtonTitle(id button) {
    id inner = DYYYGlassValue(button, @"innerView");
    NSString *text = DYYYGlassValue(DYYYGlassValue(inner, @"label"), @"text");
    if (text.length > 0) return text;

    NSString *current = DYYYGlassValue(inner, @"currentTitleText");
    if (current.length > 0) return current;

    NSString *label = [button isKindOfClass:UIView.class] ? [(UIView *)button accessibilityLabel] : nil;
    return label.length > 0 ? label : nil;
}

static UITabBarController *DYYYGlassControllerForView(UIView *view) {
    for (UIResponder *responder = view.nextResponder; responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:UITabBarController.class]) return (UITabBarController *)responder;
    }
    return nil;
}

#pragma mark - 开关

static BOOL DYYYGlassTabBarEnabled(void) {
    return DYYYGlassOSAvailable() && DYYYPrefBool(DYYYKeyGlassTabBar);
}

static BOOL DYYYGlassTabBarUsesClear(void) {
    return DYYYGlassOSAvailable() && DYYYPrefBool(DYYYKeyGlassTabBarClear);
}

#pragma mark - 材质

// 胶囊与拍摄圆键共用。档位跟「清透玻璃」开关走：关＝系统默认磨砂，开＝Clear。
//
// 深色档两种材质认的不是同一条：Clear 对 overrideUserInterfaceStyle 不敏感、只认染色
// （实测中位亮度 136.6 → 99.8；改用 override 是 157.9，等于没压暗），Regular 归 override 管，
// 再叠一层染色会压暗两次。所以染色只给 Clear。
static UIGlassEffect *DYYYGlassMakeGlassEffect(UIUserInterfaceStyle style, BOOL interactive)
    API_AVAILABLE(ios(26.0)) {
    return DYYYGlassMakeEffect(DYYYGlassTabBarUsesClear(), style, interactive);
}

// 悬浮胶囊的材质由 _UITabBarItemPlatterView 自己持有的 glassEffect 决定——
// UITabBarAppearance.backgroundEffect 是悬浮布局之前的旧 API，floating provider 根本不读它
// （实测出厂态 / Regular / Clear 三者渲染逐像素相同，均为 9.x% 细节保留）。改写这个属性才
// 拿得到清透，且原生透镜、长按拖动、角标完全不受影响：细节保留 5.9% → 26.8%，
// 与自建 Clear（31.4%）、Apple 的 clearGlassButtonConfiguration（29.8%）同档。
//
// 两条纪律：
// · glassEffect 是 UIKit 内部属性，iOS 大版本可能改名。首次读不到就永久放弃，此后整段不进入
//   （逐帧路径上反复 @try/@catch 既慢又吵），底栏保持系统默认磨砂，功能不受影响。
// · 只还原自己改过的：首次接管前把原厂那只存在 platter 上，关开关时原样放回。
static NSString *const kDYYYPlatterGlassKey = @"glassEffect";
static char kDYYYPlatterOriginalGlassKey;
static BOOL gPlatterGlassProbed = NO;
static BOOL gPlatterGlassSupported = NO;
// glassEffect 是 copy 属性（实测回读指针 != 写入指针），所以记的是 platter 存下的那只【副本】。
// 弱引用：platter 换掉它、或 platter 本身销毁，这里都会变，正好当作「需要重装」的信号。
static __weak id gPlatterGlassInstalled = nil;
static UIUserInterfaceStyle gPlatterGlassStyle = UIUserInterfaceStyleUnspecified;

static void DYYYGlassApplyPlatterGlass(UIView *platter, UIUserInterfaceStyle style)
    API_AVAILABLE(ios(26.0)) {
    if (!platter || (gPlatterGlassProbed && !gPlatterGlassSupported)) return;

    id current = nil;
    @try {
        current = [platter valueForKey:kDYYYPlatterGlassKey];
    } @catch (__unused NSException *exception) {
        gPlatterGlassProbed = YES;      // 属性不在，永久放弃
        gPlatterGlassSupported = NO;
        return;
    }
    gPlatterGlassProbed = YES;
    gPlatterGlassSupported = YES;

    BOOL patched = current && current == gPlatterGlassInstalled;

    if (!DYYYGlassTabBarUsesClear()) {
        if (!patched) return;                       // 没接管过，无需还原
        id original = objc_getAssociatedObject(platter, &kDYYYPlatterOriginalGlassKey);
        @try {
            [platter setValue:(original == NSNull.null ? nil : original)
                       forKey:kDYYYPlatterGlassKey];
        } @catch (__unused NSException *exception) {}
        gPlatterGlassInstalled = nil;
        gPlatterGlassStyle = UIUserInterfaceStyleUnspecified;
        [platter setNeedsLayout];
        return;
    }

    // 装的还是我们那只、档位也没变，就什么都不做。逐帧无脑重写会打断系统的呈现过渡。
    if (patched && style == gPlatterGlassStyle) return;

    if (!objc_getAssociatedObject(platter, &kDYYYPlatterOriginalGlassKey)) {
        objc_setAssociatedObject(platter, &kDYYYPlatterOriginalGlassKey, current ?: NSNull.null,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // interactive 照抄现有那只。UIKit 给 platter 的原厂配置就是 interactive=YES，整块胶囊的
    // 按压/触摸/高亮动效全从它来；写死 NO 会把这些动效一并抹掉（beta23 踩过）。
    BOOL interactive = [current isKindOfClass:UIGlassEffect.class]
        ? ((UIGlassEffect *)current).interactive : YES;
    @try {
        [platter setValue:DYYYGlassMakeGlassEffect(style, interactive) forKey:kDYYYPlatterGlassKey];
        gPlatterGlassInstalled = [platter valueForKey:kDYYYPlatterGlassKey];
    } @catch (__unused NSException *exception) {
        gPlatterGlassSupported = NO;
        return;
    }
    gPlatterGlassStyle = style;
    [platter setNeedsLayout];
}

NSString *DYYYGlassPlatterGlassStatus(void) {
    if (!gPlatterGlassProbed) return @"未尝试（功能关闭或 platter 尚未建立）";
    if (!gPlatterGlassSupported) return @"属性不存在，已放弃——保持系统默认磨砂";
    if (!DYYYGlassTabBarUsesClear()) return @"清透开关关闭 · 系统默认磨砂";
    id installed = gPlatterGlassInstalled;
    if (!installed) return @"清透开关开启但尚未装上，下一次布局补";
    UIColor *tint = DYYYGlassTintForStyle(gPlatterGlassStyle);
    BOOL interactive = [installed isKindOfClass:UIGlassEffect.class]
        && ((UIGlassEffect *)installed).interactive;
    return [NSString stringWithFormat:@"已改写 · Clear · interactive=%@ · 染色 %@",
            interactive ? @"YES" : @"NO", tint ? tint.description : @"(nil，浅色档)"];
}

#pragma mark - 深浅色

// 深浅色是唯一不能靠继承拿到的东西：抖音把 window.overrideUserInterfaceStyle 钉死为浅色
// （beta3 探针逐级实证），它的深色模式是自己换肤画出来的，压根不进 UIKit 的 trait，
// 所以沿视图树继承到的永远是浅色。
//
// UIWindowScene 的 trait 由系统直接下发，而 overrideUserInterfaceStyle 只存在于
// UIView / UIViewController / UIWindow 上——抖音没有 API 能盖住场景那一层，取它即得真值。
//
// 评论面板的玻璃同源，见 DYYYCommentGlass.xm 的 DYYYApplyGlassStyle。
//
// override 与染色分工明确：override 只管内容着色（标题模板图、拍摄图标靠 trait 取色），
// 玻璃材质归染色管——Clear 对 override 不敏感，实测给 platter 加 override 深色后中位亮度
// 157.9，等于没压暗；换成染色黑 30% 才是 99.8。
static UIUserInterfaceStyle gGlassStyle = UIUserInterfaceStyleUnspecified;

static void DYYYGlassApplyStyle(UIUserInterfaceStyle style) API_AVAILABLE(ios(26.0)) {
    if (style == UIUserInterfaceStyleUnspecified || style == gGlassStyle) return;
    gGlassStyle = style;

    if (gBar) gBar.overrideUserInterfaceStyle = style;
    if (gPlusKey) {
        gPlusKey.overrideUserInterfaceStyle = style;
        gPlusKey.effect = DYYYGlassMakeGlassEffect(style, YES);
    }
    // platter 的玻璃在下一次布局里跟着重写；trait 变化未必伴随布局，主动踢一次。
    [gDouyinBar setNeedsLayout];
}

// 挂在场景上监听，系统一切深浅色即刻改；否则只能等抖音下次布局，就是 beta3 那种「切一下页才变」。
static void DYYYGlassObserveStyle(UIView *host) API_AVAILABLE(ios(26.0)) {
    UIWindowScene *scene = host.window.windowScene;
    if (!scene || scene == gObservedScene) return;
    gObservedScene = scene;
    [scene registerForTraitChanges:@[ UITraitUserInterfaceStyle.class ]
                       withHandler:^(UIWindowScene *changed, __unused UITraitCollection *previous) {
        if (gBar) DYYYGlassApplyStyle(changed.traitCollection.userInterfaceStyle);
    }];
}

#pragma mark - 标题图

// iOS 26 悬浮底栏按「图标在上、标签在下」排版，只给标题时图标槽空着、标题落到按钮底部；
// titlePositionAdjustment 属于旧版层叠布局，悬浮 provider 完全忽略（实测给到 -168 仍纹丝
// 不动）。故把标题渲染成模板图当图标用、标题置空，由系统把它当图标居中。
// 模板图只取 alpha，着色仍归系统，选中态与深浅色都自动跟上。
// 字重取 Semibold：玻璃胶囊上压着的内容要够重，太细在半透明底上会发糊。
static UIImage *DYYYGlassTitleImage(NSString *title) {
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:kDYYYTitleFontSize weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: UIColor.blackColor
    };
    CGSize size = [title sizeWithAttributes:attributes];
    size.width = ceil(size.width);
    size.height = ceil(size.height);

    UIGraphicsImageRendererFormat *format = UIGraphicsImageRendererFormat.preferredFormat;
    format.opaque = NO;
    UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format]
        imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            [title drawAtPoint:CGPointZero withAttributes:attributes];
        }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - 拍摄图标

// 取抖音当前真实显示的拍摄图标。别的插件替换图标改的正是这个 image view，故天然跟随
//（UIButton 自己的 state image 也经 imageView 渲染，同样命中）。
static UIImage *DYYYGlassPlusSourceIcon(UIView *button) {
    for (UIView *subview in button.subviews) {
        if (![subview isKindOfClass:UIImageView.class]) continue;
        UIImage *image = ((UIImageView *)subview).image;
        if (image) return image;
    }
    return nil;
}

// 按 alpha 裁掉四周透明留白。抖音给的图是 75×49 而字形只有约 33×30，直接缩进圆键会小到看不清；
// 裁完再排版，换了图标也自适应，不必写死内缩。
static UIImage *DYYYGlassTrimTransparent(UIImage *image) {
    CGImageRef source = image.CGImage;
    if (!source) return image;

    size_t width = CGImageGetWidth(source);
    size_t height = CGImageGetHeight(source);
    if (width == 0 || height == 0) return image;

    uint8_t *alpha = (uint8_t *)calloc(width * height, sizeof(uint8_t));
    if (!alpha) return image;

    CGContextRef context = CGBitmapContextCreate(alpha, width, height, 8, width, NULL,
                                                 (CGBitmapInfo)kCGImageAlphaOnly);
    if (!context) {
        free(alpha);
        return image;
    }
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), source);
    CGContextRelease(context);

    size_t minX = width, minY = height, maxX = 0, maxY = 0;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (alpha[y * width + x] == 0) continue;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
        }
    }
    free(alpha);
    if (minX > maxX || minY > maxY) return image;   // 整张全透明，原样返回

    CGImageRef cropped = CGImageCreateWithImageInRect(
        source, CGRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1));
    if (!cropped) return image;

    UIImage *result = [UIImage imageWithCGImage:cropped
                                          scale:image.scale
                                    orientation:image.imageOrientation];
    CGImageRelease(cropped);
    return result;
}

// 图标同样走模板图：抖音会随页面在白/黑两版图标间切换，只取 alpha 则两版形状一致，
// 着色交给圆键的 trait，浅色玻璃上不会出现看不见的白图标。
static void DYYYGlassSyncPlusIcon(UIView *button) {
    UIImage *source = DYYYGlassPlusSourceIcon(button);
    if (!source || source == gPlusSourceIcon) return;
    gPlusSourceIcon = source;
    gPlusIcon.image = [DYYYGlassTrimTransparent(source)
        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - 点击转发

@interface DYYYGlassTabBarProxy : NSObject <UITabBarDelegate>
- (void)plusKeyDidTap;
@end

@implementation DYYYGlassTabBarProxy

// 拍摄不是页面，走抖音自己的拍摄回调，传它自己的按钮。
- (void)plusKeyDidTap {
    UITabBarController *controller = DYYYGlassControllerForView(gPlusKey);
    SEL selector = NSSelectorFromString(kDYYYPlusClickSelector);
    if (controller && gPlusButton && [controller respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, gPlusButton);
    }
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    UITabBarController *controller = DYYYGlassControllerForView(tabBar);
    NSUInteger index = [tabBar.items indexOfObjectIdenticalTo:item];
    if (!controller || index == NSNotFound || index >= gItemButtons.count) return;

    id button = gItemButtons[index];
    // 切页必须走抖音自己的按钮点击回调。直接写 selectedIndex 会被它的 override 吞掉——
    // 实测底栏选中态变了、抖音的 selectedIndex 仍是 0、页面也没换，只是「看着切了」。
    // 连手势一并原样回传，抖音据此构造点击上下文，与真实点按走完全相同的路径。
    SEL selector = NSSelectorFromString(kDYYYTabClickSelector);
    if ([controller respondsToSelector:selector]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(controller, selector, button,
                                                  DYYYGlassValue(button, @"singleTapGes"));
    }
}

@end

#pragma mark - 未读角标镜像

// 读抖音按钮当前的角标。走子视图扫描而不是 badge / badgeContainerView 属性：那两个 getter
// 可能懒建对象，而这里是逐帧路径，只读不建才安全。
static NSString *DYYYGlassBadgeValue(id button) {
    if (![button isKindOfClass:UIView.class]) return nil;

    UIView *badge = nil;
    for (UIView *container in ((UIView *)button).subviews) {
        if (![NSStringFromClass(container.class) isEqualToString:kDYYYBadgeContainerClass]
            || container.isHidden || container.alpha < 0.01) {
            continue;
        }
        for (UIView *candidate in container.subviews) {
            // 尺寸也要判：抖音会把角标留在树里收成零尺寸，那不算「有角标」。
            if ([NSStringFromClass(candidate.class) isEqualToString:kDYYYBadgeClass]
                && !candidate.isHidden && candidate.alpha >= 0.01
                && !CGRectIsEmpty(candidate.bounds)) {
                badge = candidate;
                break;
            }
        }
        if (badge) break;
    }
    if (!badge) return nil;

    NSString *text = DYYYGlassValue(badge, @"badgeText");
    if (text.length > 0) return text;                      // 抖音自己给的文案，如 "99+"
    unsigned long long count = [DYYYGlassValue(badge, @"badgeNumber") unsignedLongLongValue];
    if (count > 0) return @(count).stringValue;
    return @"";                                            // 有角标但无数字 → 纯红点
}

// badgeValue 交给系统渲染即得 iOS 26 悬浮胶囊里的原生红点，badgeColor 留 nil 用系统默认色。
static void DYYYGlassSyncBadges(void) {
    NSUInteger count = MIN(gItemButtons.count, gBar.items.count);
    for (NSUInteger i = 0; i < count; i++) {
        UITabBarItem *item = gBar.items[i];
        NSString *value = DYYYGlassBadgeValue(gItemButtons[i]);
        NSString *current = item.badgeValue;
        if (current != value && ![current isEqualToString:value]) item.badgeValue = value;
    }
}

#pragma mark - 内容镜像

// 抖音的按钮数组本身就是视觉顺序，直接照抄；拍摄入口按 type 认出来单独交给圆键，
// 其余按 validIndex 映射到 tab。
//
// 分两段走：先用一轮廉价循环算出内容签名，签名没变就不碰 items。渲染标题图并不便宜，
// 而这个函数每次底栏布局都会跑一遍。返回值表示 items 是否真的重建过。
static BOOL DYYYGlassSyncItems(UITabBarController *controller, NSArray *buttons) {
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMutableArray<NSNumber *> *kinds = [NSMutableArray array];
    NSMutableArray *mirrored = [NSMutableArray array];
    NSMutableString *signature = [NSMutableString string];
    UIView *plus = nil;

    for (id button in buttons) {
        UIView *view = [button isKindOfClass:UIView.class] ? button : nil;
        // 源按钮的 opacity 会被本功能置零，不能作为存在性信号；显隐与父视图关系保留原始语义。
        if (!view || view.isHidden || !view.superview) continue;

        if ([DYYYGlassValue(button, @"type") longLongValue] == kDYYYPlusButtonType) {
            plus = view;
            continue;                  // 拍摄不进胶囊，见 DYYYGlassMakePlusKey
        }

        NSString *title = DYYYGlassButtonTitle(button);
        if (title.length == 0) continue;

        NSInteger kind = [DYYYGlassValue(button, @"validIndex") integerValue];
        [titles addObject:title];
        [kinds addObject:@(kind)];
        [mirrored addObject:button];
        [signature appendFormat:@"%@:%ld|", title, (long)kind];
    }

    gPlusButton = plus;

    if (mirrored.count == 0) return NO;
    // 按钮引用每次都刷新：抖音可能重建出标题相同的新按钮，签名察觉不到，
    // 拿着旧对象转发点击就会落空。items 与它同序等长，只在签名变化时才重建。
    gItemButtons = mirrored;

    BOOL rebuilt = ![signature isEqualToString:gSignature];
    if (rebuilt) {
        NSMutableArray<UITabBarItem *> *items = [NSMutableArray arrayWithCapacity:titles.count];
        [titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger index, __unused BOOL *stop) {
            // 标题走 image 槽（见 DYYYGlassTitleImage），title 置空，否则系统还会再排一行标签。
            UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:nil
                                                               image:DYYYGlassTitleImage(title)
                                                                 tag:(NSInteger)index];
            item.accessibilityLabel = title;   // 标题不再是文字，旁白与探针都靠它认人
            [items addObject:item];
        }];
        gBar.items = items;
        gItemKinds = kinds;
        gSignature = [signature copy];
    }

    NSUInteger current = [gItemKinds indexOfObject:@((NSInteger)controller.selectedIndex)];
    if (current != NSNotFound && current < gBar.items.count) {
        UITabBarItem *item = gBar.items[current];
        if (gBar.selectedItem != item) gBar.selectedItem = item;
    }

    DYYYGlassSyncBadges();
    return rebuilt;
}

// 其他插件（DYYY 等）改标题、隐红点都发生在按钮的子视图里，而 UIKit 的布局遍历是父先子后，
// 抖音底栏那一轮读到的必然是它们改写前的旧值；改标题本身又不会让底栏重新布局，不补这一次
// 就会一直停在旧内容。
//
// 延到主队列再读，而不是在子视图的 hook 里直接读：谁的 hook 在外层取决于插件加载顺序，
// 只有等整轮布局结束才保证读到最终值。gPendingMirror 让一轮布局最多排一次。
static BOOL gPendingMirror = NO;

static void DYYYGlassScheduleMirror(void) {
    if (gPendingMirror || !gBar) return;
    gPendingMirror = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        gPendingMirror = NO;
        AWENormalModeTabBar *bar = gDouyinBar;
        UITabBarController *controller = bar ? DYYYGlassControllerForView(bar) : nil;
        if (!gBar || !controller) return;
        // 内容没变时纯空转；变了才重建 items，并要求底栏重排一次几何——胶囊宽度归 UIKit 算，
        // 圆键位置得跟着它走。签名收敛后不再标脏，不会形成布局环。
        if (DYYYGlassSyncItems(controller, DYYYGlassValue(bar, @"tabBarButtons"))) [bar setNeedsLayout];
    });
}

#pragma mark - 拍摄圆键

// interactive 是 iOS 26 玻璃自带的触摸反馈（按压形变），不需要我们画任何东西；
// capsuleConfiguration 作用在正方形 frame 上即为正圆。
// 触发用铺满的透明 UIButton：touchUpInside 同时满足「轻点触发」与「长按后松手仍触发」。
// 材质与胶囊同为 Clear（见 DYYYGlassMakeGlassEffect）——胶囊清透了圆键必须跟上，
// 否则又是「胶囊清透、圆键磨砂」的割裂。
static UIVisualEffectView *DYYYGlassMakePlusKey(id target) API_AVAILABLE(ios(26.0)) {
    UIVisualEffectView *key =
        [[UIVisualEffectView alloc] initWithEffect:DYYYGlassMakeGlassEffect(gGlassStyle, YES)];
    key.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];

    gPlusIcon = [[UIImageView alloc] init];
    gPlusIcon.contentMode = UIViewContentModeScaleAspectFit;
    gPlusIcon.tintColor = UIColor.labelColor;
    [key.contentView addSubview:gPlusIcon];

    gPlusHit = [UIButton buttonWithType:UIButtonTypeCustom];
    [gPlusHit addTarget:target action:@selector(plusKeyDidTap)
       forControlEvents:UIControlEventTouchUpInside];
    [key.contentView addSubview:gPlusHit];
    return key;
}

static UIView *DYYYGlassFindPlatter(UIView *root) {
    for (UIView *subview in root.subviews) {
        if ([NSStringFromClass(subview.class) containsString:kDYYYPlatterClass]) return subview;
        UIView *found = DYYYGlassFindPlatter(subview);
        if (found) return found;
    }
    return nil;
}

// 胶囊让出右侧一块，圆键补上。几何全部从 platter 实测：直径取它的高、纵向与它对齐、
// 右边距取它自己的左内缩，这样胶囊与圆键的外边距对称。
// platter 首帧还不存在时用兜底值，次帧即被真实值取代；写入先比较，不会形成布局环。
static void DYYYGlassLayoutGlass(AWENormalModeTabBar *douyinBar) API_AVAILABLE(ios(26.0)) {
    UIView *platterView = DYYYGlassFindPlatter(gBar);
    gPlatter = platterView;
    // 找到 platter 就顺手把它的玻璃换成 Clear。放在所有提前 return 之前：
    // 拍摄按钮被其他插件移除时下面会早退，但胶囊材质照样要生效。
    DYYYGlassApplyPlatterGlass(platterView, gGlassStyle);

    CGRect platter = platterView ? [platterView convertRect:platterView.bounds toView:gBar] : CGRectZero;
    BOOL measured = CGRectGetHeight(platter) > 0.0;
    CGFloat diameter = measured ? CGRectGetHeight(platter) : kDYYYPlatterFallbackHeight;
    CGFloat inset = measured ? CGRectGetMinX(platter) : kDYYYPlatterFallbackInset;
    CGFloat top = measured ? CGRectGetMinY(platter) : 0.0;

    // 拍摄按钮被其他插件移除时圆键一并隐藏，胶囊占回整条宽度。
    BOOL available = gPlusButton != nil;
    if (gPlusKey.isHidden == available) gPlusKey.hidden = !available;

    CGSize size = douyinBar.bounds.size;
    CGFloat barWidth = available ? size.width - diameter - kDYYYPlusKeyGap : size.width;
    CGRect barFrame = CGRectMake(0.0, 0.0, barWidth, size.height);
    if (!CGRectEqualToRect(gBar.frame, barFrame)) gBar.frame = barFrame;
    if (!available) return;

    CGRect keyFrame = CGRectMake(size.width - inset - diameter, top, diameter, diameter);
    if (!CGRectEqualToRect(gPlusKey.frame, keyFrame)) gPlusKey.frame = keyFrame;

    CGRect bounds = gPlusKey.bounds;
    CGRect iconFrame = CGRectInset(bounds, kDYYYPlusIconInset, kDYYYPlusIconInset);
    if (!CGRectEqualToRect(gPlusIcon.frame, iconFrame)) gPlusIcon.frame = iconFrame;
    if (!CGRectEqualToRect(gPlusHit.frame, bounds)) gPlusHit.frame = bounds;

    DYYYGlassSyncPlusIcon(gPlusButton);
}

// 抖音自绘底栏的内容隐去：背景层与按钮都不可见、不接收触摸，交互交给覆盖其上的玻璃底栏。
// 只动内容，不动底栏自身的 hidden/alpha——那是抖音的显隐状态，玻璃底栏靠继承跟随它。
//
// 驱动点是抖音底栏的 layoutSubviews，每帧都会走到这里，因此所有写入都必须先比较：
// 值没变还照写会让 UITabBar 反复重新布局，把系统的选中状态与长按拖动手势冲掉。
static void DYYYGlassSetDouyinContentVisible(AWENormalModeTabBar *douyinBar, NSArray *buttons, BOOL visible) {
    float opacity = visible ? 1.0f : 0.0f;
    NSArray *backdrops = @[ DYYYGlassValue(douyinBar, @"backgroundView") ?: NSNull.null,
                            DYYYGlassValue(douyinBar, @"awe_blurView") ?: NSNull.null,
                            DYYYGlassValue(douyinBar, @"separatorLine") ?: NSNull.null,
                            DYYYGlassValue(douyinBar, @"skinContainerView") ?: NSNull.null ];
    for (id backdrop in backdrops) {
        if (![backdrop isKindOfClass:UIView.class]) continue;
        CALayer *layer = ((UIView *)backdrop).layer;
        if (layer.opacity != opacity) layer.opacity = opacity;
    }
    for (id button in buttons) {
        if (![button isKindOfClass:UIView.class]) continue;
        UIView *view = button;
        if (view.layer.opacity != opacity) view.layer.opacity = opacity;
        if (view.userInteractionEnabled != visible) view.userInteractionEnabled = visible;
    }
}

#pragma mark - 挂载与拆除

// 整个功能只在 iOS 26 及以上成立——低版本没有 UIGlassEffect，装上去只是一条没有玻璃的
// UITabBar 盖住抖音底栏，比原生还差。故在此一处挡住，各 helper 用 API_AVAILABLE 标注。
static void DYYYGlassUpdate(AWENormalModeTabBar *douyinBar) API_AVAILABLE(ios(26.0)) {
    // 抖音换过底栏实例时，先把旧那条的内容还原——玻璃底栏只会跟着新实例走，
    // 旧实例的按钮若停在 opacity=0，它再次出现时就是一条空底栏。
    AWENormalModeTabBar *previousBar = gDouyinBar;
    if (previousBar && previousBar != douyinBar && gBar) {
        DYYYGlassSetDouyinContentVisible(
            previousBar, DYYYGlassValue(previousBar, @"tabBarButtons"), YES);
    }
    gDouyinBar = douyinBar;

    NSArray *buttons = DYYYGlassValue(douyinBar, @"tabBarButtons");
    if (!DYYYGlassTabBarEnabled()) {
        if (!gBar) return;
        DYYYGlassSetDouyinContentVisible(douyinBar, buttons, YES);
        [gBar removeFromSuperview];
        [gPlusKey removeFromSuperview];
        gBar = nil;
        gPlusKey = nil;
        gPlusIcon = nil;
        gPlusHit = nil;
        gPlusButton = nil;
        gPlusSourceIcon = nil;
        gProxy = nil;
        gItemKinds = nil;
        gItemButtons = nil;
        gSignature = nil;
        // 重新开启时材质与 platter 玻璃都要能重新装上；探测结果不复位，那是设备能力，一次为准。
        gGlassStyle = UIUserInterfaceStyleUnspecified;
        gPlatterGlassStyle = UIUserInterfaceStyleUnspecified;
        gPlatterGlassInstalled = nil;
        // 玻璃底栏是可视化的落位基准，它一撤可视化必须跟着撤，否则会留下一层孤儿视图。
        DYYYAudioVisualizerLayout(douyinBar);
        return;
    }
    // 场景监听不撤：handler 只在 gBar 存在时才动手，重新开启开关后照旧生效。

    UITabBarController *controller = DYYYGlassControllerForView(douyinBar);
    if (!controller) return;

    if (!gBar) {
        gProxy = [[DYYYGlassTabBarProxy alloc] init];
        // 不碰 appearance：实测出厂态与装了 Regular backgroundEffect 渲染逐像素相同，
        // 悬浮 provider 不读这个旧 API。材质统一由 DYYYGlassApplyPlatterGlass 决定。
        gBar = [[UITabBar alloc] initWithFrame:douyinBar.bounds];
        gBar.delegate = gProxy;
        gPlusKey = DYYYGlassMakePlusKey(gProxy);
    }

    // 作为子视图挂在抖音底栏内：显隐/透明度/位置全部随父视图继承。
    if (gBar.superview != douyinBar) [douyinBar addSubview:gBar];
    if (gPlusKey.superview != douyinBar) [douyinBar addSubview:gPlusKey];
    // 置顶兜底——其他插件遍历底栏子视图后可能改动层级。圆键在胶囊之上。
    if (douyinBar.subviews.lastObject != gPlusKey) {
        [douyinBar bringSubviewToFront:gBar];
        [douyinBar bringSubviewToFront:gPlusKey];
    }

    DYYYGlassObserveStyle(douyinBar);
    // 监听之外再逐帧比对一次：冷启动首帧与刚挂上时都没有 trait 变化事件可等。
    DYYYGlassApplyStyle(douyinBar.window.windowScene.traitCollection.userInterfaceStyle);
    DYYYGlassSyncItems(controller, buttons);
    DYYYGlassLayoutGlass(douyinBar);
    DYYYGlassSetDouyinContentVisible(douyinBar, buttons, NO);
    // 放在最后：可视化的环绕轮廓要用 DYYYGlassLayoutGlass 刚算完的胶囊与圆键几何。
    DYYYAudioVisualizerLayout(douyinBar);
}

#pragma mark - Hook

%group DYYYGlassTabBarHooks

%hook AWENormalModeTabBar

- (void)layoutSubviews {
    %orig;
    if (@available(iOS 26.0, *)) DYYYGlassUpdate(self);
}

%end

// 角标变化不一定伴随底栏重新布局（收到推送时就不会），故在抖音写入角标的两个入口上
// 立即重跑一次同步。逐帧同步只兜稳态。
%hook AWENormalModeTabBarGeneralButton

- (id)p_showBadgeWithStyle:(unsigned long long)style count:(long long)count text:(id)text config:(id)config {
    id result = %orig;
    if (gBar) DYYYGlassSyncBadges();
    return result;
}

- (void)hideBadge {
    %orig;
    if (gBar) DYYYGlassSyncBadges();
}

%end

// 这两个子视图是其他插件改底栏内容的落点：DYYY 在 TextView 里写 label.text 改标题，
// 在 BadgeContainerView 里把 DUXBadge 隐掉。见 DYYYGlassScheduleMirror。
%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
    %orig;
    DYYYGlassScheduleMirror();
}

%end

%hook AWENormalModeTabBarBadgeContainerView

- (void)layoutSubviews {
    %orig;
    DYYYGlassScheduleMirror();
}

%end

%end

#pragma mark - 设置项注册

%ctor {
    if (DYYYGlassOSAvailable()) {
        %init(DYYYGlassTabBarHooks);
    }
}
