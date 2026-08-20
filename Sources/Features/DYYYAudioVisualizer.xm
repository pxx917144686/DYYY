//
//  DYYYAudioVisualizer.xm
//  悬浮玻璃底栏的音频可视化。
//
//  三条不可回退的结论（都来自 0.5.2-beta2/beta3 的设备导出）：
//
//  · 必须【按能量选源】。抖音同时跑两只 RemoteIO，其中一只全程恒零；取"第一路"会永远
//    画不出东西。选源在 DYYYAudioTapCopyLatestSamples 里做。
//
//  · 不需要暂停闸门，也不需要静音闸门。暂停时回调照常送全零 buffer，条子自然衰减到静止态；
//    抖音内静音时它根本不建 unit，整体淡出。多写一层状态判断只会引入不一致。
//
//  · 条子不做成玻璃。Apple 自己的音频指示（Music 正在播放、语音备忘录、灵动岛）全是实心
//    内容标记——玻璃是承载内容的容器，不是数据标记本身。几十个 UIGlassEffect 也扛不住逐帧。
//

#import "DYYYAudioVisualizer.h"
#import "DYYYUtilsAudio.h"
#import "DYYYUtilsAudio.h"
#import "DYYYUtils.h"
#import "DYYYGlassTabBar.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>

#pragma mark - 尺寸

// 三个位置的尺寸全在这里。上机看完观感只改这几个数，不用碰下面任何逻辑。
//
// ① 的横向范围刻意收在胶囊【顶边直线段】上（圆角半径 31，即 x 从 left+31 到 right−31），
// 基线压在胶囊顶边上与之相切；②③ 的条根同样与轮廓相切，不插进玻璃。
static const CGFloat kDYYYTopWidth = 4.0, kDYYYTopMin = 4.0, kDYYYTopMax = 34.0;
static const NSUInteger kDYYYTopCount = 32;

static const CGFloat kDYYYCapsuleWidth = 3.0, kDYYYCapsuleMin = 3.0, kDYYYCapsuleMax = 24.0;
static const NSUInteger kDYYYCapsuleCount = 96;

static const CGFloat kDYYYPlusWidth = 3.0, kDYYYPlusMin = 3.0, kDYYYPlusMax = 16.0;
static const NSUInteger kDYYYPlusCount = 28;

// 起落手感。上升快、下降慢是音频可视化的通用口径；这两个值用 beta3 那份真实录音离线定过：
// 实测块间（21.33 ms）最大下降 0.0877，对应自然衰减约 4.1/秒，与 0.24 s 的时间常数相符。
static const NSTimeInterval kDYYYAttackTau = 0.035, kDYYYDecayTau = 0.240;
static const NSTimeInterval kDYYYReduceMotionAttackTau = 0.20, kDYYYReduceMotionDecayTau = 0.60;

// 透明度随幅度走：静止态的圆点很淡，峰值很实，读起来有纵深。
static const CGFloat kDYYYAlphaBase = 0.28, kDYYYAlphaSpan = 0.55;
static const CGFloat kDYYYReduceTransparencyBase = 0.55, kDYYYReduceTransparencySpan = 0.40;

static const NSTimeInterval kDYYYIdleSeconds = 0.25;   // 多久没回调算"停了"
static const NSTimeInterval kDYYYFadeDuration = 0.30;
static const CGFloat kDYYYFluidResample = 3.0;         // 流体形态按条数的几倍重采样轮廓

// 与 DYYYKeyAudioVizPosition 的取值一一对应，顺序即设置对话框里的顺序。
typedef NS_ENUM(NSInteger, DYYYVizMode) {
    DYYYVizModeOff = 0,
    DYYYVizModeTop,            // ① 胶囊上方水平
    DYYYVizModeCapsuleRing,    // ② 胶囊整栏环绕
    DYYYVizModePlusRing,       // ③ 圆键环绕
};

#pragma mark - 状态

