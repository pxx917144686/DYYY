//
//  DYYYFLEXWindowShortcuts.m
//  FLEX
//
//  Created by AnthoPak on 26/09/2022.
//

#import "DYYYFLEXWindowShortcuts.h"
#import "DYYYFLEXShortcut.h"
#import "DYYYFLEXAlert.h"
#import "DYYYFLEXObjectExplorerViewController.h"

@implementation DYYYFLEXWindowShortcuts

#pragma mark - 重写

+ (instancetype)forObject:(UIView *)view {
    return [self forObject:view additionalRows:@[
        [DYYYFLEXActionShortcut title:@"动画速度" subtitle:^NSString *(UIWindow *window) {
            return [NSString stringWithFormat:@"当前速度: %.2f", window.layer.speed];
        } selectionHandler:^(UIViewController *host, UIWindow *window) {
            [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
                make.title(@"更改动画速度");
                make.message([NSString stringWithFormat:@"当前速度: %.2f", window.layer.speed]);
                make.configuredTextField(^(UITextField * _Nonnull textField) {
                    textField.placeholder = @"默认值: 1.0";
                    textField.keyboardType = UIKeyboardTypeDecimalPad;
                });
                
                make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                    NSNumberFormatter *formatter = [NSNumberFormatter new];
                    formatter.numberStyle = NSNumberFormatterDecimalStyle;
                    CGFloat speedValue = [formatter numberFromString:strings.firstObject].floatValue;
                    window.layer.speed = speedValue;

                    // 刷新宿主视图控制器以更新快捷方式副标题，反映当前速度
                    // TODO: 这不应该是必要的
                    [(DYYYFLEXObjectExplorerViewController *)host reloadData];
                });
                make.button(@"取消").cancelStyle();
            } showFrom:host];
        } accessoryType:^UITableViewCellAccessoryType(id  _Nonnull object) {
            return UITableViewCellAccessoryDisclosureIndicator;
        }]
    ]];
}

@end
