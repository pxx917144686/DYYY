#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface DYYYLiquidGlassController : NSObject
@end

@implementation DYYYLiquidGlassController

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleToggleChanged) name:NSUserDefaultsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

+ (void)appDidBecomeActive {
    [self applySystemAppearanceIfAvailable];
    [self refreshKeyWindow];
}

+ (void)handleToggleChanged {
    [self refreshKeyWindow];
}

+ (void)refreshKeyWindow {
    // 宿主抖音的底部栏旧 UI，不对 keyWindow 进行全局覆盖式叠加
    (void)objc_msgSend;
}

// 仅在 iOS 26+ 应用系统原生 Liquid Glass 外观到导航栏/标签栏
+ (void)applySystemAppearanceIfAvailable {
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


