//
//  FLEXBundleShortcuts.m
//  FLEX
//
//  创建者：Tanner Bennett，日期：12/12/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXBundleShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"
#import "FLEXMacros.h"
#import "FLEXRuntimeExporter.h"
#import "FLEXTableListViewController.h"
#import "FLEXFileBrowserController.h"

#pragma mark -
@implementation FLEXBundleShortcuts
#pragma mark Overrides // 覆盖方法

+ (instancetype)forObject:(NSBundle *)bundle { weakify(self)
    return [self forObject:bundle additionalRows:@[
        [FLEXActionShortcut
            title:@"浏览 Bundle 目录" subtitle:nil // "Browse Bundle Directory"
            viewer:^UIViewController *(NSBundle *bundle) {
                return [FLEXFileBrowserController path:bundle.bundlePath];
            }
            accessoryType:^UITableViewCellAccessoryType(NSBundle *bundle) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
        [FLEXActionShortcut title:@"将 Bundle 浏览为数据库…" subtitle:nil // "Browse Bundle as Database…"
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
        make.title(@"另存为…").message( // "Save As…"
            @"数据库将保存在 Library 文件夹中。"
            "根据类的数量，导出可能需要"
            "10 分钟或更长时间才能完成。20,000 个"
            "类大约需要 7 分钟。" // Message content
        );
        make.configuredTextField(^(UITextField *field) {
            field.placeholder = @"FLEXRuntimeExport.objc.db"; // Placeholder, likely keep as is for consistency
            field.text = [NSString stringWithFormat:
                @"%@.objc.db", bundle.executablePath.lastPathComponent
            ];
        });
        make.button(@"开始").handler(^(NSArray<NSString *> *strings) { // "Start"
            [self browseBundleAsDatabase:bundle host:host name:strings[0]];
        });
        make.button(@"取消").cancelStyle(); // "Cancel"
    } showFrom:host];
}

+ (void)browseBundleAsDatabase:(NSBundle *)bundle host:(UIViewController *)host name:(NSString *)name {
    NSParameterAssert(name.length);

    UIAlertController *progress = [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"正在生成数据库"); // "Generating Database"
        // 某些 iOS 版本如果没有初始消息并且稍后添加消息，
        // 会出现故障
        make.message(@"…"); // "…"
    }];

    [host presentViewController:progress animated:YES completion:^{
        // 生成存储数据库的路径
        NSString *path = [NSSearchPathForDirectoriesInDomains(
            NSLibraryDirectory, NSUserDomainMask, YES
        )[0] stringByAppendingPathComponent:name];

        progress.message = [path stringByAppendingString:@"\n\n正在创建数据库…"]; // "\n\nCreating database…"

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
                // 如果有错误则显示
                if (error) {
                    progress.title = @"错误"; // "Error"
                    progress.message = error;
                    [progress addAction:[UIAlertAction
                        actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil] // "OK"
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
