#import "DYYYScreenshot.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYToast.h"

// ======== DYYYScreenshot 类实现 ========
@implementation DYYYScreenshot

+ (void)takeScreenshot {
    NSLog(@"DYYY截图: takeScreenshot 被调用");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 获取当前控制器
        UIViewController *topVC = [DYYYUtils topView];
        if (!topVC) {
            [DYYYUtils showToast:@"无法获取当前界面"];
            return;
        }

        // 查找 AWEPlayInteractionViewController 实例
        AWEPlayInteractionViewController *playVC = [self findPlayInteractionViewController:topVC];
        
        // 如果找到了 AWEPlayInteractionViewController，调用其截图方法
        if (playVC && [playVC respondsToSelector:@selector(dyyy_startCustomScreenshotProcess)]) {
            NSLog(@"DYYY截图: 找到 AWEPlayInteractionViewController，调用自定义截图流程");
            [playVC dyyy_startCustomScreenshotProcess];
        } else {
            NSLog(@"DYYY截图: 未找到 AWEPlayInteractionViewController，使用通用截图流程");
            // 如果没有找到，使用通用的截图流程（带选择界面）
            [self takeScreenshotWithSelectionInterface];
        }
    });
}

+ (AWEPlayInteractionViewController *)findPlayInteractionViewController:(UIViewController *)rootVC {
    if (!rootVC) return nil;
    
    // 递归查找 AWEPlayInteractionViewController
    if ([rootVC isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) {
        return (AWEPlayInteractionViewController *)rootVC;
    }
    
    // 检查子控制器
    for (UIViewController *childVC in rootVC.childViewControllers) {
        AWEPlayInteractionViewController *found = [self findPlayInteractionViewController:childVC];
        if (found) return found;
    }
    
    // 检查presented控制器
    if (rootVC.presentedViewController) {
        AWEPlayInteractionViewController *found = [self findPlayInteractionViewController:rootVC.presentedViewController];
        if (found) return found;
    }
    
    return nil;
}

+ (void)takeScreenshotWithSelectionInterface {
    NSLog(@"DYYY截图: 启动通用截图流程（带选择界面）");
    
    UIWindow *keyWindow = DYYY_findKeyWindow();
    if (!keyWindow) {
        [DYYYUtils showToast:@"无法获取窗口进行截图"];
        return;
    }
    
    // 先截取全屏图像
    UIImage *initialScreenshot = [self captureFullScreenshot:keyWindow];
    if (!initialScreenshot) {
        [DYYYUtils showToast:@"无法获取屏幕截图"];
        return;
    }
    
    NSLog(@"DYYY截图: 成功获取屏幕截图，显示选择界面");
    
    // 显示选择区域视图
    DYYYScreenshotSelectionView *selectionView = [[DYYYScreenshotSelectionView alloc] initWithFrame:keyWindow.bounds completion:^(CGRect selectedRect, BOOL cancelled) {
        NSLog(@"DYYY截图回调: cancelled=%d, rect=%@", cancelled, NSStringFromCGRect(selectedRect));
        
        if (cancelled) {
            [DYYYUtils showToast:@"已取消截图"];
            return;
        }
        
        if (CGRectIsEmpty(selectedRect) || selectedRect.size.width < 10 || selectedRect.size.height < 10) {
            [DYYYUtils showToast:@"截图区域太小"];
            return;
        }
        
        // 裁剪图片
        UIImage *croppedImage = [self cropImage:initialScreenshot toRect:selectedRect];
        if (croppedImage) {
            NSLog(@"DYYY截图: 成功裁剪图片，显示分享菜单");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentShareSheetWithImage:croppedImage fromView:keyWindow];
            });
        } else {
            NSLog(@"DYYY截图: 裁剪图片失败");
            [DYYYUtils showToast:@"截图处理失败"];
        }
    }];
    
    // 添加到窗口
    [keyWindow addSubview:selectionView];
    [keyWindow bringSubviewToFront:selectionView];
}

