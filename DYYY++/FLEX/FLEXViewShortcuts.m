//
//  FLEXViewShortcuts.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/11/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXViewShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXImagePreviewViewController.h"

@interface FLEXViewShortcuts ()
@property (nonatomic, readonly) UIView *view;
@end

@implementation FLEXViewShortcuts

#pragma mark - 内部方法

- (UIView *)view {
    return self.object;
}

+ (UIViewController *)viewControllerForView:(UIView *)view {
    NSString *viewDelegate = @"viewDelegate";
    if ([view respondsToSelector:NSSelectorFromString(viewDelegate)]) {
        return [view valueForKey:viewDelegate];
    }

    return nil;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view {
    NSString *_viewControllerForAncestor = @"_viewControllerForAncestor";
    if ([view respondsToSelector:NSSelectorFromString(_viewControllerForAncestor)]) {
        return [view valueForKey:_viewControllerForAncestor];
    }

    return nil;
}

+ (UIViewController *)nearestViewControllerForView:(UIView *)view {
    return [self viewControllerForView:view] ?: [self viewControllerForAncestralView:view];
}


#pragma mark - 重写

+ (instancetype)forObject:(UIView *)view {
    // 在过去，FLEX 不会对这样的东西保持强引用。
    // 在使用 FLEX 很长时间后，我确信更积极地引用视图控制器这样
    // 有用的东西更为实用，这样在您访问它之前引用就不会丢失和被清除。
    //
    // 这里的替代方案是使用 future 来代替 `controller`，这将动态地
    // 获取对视图控制器的引用。然而，99% 的情况下，这并不是很有用。
    // 如果您需要刷新，您可以简单地返回再前进，它将显示视图控制器
    // 是否为 nil 或已更改。
    UIViewController *controller = [FLEXViewShortcuts nearestViewControllerForView:view];

    return [self forObject:view additionalRows:@[
        [FLEXActionShortcut title:@"最近的视图控制器"
            subtitle:^NSString *(id view) {
                return [FLEXRuntimeUtility safeDescriptionForObject:controller];
            }
            viewer:^UIViewController *(id view) {
                return [FLEXObjectExplorerFactory explorerViewControllerForObject:controller];
            }
            accessoryType:^UITableViewCellAccessoryType(id view) {
                return controller ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            }
        ],
        [FLEXActionShortcut title:@"预览图像" subtitle:^NSString *(UIView *view) {
                return !CGRectIsEmpty(view.bounds) ? @"" : @"空边界时不可用";
            }
            viewer:^UIViewController *(UIView *view) {
                return [FLEXImagePreviewViewController previewForView:view];
            }
            accessoryType:^UITableViewCellAccessoryType(UIView *view) {
                // 如果边界是 CGRectZero 则禁用预览
                return !CGRectIsEmpty(view.bounds) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            }
        ]
    ]];
}

@end
