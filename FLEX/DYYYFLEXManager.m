//
//  DYYYFLEXManager.m
//  Flipboard
//
//  Created by Ryan Olson on 4/4/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXManager.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXExplorerViewController.h"
#import "DYYYFLEXWindow.h"
#import "DYYYFLEXNavigationController.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXFileBrowserController.h"
#import "DYYYFLEXManager+DoKitExtensions.h"

@interface DYYYFLEXManager () <FLEXWindowEventDelegate, FLEXExplorerViewControllerDelegate>

@property (nonatomic, readonly, getter=isHidden) BOOL hidden;

@property (nonatomic) DYYYFLEXWindow *explorerWindow;
@property (nonatomic) DYYYFLEXExplorerViewController *explorerViewController;

@property (nonatomic, readonly) NSMutableArray<DYYYFLEXGlobalsEntry *> *userGlobalEntries;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, FLEXCustomContentViewerFuture> *customContentTypeViewers;

@end

@implementation DYYYFLEXManager

+ (instancetype)sharedManager {
    static DYYYFLEXManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [self new];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userGlobalEntries = [NSMutableArray new];
        _customContentTypeViewers = [NSMutableDictionary new];
        
        // 注册 DoKit 增强功能
        [self registerDoKitEnhancements];
    }
    return self;
}

- (DYYYFLEXWindow *)explorerWindow {
    NSAssert(NSThread.isMainThread, @"您必须只从主线程使用 %@。", NSStringFromClass([self class]));
    
    if (!_explorerWindow) {
        _explorerWindow = [[DYYYFLEXWindow alloc] initWithFrame:DYYYFLEXUtility.appKeyWindow.bounds];
        _explorerWindow.eventDelegate = self;
        _explorerWindow.rootViewController = self.explorerViewController;
    }
    
    return _explorerWindow;
}

- (DYYYFLEXExplorerViewController *)explorerViewController {
    if (!_explorerViewController) {
        _explorerViewController = [DYYYFLEXExplorerViewController new];
        _explorerViewController.delegate = self;
    }

    return _explorerViewController;
}

- (void)showExplorer {
    UIWindow *flex = self.explorerWindow;
    flex.hidden = NO;
    if (@available(iOS 13.0, *)) {
        // 只有当我们没有场景时才寻找新场景
        if (!flex.windowScene) {
            flex.windowScene = DYYYFLEXUtility.appKeyWindow.windowScene;
        }
    }
}

- (void)hideExplorer {
    self.explorerWindow.hidden = YES;
}

- (void)toggleExplorer {
    if (self.explorerWindow.isHidden) {
        if (@available(iOS 13.0, *)) {
            [self showExplorerFromScene:DYYYFLEXUtility.appKeyWindow.windowScene];
        } else {
            [self showExplorer];
        }
    } else {
        [self hideExplorer];
    }
}

- (void)dismissAnyPresentedTools:(void (^)(void))completion {
    if (self.explorerViewController.presentedViewController) {
        [self.explorerViewController dismissViewControllerAnimated:YES completion:completion];
    } else if (completion) {
        completion();
    }
}

- (void)presentTool:(UINavigationController * _Nonnull (^)(void))future completion:(void (^)(void))completion {
    [self showExplorer];
    [self.explorerViewController presentTool:future completion:completion];
}

- (void)presentEmbeddedTool:(UIViewController *)tool completion:(void (^)(UINavigationController *))completion {
    DYYYFLEXNavigationController *nav = [DYYYFLEXNavigationController withRootViewController:tool];
    [self presentTool:^UINavigationController *{
        return nav;
    } completion:^{
        if (completion) completion(nav);
    }];
}

- (void)presentObjectExplorer:(id)object completion:(void (^)(UINavigationController *))completion {
    UIViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:object];
    [self presentEmbeddedTool:explorer completion:completion];
}

- (void)showExplorerFromScene:(UIWindowScene *)scene {
    if (@available(iOS 13.0, *)) {
        self.explorerWindow.windowScene = scene;
    }
    self.explorerWindow.hidden = NO;
}

- (BOOL)isHidden {
    return self.explorerWindow.isHidden;
}

- (DYYYFLEXExplorerToolbar *)toolbar {
    return self.explorerViewController.explorerToolbar;
}


#pragma mark - FLEXWindowEventDelegate

- (BOOL)shouldHandleTouchAtPoint:(CGPoint)pointInWindow {
    // 询问资源管理器视图控制器
    return [self.explorerViewController shouldReceiveTouchAtWindowPoint:pointInWindow];
}

- (BOOL)canBecomeKeyWindow {
    // 只有当资源管理器视图控制器需要它时
    // 它需要接受按键输入并影响状态栏
    return self.explorerViewController.wantsWindowToBecomeKey;
}


#pragma mark - FLEXExplorerViewControllerDelegate

- (void)explorerViewControllerDidFinish:(DYYYFLEXExplorerViewController *)explorerViewController {
    [self hideExplorer];
}

@end
