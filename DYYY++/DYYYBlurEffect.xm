#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYSDKPatch.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"

// 定义常量
#ifndef DYYY_IGNORE_GLOBAL_ALPHA_TAG
#define DYYY_IGNORE_GLOBAL_ALPHA_TAG 88888
#endif

// 统一判断是否启用"液态玻璃UI"
static inline BOOL DYYYIsLiquidGlassEnabled(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:@"com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"];
    BOOL hideBottomBg = [defaults boolForKey:@"DYYYisHiddenBottomBg"];
    // 当隐藏底栏背景时，不启用液态玻璃效果
    return enabled && !hideBottomBg;
}

// 全局定时器与停止函数（供控制器调用）
static NSTimer *gDYYYLGTimer = nil;
void DYYYStopLiquidGlassTimerIfNeeded(void) {
    if (gDYYYLGTimer) { [gDYYYLGTimer invalidate]; gDYYYLGTimer = nil; }
}

// 检查是否有透明功能冲突
static inline BOOL DYYYHasTransparencyConflict(void) {
    // 检查是否启用了全局透明功能
    BOOL globalTransparency = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGlobalTransparency"];
    // 检查是否启用了评论区透明功能
    BOOL commentTransparency = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCommentTransparency"];
    // 检查是否启用了底部栏透明功能
    BOOL bottomBarTransparency = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYBottomBarTransparency"];
    
    return globalTransparency || commentTransparency || bottomBarTransparency;
}

// 智能解决透明功能冲突
static inline BOOL DYYYShouldApplyLiquidGlassWithConflictResolution(UIView *targetView) {
    if (!DYYYIsLiquidGlassEnabled()) {
        return NO;
    }
    
    // 如果有透明功能冲突，需要特殊处理
    if (DYYYHasTransparencyConflict()) {
        // 检查目标视图是否已经被透明功能处理过
        if (targetView.alpha < 1.0 && targetView.alpha > 0.0) {
            NSLog(@"[DYYY] 检测到透明功能冲突，跳过 Liquid Glass 应用");
            return NO;
        }
        
        // 检查是否包含透明相关的子视图
        for (UIView *subview in targetView.subviews) {
            if (subview.alpha < 1.0 && subview.alpha > 0.0) {
                NSLog(@"[DYYY] 检测到子视图透明冲突，跳过 Liquid Glass 应用");
                return NO;
            }
        }
    }
    
    return YES;
}

// 处理透明功能冲突 - 简化版本避免启动问题
static void DYYYHandleTransparencyConflict(void) {
    @try {
        if (!DYYYIsLiquidGlassEnabled()) {
            return; // Liquid Glass 未启用，无需处理
        }
        
        // 检查并处理透明功能冲突
        if (DYYYHasTransparencyConflict()) {
            NSLog(@"[DYYY] 检测到透明功能冲突，正在处理...");
            
            // 临时禁用冲突的透明功能
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            // 保存原始状态
            BOOL originalGlobalTransparency = [defaults boolForKey:@"DYYYGlobalTransparency"];
            BOOL originalCommentTransparency = [defaults boolForKey:@"DYYYCommentTransparency"];
            BOOL originalBottomBarTransparency = [defaults boolForKey:@"DYYYBottomBarTransparency"];
            
            // 保存到临时键值
            [defaults setBool:originalGlobalTransparency forKey:@"DYYYGlobalTransparency_Backup"];
            [defaults setBool:originalCommentTransparency forKey:@"DYYYCommentTransparency_Backup"];
            [defaults setBool:originalBottomBarTransparency forKey:@"DYYYBottomBarTransparency_Backup"];
            
            // 临时禁用冲突功能
            [defaults setBool:NO forKey:@"DYYYGlobalTransparency"];
            [defaults setBool:NO forKey:@"DYYYCommentTransparency"];
            [defaults setBool:NO forKey:@"DYYYBottomBarTransparency"];
            
            NSLog(@"[DYYY] 已临时禁用透明功能以避免冲突");
        }
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 处理透明功能冲突时出错: %@", exception.reason);
    }
}

