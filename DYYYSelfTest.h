#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * DYYY++ 一键自检单元
 * 在设置页触发，后台顺序执行各子系统测试，完成后主线程弹出逐项报告。
 */
@interface DYYYSelfTest : NSObject

+ (void)runAndPresentReportFromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