+ (UIImage *)captureFullScreenshot:(UIWindow *)window {
    if (!window) return nil;
    
    @try {
        NSLog(@"DYYY截图: 开始捕获全屏截图");
        CGRect bounds = window.bounds;
        CGFloat scale = [UIScreen mainScreen].scale;
        
        UIGraphicsBeginImageContextWithOptions(bounds.size, NO, scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        if (!context) {
            UIGraphicsEndImageContext();
            return nil;
        }
        
        [window layoutIfNeeded];
        BOOL success = [window drawViewHierarchyInRect:bounds afterScreenUpdates:YES];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (!success) {
            NSLog(@"DYYY截图: drawViewHierarchy 返回失败，但仍尝试使用生成的图像");
        }
        
        return image;
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: 捕获截图失败: %@", exception);
        UIGraphicsEndImageContext(); // 确保清理
        return nil;
    }
}

+ (UIImage *)cropImage:(UIImage *)image toRect:(CGRect)cropRect {
    if (!image || CGRectIsEmpty(cropRect)) {
        return nil;
    }
    
    @try {
        // 获取屏幕缩放比例
        CGFloat screenScale = [UIScreen mainScreen].scale;
        CGFloat imageScale = image.scale;
        
        // 确保裁剪区域在图像范围内
        CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
        CGRect safeCropRect = CGRectIntersection(cropRect, imageRect);
        if (CGRectIsEmpty(safeCropRect)) {
            return nil;
        }
        
        // 考虑屏幕和图像的缩放比例
        CGRect scaledCropRect = CGRectMake(
            safeCropRect.origin.x * imageScale,
            safeCropRect.origin.y * imageScale,
            safeCropRect.size.width * imageScale,
            safeCropRect.size.height * imageScale
        );
        
        // 确保裁剪区域是整数以避免像素对齐问题
        scaledCropRect.origin.x = floor(scaledCropRect.origin.x);
        scaledCropRect.origin.y = floor(scaledCropRect.origin.y);
        scaledCropRect.size.width = floor(scaledCropRect.size.width);
        scaledCropRect.size.height = floor(scaledCropRect.size.height);
        
        // 使用CoreGraphics裁剪
        CGImageRef cgImage = CGImageCreateWithImageInRect(image.CGImage, scaledCropRect);
        if (!cgImage) {
            return nil;
        }
        
        // 创建新图像，保持原始缩放比例
        UIImage *croppedImage = [UIImage imageWithCGImage:cgImage scale:imageScale orientation:image.imageOrientation];
        CGImageRelease(cgImage);
        
        return croppedImage;
    } @catch (NSException *exception) {
        NSLog(@"DYYY裁剪图像失败: %@", exception);
        return nil;
    }
}

+ (void)presentShareSheetWithImage:(UIImage *)image fromView:(UIView *)sourceView {
    if (!image) {
        [DYYYUtils showToast:@"截图处理失败，无法分享"];
        return;
    }

    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[image] applicationActivities:nil];
    
    [DYYYUtils showToast:@"截图成功！"];
    
    UIViewController *presentingController = [DYYYUtils topView];
    if (!presentingController) {
        UIWindow *keyWindow = DYYY_findKeyWindow();
        if (keyWindow) {
            presentingController = keyWindow.rootViewController;
            while (presentingController.presentedViewController) {
                presentingController = presentingController.presentedViewController;
            }
        }
    }
    
    if (!presentingController) {
        // 如果找不到控制器，至少保存到相册
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
        [DYYYUtils showToast:@"截图已保存到相册"];
        return;
    }

    // 设置iPad上的弹出源
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityViewController.popoverPresentationController.sourceView = sourceView;
        CGRect visibleRect = [sourceView convertRect:sourceView.bounds toView:nil];
        activityViewController.popoverPresentationController.sourceRect = CGRectMake(
            CGRectGetMidX(visibleRect), 
            CGRectGetMidY(visibleRect), 
            10, 10
        );
        activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    // 添加取消回调
    if (@available(iOS 8.0, *)) {
        activityViewController.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            if (!completed && !activityType) {
                // 用户取消分享时，自动保存到相册
                UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
                [DYYYUtils showToast:@"截图已保存到相册"];
            }
        };
    }

    [presentingController presentViewController:activityViewController animated:YES completion:nil];
}

+ (void)takeScreenshotOfView:(UIView *)view {
    if (!view) {
        [DYYYUtils showToast:@"无法获取目标视图"];
        return;
    }
    
    // 创建视图截图
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [UIScreen mainScreen].scale);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (image) {
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    } else {
        [DYYYUtils showToast:@"截图失败"];
    }
}

