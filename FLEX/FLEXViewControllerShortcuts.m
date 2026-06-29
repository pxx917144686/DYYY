//
//  FLEXViewControllerShortcuts.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/12/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXViewControllerShortcuts.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"

@interface FLEXViewControllerShortcuts ()
@end

@implementation FLEXViewControllerShortcuts

#pragma mark - 重写

+ (instancetype)forObject:(UIViewController *)viewController {
    BOOL (^vcIsInuse)(UIViewController *) = ^BOOL(UIViewController *controller) {
        if (controller.viewIfLoaded.window) {
            return YES;
        }

        return controller.navigationController != nil;
    };
    
    return [self forObject:viewController additionalRows:@[
        [FLEXActionShortcut title:@"进入视图控制器"
            subtitle:^NSString *(UIViewController *controller) {
                return vcIsInuse(controller) ? @"正在使用中，无法进入" : nil;
            }
            selectionHandler:^void(UIViewController *host, UIViewController *controller) {
                if (!vcIsInuse(controller)) {
                    [host.navigationController pushViewController:controller animated:YES];
                } else {
                    [FLEXAlert
                        showAlert:@"无法进入视图控制器"
                        message:@"此视图控制器的视图当前正在使用中。"
                        from:host
                    ];
                }
            }
            accessoryType:^UITableViewCellAccessoryType(UIViewController *controller) {
                if (!vcIsInuse(controller)) {
                    return UITableViewCellAccessoryDisclosureIndicator;
                } else {
                    return UITableViewCellAccessoryNone;
                }
            }
        ]
    ]];
}

@end
