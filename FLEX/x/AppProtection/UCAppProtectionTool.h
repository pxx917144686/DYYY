#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCAppProtectionTool : NSObject

+ (void)setup;
+ (void)disableProtection;
+ (void)enableWithSetup;
+ (void)presentProtectionPanelFromViewController:(UIViewController *)viewController
                                      completion:(void (^ _Nullable)(void))completion;

@end

NS_ASSUME_NONNULL_END