// 恢复透明功能 - 当禁用 Liquid Glass 时恢复原始透明功能
static void DYYYRestoreTransparencyFunctions(void) {
    if (DYYYIsLiquidGlassEnabled()) {
        return; // Liquid Glass 仍启用，无需恢复
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 检查是否有备份的透明功能设置
    if ([defaults objectForKey:@"DYYYGlobalTransparency_Backup"] != nil) {
        BOOL originalGlobalTransparency = [defaults boolForKey:@"DYYYGlobalTransparency_Backup"];
        BOOL originalCommentTransparency = [defaults boolForKey:@"DYYYCommentTransparency_Backup"];
        BOOL originalBottomBarTransparency = [defaults boolForKey:@"DYYYBottomBarTransparency_Backup"];
        
        // 恢复原始设置
        [defaults setBool:originalGlobalTransparency forKey:@"DYYYGlobalTransparency"];
        [defaults setBool:originalCommentTransparency forKey:@"DYYYCommentTransparency"];
        [defaults setBool:originalBottomBarTransparency forKey:@"DYYYBottomBarTransparency"];
        
        // 清除备份
        [defaults removeObjectForKey:@"DYYYGlobalTransparency_Backup"];
        [defaults removeObjectForKey:@"DYYYCommentTransparency_Backup"];
        [defaults removeObjectForKey:@"DYYYBottomBarTransparency_Backup"];
        
        NSLog(@"[DYYY] 已恢复原始透明功能设置");
    }
}

// 全局状态：是否正在播放视频
static BOOL isVideoPlaying = NO;

// 前向声明
static void DYYYRemoveAllSwiftUIViews(void);
void DYYYInjectSwiftUIToTabBar(AWENormalModeTabBar *tabBar);
static void DYYYCollectDouyinInterfaceInfo(void);
static void DYYYNotifySwiftUIInterfaceChanged(void);
static void collectViewControllers(UIViewController *vc, NSMutableArray *array);
static void collectViewControllersWithDepth(UIViewController *vc, NSMutableArray *array, NSInteger currentDepth, NSInteger maxDepth);
static void findTabBarInfo(UIView *view, NSMutableArray *buttons);
static void analyzeDouyinInterfaceElements(UIView *view, NSMutableArray *buttons, NSMutableDictionary *tabBarState, NSMutableDictionary *videoState, NSMutableDictionary *uiElements);
static void DYYYStartRealTimeInterfaceMonitoring(void);

// 应用启动时初始化 - 简化版本避免启动问题
%ctor {
    NSLog(@"[DYYY] Liquid Glass 模块初始化开始");
    
    // 检查是否启用 Liquid Glass UI（自动启用 SDK 26 补丁）
    if (DYYYIsLiquidGlassEnabled()) {
        NSLog(@"[DYYY] 检测到 Liquid Glass UI 已启用，自动应用 SDK 26 补丁");
        
        // 应用 Mach-O 二进制修改
        LCPatchMachOForSDK26();
        
        // 应用运行时欺骗
        _locateMachosAndChangeToSDK26();
        
        NSLog(@"[DYYY] SDK 26 补丁应用完成");
    }
    
    // 延迟处理透明功能冲突，避免启动时阻塞（使用安全延迟，防止切窗时回调悬挂）
    [DYYYUtils dispatchAfter:2.0 owner:[UIApplication sharedApplication] block:^{
        if (![UIApplication sharedApplication].keyWindow) return;
        DYYYHandleTransparencyConflict();
    }];
    
    NSLog(@"[DYYY] Liquid Glass 模块初始化完成");
}

// 查找视图的父视图控制器
@interface UIView (DYYYHelper)
- (UIViewController *)firstAvailableUIViewController;
@end

@implementation UIView (DYYYHelper)
- (UIViewController *)firstAvailableUIViewController {
    UIResponder *responder = self;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}
@end

// 移除所有 SwiftUI 视图
static void DYYYRemoveAllSwiftUIViews(void) {
    UIWindow *keyWindow = [DYYYManager getActiveWindow];
    if (!keyWindow || !keyWindow.rootViewController) return;
    
    // 移除全局 SwiftUI 视图
    UIView *rootView = keyWindow.rootViewController.view;
    const NSInteger globalTag = 987657;
    UIView *globalSwiftUIView = [rootView viewWithTag:globalTag];
    if (globalSwiftUIView) {
        [globalSwiftUIView removeFromSuperview];
        NSLog(@"[DYYY] 已移除全局 SwiftUI 视图");
    }
    
    // 移除其他可能的 SwiftUI 视图
    NSArray *swiftUITags = @[@987655, @987656, @987658]; // 添加标签栏 SwiftUI 视图标签
    for (NSNumber *tag in swiftUITags) {
        UIView *swiftUIView = [rootView viewWithTag:tag.integerValue];
        if (swiftUIView) {
            [swiftUIView removeFromSuperview];
            NSLog(@"[DYYY] 已移除 SwiftUI 视图 (tag: %@)", tag);
        }
    }
}

// 为底部标签栏注入 SwiftUI 渲染管线
void DYYYInjectSwiftUIToTabBar(AWENormalModeTabBar *tabBar) {
    if (!tabBar || !DYYYIsLiquidGlassEnabled()) return;
    
    if (@available(iOS 15.0, *)) {
        const NSInteger tabBarSwiftUITag = 987658;
        
        // 检查是否已经注入过
        UIView *existingSwiftUI = [tabBar viewWithTag:tabBarSwiftUITag];
        if (existingSwiftUI) {
            // 如果已存在，先移除旧的
            [existingSwiftUI removeFromSuperview];
        }
        
        Class Bridge = NSClassFromString(@"DYYYSwiftUIBridge");
        SEL sel = @selector(makeTabBarHostingController);
        if (Bridge && [Bridge respondsToSelector:sel]) {
            IMP imp = [Bridge methodForSelector:sel];
            UIViewController* (*fn)(id, SEL) = (UIViewController* (*)(id, SEL))imp;
            UIViewController *host = fn(Bridge, sel);
            
            if ([host isKindOfClass:[UIViewController class]] && host.view) {
                // 获取标签栏的父视图控制器
                UIViewController *parentVC = [tabBar firstAvailableUIViewController];
                if (parentVC) {
                    [parentVC addChildViewController:host];
                    
                    // 优化视图配置
                    host.view.frame = tabBar.bounds;
                    host.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    host.view.userInteractionEnabled = NO; // 不阻挡按钮交互
                    host.view.backgroundColor = [UIColor clearColor];
                    host.view.tag = tabBarSwiftUITag;
                    
                    // 设置渲染优化
                    host.view.layer.shouldRasterize = YES;
                    host.view.layer.rasterizationScale = [UIScreen mainScreen].scale;
                    host.view.layer.opaque = NO;
                    
                    // 智能插入位置：找到背景视图后插入
                    NSInteger insertIndex = 0;
                    for (NSInteger i = 0; i < tabBar.subviews.count; i++) {
                        UIView *subview = tabBar.subviews[i];
                        // 查找背景视图（通常是包含 UIImageView 的 UIView）
                        if ([subview class] == [UIView class]) {
                            BOOL hasImageView = NO;
                            for (UIView *childView in subview.subviews) {
                                if ([childView isKindOfClass:[UIImageView class]]) {
                                    hasImageView = YES;
                                    break;
                                }
                            }
                            if (hasImageView) {
                                insertIndex = i + 1; // 插入到背景视图之后
                                break;
                            }
                        }
                    }
                    
                    [tabBar insertSubview:host.view atIndex:insertIndex];
                    [host didMoveToParentViewController:parentVC];
                    
                    // 收集抖音界面信息并传递给 SwiftUI
                    DYYYCollectDouyinInterfaceInfo();
                    
                    NSLog(@"[DYYY] SwiftUI 渲染管线已注入到底部标签栏 (index: %ld)", (long)insertIndex);
                }
            }
        }
    }
}

// 收集抖音界面元素信息
static void DYYYCollectDouyinInterfaceInfo(void) {
    if (!DYYYIsLiquidGlassEnabled()) return;
    
    // 使用后台队列避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIWindow *keyWindow = [DYYYManager getActiveWindow];
        if (!keyWindow) {
            return;
        }
        
        NSMutableArray *viewControllers = [NSMutableArray array];
        collectViewControllersWithDepth(keyWindow.rootViewController, viewControllers, 0, 3);
        
        NSMutableDictionary *interfaceInfo = [NSMutableDictionary dictionary];
        interfaceInfo[@"viewControllers"] = viewControllers;
        interfaceInfo[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
        
        // 分析标签栏信息
        NSMutableArray *tabBarButtons = [NSMutableArray array];
        NSMutableDictionary *tabBarState = [NSMutableDictionary dictionary];
        NSMutableDictionary *videoState = [NSMutableDictionary dictionary];
        NSMutableDictionary *uiElements = [NSMutableDictionary dictionary];
        
        for (UIViewController *vc in viewControllers) {
            if (vc.view) {
                findTabBarInfo(vc.view, tabBarButtons);
                analyzeDouyinInterfaceElements(vc.view, tabBarButtons, tabBarState, videoState, uiElements);
            }
        }
        
        interfaceInfo[@"tabBarButtons"] = tabBarButtons;
        interfaceInfo[@"tabBarState"] = tabBarState;
        interfaceInfo[@"videoState"] = videoState;
        interfaceInfo[@"uiElements"] = uiElements;
        interfaceInfo[@"isVideoPlaying"] = @(isVideoPlaying);
        interfaceInfo[@"currentTheme"] = [DYYYManager isDarkMode] ? @"dark" : @"light";
        
        // 保存到 UserDefaults
        [[NSUserDefaults standardUserDefaults] setObject:interfaceInfo forKey:@"DYYYInterfaceInfo"];
        
        // 通知 SwiftUI 更新
        dispatch_async(dispatch_get_main_queue(), ^{
            DYYYNotifySwiftUIInterfaceChanged();
        });
        
        NSLog(@"[DYYY] 界面信息已收集: %@", interfaceInfo);
    });
}

