// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXNavigationController.h
//  FLEX
//
//  由 Tanner 创建于 1/30/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXNavigationController : UINavigationController

+ (instancetype)withRootViewController:(UIViewController *)rootVC;

@end

@interface UINavigationController (FLEXObjectExploring)

/// 将对象浏览器视图控制器推送到导航堆栈
- (void)pushExplorerForObject:(id)object;
/// 将对象浏览器视图控制器推送到导航堆栈
- (void)pushExplorerForObject:(id)object animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