@interface DYYYAudioVisualizerDriver : NSObject
- (void)tick:(CADisplayLink *)link;
@end

// 一根条子的落位：轮廓上的锚点 + 让它的伸展方向对准外法向的旋转角。
typedef struct {
    CGPoint anchor;
    CGFloat rotation;
} DYYYVizAnchor;

static UIView *gHost = nil;
static CAShapeLayer *gFluidLayer = nil;
static NSMutableArray<CALayer *> *gBars = nil;
static CADisplayLink *gLink = nil;
static DYYYAudioVisualizerDriver *gDriver = nil;

static DYYYVizMode gMode = DYYYVizModeOff;
static BOOL gFluid = NO;
static BOOL gVisible = NO;
static CFTimeInterval gLastTimestamp = 0;

// 布局产物。gCount 为 0 表示还没建起来。
static NSUInteger gCount = 0;
static DYYYVizAnchor *gAnchors = NULL;
static float *gU = NULL;          // 每根条对应的频段位置 0…1（0 = 最低频）
static float *gLevels = NULL;     // 当前显示的电平
static float *gTargets = NULL;
static float *gBands = NULL;
static CGFloat gBarWidth = 0, gBarMin = 0, gBarMax = 0;
// 上次布局用的几何签名，变了才重建。
static CGRect gCapsuleFrame = CGRectNull;
static CGRect gPlusFrame = CGRectNull;

#pragma mark - 开关

static DYYYVizMode DYYYVizCurrentMode(void) {
    if (!DYYYGlassOSAvailable()) return DYYYVizModeOff;
    NSInteger position = DYYYPrefInteger(DYYYKeyAudioVizPosition);
    if (position < DYYYVizModeOff || position > DYYYVizModePlusRing) return DYYYVizModeOff;
    return (DYYYVizMode)position;
}

#pragma mark - 轮廓参数化

// 胶囊外轮廓，从【顶部中点】出发顺时针。圆角等于半高时它就是一条标准胶囊线。
// 从顶部起算是为了让低频（能量最大）落在正上方——参见 DYYYVizBuildRing 里的 u 映射。
static void DYYYVizCapsulePoint(CGRect rect, CGFloat radius, CGFloat s,
                              CGPoint *point, CGPoint *normal) {
    CGFloat halfStraight = CGRectGetWidth(rect) / 2.0 - radius;
    CGFloat arc = (CGFloat)M_PI * radius;
    CGFloat straight = CGRectGetWidth(rect) - 2.0 * radius;
    CGFloat a = halfStraight, b = a + arc, c = b + straight, d = c + arc;
    CGFloat top = CGRectGetMinY(rect), bottom = CGRectGetMaxY(rect);

    if (s < a) {
        *point = CGPointMake(CGRectGetMidX(rect) + s, top);
        *normal = CGPointMake(0, -1);
    } else if (s < b) {
        CGFloat angle = -(CGFloat)M_PI_2 + (s - a) / radius;
        CGPoint center = CGPointMake(CGRectGetMaxX(rect) - radius, top + radius);
        *normal = CGPointMake(cos(angle), sin(angle));
        *point = CGPointMake(center.x + radius * normal->x, center.y + radius * normal->y);
    } else if (s < c) {
        *point = CGPointMake(CGRectGetMaxX(rect) - radius - (s - b), bottom);
        *normal = CGPointMake(0, 1);
    } else if (s < d) {
        CGFloat angle = (CGFloat)M_PI_2 + (s - c) / radius;
        CGPoint center = CGPointMake(CGRectGetMinX(rect) + radius, top + radius);
        *normal = CGPointMake(cos(angle), sin(angle));
        *point = CGPointMake(center.x + radius * normal->x, center.y + radius * normal->y);
    } else {
        *point = CGPointMake(CGRectGetMinX(rect) + radius + (s - d), top);
        *normal = CGPointMake(0, -1);
    }
}

