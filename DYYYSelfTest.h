#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * DYYY++ 一键自检单元
 * 从设置页触发，弹出实时自检页面：逐项执行并实时刷新结果。
 */
@interface DYYYSelfTest : NSObject

+ (void)presentFromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
