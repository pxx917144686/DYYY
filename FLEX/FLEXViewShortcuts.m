// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXViewShortcuts.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/11/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXViewShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXImagePreviewViewController.h"
#import "FLEXUtility.h"

@interface FLEXViewShortcuts ()
@property (nonatomic, readonly) UIView *view;
@end

@implementation FLEXViewShortcuts

#pragma mark - 内部

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


#pragma mark - 覆盖

+ (instancetype)forObject:(UIView *)view {
    // 过去，FLEX 不会对此类对象持有强引用。
    // 在长时间使用 FLEX 之后，我确信更积极地引用像视图控制器这样有用的东西会更有用，
    // 这样引用就不会丢失并在您访问它之前被清除。
    //
    // 这里的替代方案是使用 future 来代替 `controller`，它会动态获取对视图控制器的引用。
    // 然而，99% 的情况下，这并不是那么有用。如果您需要刷新它，
    // 您只需返回然后再前进，如果视图控制器为 nil 或已更改，它就会显示出来。
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
        [FLEXActionShortcut title:@"预览视图" subtitle:^NSString *(UIView *view) {
                return !CGRectIsEmpty(view.bounds) ? @"" : @"边界为空时不可用";
            }
            viewer:^UIViewController *(UIView *view) {
                return [FLEXImagePreviewViewController previewForView:view];
            }
            accessoryType:^UITableViewCellAccessoryType(UIView *view) {
                // 如果边界为 CGRectZero，则禁用预览
                return !CGRectIsEmpty(view.bounds) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            }
        ],
        [FLEXActionShortcut title:@"预览背景色" subtitle:^NSString *(UIView *view) {
            return view.backgroundColor ? @"包含背景色" : nil;
        } viewer:^UIViewController *(UIView *view) {
            UIImage *image = [FLEXUtility previewImageForView:view];
            if (image) {
                return [FLEXImagePreviewViewController forImage:image];
            }
            return nil;
        } accessoryType:^UITableViewCellAccessoryType(UIView *view) {
            return view.backgroundColor ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        }]
    ]];
}

@end