static void DYYYVizCirclePoint(CGPoint center, CGFloat radius, CGFloat perimeter, CGFloat s,
                             CGPoint *point, CGPoint *normal) {
    CGFloat angle = -(CGFloat)M_PI_2 + (s / perimeter) * 2.0 * (CGFloat)M_PI;
    *normal = CGPointMake(cos(angle), sin(angle));
    *point = CGPointMake(center.x + radius * normal->x, center.y + radius * normal->y);
}

// 让图层的伸展方向（本地 -Y）对准外法向：R(θ)·(0,−1) = (sinθ, −cosθ) = (nx, ny)。
static CGFloat DYYYVizRotationForNormal(CGPoint normal) {
    return atan2(normal.x, -normal.y);
}

#pragma mark - 布局

static void DYYYVizFreeGeometry(void) {
    free(gAnchors); gAnchors = NULL;
    free(gU);       gU = NULL;
    free(gLevels);  gLevels = NULL;
    free(gTargets); gTargets = NULL;
    free(gBands);   gBands = NULL;
    gCount = 0;
}

static BOOL DYYYVizAllocGeometry(NSUInteger count) {
    DYYYVizFreeGeometry();
    gAnchors = (DYYYVizAnchor *)calloc(count, sizeof(DYYYVizAnchor));
    gU = (float *)calloc(count, sizeof(float));
    gLevels = (float *)calloc(count, sizeof(float));
    gTargets = (float *)calloc(count, sizeof(float));
    gBands = (float *)calloc(DYYYAudioLevelsBandCount(), sizeof(float));
    if (!gAnchors || !gU || !gLevels || !gTargets || !gBands) {
        DYYYVizFreeGeometry();
        return NO;
    }
    gCount = count;
    return YES;
}

// 环绕：沿周长等距摆条，u 取"距顶部中点的较短弧长"归一化。
// 于是正上方 = 最低频 = 能量最大，绕到正下方 = 最高频 = 实测素材里基本为零，底部自然静止。
static void DYYYVizBuildRing(NSUInteger count, CGFloat perimeter,
                           void (^pointAt)(CGFloat s, CGPoint *point, CGPoint *normal)) {
    for (NSUInteger k = 0; k < count; k++) {
        CGFloat s = (k + 0.5) * perimeter / count;
        CGPoint point = CGPointZero, normal = CGPointZero;
        pointAt(s, &point, &normal);
        gAnchors[k] = (DYYYVizAnchor){ point, DYYYVizRotationForNormal(normal) };
        gU[k] = (float)(MIN(s, perimeter - s) / (perimeter / 2.0));
    }
}

static void DYYYVizBuildTop(CGRect capsule) {
    CGFloat radius = MIN(CGRectGetHeight(capsule), CGRectGetWidth(capsule)) / 2.0;
    CGFloat width = CGRectGetWidth(capsule) - 2.0 * radius;      // 只占顶边直线段
    CGFloat gap = (width - kDYYYTopCount * kDYYYTopWidth) / (kDYYYTopCount - 1);
    for (NSUInteger k = 0; k < kDYYYTopCount; k++) {
        CGFloat x = CGRectGetMinX(capsule) + radius + k * (kDYYYTopWidth + gap) + kDYYYTopWidth / 2.0;
        gAnchors[k] = (DYYYVizAnchor){ CGPointMake(x, CGRectGetMinY(capsule)), 0.0 };
        // 低频在中央，与环绕形态的"低频在正上方"在视觉上对齐。
        gU[k] = (float)(fabs((double)k - (kDYYYTopCount - 1) / 2.0) / ((kDYYYTopCount - 1) / 2.0));
    }
}