// 递归收集视图控制器
static void collectViewControllers(UIViewController *vc, NSMutableArray *array) {
    if (!vc) return;
    
    [array addObject:NSStringFromClass([vc class])];
    
    for (UIViewController *child in vc.childViewControllers) {
        collectViewControllers(child, array);
    }
}

// 带深度限制的递归收集视图控制器
static void collectViewControllersWithDepth(UIViewController *vc, NSMutableArray *array, NSInteger currentDepth, NSInteger maxDepth) {
    if (!vc || currentDepth >= maxDepth) return;
    
    [array addObject:NSStringFromClass([vc class])];
    
    for (UIViewController *child in vc.childViewControllers) {
        collectViewControllersWithDepth(child, array, currentDepth + 1, maxDepth);
    }
}

// 查找标签栏信息
static void findTabBarInfo(UIView *view, NSMutableArray *buttons) {
    if (!view) return;
    
    // 分析标签栏状态
    if ([view isKindOfClass:NSClassFromString(@"AWENormalModeTabBar")]) {
        NSMutableArray *tabButtons = [NSMutableArray array];
        NSInteger selectedIndex = -1;
        
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"AWENormalModeTabBarGeneralButton")]) {
                NSString *label = subview.accessibilityLabel;
                if (label) {
                    [tabButtons addObject:label];
                    
                    // 检查是否选中
                    if ([subview respondsToSelector:@selector(status)]) {
                        NSInteger status = [[subview valueForKey:@"status"] integerValue];
                        if (status == 2) { // 选中状态
                            selectedIndex = tabButtons.count - 1;
                        }
                    }
                }
            }
        }
        
        [buttons addObjectsFromArray:tabButtons];
    }
    
    // 递归查找子视图
    for (UIView *subview in view.subviews) {
        findTabBarInfo(subview, buttons);
    }
}