+ (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            [DYYYUtils showToast:[NSString stringWithFormat:@"截图保存失败: %@", error.localizedDescription]];
        } else {
            // 保存成功，播放系统截图声音和触感反馈
            if (@available(iOS 10.0, *)) {
                UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
                [generator prepare];
                [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
            }
            
            [DYYYUtils showToast:@"截图已保存到相册"];
        }
    });
}

@end

// ======== 工具函数实现 ========
UIWindow * _Nullable DYYY_findKeyWindow() {
    UIWindow *keyWindow = nil;
    
    @try {
        if (@available(iOS 15.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                     UIWindowScene *windowScene = (UIWindowScene *)scene;
                     // keyWindow属性在iOS 15中对UIWindowScene可用
                     if ([windowScene respondsToSelector:@selector(keyWindow)]) {
                        keyWindow = windowScene.keyWindow;
                     } else { // iOS 13/14回退方案
                        for (UIWindow *window in windowScene.windows) {
                            if (window.isKeyWindow) {
                                keyWindow = window;
                                break;
                            }
                        }
                     }
                     if (keyWindow) break;
                }
            }
        }
        
        if (!keyWindow && @available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (!keyWindow) {
                         for (UIWindow *window in windowScene.windows) {
                            if (window.screen == UIScreen.mainScreen && !window.hidden && window.alpha > 0 && CGRectIntersectsRect(window.frame, UIScreen.mainScreen.bounds)) {
                                keyWindow = window;
                                break;
                            }
                        }
                    }
                    if (keyWindow) break;
                }
            }
        }
        
        if (!keyWindow) {
            keyWindow = UIApplication.sharedApplication.keyWindow;
        }
        
        // 最终回退方案
        if (!keyWindow && [UIApplication.sharedApplication.delegate respondsToSelector:@selector(window)]) {
           keyWindow = UIApplication.sharedApplication.delegate.window;
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY: 查找keyWindow时发生异常: %@", exception);
    }
    
    return keyWindow;
}

// ======== DYYYScreenshotSelectionView 实现 ========
@implementation DYYYScreenshotSelectionView

- (instancetype)initWithFrame:(CGRect)frame completion:(void (^)(CGRect, BOOL))completion {
    self = [super initWithFrame:frame];
    if (self) {
        // 保存completion block
        _completionBlock = [completion copy];
        
        // 基本设置
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.userInteractionEnabled = YES;
        
        // 初始化属性
        _currentSelectionRect = CGRectZero;
        _selectionStartPoint = CGPointZero;

        // 创建暗色遮罩视图
        _dimOverlayView = [[UIView alloc] initWithFrame:self.bounds];
        _dimOverlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        _dimOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _dimOverlayView.userInteractionEnabled = YES;
        [self addSubview:_dimOverlayView];
        
        // 添加点击背景取消的手势识别器
        UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
        backgroundTap.delaysTouchesBegan = NO;
        backgroundTap.cancelsTouchesInView = NO;
        [_dimOverlayView addGestureRecognizer:backgroundTap];

        // 创建遮罩图层
        _dimMaskLayer = [CAShapeLayer layer];
        _dimMaskLayer.frame = self.bounds;
        _dimMaskLayer.fillRule = kCAFillRuleEvenOdd;
        _dimOverlayView.layer.mask = _dimMaskLayer;

        // 创建选择边框图层
        _selectionBorderLayer = [CAShapeLayer layer];
        _selectionBorderLayer.lineWidth = 2.0;
        _selectionBorderLayer.strokeColor = [UIColor whiteColor].CGColor;
        _selectionBorderLayer.fillColor = [UIColor clearColor].CGColor;
        _selectionBorderLayer.lineDashPattern = @[@6, @3];
        [self.layer addSublayer:_selectionBorderLayer];

        // 添加拖拽手势
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:_panGesture];

        // 创建确认按钮
        _confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_confirmButton setTitle:@"截取" forState:UIControlStateNormal];
        [_confirmButton addTarget:self action:@selector(confirmTapped:) forControlEvents:UIControlEventTouchUpInside];
        _confirmButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.1 alpha:0.9];
        [_confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _confirmButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _confirmButton.layer.cornerRadius = 8;
        _confirmButton.alpha = 0.0;
        _confirmButton.userInteractionEnabled = YES;
        _confirmButton.layer.zPosition = 999;
        [self addSubview:_confirmButton];

        // 创建取消按钮
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(cancelTapped:) forControlEvents:UIControlEventTouchUpInside];
        _cancelButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:0.9];
        [_cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _cancelButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        _cancelButton.layer.cornerRadius = 8;
        _cancelButton.userInteractionEnabled = YES;
        _cancelButton.layer.zPosition = 999;
        // 添加阴影效果
        _cancelButton.layer.shadowColor = [UIColor blackColor].CGColor;
        _cancelButton.layer.shadowOffset = CGSizeMake(0, 2);
        _cancelButton.layer.shadowRadius = 3.0;
        _cancelButton.layer.shadowOpacity = 0.5;
        [self addSubview:_cancelButton];
        
        // 支持双击屏幕取消
        UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTapGesture.numberOfTapsRequired = 2;
        [self addGestureRecognizer:doubleTapGesture];
        
        // 添加提示标签
        UILabel *tapHintLabel = [[UILabel alloc] init];
        tapHintLabel.text = @"拖动选择截图区域，点击空白区域取消";
        tapHintLabel.textColor = [UIColor whiteColor];
        tapHintLabel.font = [UIFont systemFontOfSize:14];
        tapHintLabel.textAlignment = NSTextAlignmentCenter;
        tapHintLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        tapHintLabel.layer.cornerRadius = 10;
        tapHintLabel.clipsToBounds = YES;
        [self addSubview:tapHintLabel];
        
        // 设置提示标签位置
        CGFloat labelWidth = 280;
        CGFloat labelHeight = 30;
        tapHintLabel.frame = CGRectMake((frame.size.width - labelWidth) / 2, 50, labelWidth, labelHeight);
        tapHintLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        // 初始更新
        [self updateSelectionAppearance];
        [self setNeedsLayout];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"DYYY截图: DYYYScreenshotSelectionView dealloc");
}