static void DYYYVizRebuildLayers(void) {
    for (CALayer *bar in gBars) [bar removeFromSuperlayer];
    [gBars removeAllObjects];
    [gFluidLayer removeFromSuperlayer];
    gFluidLayer = nil;
    if (!gHost) return;

    UIColor *color = [UIColor.labelColor resolvedColorWithTraitCollection:gHost.traitCollection];
    if (gFluid) {
        gFluidLayer = [CAShapeLayer layer];
        gFluidLayer.fillColor = [color colorWithAlphaComponent:kDYYYAlphaBase + kDYYYAlphaSpan * 0.35].CGColor;
        gFluidLayer.actions = @{ @"path": NSNull.null, @"fillColor": NSNull.null };
        [gHost.layer addSublayer:gFluidLayer];
        return;
    }
    for (NSUInteger k = 0; k < gCount; k++) {
        CALayer *bar = [CALayer layer];
        bar.backgroundColor = color.CGColor;
        bar.cornerRadius = gBarWidth / 2.0;
        bar.anchorPoint = CGPointMake(0.5, 1.0);
        bar.bounds = CGRectMake(0, 0, gBarWidth, gBarMin);
        bar.position = gAnchors[k].anchor;
        bar.affineTransform = CGAffineTransformMakeRotation(gAnchors[k].rotation);
        bar.opacity = kDYYYAlphaBase;
        bar.actions = @{ @"bounds": NSNull.null, @"opacity": NSNull.null,
                         @"position": NSNull.null, @"transform": NSNull.null };
        [gHost.layer addSublayer:bar];
        [gBars addObject:bar];
    }
}

static void DYYYVizTeardown(void) {
    DYYYAudioTapSetLiveMeteringEnabled(NO);
    DYYYAudioTapSetEnabled(NO);
    [gLink invalidate];
    gLink = nil;
    gDriver = nil;
    [gHost removeFromSuperview];
    gHost = nil;
    gFluidLayer = nil;
    [gBars removeAllObjects];
    DYYYVizFreeGeometry();
    gMode = DYYYVizModeOff;
    gVisible = NO;
    gCapsuleFrame = CGRectNull;
    gPlusFrame = CGRectNull;
    DYYYAudioLevelsReset();
}

#pragma mark - 逐帧

static void DYYYVizApplyBars(void) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGFloat span = UIAccessibilityIsReduceTransparencyEnabled() ? kDYYYReduceTransparencySpan : kDYYYAlphaSpan;
    CGFloat base = UIAccessibilityIsReduceTransparencyEnabled() ? kDYYYReduceTransparencyBase : kDYYYAlphaBase;
    for (NSUInteger k = 0; k < gBars.count; k++) {
        CGFloat level = gLevels[k];
        CALayer *bar = gBars[k];
        // 写 bounds 而不是 transform 缩放：transform 会把 cornerRadius 一起压扁，
        // 低电平时端头变成椭圆。写 bounds 时 Core Animation 自动把圆角夹到较短边的一半，
        // 高度收到等于宽度就正好是个圆点。
        bar.bounds = CGRectMake(0, 0, gBarWidth, gBarMin + (gBarMax - gBarMin) * level);
        bar.opacity = (float)(base + span * level);
    }
    [CATransaction commit];
}

