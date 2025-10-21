//
//  FLEXManager+Extensibility.m
//  FLEX
//
//  Created by Tanner on 2/2/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXManager+Extensibility.h"
#import "FLEXManager+Private.h"
#import "FLEXNavigationController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXKeyboardShortcutManager.h"
#import "FLEXExplorerViewController.h"
#import "FLEXNetworkMITMViewController.h"
#import "FLEXKeyboardHelpViewController.h"
#import "FLEXFileBrowserController.h"
#import "FLEXArgumentInputStructView.h"
#import "FLEXUtility.h"

@interface FLEXManager (ExtensibilityPrivate)
@property (nonatomic, readonly) UIViewController *topViewController;
@end

@implementation FLEXManager (Extensibility)

#pragma mark - 全局屏幕条目

- (void)registerGlobalEntryWithName:(NSString *)entryName objectFutureBlock:(id (^)(void))objectFutureBlock {
    NSParameterAssert(entryName);
    NSParameterAssert(objectFutureBlock);
    NSAssert(NSThread.isMainThread, @"此方法必须从主线程调用。");

    entryName = entryName.copy;
    FLEXGlobalsEntry *entry = [FLEXGlobalsEntry entryWithNameFuture:^NSString *{
        return entryName;
    } viewControllerFuture:^UIViewController *{
        return [FLEXObjectExplorerFactory explorerViewControllerForObject:objectFutureBlock()];
    }];

    [self.userGlobalEntries addObject:entry];
}

- (void)registerGlobalEntryWithName:(NSString *)entryName viewControllerFutureBlock:(UIViewController * (^)(void))viewControllerFutureBlock {
    NSParameterAssert(entryName);
    NSParameterAssert(viewControllerFutureBlock);
    NSAssert(NSThread.isMainThread, @"此方法必须从主线程调用。");

    entryName = entryName.copy;
    FLEXGlobalsEntry *entry = [FLEXGlobalsEntry entryWithNameFuture:^NSString *{
        return entryName;
    } viewControllerFuture:^UIViewController *{
        UIViewController *viewController = viewControllerFutureBlock();
        NSCAssert(viewController, @"'%@' 条目返回了空的 viewController。viewControllerFutureBlock 不应返回 nil。", entryName);
        return viewController;
    }];

    [self.userGlobalEntries addObject:entry];
}

- (void)registerGlobalEntryWithName:(NSString *)entryName action:(FLEXGlobalsEntryRowAction)rowSelectedAction {
    NSParameterAssert(entryName);
    NSParameterAssert(rowSelectedAction);
    NSAssert(NSThread.isMainThread, @"此方法必须从主线程调用。");
    
    entryName = entryName.copy;
    FLEXGlobalsEntry *entry = [FLEXGlobalsEntry entryWithNameFuture:^NSString * _Nonnull{
        return entryName;
    } action:rowSelectedAction];
    
    [self.userGlobalEntries addObject:entry];
}

- (void)clearGlobalEntries {
    [self.userGlobalEntries removeAllObjects];
}


#pragma mark - 编辑

+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding {
    [FLEXArgumentInputStructView registerFieldNames:names forTypeEncoding:typeEncoding];
}


#pragma mark - 模拟器快捷键

- (void)registerSimulatorShortcutWithKey:(NSString *)key modifiers:(UIKeyModifierFlags)modifiers action:(dispatch_block_t)action description:(NSString *)description {
#if TARGET_OS_SIMULATOR
    [FLEXKeyboardShortcutManager.sharedManager registerSimulatorShortcutWithKey:key modifiers:modifiers action:action description:description allowOverride:YES];
#endif
}

- (void)setSimulatorShortcutsEnabled:(BOOL)simulatorShortcutsEnabled {
#if TARGET_OS_SIMULATOR
    [FLEXKeyboardShortcutManager.sharedManager setEnabled:simulatorShortcutsEnabled];
#endif
}

- (BOOL)simulatorShortcutsEnabled {
#if TARGET_OS_SIMULATOR
    return FLEXKeyboardShortcutManager.sharedManager.isEnabled;
#else
    return NO;
#endif
}


#pragma mark - 快捷键默认设置

- (void)registerDefaultSimulatorShortcutWithKey:(NSString *)key modifiers:(UIKeyModifierFlags)modifiers action:(dispatch_block_t)action description:(NSString *)description {
#if TARGET_OS_SIMULATOR
    // 不允许覆盖，以避免更改应用程序注册的键
    [FLEXKeyboardShortcutManager.sharedManager registerSimulatorShortcutWithKey:key modifiers:modifiers action:action description:description allowOverride:NO];
#endif
}