// 深度分析抖音界面元素
static void analyzeDouyinInterfaceElements(UIView *view, NSMutableArray *buttons, NSMutableDictionary *tabBarState, NSMutableDictionary *videoState, NSMutableDictionary *uiElements) {
    if (!view) return;
    
    // 分析标签栏状态
    if ([view isKindOfClass:NSClassFromString(@"AWENormalModeTabBar")]) {
        NSMutableArray *tabButtons = [NSMutableArray array];
        NSInteger selectedIndex = -1;
        
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"AWENormalModeTabBarGeneralButton")]) {
                NSString *label = subview.accessibilityLabel;
                if (label) {
                    [tabButtons addObject:label];
                    
                    // 检查是否选中
                    if ([subview respondsToSelector:@selector(status)]) {
                        NSInteger status = [[subview valueForKey:@"status"] integerValue];
                        if (status == 2) { // 选中状态
                            selectedIndex = tabButtons.count - 1;
                        }
                    }
                }
            }
        }
        
        tabBarState[@"buttons"] = tabButtons;
        tabBarState[@"selectedIndex"] = @(selectedIndex);
        tabBarState[@"buttonCount"] = @(tabButtons.count);
    }
    
    // 分析视频播放状态
    if ([view isKindOfClass:NSClassFromString(@"AWEPlayer")] || 
        [view isKindOfClass:NSClassFromString(@"AWEPlayerPlayControlHandler")]) {
        videoState[@"isPlaying"] = @(isVideoPlaying);
        videoState[@"playerView"] = NSStringFromClass([view class]);
    }
    
    // 分析其他UI元素
    NSString *className = NSStringFromClass([view class]);
    if ([className hasPrefix:@"AWE"] || [className hasPrefix:@"Douyin"]) {
        uiElements[className] = @{
            @"frame": NSStringFromCGRect(view.frame),
            @"hidden": @(view.isHidden),
            @"alpha": @(view.alpha)
        };
    }
    
    // 递归分析子视图
    for (UIView *subview in view.subviews) {
        analyzeDouyinInterfaceElements(subview, buttons, tabBarState, videoState, uiElements);
    }
}

// 通知 SwiftUI 界面状态改变
static void DYYYNotifySwiftUIInterfaceChanged(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYInterfaceStateChanged" object:nil];
    });
}

// 设置视频播放状态
static inline void DYYYSetVideoPlayingState(BOOL playing) {
    isVideoPlaying = playing;
    NSLog(@"[DYYY] 视频播放状态: %@", playing ? @"播放中" : @"已停止");
    
    // 视频状态改变时更新界面信息
    if (DYYYIsLiquidGlassEnabled()) {
        DYYYCollectDouyinInterfaceInfo();
    }
}

// 实时界面变化响应 - 定时器触发
static void DYYYStartRealTimeInterfaceMonitoring(void) {
    if (!DYYYIsLiquidGlassEnabled()) return;

    // 确保仅一个定时器在运行
    static dispatch_once_t sObserverOnce;

    // 安装生命周期观察者：窗口切换/前后台/设置变更时，安全地启动或停止监控
    dispatch_once(&sObserverOnce, ^{
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification * _Nonnull note) {
            if (gDYYYLGTimer) { [gDYYYLGTimer invalidate]; gDYYYLGTimer = nil; }
        }];
        [nc addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification * _Nonnull note) {
            if (DYYYIsLiquidGlassEnabled() && !gDYYYLGTimer) { DYYYStartRealTimeInterfaceMonitoring(); }
        }];
        [nc addObserverForName:UIWindowDidResignKeyNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification * _Nonnull note) {
            if (gDYYYLGTimer) { [gDYYYLGTimer invalidate]; gDYYYLGTimer = nil; }
        }];
        [nc addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification * _Nonnull note) {
            if (DYYYIsLiquidGlassEnabled() && !gDYYYLGTimer) { DYYYStartRealTimeInterfaceMonitoring(); }
        }];
        [nc addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification * _Nonnull note) {
            if (!DYYYIsLiquidGlassEnabled()) {
                if (gDYYYLGTimer) { [gDYYYLGTimer invalidate]; gDYYYLGTimer = nil; }
            } else {
                if (!gDYYYLGTimer) { DYYYStartRealTimeInterfaceMonitoring(); }
            }
        }];
    });

    if (gDYYYLGTimer) return; // 已在运行

    // 创建定时器：每0.5秒检查一次界面变化（主线程 RunLoop）
    gDYYYLGTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(__kindof NSTimer * _Nonnull timer) {
        if (!DYYYIsLiquidGlassEnabled()) {
            DYYYStopLiquidGlassTimerIfNeeded();
            return;
        }

        // 在窗口切换等场景下，确保当前 keyWindow 存在再工作
        if (UIApplication.sharedApplication.keyWindow == nil) {
            return;
        }

        // 检查界面信息是否发生变化
        static NSDictionary *lastInterfaceInfo = nil;
        NSDictionary *currentInfo = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"DYYYInterfaceInfo"];
        if (![lastInterfaceInfo isEqual:currentInfo]) {
            lastInterfaceInfo = [currentInfo copy];
            DYYYCollectDouyinInterfaceInfo();
        }
    }];
}

// 判断是否应该应用 Liquid Glass
static inline BOOL DYYYShouldApplyLiquidGlass(void) {
    return DYYYIsLiquidGlassEnabled();
}