// 流体形态：按条数的若干倍重采样轮廓，电平在条与条之间插值，再用二次贝塞尔的中点法收成平滑闭合路径。
static void DYYYVizApplyFluid(CGRect capsule, CGRect plus) {
    if (!gFluidLayer || gCount == 0) return;
    NSUInteger samples = (NSUInteger)(gCount * kDYYYFluidResample);
    CGMutablePathRef path = CGPathCreateMutable();

    if (gMode == DYYYVizModeTop) {
        CGFloat radius = MIN(CGRectGetHeight(capsule), CGRectGetWidth(capsule)) / 2.0;
        CGFloat left = CGRectGetMinX(capsule) + radius;
        CGFloat width = CGRectGetWidth(capsule) - 2.0 * radius;
        CGFloat baseline = CGRectGetMinY(capsule);
        CGPathMoveToPoint(path, NULL, left, baseline);
        CGPoint previous = CGPointZero;
        for (NSUInteger k = 0; k < gCount; k++) {
            CGPoint current = CGPointMake(left + (k + 0.5) * width / gCount,
                                          baseline - (gBarMin + (gBarMax - gBarMin) * gLevels[k]));
            if (k == 0) CGPathAddLineToPoint(path, NULL, current.x, current.y);
            else CGPathAddQuadCurveToPoint(path, NULL, previous.x, previous.y,
                                           (previous.x + current.x) / 2.0, (previous.y + current.y) / 2.0);
            previous = current;
        }
        CGPathAddLineToPoint(path, NULL, previous.x, previous.y);
        CGPathAddLineToPoint(path, NULL, left + width, baseline);
        CGPathCloseSubpath(path);
    } else {
        BOOL capsuleRing = gMode == DYYYVizModeCapsuleRing;
        CGFloat radius = capsuleRing ? MIN(CGRectGetHeight(capsule), CGRectGetWidth(capsule)) / 2.0
                                     : CGRectGetHeight(plus) / 2.0;
        CGFloat perimeter = capsuleRing
            ? 2.0 * (CGRectGetWidth(capsule) - 2.0 * radius) + 2.0 * (CGFloat)M_PI * radius
            : 2.0 * (CGFloat)M_PI * radius;
        // 胶囊环绕时 plus 可能是 CGRectNull（拍摄键被其他插件移除），别去取它的中点。
        CGPoint center = capsuleRing ? CGPointZero
                                     : CGPointMake(CGRectGetMidX(plus), CGRectGetMidY(plus));

        CGPoint first = CGPointZero, previous = CGPointZero;
        for (NSUInteger j = 0; j <= samples; j++) {
            NSUInteger index = j % samples;
            CGFloat s = (index + 0.5) * perimeter / samples;
            CGPoint point = CGPointZero, normal = CGPointZero;
            if (capsuleRing) DYYYVizCapsulePoint(capsule, radius, s, &point, &normal);
            else DYYYVizCirclePoint(center, radius, perimeter, s, &point, &normal);

            CGFloat position = (CGFloat)index * gCount / samples;
            NSUInteger low = (NSUInteger)position;
            CGFloat frac = position - low;
            CGFloat level = gLevels[low % gCount] * (1.0 - frac) + gLevels[(low + 1) % gCount] * frac;
            CGFloat length = gBarMin + (gBarMax - gBarMin) * level;
            CGPoint outer = CGPointMake(point.x + normal.x * length, point.y + normal.y * length);

            if (j == 0) { first = outer; previous = outer; CGPathMoveToPoint(path, NULL, outer.x, outer.y); }
            else {
                CGPathAddQuadCurveToPoint(path, NULL, previous.x, previous.y,
                                          (previous.x + outer.x) / 2.0, (previous.y + outer.y) / 2.0);
                previous = outer;
            }
        }
        CGPathAddQuadCurveToPoint(path, NULL, previous.x, previous.y,
                                  (previous.x + first.x) / 2.0, (previous.y + first.y) / 2.0);
        CGPathCloseSubpath(path);
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    gFluidLayer.path = path;
    [CATransaction commit];
    CGPathRelease(path);
}

static void DYYYVizSetVisible(BOOL visible) {
    if (visible == gVisible || !gHost) return;
    gVisible = visible;
    [UIView animateWithDuration:kDYYYFadeDuration animations:^{ gHost.alpha = visible ? 1.0 : 0.0; }];
}

@implementation DYYYAudioVisualizerDriver

- (void)tick:(CADisplayLink *)link {
    if (gCount == 0 || !gHost) return;
    NSTimeInterval dt = gLastTimestamp > 0 ? link.timestamp - gLastTimestamp : 1.0 / 60.0;
    gLastTimestamp = link.timestamp;
    if (dt <= 0 || dt > 0.5) dt = 1.0 / 60.0;

    BOOL active = DYYYAudioTapHasRecentAudio(kDYYYIdleSeconds);
    DYYYVizSetVisible(active);

    if (!DYYYAudioLevelsSampleBands(gBands, dt)) {
        memset(gTargets, 0, gCount * sizeof(float));
    } else {
        DYYYAudioLevelsResample(gBands, gU, gTargets, (uint32_t)gCount);
        DYYYAudioLevelsSpatialSmooth(gTargets, (uint32_t)gCount);
    }

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    DYYYAudioLevelsSmooth(gLevels, gTargets, (uint32_t)gCount, dt,
                        reduceMotion ? kDYYYReduceMotionAttackTau : kDYYYAttackTau,
                        reduceMotion ? kDYYYReduceMotionDecayTau : kDYYYDecayTau);

    // 停了且已经全部落回静止态时，把帧率降下来空转，不再写图层。
    BOOL settled = !active;
    if (settled) {
        for (NSUInteger k = 0; k < gCount; k++) {
            if (gLevels[k] > 0.002f) { settled = NO; break; }
        }
    }
    link.preferredFrameRateRange = settled ? CAFrameRateRangeMake(8, 15, 10)
                                           : CAFrameRateRangeMake(30, 60, 60);
    if (settled) return;

    if (gFluid) DYYYVizApplyFluid(gCapsuleFrame, gPlusFrame);
    else DYYYVizApplyBars();
}

@end

#pragma mark - 挂载

void DYYYAudioVisualizerLayout(UIView *douyinBar) {
    if (!DYYYGlassOSAvailable()) {
        DYYYVizTeardown();
        return;
    }
    DYYYVizMode mode = DYYYVizCurrentMode();
    UIView *platter = DYYYGlassPlatterCurrent();
    UIView *plusKey = DYYYGlassPlusKeyCurrent();
    // 三个位置都以玻璃胶囊/圆键为基准，悬浮玻璃底栏关着时整体不成立。
    if (mode == DYYYVizModeOff || !douyinBar || !platter) {
        DYYYVizTeardown();
        return;
    }

    CGRect capsule = [platter convertRect:platter.bounds toView:douyinBar];
    CGRect plus = plusKey && !plusKey.isHidden ? plusKey.frame : CGRectNull;
    if (mode == DYYYVizModePlusRing && CGRectIsNull(plus)) {
        DYYYVizTeardown();
        return;
    }
    BOOL fluid = DYYYPrefInteger(DYYYKeyAudioVizStyle) != 0;
    DYYYAudioTapSetEnabled(YES);
    DYYYAudioTapSetLiveMeteringEnabled(YES);

    if (!gHost) {
        gHost = [[UIView alloc] initWithFrame:douyinBar.bounds];
        gHost.userInteractionEnabled = NO;
        gHost.clipsToBounds = NO;      // 条子要长到底栏外面去
        gHost.alpha = 0.0;
        gBars = [NSMutableArray array];
        gVisible = NO;
    }
    // 挂在玻璃【之下】：条根塞在玻璃边缘底下，不会出现硬接缝。
    UITabBar *glass = DYYYGlassTabBarCurrent();
    if (gHost.superview != douyinBar) {
        if (glass.superview == douyinBar) [douyinBar insertSubview:gHost belowSubview:glass];
        else [douyinBar addSubview:gHost];
    } else if (glass.superview == douyinBar &&
               [douyinBar.subviews indexOfObjectIdenticalTo:gHost] >
               [douyinBar.subviews indexOfObjectIdenticalTo:glass]) {
        [douyinBar insertSubview:gHost belowSubview:glass];
    }
    if (!CGRectEqualToRect(gHost.frame, douyinBar.bounds)) gHost.frame = douyinBar.bounds;

    // 深浅色是唯一继承不到的东西：抖音把 window.overrideUserInterfaceStyle 钉死浅色，
    // 只有场景那一层是系统直接下发的真值。与 DYYYGlassApplyStyle 同源。
    UIUserInterfaceStyle style = douyinBar.window.windowScene.traitCollection.userInterfaceStyle;
    BOOL styleChanged = style != UIUserInterfaceStyleUnspecified &&
                        gHost.overrideUserInterfaceStyle != style;
    if (styleChanged) gHost.overrideUserInterfaceStyle = style;

    BOOL geometryChanged = mode != gMode || fluid != gFluid ||
        !CGRectEqualToRect(capsule, gCapsuleFrame) || !CGRectEqualToRect(plus, gPlusFrame);
    if (!geometryChanged && !styleChanged) return;

    gCapsuleFrame = capsule;
    gPlusFrame = plus;

    if (geometryChanged) {
        gMode = mode;
        gFluid = fluid;
        CGFloat capsuleRadius = MIN(CGRectGetHeight(capsule), CGRectGetWidth(capsule)) / 2.0;
        BOOL built = NO;
        switch (mode) {
            case DYYYVizModeTop:
                gBarWidth = kDYYYTopWidth; gBarMin = kDYYYTopMin; gBarMax = kDYYYTopMax;
                if ((built = DYYYVizAllocGeometry(kDYYYTopCount))) DYYYVizBuildTop(capsule);
                break;
            case DYYYVizModeCapsuleRing: {
                gBarWidth = kDYYYCapsuleWidth; gBarMin = kDYYYCapsuleMin; gBarMax = kDYYYCapsuleMax;
                if (!(built = DYYYVizAllocGeometry(kDYYYCapsuleCount))) break;
                CGFloat perimeter = 2.0 * (CGRectGetWidth(capsule) - 2.0 * capsuleRadius) +
                                    2.0 * (CGFloat)M_PI * capsuleRadius;
                DYYYVizBuildRing(kDYYYCapsuleCount, perimeter, ^(CGFloat s, CGPoint *p, CGPoint *n) {
                    DYYYVizCapsulePoint(capsule, capsuleRadius, s, p, n);
                });
                break;
            }
            case DYYYVizModePlusRing: {
                gBarWidth = kDYYYPlusWidth; gBarMin = kDYYYPlusMin; gBarMax = kDYYYPlusMax;
                if (!(built = DYYYVizAllocGeometry(kDYYYPlusCount))) break;
                CGFloat radius = CGRectGetHeight(plus) / 2.0;
                CGFloat perimeter = 2.0 * (CGFloat)M_PI * radius;
                CGPoint center = CGPointMake(CGRectGetMidX(plus), CGRectGetMidY(plus));
                DYYYVizBuildRing(kDYYYPlusCount, perimeter, ^(CGFloat s, CGPoint *p, CGPoint *n) {
                    DYYYVizCirclePoint(center, radius, perimeter, s, p, n);
                });
                break;
            }
            default:
                break;
        }
        // 建不起来就整套拆干净：几何签名已经写进去了，半吊子状态会让下一轮布局直接早退，
        // 从此再也不重试。
        if (!built) { DYYYVizTeardown(); return; }
    }
    DYYYVizRebuildLayers();

    if (!gLink) {
        gDriver = [[DYYYAudioVisualizerDriver alloc] init];
        gLink = [CADisplayLink displayLinkWithTarget:gDriver selector:@selector(tick:)];
        gLink.preferredFrameRateRange = CAFrameRateRangeMake(30, 60, 60);
        gLastTimestamp = 0;
        [gLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
}

#pragma mark - 设置项注册

// 位置与形态都是单选，用对话框选。设置项只负责写 NSUserDefaults：
// DYYYAudioVisualizerLayout 每次底栏布局都会重读，位置/形态变了自然会重建，
// 不需要额外的即时刷新通路。
%ctor {
    // 只安装透明转发；实际登记、事件记录与 Render Notify 由布局中的有效模式开启。
    DYYYAudioTapInstall();
    DYYYAudioTapSetEnabled(NO);
}
