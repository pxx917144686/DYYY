//
//  FLEXViewControllerShortcuts.m
//  FLEX
//
//  Created by Tanner Bennett on 12/12/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXViewControllerShortcuts.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"


@interface FLEXViewControllerShortcuts ()
@end

@implementation FLEXViewControllerShortcuts

#pragma mark - Overrides

+ (instancetype)forObject:(UIViewController *)viewController {
    BOOL (^vcIsInuse)(UIViewController *) = ^BOOL(UIViewController *controller) {
        if (controller.viewIfLoaded.window) {
            return YES;
        }

        return controller.navigationController != nil;
    };
    
    return [self forObject:viewController additionalRows:@[
        [FLEXActionShortcut title:@"推送视图控制器"
            subtitle:^NSString *(UIViewController *controller) {
                return vcIsInuse(controller) ? @"正在使用，无法推送" : nil;
            }
            selectionHandler:^void(UIViewController *host, UIViewController *controller) {
                if (!vcIsInuse(controller)) {
                    [host.navigationController pushViewController:controller animated:YES];
                } else {
                    [FLEXAlert
                        showAlert:@"无法推送视图控制器"
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
