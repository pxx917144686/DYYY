//
//  DYYYSettingViewController.m
//  DYYY
//
//  设置页主文件：保留类扩展入口（isExiting 属性合成）、公共 C 函数与空 category 声明。
//  生命周期/外观/头像/搜索栏/table 搭建 → DYYYSettingViewControllerAppearance.m
//  清理/备份恢复/ABTest 配置 → DYYYSettingViewControllerBackup.m
//  data source/delegate/搜索过滤/图标颜色 → DYYYSettingViewControllerTable.m
//  颜色/样式选择/源码弹窗/长按和重置 → DYYYSettingViewControllerPresentation.m
//

#import "DYYYSettingViewController.h"
#import "DYYYSettingViewControllerPrivate.h"
#import "AwemeHeaders.h"

// 获取顶层视图控制器
UIViewController *topView(void) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                window = windowScene.windows.firstObject;
                break;
            }
        }
    } else {
        window = [UIApplication sharedApplication].keyWindow;
    }
    
    UIViewController *rootViewController = window.rootViewController;
    UIViewController *topVC = rootViewController;
    
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)topVC;
        topVC = nav.topViewController;
    }
    
    return topVC;
}

#ifndef AWESettingBaseViewController_DEFINED
#define AWESettingBaseViewController_DEFINED
@interface AWESettingBaseViewController (DYYY_Addition)
@end
#endif

@implementation DYYYSettingViewController
// 方法实现按功能域分布在 +Appearance/+Backup/+Table/+Presentation 各 category 中。
// 保留本实现体以完成 isExiting 属性的自动合成。
@end
