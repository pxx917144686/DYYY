// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXActivityViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 5/26/22.
//

#import "FLEXActivityViewController.h"
#import "FLEXMacros.h"
#import "FLEXUtility.h" // 确保导入了 FLEXUtility.h

@interface FLEXActivityViewController ()
@end

@implementation FLEXActivityViewController

+ (id)sharing:(NSArray *)items source:(id)sender {
    // 创建 UIActivityViewController 实例
    UIViewController *shareSheet = [[UIActivityViewController alloc]
        initWithActivityItems:items applicationActivities:nil
    ];

    // 如果提供了 sender 并且设备是 iPad，则配置 popover
    if (sender && UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIPopoverPresentationController *popover = shareSheet.popoverPresentationController;

        // 设置来源视图
        if ([sender isKindOfClass:UIView.class]) {
            popover.sourceView = sender;
            popover.sourceRect = [(UIView *)sender bounds]; // 默认使用视图边界
        }
        // 设置来源 UIBarButtonItem
        if ([sender isKindOfClass:UIBarButtonItem.class]) {
            popover.barButtonItem = sender;
        }
        // 设置来源矩形 (NSValue 包装的 CGRect) - 恢复原始逻辑或修正
        if ([sender isKindOfClass:NSValue.class]) {
            // 假设 NSValue 包含 CGRect
            @try {
                CGRect rect = [sender CGRectValue];
                // 需要一个来源视图来定位矩形，这里假设是 keyWindow
                // 使用正确的 API 获取 application delegate window
                UIView *sourceView = FLEXUtility.appKeyWindow ?: UIApplication.sharedApplication.delegate.window;
                if (sourceView) {
                    popover.sourceView = sourceView;
                    popover.sourceRect = rect;
                }
            } @catch (NSException *exception) {
                // NSValue 可能不包含 CGRect，忽略错误或记录日志
                NSLog(@"FLEX: 从 NSValue 源获取 CGRect 时出错: %@", exception);
            }
        }
    }

    return shareSheet; // 返回配置好的 UIActivityViewController
}

// 重写 dismissViewControllerAnimated:completion: 以防止意外关闭其他视图控制器
// (根据原始注释意图，但这里没有实现)
// - (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
//     // 可以选择性地阻止 dismiss 操作，或者只在特定条件下允许
//     // super.dismissViewControllerAnimated:flag completion:completion];
// }

@end
