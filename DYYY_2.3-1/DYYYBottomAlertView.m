#import "DYYYBottomAlertView.h"
#import "AwemeHeaders.h"
#import "DYYYUtils.h"

@implementation DYYYBottomAlertView

+ (UIViewController *)showAlertWithTitle:(NSString *)title
                                 message:(NSString *)message
                               avatarURL:(nullable NSString *)avatarURL
                        cancelButtonText:(nullable NSString *)cancelButtonText
                       confirmButtonText:(nullable NSString *)confirmButtonText
                            cancelAction:(DYYYAlertActionHandler)cancelAction
                             closeAction:(nullable DYYYAlertActionHandler)closeAction
                           confirmAction:(DYYYAlertActionHandler)confirmAction {
    AFDPrivacyHalfScreenViewController *vc = [NSClassFromString(@"AFDPrivacyHalfScreenViewController") new];

    if (!vc)
        return nil;

    if (cancelButtonText.length == 0) {
        cancelButtonText = @"取消";
    }

    if (confirmButtonText.length == 0) {
        confirmButtonText = @"确定";
    }

    UIImageView *imageView = nil;
    if (avatarURL.length > 0) {
        imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [imageView.widthAnchor constraintEqualToConstant:60].active = YES;
        [imageView.heightAnchor constraintEqualToConstant:60].active = YES;
        imageView.layer.cornerRadius = 30;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.layer.masksToBounds = YES;
        imageView.clipsToBounds = YES;

        // 设置默认占位图
        imageView.image = [UIImage imageNamed:@"AppIcon60x60"];

        // 异步加载网络图片
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURL]];
          if (imageData) {
              UIImage *image = [UIImage imageWithData:imageData];
              if (image) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    imageView.image = image;
                  });
              }
          }
        });
    }

    DYYYAlertActionHandler wrappedCancelAction = ^{
      if (cancelAction)
          cancelAction();
    };

    DYYYAlertActionHandler wrappedCloseActionBlock = ^{
      if (closeAction) {
          closeAction();
      } else {
          wrappedCancelAction();
      }
    };

    DYYYAlertActionHandler wrappedConfirmAction = ^{
      if (confirmAction)
          confirmAction();
    };

    vc.closeButtonClickedBlock = wrappedCloseActionBlock;
    vc.slideDismissBlock = wrappedCloseActionBlock;
    vc.tapDismissBlock = wrappedCloseActionBlock;

    [vc configWithImageView:imageView
                     lockImage:nil
              defaultLockState:NO
                titleLabelText:title
              contentLabelText:message
          leftCancelButtonText:cancelButtonText
        rightConfirmButtonText:confirmButtonText
          rightBtnClickedBlock:wrappedConfirmAction
        leftButtonClickedBlock:wrappedCancelAction];

    if (avatarURL.length > 0) {
        [vc setCornerRadius:11];
        [vc setOnlyTopCornerClips:YES];
    } else {
        [vc setUseCardUIStyle:YES];
    }

    UIViewController *topVC = [DYYYUtils topView];
    if (topVC && [vc respondsToSelector:@selector(presentOnViewController:)] && ![topVC isBeingPresented] && ![topVC isBeingDismissed]) {
        [vc presentOnViewController:topVC];
    } else {
        return nil;
    }

    return vc;
}

+ (UIViewController *)showAlertWithTitle:(NSString *)title
                                 message:(NSString *)message
                           confirmButton:(NSString *)confirmButtonTitle
                            cancelButton:(NSString *)cancelButtonTitle
                            confirmBlock:(void (^)(void))confirmBlock
                             cancelBlock:(void (^)(void))cancelBlock {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    if (confirmButtonTitle) {
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:confirmButtonTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
            if (confirmBlock) {
                confirmBlock();
            }
        }];
        [alert addAction:confirmAction];
    }
    
    if (cancelButtonTitle) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle
                                                              style:UIAlertActionStyleCancel
                                                            handler:^(UIAlertAction * _Nonnull action) {
            if (cancelBlock) {
                cancelBlock();
            }
        }];
        [alert addAction:cancelAction];
    }
    
    // 获取最顶层视图控制器并展示弹窗
    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
    
    return alert;
}

+ (UIViewController *)showAlertWithTitle:(NSString *)title
                                 message:(NSString *)message
                         cancelButtonText:(NSString *)cancelButtonText
                        confirmButtonText:(NSString *)confirmButtonText
                            cancelAction:(DYYYAlertActionHandler)cancelAction
                           confirmAction:(DYYYAlertActionHandler)confirmAction {
    
    [self showAlertWithTitle:title
                     message:message
               confirmButton:confirmButtonText
                cancelButton:cancelButtonText
                confirmBlock:confirmAction
                 cancelBlock:cancelAction];
    
    return nil;
}

+ (UIViewController *)showAlertWithTitle:(NSString *)title
                                 message:(NSString *)message
                            cancelAction:(DYYYAlertActionHandler)cancelAction
                           confirmAction:(DYYYAlertActionHandler)confirmAction {
    return [self showAlertWithTitle:title 
                            message:message 
                    cancelButtonText:@"取消" 
                   confirmButtonText:@"确定" 
                        cancelAction:cancelAction 
                       confirmAction:confirmAction];
}

+ (void)dismissAlertViewController:(UIViewController *)viewController {
    if (!viewController) return;
    
    [viewController willMoveToParentViewController:nil];
    [viewController.view removeFromSuperview];
    [viewController removeFromParentViewController];
}

+ (UIViewController *)topViewController {
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    return [self topViewControllerWithRootViewController:rootVC];
}

+ (UIViewController *)topViewControllerWithRootViewController:(UIViewController *)rootVC {
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarVC = (UITabBarController *)rootVC;
        return [self topViewControllerWithRootViewController:tabBarVC.selectedViewController];
    } else if ([rootVC isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navVC = (UINavigationController *)rootVC;
        return [self topViewControllerWithRootViewController:navVC.visibleViewController];
    } else if (rootVC.presentedViewController) {
        return [self topViewControllerWithRootViewController:rootVC.presentedViewController];
    }
    return rootVC;
}

@end