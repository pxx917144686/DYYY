#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCDecryptTool : NSObject
+ (void)installDecryptHooksIfNeeded;
+ (void)presentDecryptPanelFromViewController:(nullable UIViewController *)viewController;
@end

NS_ASSUME_NONNULL_END