// 模糊效果相关函数
static void DYYYUpdateBlurEffectForTraitCollection(UIView *view, UITraitCollection *traitCollection);
static void DYYYOptimizeBlurViewPerformance(UIVisualEffectView *blurView);
static void DYYYUpdateBlurEffectForView(UIView *containerView, float transparency, BOOL isDarkMode);
static void DYYYRemoveBlurViewsWithTag(UIView *view, NSInteger tag);
static void DYYYConfigureSharedBlurAppearance(UIVisualEffectView *blurView, float transparency, BOOL isDarkMode);
static void DYYYSetupViewHierarchyForBlur(UIView *view, BOOL preserveSpecialViews);
static void DYYYEnhanceTextForBlurEffect(UIView *view, float transparency, BOOL isDarkMode);
static void DYYYApplyBlurEffect(UIView *view, float transparency);
static void DYYYSetViewsTransparent(UIView *view, BOOL skipSpecialViews);
static void DYYYAddCustomViewToParent(UIView *view, CGFloat transparency);
static void DYYYAddCustomViewToParent2(UIView *parentView, float transparency);
static void DYYYApplyCommentInputBlur(UIView *view);
static void DYYYSetViewsTransparentWithDepth(UIView *view, BOOL skipSpecialViews, int depth);
static void DYYYApplyBlurEffectSafely(UIView *view, float transparency);

// 配置共享模糊外观 - 按照 Apple 官方指导
static void DYYYConfigureSharedBlurAppearance(UIVisualEffectView *blurView, float transparency, BOOL isDarkMode) {
    blurView.alpha = transparency;
    blurView.layer.cornerRadius = 12.0;
    blurView.clipsToBounds = YES;
    
    // 使用 Apple 官方推荐的系统材质效果
    UIBlurEffect *blurEffect;
    if (@available(iOS 15.0, *)) {
        // iOS 15+ 使用系统材质
        if (isDarkMode) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
        } else {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        }
    } else {
        // iOS 15 以下降级到传统模糊效果
        if (isDarkMode) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        } else {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
    }
    
    blurView.effect = blurEffect;
}

// 为模糊效果设置视图层次结构 - 按照 Apple 官方指导
static void DYYYSetupViewHierarchyForBlur(UIView *view, BOOL preserveSpecialViews) {
    if (!view) return;
    
    // 移除现有的模糊视图
    DYYYRemoveBlurViewsWithTag(view, 99999);
    
    // 使用 Apple 官方推荐的系统材质效果
    UIBlurEffect *blurEffect;
    if (@available(iOS 15.0, *)) {
        // iOS 15+ 使用系统材质
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        // iOS 15 以下降级到传统模糊效果
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.tag = 99999;
    blurView.frame = view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [view insertSubview:blurView atIndex:0];
    
    // 优化性能
    DYYYOptimizeBlurViewPerformance(blurView);
}

// 为模糊效果增强文本
static void DYYYEnhanceTextForBlurEffect(UIView *view, float transparency, BOOL isDarkMode) {
    if (!view) return;
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.alpha = transparency;
            
            if (isDarkMode) {
                label.textColor = [UIColor whiteColor];
            } else {
                label.textColor = [UIColor blackColor];
            }
        } else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.alpha = transparency;
        }
        
        // 递归处理子视图
        DYYYEnhanceTextForBlurEffect(subview, transparency, isDarkMode);
    }
}

// 应用模糊效果
static void DYYYApplyBlurEffect(UIView *view, float transparency) {
    if (!view) return;
    
    BOOL isDarkMode = [DYYYManager isDarkMode];
    
    // 设置视图层次结构
    DYYYSetupViewHierarchyForBlur(view, YES);
    
    // 增强文本效果
    DYYYEnhanceTextForBlurEffect(view, transparency, isDarkMode);
    
    // 更新模糊效果
    DYYYUpdateBlurEffectForView(view, transparency, isDarkMode);
}

// 设置视图透明
static void DYYYSetViewsTransparent(UIView *view, BOOL skipSpecialViews) {
    if (!view) return;
    
    // 跳过特殊视图
    if (skipSpecialViews && view.tag == DYYY_IGNORE_GLOBAL_ALPHA_TAG) {
        return;
    }
    
    view.alpha = 0.3;
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        DYYYSetViewsTransparent(subview, skipSpecialViews);
    }
}

// 添加自定义视图到父视图
static void DYYYAddCustomViewToParent(UIView *view, CGFloat transparency) {
    if (!view) return;
    
    UIView *customView = [[UIView alloc] initWithFrame:view.bounds];
    customView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:transparency];
    customView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [view addSubview:customView];
}

// 添加自定义视图到父视图2
static void DYYYAddCustomViewToParent2(UIView *parentView, float transparency) {
    if (!parentView) return;
    
    UIView *overlayView = [[UIView alloc] initWithFrame:parentView.bounds];
    overlayView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:transparency];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlayView.userInteractionEnabled = NO;
    
    [parentView addSubview:overlayView];
}

// 应用评论输入模糊
static void DYYYApplyCommentInputBlur(UIView *view) {
    if (!view) return;
    
    // 创建模糊效果
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    blurView.frame = view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [view insertSubview:blurView atIndex:0];
}