- (void)registerDefaultSimulatorShortcuts {
    [self registerDefaultSimulatorShortcutWithKey:@"f" modifiers:0 action:^{
        [self toggleExplorer];
    } description:@"切换FLEX工具栏"];

    [self registerDefaultSimulatorShortcutWithKey:@"g" modifiers:0 action:^{
        [self showExplorerIfNeeded];
        [self.explorerViewController toggleMenuTool];
    } description:@"切换FLEX全局菜单"];

    [self registerDefaultSimulatorShortcutWithKey:@"v" modifiers:0 action:^{
        [self showExplorerIfNeeded];
        [self.explorerViewController toggleViewsTool];
    } description:@"切换视图层次结构菜单"];

    [self registerDefaultSimulatorShortcutWithKey:@"s" modifiers:0 action:^{
        [self showExplorerIfNeeded];
        [self.explorerViewController toggleSelectTool];
    } description:@"切换选择工具"];

    [self registerDefaultSimulatorShortcutWithKey:@"m" modifiers:0 action:^{
        [self showExplorerIfNeeded];
        [self.explorerViewController toggleMoveTool];
    } description:@"切换移动工具"];

    [self registerDefaultSimulatorShortcutWithKey:@"n" modifiers:0 action:^{
        [self toggleTopViewControllerOfClass:[FLEXNetworkMITMViewController class]];
    } description:@"切换网络历史视图"];

    [self registerDefaultSimulatorShortcutWithKey:UIKeyInputDownArrow modifiers:0 action:^{
        if (self.isHidden || ![self.explorerViewController handleDownArrowKeyPressed]) {
            [self tryScrollDown];
        }
    } description:@"循环选择视图\n\t\t向下移动视图\n\t\t向下滚动"];

    [self registerDefaultSimulatorShortcutWithKey:UIKeyInputUpArrow modifiers:0 action:^{
        if (self.isHidden || ![self.explorerViewController handleUpArrowKeyPressed]) {
            [self tryScrollUp];
        }
    } description:@"循环选择视图\n\t\t向上移动视图\n\t\t向上滚动"];

    [self registerDefaultSimulatorShortcutWithKey:UIKeyInputRightArrow modifiers:0 action:^{
        if (!self.isHidden) {
            [self.explorerViewController handleRightArrowKeyPressed];
        }
    } description:@"向右移动选中视图"];

    [self registerDefaultSimulatorShortcutWithKey:UIKeyInputLeftArrow modifiers:0 action:^{
        if (self.isHidden) {
            [self tryGoBack];
        } else {
            [self.explorerViewController handleLeftArrowKeyPressed];
        }
    } description:@"向左移动选中视图"];

    [self registerDefaultSimulatorShortcutWithKey:@"?" modifiers:0 action:^{
        [self toggleTopViewControllerOfClass:[FLEXKeyboardHelpViewController class]];
    } description:@"切换（当前）帮助菜单"];

    [self registerDefaultSimulatorShortcutWithKey:UIKeyInputEscape modifiers:0 action:^{
        [[self.topViewController presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    } description:@"结束文本编辑\n\t\t关闭顶部视图控制器"];

    [self registerDefaultSimulatorShortcutWithKey:@"o" modifiers:UIKeyModifierCommand|UIKeyModifierShift action:^{
        [self toggleTopViewControllerOfClass:[FLEXFileBrowserController class]];
    } description:@"切换文件浏览器菜单"];
}

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sharedManager registerDefaultSimulatorShortcuts];
    });
}


#pragma mark - 私有方法

- (UIEdgeInsets)contentInsetsOfScrollView:(UIScrollView *)scrollView {
    if (@available(iOS 11, *)) {
        return scrollView.adjustedContentInset;
    }

    return scrollView.contentInset;
}

- (void)tryScrollDown {
    UIScrollView *scrollview = [self firstScrollView];
    UIEdgeInsets insets = [self contentInsetsOfScrollView:scrollview];
    CGPoint contentOffset = scrollview.contentOffset;
    CGFloat maxYOffset = scrollview.contentSize.height - scrollview.bounds.size.height + insets.bottom;
    contentOffset.y = MIN(contentOffset.y + 200, maxYOffset);
    [scrollview setContentOffset:contentOffset animated:YES];
}

- (void)tryScrollUp {
    UIScrollView *scrollview = [self firstScrollView];
    UIEdgeInsets insets = [self contentInsetsOfScrollView:scrollview];
    CGPoint contentOffset = scrollview.contentOffset;
    contentOffset.y = MAX(contentOffset.y - 200, -insets.top);
    [scrollview setContentOffset:contentOffset animated:YES];
}

- (UIScrollView *)firstScrollView {
    NSMutableArray<UIView *> *views = FLEXUtility.appKeyWindow.subviews.mutableCopy;
    UIScrollView *scrollView = nil;
    while (views.count > 0) {
        UIView *view = views.firstObject;
        [views removeObjectAtIndex:0];
        if ([view isKindOfClass:[UIScrollView class]]) {
            scrollView = (UIScrollView *)view;
            break;
        } else {
            [views addObjectsFromArray:view.subviews];
        }
    }
    return scrollView;
}

- (void)tryGoBack {
    UINavigationController *navigationController = nil;
    UIViewController *topViewController = self.topViewController;
    if ([topViewController isKindOfClass:[UINavigationController class]]) {
        navigationController = (UINavigationController *)topViewController;
    } else {
        navigationController = topViewController.navigationController;
    }
    [navigationController popViewControllerAnimated:YES];
}

- (UIViewController *)topViewController {
    return [FLEXUtility topViewControllerInWindow:UIApplication.sharedApplication.keyWindow];
}

- (void)toggleTopViewControllerOfClass:(Class)class {
    UINavigationController *topViewController = (id)self.topViewController;
    if ([topViewController isKindOfClass:[FLEXNavigationController class]]) {
        if ([topViewController.topViewController isKindOfClass:[class class]]) {
            if (topViewController.viewControllers.count == 1) {
                // 因为已经在显示它，所以关闭
                [topViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
            } else {
                // 弹出，因为我们正在查看它，但它不是栈上唯一的内容
                [topViewController popViewControllerAnimated:YES];
            }
        } else {
            // 将其推送到现有导航栈中
            [topViewController pushViewController:[class new] animated:YES];
        }
    } else {
        // 在全新的导航控制器中呈现它
        [self.explorerViewController presentViewController:
            [FLEXNavigationController withRootViewController:[class new]]
        animated:YES completion:nil];
    }
}

- (void)showExplorerIfNeeded {
    if (self.isHidden) {
        [self showExplorer];
    }
}

@end
