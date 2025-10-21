//
//  FLEXBundleShortcuts.m
//  FLEX
//
//  由 Tanner Bennett 于 12/12/19 创建.
//  版权所有 © 2020 FLEX Team. 保留所有权利.
//

#import "FLEXBundleShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"
#import "FLEXMacros.h"
#import "FLEXRuntimeExporter.h"
#import "FLEXTableListViewController.h"
#import "FLEXFileBrowserController.h"

#pragma mark -
@implementation FLEXBundleShortcuts
#pragma mark 重写

+ (instancetype)forObject:(NSBundle *)bundle { weakify(self)
    return [self forObject:bundle additionalRows:@[
        [FLEXActionShortcut
            title:@"浏览包目录" subtitle:nil
            viewer:^UIViewController *(NSBundle *bundle) {
                return [FLEXFileBrowserController path:bundle.bundlePath];
            }
            accessoryType:^UITableViewCellAccessoryType(NSBundle *bundle) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
        [FLEXActionShortcut title:@"以数据库形式浏览包…" subtitle:nil
            selectionHandler:^(UIViewController *host, NSBundle *bundle) { strongify(self)
                [self promptToExportBundleAsDatabase:bundle host:host];
            }
            accessoryType:^UITableViewCellAccessoryType(NSBundle *bundle) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
    ]];
}

+ (void)promptToExportBundleAsDatabase:(NSBundle *)bundle host:(UIViewController *)host {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"另存为…").message(
            @"数据库将保存在库文件夹中。"
            "根据类的数量，导出可能需要"
            "10分钟或更长时间。20,000个"
            "类大约需要7分钟。"
        );
        make.configuredTextField(^(UITextField *field) {
            field.placeholder = @"FLEXRuntimeExport.objc.db";
            field.text = [NSString stringWithFormat:
                @"%@.objc.db", bundle.executablePath.lastPathComponent
            ];
        });
        make.button(@"开始").handler(^(NSArray<NSString *> *strings) {
            [self browseBundleAsDatabase:bundle host:host name:strings[0]];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:host];
}

+ (void)browseBundleAsDatabase:(NSBundle *)bundle host:(UIViewController *)host name:(NSString *)name {
    NSParameterAssert(name.length);

    UIAlertController *progress = [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"正在生成数据库");
        // 某些iOS版本如果初始没有消息并且后续添加会出现故障
        make.message(@"…");
    }];

    [host presentViewController:progress animated:YES completion:^{
        // 生成存储数据库的路径
        NSString *path = [NSSearchPathForDirectoriesInDomains(
            NSLibraryDirectory, NSUserDomainMask, YES
        )[0] stringByAppendingPathComponent:name];

        progress.message = [path stringByAppendingString:@"\n\n正在创建数据库…"];

        // 生成数据库并显示进度
        [FLEXRuntimeExporter createRuntimeDatabaseAtPath:path
            forImages:@[bundle.executablePath]
            progressHandler:^(NSString *status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress.message = [progress.message
                        stringByAppendingFormat:@"\n%@", status
                    ];
                    [progress.view setNeedsLayout];
                    [progress.view layoutIfNeeded];
                });
            } completion:^(NSString *error) {
                // 显示错误（如果有）
                if (error) {
                    progress.title = @"错误";
                    progress.message = error;
                    [progress addAction:[UIAlertAction
                        actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]
                    ];
                }
                // 浏览数据库
                else {
                    [progress dismissViewControllerAnimated:YES completion:nil];
                    [host.navigationController pushViewController:[
                        [FLEXTableListViewController alloc] initWithPath:path
                    ] animated:YES];
                }
            }
        ];
    }];
}

@end