// 更新模糊效果以适应特征集合 - 按照 Apple 官方指导
static void DYYYUpdateBlurEffectForTraitCollection(UIView *view, UITraitCollection *traitCollection) {
    if (!view) return;
    
    UIVisualEffectView *blurView = [view viewWithTag:99999];
    if (!blurView) return;
    
    BOOL isDarkMode = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    
    // 使用 Apple 官方推荐的系统材质效果
    UIBlurEffect *blurEffect;
    if (@available(iOS 15.0, *)) {
        // iOS 15+ 使用系统材质
        if (isDarkMode) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
        } else {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        }
    } else {
        // iOS 15 以下降级到传统模糊效果
        if (isDarkMode) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        } else {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
    }
    
    blurView.effect = blurEffect;
}

// 优化模糊视图性能
static void DYYYOptimizeBlurViewPerformance(UIVisualEffectView *blurView) {
    if (!blurView) return;
    
    blurView.layer.shouldRasterize = YES;
    blurView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    blurView.layer.opaque = NO;
}

// 更新视图的模糊效果
static void DYYYUpdateBlurEffectForView(UIView *containerView, float transparency, BOOL isDarkMode) {
    if (!containerView) return;
    
    UIVisualEffectView *blurView = [containerView viewWithTag:99999];
    if (blurView) {
        DYYYConfigureSharedBlurAppearance(blurView, transparency, isDarkMode);
    }
}

// 移除指定标签的模糊视图
static void DYYYRemoveBlurViewsWithTag(UIView *view, NSInteger tag) {
    if (!view) return;
    
    UIView *blurView = [view viewWithTag:tag];
    if (blurView) {
        [blurView removeFromSuperview];
    }
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        DYYYRemoveBlurViewsWithTag(subview, tag);
    }
}

// 设置视图透明（带深度限制）
static void DYYYSetViewsTransparentWithDepth(UIView *view, BOOL skipSpecialViews, int depth) {
    if (!view || depth <= 0) return;
    
    // 跳过特殊视图
    if (skipSpecialViews && view.tag == DYYY_IGNORE_GLOBAL_ALPHA_TAG) {
        return;
    }
    
    view.alpha = 0.3;
    
    // 递归处理子视图，减少深度
    for (UIView *subview in view.subviews) {
        DYYYSetViewsTransparentWithDepth(subview, skipSpecialViews, depth - 1);
    }
}

// 安全地应用模糊效果
static void DYYYApplyBlurEffectSafely(UIView *view, float transparency) {
    if (!view) return;
    
    @try {
        DYYYApplyBlurEffect(view, transparency);
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 应用模糊效果时出错: %@", exception.reason);
    }
}

// 前向声明
static UIVisualEffectView* DYYYCreateLiquidGlassEffect(UIView *parentView, BOOL isDarkMode);
void DYYYApplySafeLiquidGlassToTabBar(UIView *tabBar);

// 专门针对 AWENormalModeTabBar 的安全 Liquid Glass 效果 - 避免底部冲突
void DYYYApplyLiquidGlassToDouyinUI(UIView *targetView) {
    if (!targetView) return;
    
    // 安全检查：确保视图在主线程上
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DYYYApplyLiquidGlassToDouyinUI(targetView);
        });
        return;
    }
    
    // 安全检查：确保视图仍然有效
    if (targetView.window == nil) {
        NSLog(@"[DYYY] 视图已从窗口移除，跳过 Liquid Glass 应用");
        return;
    }
    
    // 特殊处理：检查是否是 AWENormalModeTabBar
    NSString *className = NSStringFromClass([targetView class]);
    BOOL isTabBar = [className isEqualToString:@"AWENormalModeTabBar"];
    
    if (isTabBar) {
        NSLog(@"[DYYY] 检测到 AWENormalModeTabBar，使用特殊的安全处理");
        DYYYApplySafeLiquidGlassToTabBar(targetView);
        return;
    }
    
    // 使用智能冲突解决机制
    if (!DYYYShouldApplyLiquidGlassWithConflictResolution(targetView)) {
        return;
    }
    
    // 检查是否已经应用过 Liquid Glass 效果
    UIView *existingEffect = [targetView viewWithTag:99997];
    if (existingEffect) {
        return; // 已应用过
    }
    
    // 临时禁用模糊效果，使用简单的半透明背景
    @try {
        UIView *liquidGlassView = [[UIView alloc] init];
        liquidGlassView.tag = 99997; // 抖音 UI Liquid Glass 效果标签
        liquidGlassView.frame = targetView.bounds;
        liquidGlassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        liquidGlassView.userInteractionEnabled = NO;
        
        // 使用简单的半透明背景代替模糊效果
        if (@available(iOS 13.0, *)) {
            BOOL isDarkMode = targetView.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            if (isDarkMode) {
                liquidGlassView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
            } else {
                liquidGlassView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
            }
        } else {
            liquidGlassView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
        }
        
        // 根据是否有透明功能冲突调整透明度
        if (DYYYHasTransparencyConflict()) {
            liquidGlassView.alpha = 0.6; // 降低透明度避免冲突
            NSLog(@"[DYYY] 检测到透明功能冲突，降低 Liquid Glass 透明度");
        } else {
            liquidGlassView.alpha = 0.9; // 正常透明度
        }
        
        // 智能插入位置：在背景视图之后，内容视图之前
        NSInteger insertIndex = 0;
        for (NSInteger i = 0; i < targetView.subviews.count; i++) {
            UIView *subview = targetView.subviews[i];
            // 查找背景相关的视图
            if ([subview isKindOfClass:[UIImageView class]] || 
                [subview isKindOfClass:[UIVisualEffectView class]]) {
                insertIndex = i + 1;
                break;
            }
        }
        
        [targetView insertSubview:liquidGlassView atIndex:insertIndex];
        
        NSLog(@"[DYYY] 已为抖音 UI 应用安全的 Liquid Glass 效果 (index: %ld, alpha: %.1f)", (long)insertIndex, liquidGlassView.alpha);
        
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 应用 Liquid Glass 效果时发生异常: %@", exception.reason);
    }
}