- (void)updateSelectionAppearance {
    @try {
        // 更新遮罩层，突出显示选择区域
        if (!CGRectIsEmpty(_currentSelectionRect) && _currentSelectionRect.size.width > 10 && _currentSelectionRect.size.height > 10) {
            // 创建遮罩路径（整个屏幕减去选择区域）
            UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.bounds];
            UIBezierPath *selectionPath = [UIBezierPath bezierPathWithRect:_currentSelectionRect];
            [path appendPath:selectionPath];
            
            // 设置遮罩图层
            _dimMaskLayer.path = path.CGPath;
            
            // 更新边框
            UIBezierPath *borderPath = [UIBezierPath bezierPathWithRect:_currentSelectionRect];
            _selectionBorderLayer.path = borderPath.CGPath;
            
            // 显示确认按钮
            [UIView animateWithDuration:0.2 animations:^{
                self.confirmButton.alpha = 1.0;
            }];
        } else {
            // 如果没有选择区域，清除遮罩和边框
            _dimMaskLayer.path = nil;
            _selectionBorderLayer.path = nil;
            
            // 隐藏确认按钮
            self.confirmButton.alpha = 0.0;
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: updateSelectionAppearance 异常: %@", exception);
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    @try {
        CGPoint location = [gesture locationInView:self];
        
        switch (gesture.state) {
            case UIGestureRecognizerStateBegan:
                // 记录起始点
                self.selectionStartPoint = location;
                self.currentSelectionRect = CGRectZero;
                NSLog(@"DYYY截图: 开始选择区域，起始点: %@", NSStringFromCGPoint(location));
                break;
                
            case UIGestureRecognizerStateChanged:
                // 更新选择区域
                self.currentSelectionRect = CGRectMake(
                    MIN(self.selectionStartPoint.x, location.x),
                    MIN(self.selectionStartPoint.y, location.y),
                    ABS(location.x - self.selectionStartPoint.x),
                    ABS(location.y - self.selectionStartPoint.y)
                );
                
                // 更新外观
                [self updateSelectionAppearance];
                break;
                
            case UIGestureRecognizerStateEnded:
                // 完成选择
                if (CGRectGetWidth(self.currentSelectionRect) < 10 || CGRectGetHeight(self.currentSelectionRect) < 10) {
                    // 如果选择区域太小，重置
                    NSLog(@"DYYY截图: 选择区域太小，重置");
                    self.currentSelectionRect = CGRectZero;
                    [self updateSelectionAppearance];
                } else {
                    NSLog(@"DYYY截图: 选择区域完成: %@", NSStringFromCGRect(self.currentSelectionRect));
                }
                break;
                
            default:
                break;
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: handlePan 异常: %@", exception);
    }
}

- (void)backgroundTapped:(UITapGestureRecognizer *)gesture {
    @try {
        // 确保是在背景区域点击，而不是按钮区域
        CGPoint location = [gesture locationInView:self];
        
        // 检查是否点击在按钮上
        if (CGRectContainsPoint(self.cancelButton.frame, location) || 
            CGRectContainsPoint(self.confirmButton.frame, location)) {
            return;
        }
        
        // 如果有选择区域，且点击在选择区域内，则不关闭
        if (!CGRectIsEmpty(self.currentSelectionRect) && 
            CGRectContainsPoint(self.currentSelectionRect, location)) {
            return;
        }
        
        NSLog(@"DYYY截图: 用户点击背景取消截图");
        
        // 强制触感反馈给用户
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 立即移除自身并回调
        [self removeFromSuperview];
        
        // 调用取消回调
        if (self.completionBlock) {
            self.completionBlock(CGRectZero, YES);
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: backgroundTapped 异常: %@", exception);
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // 优先检查取消按钮 - 扩大点击范围
    CGRect expandedCancelFrame = CGRectInset(self.cancelButton.frame, -20, -20);
    if (CGRectContainsPoint(expandedCancelFrame, point)) {
        return self.cancelButton;
    }
    
    // 检查确认按钮
    if (CGRectContainsPoint(self.confirmButton.frame, point)) {
        return self.confirmButton;
    }
    
    return [super hitTest:point withEvent:event];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    @try {
        _dimOverlayView.frame = self.bounds;
        _dimMaskLayer.frame = self.bounds;

        CGFloat buttonWidth = 100;
        CGFloat buttonHeight = 44;
        CGFloat buttonSpacing = 20;
        CGFloat bottomPadding = 50;

        if (@available(iOS 11.0, *)) {
            bottomPadding += self.safeAreaInsets.bottom > 0 ? self.safeAreaInsets.bottom : 20;
        } else {
            bottomPadding += 20;
        }

        CGFloat totalButtonWidth = buttonWidth * 2 + buttonSpacing;
        CGFloat startX = (self.bounds.size.width - totalButtonWidth) / 2.0;

        _cancelButton.frame = CGRectMake(startX, self.bounds.size.height - buttonHeight - bottomPadding, buttonWidth, buttonHeight);
        _confirmButton.frame = CGRectMake(startX + buttonWidth + buttonSpacing, self.bounds.size.height - buttonHeight - bottomPadding, buttonWidth, buttonHeight);
        
        [self updateSelectionAppearance];
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: layoutSubviews 异常: %@", exception);
    }
}

- (void)cancelTapped:(UIButton *)sender {
    @try {
        // 记录日志
        NSLog(@"DYYY截图: 取消按钮被点击");
        
        // 立即触发触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 更改按钮视觉反馈
        sender.backgroundColor = [UIColor grayColor];
        sender.transform = CGAffineTransformMakeScale(0.9, 0.9);
        
        // 立即移除自身
        [self removeFromSuperview];
        
        // 调用取消回调
        if (self.completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(CGRectZero, YES);
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: cancelTapped 异常: %@", exception);
    }
}

- (void)confirmTapped:(UIButton *)sender {
    @try {
        // 记录日志
        NSLog(@"DYYY截图: 确认按钮被点击，选择区域: %@", NSStringFromCGRect(self.currentSelectionRect));
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 视觉反馈
        sender.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0];
        sender.transform = CGAffineTransformMakeScale(0.9, 0.9);
        
        // 获取当前选择区域
        CGRect selectedRect = self.currentSelectionRect;
        
        // 移除选择视图
        [self removeFromSuperview];
        
        // 调用完成回调
        if (self.completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(selectedRect, NO);
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: confirmTapped 异常: %@", exception);
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    @try {
        NSLog(@"DYYY截图: 用户双击取消截图");
        
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
        [self removeFromSuperview];
        
        if (self.completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(CGRectZero, YES);
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图: handleDoubleTap 异常: %@", exception);
    }
}

@end
