//
//  FLEXUIAppShortcuts.m
//  FLEX
//
//  由 Tanner 创建于 5/25/20.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXUIAppShortcuts.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"

@implementation FLEXUIAppShortcuts

#pragma mark - 重写

+ (instancetype)forObject:(UIApplication *)application {
    return [self forObject:application additionalRows:@[
        [FLEXActionShortcut title:@"打开 URL…"
            subtitle:^NSString *(UIViewController *controller) {
                return nil;
            }
            selectionHandler:^void(UIViewController *host, UIApplication *app) {
                [FLEXAlert makeAlert:^(FLEXAlert *make) {
                    make.title(@"打开 URL");
                    make.message(
                        @"这将调用 openURL: 或 openURL:options:completion: "
                         "并使用下面的字符串。'仅当通用链接时打开'选项只会在 "
                         "该 URL 是已注册的通用链接时才打开。"
                    );
                    
                    make.textField(@"twitter://user?id=12345");
                    make.button(@"打开").handler(^(NSArray<NSString *> *strings) {
                        [self openURL:strings[0] inApp:app onlyIfUniveral:NO host:host];
                    });
                    make.button(@"仅当通用链接时打开").handler(^(NSArray<NSString *> *strings) {
                        [self openURL:strings[0] inApp:app onlyIfUniveral:YES host:host];
                    });
                    make.button(@"取消").cancelStyle();
                } showFrom:host];
            }
            accessoryType:^UITableViewCellAccessoryType(UIViewController *controller) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ]
    ]];
}

+ (void)openURL:(NSString *)urlString
          inApp:(UIApplication *)app
 onlyIfUniveral:(BOOL)universalOnly
           host:(UIViewController *)host {
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (url) {
        if (@available(iOS 10, *)) {
            [app openURL:url options:@{
                UIApplicationOpenURLOptionUniversalLinksOnly: @(universalOnly)
            } completionHandler:^(BOOL success) {
                if (!success) {
                    [FLEXAlert showAlert:@"没有通用链接处理程序"
                        message:@"没有已安装的应用程序注册处理此链接。"
                        from:host
                    ];
                }
            }];
        } else {
            [app openURL:url];
        }
    } else {
        [FLEXAlert showAlert:@"错误" message:@"无效的 URL" from:host];
    }
}

@end

