// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXAddressExplorerCoordinator.m
//  FLEX
//
//  Created by Tanner Bennett on 7/10/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXAddressExplorerCoordinator.h"
#import "FLEXGlobalsViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXUtility.h"

@interface UITableViewController (FLEXAddressExploration)
// 取消选中行
- (void)deselectSelectedRow;
// 尝试探索地址
- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely;
@end

@implementation FLEXAddressExplorerCoordinator

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    // 全局入口标题
    return @"🔍  地址浏览器";
}

+ (FLEXGlobalsEntryRowAction)globalsEntryRowAction:(FLEXGlobalsRow)row {
    // 全局入口行操作
    return ^(UITableViewController *host) {

        NSString *title = @"通过地址探索对象";
        NSString *message = @"在下方粘贴一个以 '0x' 开头的十六进制地址。"
        "如果您需要绕过指针验证，请使用不安全选项，"
        "但请注意，如果地址无效，应用程序可能会崩溃。";

        // 显示输入弹窗
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(title).message(message);
            make.configuredTextField(^(UITextField *textField) {
                NSString *copied = UIPasteboard.generalPasteboard.string; // 获取剪贴板内容
                textField.placeholder = @"0x00000070deadbeef"; // 设置占位符
                // 如果剪贴板内容是地址，则自动粘贴
                if ([copied hasPrefix:@"0x"]) {
                    textField.text = copied;
                    [textField selectAll:nil]; // 全选文本
                }
            });
            // 安全探索按钮
            make.button(@"探索").handler(^(NSArray<NSString *> *strings) {
                [host tryExploreAddress:strings.firstObject safely:YES];
            });
            // 不安全探索按钮
            make.button(@"不安全探索").destructiveStyle().handler(^(NSArray *strings) {
                [host tryExploreAddress:strings.firstObject safely:NO];
            });
            make.button(@"取消").cancelStyle(); // 取消按钮
        } showFrom:host];

    };
}

@end

@implementation UITableViewController (FLEXAddressExploration)

// 取消选中表格中的当前选中行
- (void)deselectSelectedRow {
    NSIndexPath *selected = self.tableView.indexPathForSelectedRow;
    [self.tableView deselectRowAtIndexPath:selected animated:YES];
}

// 尝试探索地址
- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely {
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    unsigned long long hexValue = 0;
    BOOL didParseAddress = [scanner scanHexLongLong:&hexValue];
    const void *pointerValue = (void *)hexValue;

    NSString *error = nil;

    if (didParseAddress) {
        if (safely && ![FLEXRuntimeUtility pointerIsValidObjcObject:pointerValue]) {
            error = @"给定的地址可能不是一个有效的 Objective-C 对象。";
        }
    } else {
        error = @"地址格式错误。请确保它不太长并且以 '0x' 开头。";
    }

    if (!error) {
        id object = (__bridge id)pointerValue;
        FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:object];
        [self.navigationController pushViewController:explorer animated:YES];
    } else {
        [FLEXAlert showAlert:@"错误" message:error from:self];
        [self deselectSelectedRow];
    }
}

@end
