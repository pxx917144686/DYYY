//
//  DYYYCommentDanmaku.xm
//  半屏评论区打开时保持弹幕可见，全屏评论区保持抖音原生行为（弹幕隐藏）。
//
//  抖音隐弹幕就是把 DDanmakuPlayerView 的 alpha 从 1 改成 0——三份导出对照读出来的：
//  容器 AWEDanmakuContainerView 恒为 hidden=false alpha=1，各条弹幕视图也都在，只有这一层变。
//  所以接管点就是这一个属性，不去追弹幕控制器那套 setHide: / updateDanmakuShowStatusIfNeed:
//  （静态看不出评论面板走的是哪一条）。
//

#import "AwemeHeaders.h"
#import "DYYYCommentGlass.h"
#import "DYYYUtils.h"

#import <math.h>

// 接管过的那一层。全屏进出时抖音不会再写一次 alpha，得靠它主动切回去。
static __weak UIView *gDanmakuView = nil;
static NSUInteger gKeepHits = 0;

NSString *DYYYCommentDanmakuStats(void) {
    UIView *view = gDanmakuView;
    return [NSString stringWithFormat:@"弹幕接管=%lu 次  当前 alpha=%@",
            (unsigned long)gKeepHits,
            view ? [NSString stringWithFormat:@"%.2f", view.alpha] : @"(未接管过)"];
}

// 评论面板开着、且不在全屏态时，弹幕该保持可见。
// 面板在不在屏用玻璃那把尺子（DYYYCommentGlassCurrentSlot），与探针同一判据。
static BOOL DYYYShouldKeepDanmaku(void) {
    if (!DYYYCommentGlassOn()) return NO;

    UIView *slot = DYYYCommentGlassCurrentSlot();
    return slot.window != nil && !slot.hidden;
}

void DYYYCommentDanmakuSyncForFullPanel(void) {
    UIView *view = gDanmakuView;
    if (!view) return;

    CGFloat wanted = DYYYShouldKeepDanmaku() ? 1.0 : 0.0;
    if (fabs(view.alpha - wanted) > 0.01) view.alpha = wanted;
}

%hook DDanmakuPlayerView

- (void)setAlpha:(CGFloat)alpha {
    // 只顶「压成透明」这一种写入，且只在评论面板开着时顶。长按面板、横屏、用户自己关弹幕
    // 同样走这个 setter，那些一律放行。
    if (alpha >= 0.01 || !DYYYShouldKeepDanmaku()) {
        %orig;
        return;
    }

    gDanmakuView = self;
    gKeepHits++;
    %orig(1.0);
}

%end
