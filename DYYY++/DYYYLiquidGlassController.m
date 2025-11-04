#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "DYYYManager.h"

@interface DYYYLiquidGlassController : NSObject
@end

@implementation DYYYLiquidGlassController

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleToggleChanged) name:NSUserDefaultsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

    // 窗口/应用生命周期监听：失效与重启 Liquid Glass 监控
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [nc addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(windowDidBecomeKey:) name:UIWindowDidBecomeKeyNotification object:nil];
    [nc addObserver:self selector:@selector(windowDidResignKey:) name:UIWindowDidResignKeyNotification object:nil];
}

+ (void)appDidBecomeActive {
    [self applySystemAppearanceIfAvailable];
    [self refreshKeyWindow];
}

+ (void)appWillEnterForeground {
    // 若开关开启，重新启动实时监控
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:@"com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"];
    BOOL hideBottomBg = [defaults boolForKey:@"DYYYisHiddenBottomBg"];
    if (enabled && !hideBottomBg) {
        extern void DYYYStartRealTimeInterfaceMonitoring(void);
        DYYYStartRealTimeInterfaceMonitoring();
    }
}

+ (void)appDidEnterBackground {
    [self shutdownLiquidGlassArtifacts];
}

+ (void)windowDidBecomeKey:(NSNotification *)note {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:@"com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"];
    BOOL hideBottomBg = [defaults boolForKey:@"DYYYisHiddenBottomBg"];
    if (enabled && !hideBottomBg) {
        extern void DYYYStartRealTimeInterfaceMonitoring(void);
        DYYYStartRealTimeInterfaceMonitoring();
    }
}

+ (void)windowDidResignKey:(NSNotification *)note {
    [self shutdownLiquidGlassArtifacts];
}

+ (void)handleToggleChanged {
    [self refreshKeyWindow];
}

+ (void)refreshKeyWindow {
    // 宿主抖音的底部栏旧 UI，不对 keyWindow 进行全局覆盖式叠加
    (void)objc_msgSend;
}

// 失效并清理 Liquid Glass 产生的所有 UI/定时器/关联对象
+ (void)shutdownLiquidGlassArtifacts {
    @try {
        // 关闭并置空全局定时器
        extern void DYYYStopLiquidGlassTimerIfNeeded(void);
        DYYYStopLiquidGlassTimerIfNeeded();

        // 遍历所有窗口，移除我们注入的标签视图
        for (UIWindow *win in UIApplication.sharedApplication.windows) {
            if (!win) continue;
            NSArray<NSNumber *> *tags = @[@99999, @99997, @99996];
            for (NSNumber *tag in tags) {
                UIView *v = [win viewWithTag:tag.integerValue];
                if (v) {
                    [v removeFromSuperview];
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

// 仅在 iOS 26+ 应用系统原生 Liquid Glass 外观到导航栏/标签栏
+ (void)applySystemAppearanceIfAvailable {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:@"com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"];
    BOOL hideBottomBg = [defaults boolForKey:@"DYYYisHiddenBottomBg"];
    // 当隐藏底栏背景或未启用液态玻璃时，跳过系统外观应用
    if (!(enabled && !hideBottomBg)) {
        return;
    }
    if (@available(iOS 26.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];

        // UINavigationBar
        UINavigationBarAppearance *navApp = [[UINavigationBarAppearance alloc] init];
        [navApp configureWithTransparentBackground];
        navApp.backgroundEffect = blur;
        navApp.backgroundColor = [UIColor clearColor];

        UINavigationBar *navBarAppearance = [UINavigationBar appearance];
        navBarAppearance.standardAppearance = navApp;
        navBarAppearance.scrollEdgeAppearance = navApp;
        if (@available(iOS 15.0, *)) {
            navBarAppearance.compactAppearance = navApp;
            navBarAppearance.compactScrollEdgeAppearance = navApp;
        }

        // 不对 UITabBar 应用 Liquid Glass，避免影响宿主旧底部栏效果

        // 可选：UIToolbar
        if ([UIToolbar class]) {
            UIToolbarAppearance *toolApp = [[UIToolbarAppearance alloc] init];
            [toolApp configureWithTransparentBackground];
            toolApp.backgroundEffect = blur;
            toolApp.backgroundColor = [UIColor clearColor];
            UIToolbar *toolBarAppearance = [UIToolbar appearance];
            if (@available(iOS 15.0, *)) {
                toolBarAppearance.standardAppearance = toolApp;
                toolBarAppearance.compactAppearance = toolApp;
            }
        }
    }
}

@end