// 专门为 AWENormalModeTabBar 应用真正的 Liquid Glass 效果 - 按照 Apple 官方指导
void DYYYApplySafeLiquidGlassToTabBar(UIView *tabBar) {
    if (!tabBar) return;
    
    @try {
        // 检查是否已经应用过效果
        UIView *existingEffect = [tabBar viewWithTag:99996]; // 使用不同的标签避免冲突
        if (existingEffect) {
            return; // 已应用过
        }
        
        // 按照 Apple 官方指导：使用 UIVisualEffectView 配合 UIBlurEffect
        UIVisualEffectView *liquidGlassView = nil;
        
        if (@available(iOS 15.0, *)) {
            // iOS 15+ 使用系统材质效果 - Apple 官方推荐
            BOOL isDarkMode = tabBar.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            UIBlurEffect *blurEffect;
            
            if (isDarkMode) {
                // 深色模式：使用厚材质
                blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
            } else {
                // 浅色模式：使用超薄材质
                blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
            }
            
            liquidGlassView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            NSLog(@"[DYYY] 使用 iOS 15+ 系统材质效果创建 Liquid Glass");
        } else {
            // iOS 15 以下降级到传统模糊效果
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            liquidGlassView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            NSLog(@"[DYYY] 使用传统模糊效果创建 Liquid Glass");
        }
        
        if (!liquidGlassView) {
            NSLog(@"[DYYY] 错误：无法创建 UIVisualEffectView");
            return;
        }
        
        // 设置视图属性
        liquidGlassView.tag = 99996; // 标签栏专用标签
        liquidGlassView.frame = tabBar.bounds;
        liquidGlassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        liquidGlassView.userInteractionEnabled = NO;
        
        // 设置透明度 - 避免与底部系统冲突
        liquidGlassView.alpha = 0.8;
        
        // 添加圆角效果，增强悬浮感
        liquidGlassView.layer.cornerRadius = 12.0;
        liquidGlassView.layer.masksToBounds = YES;
        
        // 添加轻微的阴影效果
        liquidGlassView.layer.shadowColor = [UIColor blackColor].CGColor;
        liquidGlassView.layer.shadowOffset = CGSizeMake(0, -2);
        liquidGlassView.layer.shadowRadius = 4.0;
        liquidGlassView.layer.shadowOpacity = 0.1;
        
        // 优化性能
        liquidGlassView.layer.shouldRasterize = YES;
        liquidGlassView.layer.rasterizationScale = [UIScreen mainScreen].scale;
        
        // 插入到最底层，作为背景
        [tabBar insertSubview:liquidGlassView atIndex:0];
        
        NSLog(@"[DYYY] 已为 AWENormalModeTabBar 应用真正的 Liquid Glass 效果");
        
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 为标签栏应用 Liquid Glass 效果时发生异常: %@", exception.reason);
    }
}

