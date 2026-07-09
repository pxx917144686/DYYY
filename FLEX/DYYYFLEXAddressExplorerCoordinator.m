//
//  DYYYFLEXAddressExplorerCoordinator.m
//  FLEX
//
//  Created by Tanner Bennett on 7/10/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXAddressExplorerCoordinator.h"
#import "DYYYFLEXGlobalsViewController.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXObjectExplorerViewController.h"
#import "DYYYFLEXRuntimeUtility.h"
#import "DYYYFLEXUtility.h"

@interface UITableViewController (FLEXAddressExploration)
- (void)deselectSelectedRow;
- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely;
@end

@implementation DYYYFLEXAddressExplorerCoordinator

#pragma mark - DYYYFLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"🔎  地址浏览";
}

+ (FLEXGlobalsEntryRowAction)globalsEntryRowAction:(FLEXGlobalsRow)row {
    return ^(UITableViewController *host) {

        NSString *title = @"在地址处探索对象";
        NSString *message = @"在下面粘贴一个十六进制地址，以“0x”开头。"
        "如果您需要绕过指针验证，请使用不安全选项，"
        "但要知道，如果地址无效，应用程序可能会崩溃。";

        [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
            make.title(title).message(message);
            make.configuredTextField(^(UITextField *textField) {
                NSString *copied = UIPasteboard.generalPasteboard.string;
                textField.placeholder = @"0x00000070deadbeef";
                // Go ahead and paste our clipboard if we have an address copied
                if ([copied hasPrefix:@"0x"]) {
                    textField.text = copied;
                    [textField selectAll:nil];
                }
            });
            make.button(@"搜索").handler(^(NSArray<NSString *> *strings) {
                [host tryExploreAddress:strings.firstObject safely:YES];
            });
            make.button(@"不安全的搜索").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
                [host tryExploreAddress:strings.firstObject safely:NO];
            });
            make.button(@"取消").cancelStyle();
        } showFrom:host];

    };
}

@end

@implementation UITableViewController (FLEXAddressExploration)

- (void)deselectSelectedRow {
    NSIndexPath *selected = self.tableView.indexPathForSelectedRow;
    [self.tableView deselectRowAtIndexPath:selected animated:YES];
}

- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely {
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    unsigned long long hexValue = 0;
    BOOL didParseAddress = [scanner scanHexLongLong:&hexValue];
    const void *pointerValue = (void *)hexValue;

    NSString *error = nil;

    if (didParseAddress) {
        if (safely && ![DYYYFLEXRuntimeUtility pointerIsValidObjcObject:pointerValue]) {
            error = @"给定的地址可能是一个无效的对象。";
        }
    } else {
        error = @"格式不一的地址。确保它不会太长，并以“0x”开头。";
    }

    if (!error) {
        id object = (__bridge id)pointerValue;
        DYYYFLEXObjectExplorerViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:object];
        [self.navigationController pushViewController:explorer animated:YES];
    } else {
        [DYYYFLEXAlert showAlert:@"Uh-oh" message:error from:self];
        [self deselectSelectedRow];
    }
}

@end
