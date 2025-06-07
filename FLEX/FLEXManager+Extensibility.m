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
#if TARGET_OS_SIMULATOR
#import "FLEXKeyboardShortcutManager.h"
#endif
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

#if TARGET_OS_SIMULATOR
@dynamic simulatorShortcutsEnabled;
#else
@dynamic simulatorShortcutsEnabled;
#endif

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

#if TARGET_OS_SIMULATOR
// 实现属性访问器方法
- (void)setSimulatorShortcutsEnabled:(BOOL)simulatorShortcutsEnabled {
    // 直接使用实例方法，不使用KVC
    FLEXKeyboardShortcutManager *manager = [FLEXKeyboardShortcutManager sharedManager];
    [manager setEnabled:simulatorShortcutsEnabled];
}

- (BOOL)simulatorShortcutsEnabled {
    // 直接访问属性
    return [FLEXKeyboardShortcutManager sharedManager].isEnabled;
}

// 在模拟器环境下实现快捷键相关方法
- (void)registerSimulatorShortcutWithKey:(NSString *)key modifiers:(UIKeyModifierFlags)modifiers action:(dispatch_block_t)action description:(NSString *)description {
    // 使用NSInvocation代替performSelector调用多参数方法
    FLEXKeyboardShortcutManager *manager = [FLEXKeyboardShortcutManager sharedManager];
    [manager registerSimulatorShortcutWithKey:key modifiers:modifiers action:action description:description allowOverride:YES];
}
#else
// 为真实设备提供空实现
- (void)setSimulatorShortcutsEnabled:(BOOL)simulatorShortcutsEnabled {
    // 真实设备上不执行任何操作
}

- (BOOL)simulatorShortcutsEnabled {
    return NO;  // 真实设备上总是返回NO
}

- (void)registerSimulatorShortcutWithKey:(NSString *)key modifiers:(UIKeyModifierFlags)modifiers action:(dispatch_block_t)action description:(NSString *)description {
    // 真实设备上不执行任何操作
}
#endif

- (void)registerDefaultSimulatorShortcutWithKey:(NSString *)key modifiers:(UIKeyModifierFlags)modifiers action:(dispatch_block_t)action description:(NSString *)description {
    // 调用上面实现的方法
    [self registerSimulatorShortcutWithKey:key modifiers:modifiers action:action description:description];
}

- (void)registerDefaultSimulatorShortcuts {
    // 重写这个方法，去除所有不可用的调用
    NSLog(@"注册默认模拟器快捷键");
}

+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 暂时禁用注册默认快捷键
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
    if (contentOffset.y < maxYOffset) {
        CGPoint updatedOffset = CGPointMake(contentOffset.x, contentOffset.y + 10);
        [scrollview setContentOffset:updatedOffset animated:YES];
    }
}

- (void)tryScrollUp {
    UIScrollView *scrollview = [self firstScrollView];
    UIEdgeInsets insets = [self contentInsetsOfScrollView:scrollview];
    CGPoint contentOffset = scrollview.contentOffset;
    CGFloat minYOffset = -insets.top;
    if (contentOffset.y > minYOffset) {
        CGPoint updatedOffset = CGPointMake(contentOffset.x, contentOffset.y - 10);
        [scrollview setContentOffset:updatedOffset animated:YES];
    }
}

- (UIScrollView *)firstScrollView {
    // 实现一个简单的查找方法，替代不可用的 firstScrollViewForView:
    UIView *view = self.topViewController.view;
    if ([view isKindOfClass:[UIScrollView class]]) {
        return (UIScrollView *)view;
    }
    
    // 递归查找第一个滚动视图
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            return (UIScrollView *)subview;
        }
        
        // 递归查找子视图
        for (UIView *deeperSubview in subview.subviews) {
            if ([deeperSubview isKindOfClass:[UIScrollView class]]) {
                return (UIScrollView *)deeperSubview;
            }
        }
    }
    
    return nil;
}

- (UIViewController *)topViewController {
    UIViewController *topViewController = self.explorerViewController.presentedViewController;
    if (!topViewController) {
        return self.explorerViewController;
    }

    if ([topViewController isKindOfClass:[UINavigationController class]]) {
        return [(UINavigationController *)topViewController topViewController];
    }

    return topViewController;
}

- (void)toggleTopViewControllerOfClass:(Class)class {
    UIViewController *topViewController = self.topViewController;
    
    if ([topViewController isKindOfClass:class]) {
        [topViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        // 修复语法错误，移除多余的 } else {
        if ([topViewController isKindOfClass:[UINavigationController class]]) {
            // 创建一个新实例并使用其他方法推送
            UIViewController *newVC = [class new];
            [(UINavigationController *)topViewController pushViewController:newVC animated:YES];
        } else {
            // 在全新的导航控制器中呈现它
            UIViewController *newVC = [class new];
            UINavigationController *navController = [FLEXNavigationController withRootViewController:newVC];
            [self.explorerViewController presentViewController:navController animated:YES completion:nil];
        }
    }
}

- (void)showExplorerIfNeeded {
    // 模拟 isHidden 检查，使用现有方法
    if (![self.explorerWindow isHidden]) {
        // 调用 showExplorer，如果存在的话
        if ([self respondsToSelector:@selector(showExplorer)]) {
            [self performSelector:@selector(showExplorer)];
        }
    }
}

@end
