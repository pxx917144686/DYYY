//
//  FLEXWindowShortcuts.m
//  FLEX
//
//  Created by AnthoPak on 26/09/2022.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXWindowShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"
#import "FLEXObjectExplorerViewController.h"

@implementation FLEXWindowShortcuts

#pragma mark - Overrides

+ (instancetype)forObject:(UIView *)view {
    return [self forObject:view additionalRows:@[
        [FLEXActionShortcut title:@"动画速度" subtitle:^NSString *(UIWindow *window) {
            return [NSString stringWithFormat:@"当前速度：%.2f", window.layer.speed];
        } selectionHandler:^(UIViewController *host, UIWindow *window) {
            [FLEXAlert makeAlert:^(FLEXAlert *make) {
                make.title(@"修改动画速度");
                make.message([NSString stringWithFormat:@"当前速度：%.2f", window.layer.speed]);
                make.configuredTextField(^(UITextField * _Nonnull textField) {
                    textField.placeholder = @"默认值：1.0";
                    textField.keyboardType = UIKeyboardTypeDecimalPad;
                });
                
                make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                    NSNumberFormatter *formatter = [NSNumberFormatter new];
                    formatter.numberStyle = NSNumberFormatterDecimalStyle;
                    CGFloat speedValue = [formatter numberFromString:strings.firstObject].floatValue;
                    window.layer.speed = speedValue;

                    [(FLEXObjectExplorerViewController *)host reloadData];
                });
                make.button(@"取消").cancelStyle();
            } showFrom:host];
        } accessoryType:^UITableViewCellAccessoryType(id  _Nonnull object) {
            return UITableViewCellAccessoryDisclosureIndicator;
        }]
    ]];
}

@end