// 高质量 Liquid Glass 效果创建 - 完全避免崩溃
static UIVisualEffectView* DYYYCreateLiquidGlassEffect(UIView *parentView, BOOL isDarkMode) {
    if (!parentView) return nil;
    
    @try {
        UIVisualEffect *effect = nil;
        
        // 使用经过验证的、稳定的系统材质效果
        if (@available(iOS 15.0, *)) {
            // 使用最稳定的系统材质效果
            if (isDarkMode) {
                effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
            } else {
                effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
            }
            NSLog(@"[DYYY] 使用稳定的 iOS 15+ 系统材质效果");
        }
        // iOS 15 以下使用传统模糊效果
        else {
            if (isDarkMode) {
                effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            } else {
                effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            }
            NSLog(@"[DYYY] 使用传统模糊效果 (iOS 15 以下)");
        }
        
        // 安全检查：确保效果创建成功
        if (!effect) {
            NSLog(@"[DYYY] 警告：无法创建模糊效果，使用备用方案");
            effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
        
        UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        
        // 安全检查：确保视图创建成功
        if (!visualEffectView) {
            NSLog(@"[DYYY] 错误：无法创建 UIVisualEffectView");
            return nil;
        }
        
        // 设置视图属性
        visualEffectView.frame = parentView.bounds;
        visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        visualEffectView.userInteractionEnabled = NO;
        visualEffectView.backgroundColor = [UIColor clearColor];
        
        // 优化性能
        DYYYOptimizeBlurViewPerformance(visualEffectView);
        
        NSLog(@"[DYYY] 成功创建 Liquid Glass 效果视图");
        return visualEffectView;
        
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 创建 Liquid Glass 效果时发生异常: %@", exception.reason);
        return nil;
    }
}

// 高质量动态切换 Liquid Glass 效果 - 完全避免崩溃
static void DYYYAnimateLiquidGlassChange(UIVisualEffectView *visualEffectView, BOOL isDarkMode) {
    if (!visualEffectView) return;
    
    @try {
        UIVisualEffect *newEffect = nil;
        
        // 使用经过验证的、稳定的系统材质效果
        if (@available(iOS 15.0, *)) {
            if (isDarkMode) {
                newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
            } else {
                newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
            }
            NSLog(@"[DYYY] 动态切换到稳定的 iOS 15+ 系统材质效果");
        }
        // iOS 15 以下使用传统模糊效果
        else {
            if (isDarkMode) {
                newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
            } else {
                newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            }
            NSLog(@"[DYYY] 动态切换到传统模糊效果");
        }
        
        // 安全检查：确保效果创建成功
        if (!newEffect) {
            NSLog(@"[DYYY] 警告：无法创建新的模糊效果，使用备用方案");
            newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
        
        // 安全检查：确保视图仍然有效
        if (visualEffectView.window == nil) {
            NSLog(@"[DYYY] 警告：视图已从窗口移除，跳过效果切换");
            return;
        }
        
        [UIView animateWithDuration:0.3 animations:^{
            visualEffectView.effect = newEffect;
        } completion:^(BOOL finished) {
            if (finished) {
                NSLog(@"[DYYY] 成功完成 Liquid Glass 效果切换");
            } else {
                NSLog(@"[DYYY] Liquid Glass 效果切换被中断");
            }
        }];
        
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 切换 Liquid Glass 效果时发生异常: %@", exception.reason);
    }
}

// 添加 UIView 类别方法声明
@interface UIView (DYYYMaterialEffects)
- (void)updateMaterialEffectsForTraitCollection:(UITraitCollection *)traitCollection;
@end

@implementation UIView (DYYYMaterialEffects)
- (void)updateMaterialEffectsForTraitCollection:(UITraitCollection *)traitCollection {
    if (!DYYYIsLiquidGlassEnabled()) return;
    
    // 检查是否是 AWENormalModeTabBar
    NSString *className = NSStringFromClass([self class]);
    BOOL isTabBar = [className isEqualToString:@"AWENormalModeTabBar"];
    
    // 查找并更新 Liquid Glass 效果视图 - 使用真正的 Liquid Glass 效果
    for (UIView *subview in self.subviews) {
        @try {
            BOOL isDarkMode = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            
            if (subview.tag == 99996 && isTabBar && [subview isKindOfClass:[UIVisualEffectView class]]) {
                // 标签栏专用 Liquid Glass 效果更新
                UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
                UIBlurEffect *newEffect = nil;
                
                if (@available(iOS 15.0, *)) {
                    // iOS 15+ 使用系统材质效果
                    if (isDarkMode) {
                        newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
                    } else {
                        newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
                    }
                } else {
                    // iOS 15 以下降级到传统模糊效果
                    newEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
                }
                
                if (newEffect) {
                    [UIView animateWithDuration:0.3 animations:^{
                        effectView.effect = newEffect;
                    }];
                    NSLog(@"[DYYY] 更新标签栏 Liquid Glass 主题效果");
                }
            }
            else if (subview.tag == 99997) {
                // 普通 UI 效果更新 - 使用简单背景
                if (isDarkMode) {
                    subview.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
                } else {
                    subview.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
                }
                NSLog(@"[DYYY] 更新普通 UI Liquid Glass 主题效果");
            }
        } @catch (NSException *exception) {
            NSLog(@"[DYYY] 更新主题效果时发生异常: %@", exception.reason);
        }
    }
}
@end

// Hook 实现 - 避免启动问题
%hook UIView

- (void)didMoveToSuperview {
    %orig;
    
    // 简化版本：只处理标签栏，避免启动时过度处理
    @try {
        if (DYYYIsLiquidGlassEnabled()) {
            NSString *className = NSStringFromClass([self class]);
            
            // 只处理标签栏，减少启动负担
            if ([className isEqualToString:@"AWENormalModeTabBar"]) {
                [DYYYUtils dispatchAfter:0.5 owner:self block:^{
                    @try {
                        if (![UIApplication sharedApplication].keyWindow) return;
                        if (self.window != [UIApplication sharedApplication].keyWindow) return;
                        if (DYYYShouldApplyLiquidGlassWithConflictResolution(self)) {
                            DYYYApplyLiquidGlassToDouyinUI(self);
                            NSLog(@"[DYYY] 为标签栏应用 Liquid Glass 效果");
                        }
                    } @catch (NSException *exception) {
                        NSLog(@"[DYYY] 应用 Liquid Glass 时出错: %@", exception.reason);
                    }
                }];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] Hook didMoveToSuperview 时出错: %@", exception.reason);
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    
    // 简化版本：减少主题变化处理
    @try {
        if (DYYYIsLiquidGlassEnabled()) {
            UITraitCollection *currentTraitCollection = self.traitCollection;
            if (currentTraitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
                [DYYYUtils dispatchAfter:0.3 owner:self block:^{
                    @try {
                        if (![UIApplication sharedApplication].keyWindow) return;
                        if (self.window != [UIApplication sharedApplication].keyWindow) return;
                        [self updateMaterialEffectsForTraitCollection:currentTraitCollection];
                    } @catch (NSException *exception) {
                        NSLog(@"[DYYY] 更新主题效果时出错: %@", exception.reason);
                    }
                }];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] Hook traitCollectionDidChange 时出错: %@", exception.reason);
    }
}

%end