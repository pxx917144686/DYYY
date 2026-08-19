//
//  DYYYPlayInteractionVisualHooks.xm
//  DYYY
//
//  深色模式、视觉样式、性能和列表布局 hook（拆分自 AWEPlayInteractionViewController.xm）。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "FLEXHeaders.h"
#import <PhotosUI/PhotosUI.h>
#import "DYYYUtils.h"
#import "DYYYBottomAlertView.h"
#import "DYYYToast.h"
#import "DYYYConfirmCloseView.h"
#import "DYYYScreenshot.h"
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>
#import "DYYYFloatSpeedButton.h"
#import "DYYYPipPlayer.h"
#import "DYYYMenuComponents.h"
#import "DYYYPlayInteractionAdditions.h"

%hook AWEPlayInteractionViewController

%new
- (void)applySmartTextColorToAllMenuItems {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 获取主容器的背景色
    UIView *menuContainer = scrollView.superview;
    UIColor *backgroundColor = [UIColor clearColor];
    BOOL isDarkMode = NO; // 默认假设浅色背景
    
    if ([menuContainer isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *effectView = (UIVisualEffectView *)menuContainer;
        UIBlurEffectStyle style = [self inferVisualEffectStyle:effectView.effect];
        isDarkMode = (style == UIBlurEffectStyleDark);
        
        // 检查是否有自定义背景色
        for (UIView *subview in effectView.contentView.subviews) {
            if (subview.tag == 8888) {
                backgroundColor = subview.backgroundColor;
                
                // 更精确地检测背景色是否为深色
                CGFloat r = 0, g = 0, b = 0, a = 0;
                [backgroundColor getRed:&r green:&g blue:&b alpha:&a];
                
                // 计算亮度值，使用感知亮度公式
                CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * b;
                isDarkMode = (luminance < 0.5);
                break;
            }
        }
    }
    
    // 根据背景确定文本颜色
    UIColor *textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
    
    // 更新所有模块的文本颜色
    for (UIView *moduleView in moduleViews) {
        [self updateTextColorsInView:moduleView withTextColor:textColor];
    }
}

%new
- (UIBlurEffectStyle)inferVisualEffectStyle:(UIBlurEffect *)effect {
    // 改进视觉效果样式检测
    if (!effect) return UIBlurEffectStyleDark;
    
    // 尝试通过比较获取效果风格
    if (@available(iOS 13.0, *)) {
        if ([effect isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]] ||
            [effect isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]]) {
            return UIBlurEffectStyleDark;
        } 
        else if ([effect isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight]] ||
                 [effect isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]]) {
            return UIBlurEffectStyleLight;
        }
    } else {
        if ([effect isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]]) {
            return UIBlurEffectStyleDark;
        } 
        else if ([effect isEqual:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]]) {
            return UIBlurEffectStyleLight;
        }
    }
    // 尝试从关联对象中获取风格
    NSNumber *styleNumber = objc_getAssociatedObject(effect, "blurStyleNumber");
    if (styleNumber != nil) {
        NSInteger styleValue = [styleNumber integerValue];
        if (styleValue == UIBlurEffectStyleDark) {
            return UIBlurEffectStyleDark;
        } else if (styleValue == UIBlurEffectStyleLight) {
            return UIBlurEffectStyleLight;
        }
    }
    
    // 默认为深色风格
    return UIBlurEffectStyleDark;
}

%new
- (void)updateTextColorsInView:(UIView *)view withTextColor:(UIColor *)textColor {
    // 递归处理所有子视图
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = textColor;
        } else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitleColor:textColor forState:UIControlStateNormal];
            
            // 递归处理按钮的子视图
            [self updateTextColorsInView:button withTextColor:textColor];
        } else if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            // 处理毛玻璃效果视图内部的控件
            UIVisualEffectView *visualEffectView = (UIVisualEffectView *)subview;
            [self updateTextColorsInView:visualEffectView.contentView withTextColor:textColor];
        } else {
            // 继续递归处理其他子视图
            [self updateTextColorsInView:subview withTextColor:textColor];
        }
    }
}

%new
- (void)safelyUpdateUI:(void (^)(void))block {
    if ([NSThread isMainThread]) {
        if (block) block();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) block();
        });
    }
}

%new
- (void)optimizeSpaceUtilizationAfterHeaderHidden {
    // 查找当前菜单面板
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    
    UIView *overlayView = nil;
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            overlayView = view;
            break;
        }
    }
    
    if (!overlayView) return;
    
    // 获取菜单容器和滚动视图
    UIView *menuContainer = nil;
    UIScrollView *scrollView = nil;
    
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            
            // 查找滚动视图
            for (UIView *containerSubview in menuContainer.subviews) {
                if ([containerSubview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *effectView = (UIVisualEffectView *)containerSubview;
                    for (UIView *contentView in effectView.contentView.subviews) {
                        if ([contentView isKindOfClass:[UIScrollView class]]) {
                            scrollView = (UIScrollView *)contentView;
                            break;
                        }
                    }
                }
                if (scrollView) break;
            }
            break;
        }
    }
    
    if (!scrollView || !menuContainer) return;
    
    // 获取当前视图模式
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    // 现在scrollView已经占据了全部空间，重新优化模块布局
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (moduleViews && moduleViews.count > 0) {
        CGFloat fullHeight = scrollView.frame.size.height; // 现在是全高度
        
        [UIView animateWithDuration:0.3 
                              delay:0.1 
                            options:UIViewAnimationOptionCurveEaseInOut 
                         animations:^{
            if (isListView) {
                // 列表视图模式优化 - 利用全部空间
                CGFloat cellHeight = 56;
                CGFloat totalItemsVisible = floor(fullHeight / cellHeight);
                
                // 计算最优间距
                CGFloat optimalSpacing = 0;
                if (moduleViews.count > 0 && totalItemsVisible > 0) {
                    CGFloat remainingSpace = fullHeight - (MIN(totalItemsVisible, moduleViews.count) * cellHeight);
                    optimalSpacing = remainingSpace / (MIN(totalItemsVisible, moduleViews.count) + 1);
                    optimalSpacing = MAX(optimalSpacing, 4); // 最小间距4pt
                }
                
                for (NSInteger i = 0; i < moduleViews.count; i++) {
                    UIView *moduleView = moduleViews[i];
                    
                    // 添加缩放动画
                    moduleView.transform = CGAffineTransformMakeScale(0.98, 0.98);
                    [UIView animateWithDuration:0.25 delay:0.03 * i options:UIViewAnimationOptionCurveEaseOut animations:^{
                        moduleView.transform = CGAffineTransformIdentity;
                        
                        // 调整位置 - 从顶部开始
                        CGRect frame = moduleView.frame;
                        frame.origin.y = optimalSpacing + i * (cellHeight + optimalSpacing);
                        moduleView.frame = frame;
                    } completion:nil];
                }
                
                // 更新内容大小
                CGFloat totalHeight = (cellHeight + optimalSpacing) * moduleViews.count + optimalSpacing;
                scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, MAX(totalHeight, fullHeight));
                
            } else {
                // 卡片视图模式优化 - 利用全部空间
                CGFloat moduleHeight = 80;
                CGFloat optimalSpacing = 8; // 更紧凑的间距
                
                // 如果项目很少，可以增大间距以充分利用空间
                if (moduleViews.count <= 5) {
                    CGFloat availableSpace = fullHeight - (moduleViews.count * moduleHeight);
                    optimalSpacing = availableSpace / (moduleViews.count + 1);
                    optimalSpacing = MAX(optimalSpacing, 8); // 最小间距8pt
                    optimalSpacing = MIN(optimalSpacing, 20); // 最大间距20pt
                }
                
                for (NSInteger i = 0; i < moduleViews.count; i++) {
                    UIView *moduleView = moduleViews[i];
                    
                    // 添加缩放动画
                    moduleView.transform = CGAffineTransformMakeScale(0.96, 0.96);
                    [UIView animateWithDuration:0.25 delay:0.05 * i options:UIViewAnimationOptionCurveEaseOut animations:^{
                        moduleView.transform = CGAffineTransformIdentity;
                        
                        // 调整位置 - 从顶部开始
                        CGRect frame = moduleView.frame;
                        frame.origin.y = optimalSpacing + i * (moduleHeight + optimalSpacing);
                        moduleView.frame = frame;
                    } completion:nil];
                }
                
                // 更新内容大小
                CGFloat totalHeight = (moduleHeight + optimalSpacing) * moduleViews.count + optimalSpacing;
                scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, MAX(totalHeight, fullHeight));
            }
        } completion:nil];
    }
}

%new
- (void)restoreOriginalLayoutAfterHeaderShown {
    // 查找当前菜单面板
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    
    UIView *overlayView = nil;
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            overlayView = view;
            break;
        }
    }
    
    if (!overlayView) return;
    
    // 获取菜单容器和滚动视图
    UIView *menuContainer = nil;
    UIScrollView *scrollView = nil;
    
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            
            // 查找滚动视图
            for (UIView *containerSubview in menuContainer.subviews) {
                if ([containerSubview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *effectView = (UIVisualEffectView *)containerSubview;
                    for (UIView *contentView in effectView.contentView.subviews) {
                        if ([contentView isKindOfClass:[UIScrollView class]]) {
                            scrollView = (UIScrollView *)contentView;
                            break;
                        }
                    }
                }
                if (scrollView) break;
            }
            break;
        }
    }
    
    if (!scrollView || !menuContainer) return;
    
    // 获取当前视图模式
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    // 恢复滚动视图内容的原始布局
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (moduleViews && moduleViews.count > 0) {
        [UIView animateWithDuration:0.3 animations:^{
            if (isListView) {
                // 恢复列表视图模式的原始布局
                CGFloat cellHeight = 56;
                for (NSInteger i = 0; i < moduleViews.count; i++) {
                    UIView *moduleView = moduleViews[i];
                    CGRect frame = moduleView.frame;
                    frame.origin.y = i * cellHeight;
                    moduleView.frame = frame;
                }
                
                // 更新内容大小
                scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, cellHeight * moduleViews.count);
                
            } else {
                // 恢复卡片视图模式的原始布局
                CGFloat moduleHeight = 80;
                CGFloat spacing = 16; // 恢复原始间距
                
                for (NSInteger i = 0; i < moduleViews.count; i++) {
                    UIView *moduleView = moduleViews[i];
                    CGRect frame = moduleView.frame;
                    frame.origin.y = spacing + i * (moduleHeight + spacing);
                    moduleView.frame = frame;
                }
                
                // 更新内容大小
                scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, (moduleHeight + spacing) * moduleViews.count + spacing);
            }
        }];
    }
}

%new
- (void)removeBreathingEffectFromHeaderView:(UIView *)headerView {
    [headerView.layer removeAnimationForKey:@"breathing"];
}

%new
- (void)enhanceCardHoverEffect:(UIButton *)button {
    // 卡片模式下的悬浮增强效果
    CAGradientLayer *hoverGradient = [CAGradientLayer layer];
    hoverGradient.frame = button.bounds;
    hoverGradient.cornerRadius = button.layer.cornerRadius;
    
    // 获取当前卡片渐变色
    NSArray *originalColors = nil;
    for (CALayer *layer in button.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            originalColors = [(CAGradientLayer *)layer colors];
            break;
        }
    }
    
    // 增强亮度制作悬浮效果
    NSMutableArray *enhancedColors = [NSMutableArray array];
    if (originalColors) {
        for (id colorRef in originalColors) {
            UIColor *originalColor = [UIColor colorWithCGColor:(__bridge CGColorRef)colorRef];
            CGFloat r, g, b, a;
            [originalColor getRed:&r green:&g blue:&b alpha:&a];
            
            // 提高颜色亮度，但保持色调
            UIColor *brighterColor = [UIColor colorWithRed:MIN(r + 0.1, 1.0)
                                                     green:MIN(g + 0.1, 1.0)
                                                      blue:MIN(b + 0.1, 1.0)
                                                     alpha:a];
            [enhancedColors addObject:(id)brighterColor.CGColor];
        }
    }
    
    // 应用增强效果
    [UIView animateWithDuration:0.18 animations:^{
        button.transform = CGAffineTransformMakeScale(1.03, 1.03);
        button.layer.shadowOpacity = 0.4;
        button.layer.shadowRadius = 12;
        
        // 更新卡片的渐变色
        for (CALayer *layer in button.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]] && enhancedColors.count > 0) {
                [(CAGradientLayer *)layer setColors:enhancedColors];
            }
        }
    }];
}

%new
- (void)restoreCardNormalEffect:(UIButton *)button {
    // 恢复卡片原始状态
    [UIView animateWithDuration:0.2 animations:^{
        button.transform = CGAffineTransformIdentity;
        button.layer.shadowOpacity = 0.25;
        button.layer.shadowRadius = 8;
    }];
    
    // 恢复原始渐变色
    DYYYMenuModule *module = objc_getAssociatedObject(button, "moduleData");
    if (module) {
        for (CALayer *layer in button.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]]) {
                CAGradientLayer *gradientLayer = (CAGradientLayer *)layer;
                gradientLayer.colors = @[
                    (id)[DYYYManager colorWithHexString:module.color].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0.1].CGColor
                ];
                break;
            }
        }
    }
}

%new
- (void)removeVisualGuidanceFromHeaderView:(UIView *)headerView {
    UIView *indicatorView = [headerView viewWithTag:9090];
    if (indicatorView) {
        [UIView animateWithDuration:0.2 animations:^{
            indicatorView.alpha = 0;
        } completion:^(BOOL finished) {
            [indicatorView removeFromSuperview];
        }];
    }
}

// ======== 截图功能方法实现 ========

%new
- (void)addMaterialEntranceCompleteEffect:(UIView *)container {
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @0.8;
    scaleAnimation.toValue = @1.0;
    scaleAnimation.duration = 0.3;
    scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [container.layer addAnimation:scaleAnimation forKey:@"materialEntrance"];
}

%new
- (void)addBreathingEffectToHeaderView:(UIView *)headerView {
    CABasicAnimation *breathingAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathingAnimation.fromValue = @1.0;
    breathingAnimation.toValue = @0.7;
    breathingAnimation.duration = 2.0;
    breathingAnimation.autoreverses = YES;
    breathingAnimation.repeatCount = HUGE_VALF;
    breathingAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [headerView.layer addAnimation:breathingAnimation forKey:@"breathing"];
}

%new
- (void)addVisualGuidanceToHeaderView:(UIView *)headerView {
    // 在顶部添加向下箭头指示
    UIImageView *arrowIndicator = [[UIImageView alloc] initWithFrame:CGRectMake((headerView.bounds.size.width - 20)/2, headerView.bounds.size.height - 25, 20, 15)];
    arrowIndicator.image = [UIImage systemImageNamed:@"chevron.down"];
    arrowIndicator.tintColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    arrowIndicator.tag = 9090; // 标记用于后续移除
    [headerView addSubview:arrowIndicator];
    
    // 添加脉动动画
    CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.fromValue = @1.0;
    pulseAnimation.toValue = @1.2;
    pulseAnimation.duration = 1.0;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.repeatCount = HUGE_VALF;
    [arrowIndicator.layer addAnimation:pulseAnimation forKey:@"pulse"];
}

%new
- (void)setupFluidScrolling:(UIScrollView *)scrollView {
    // 设置流体滚动属性
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    scrollView.alwaysBounceVertical = YES;
    
    // 添加滚动监听
    scrollView.delegate = (id<UIScrollViewDelegate>)self;
    
    // 保存原始内容边距
    objc_setAssociatedObject(scrollView, "originalInsets", [NSValue valueWithUIEdgeInsets:scrollView.contentInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 添加拉伸效果
    [self addParallaxEffectToModulesIn:scrollView];
}

%new
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateParallaxEffectForScrollView:scrollView];
    
    // 显示隐藏的头部控件
    CGFloat offset = scrollView.contentOffset.y;
    if (offset < -20) {
        [self showHeaderControlsWithAnimation];
        [self resetHeaderControlVisibility]; // 重置计时器
    }
}

%new
- (void)addParallaxEffectToModulesIn:(UIScrollView *)scrollView {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    for (UIView *moduleView in moduleViews) {
        // 为每个模块添加3D变换准备
        moduleView.layer.transform = CATransform3DIdentity;
        moduleView.layer.anchorPoint = CGPointMake(0.5, 0.5);
    }
}

%new
- (void)updateParallaxEffectForScrollView:(UIScrollView *)scrollView {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    CGFloat scrollOffset = scrollView.contentOffset.y;
    CGFloat screenHeight = scrollView.frame.size.height;
    
    for (UIView *moduleView in moduleViews) {
        // 计算模块在屏幕中的相对位置
        CGFloat moduleCenter = moduleView.frame.origin.y + moduleView.frame.size.height/2;
        CGFloat distanceFromCenter = moduleCenter - (scrollOffset + screenHeight/2);
        CGFloat normalizedDistance = distanceFromCenter / (screenHeight/2);
        
        // 应用轻微的旋转和缩放效果
        CGFloat rotationAngle = normalizedDistance * 0.02; // 极轻微的角度
        CGFloat scale = 1.0 - ABS(normalizedDistance) * 0.03; // 轻微的缩放
        scale = MAX(0.95, scale); // 缩放不小于0.95
        
        // 创建3D变换
        CATransform3D transform = CATransform3DIdentity;
        transform.m34 = -1.0 / 1000; // 控制透视效果
        transform = CATransform3DScale(transform, scale, scale, 1);
        transform = CATransform3DRotate(transform, rotationAngle, 1, 0, 0);
        
        // 应用变换
        moduleView.layer.transform = transform;
        
        // 更新透明度
        CGFloat alphaFactor = 1.0 - MIN(ABS(normalizedDistance) * 0.3, 0.3);
        moduleView.alpha = alphaFactor;
    }
}

%new
- (void)setupAppearanceObserver {
    if (@available(iOS 13.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleUserInterfaceStyleChanged:) 
                                                     name:@"UITraitCollectionDidChangeNotification" 
                                                   object:nil];
    }
}

%new
- (void)handleUserInterfaceStyleChanged:(NSNotification *)notification {
    UITraitCollection *traitCollection;
    if (@available(iOS 13.0, *)) {
        UIViewController *topVC = [DYYYManager getActiveTopController];
        traitCollection = topVC.traitCollection;
        
        // 查找并更新当前菜单面板
        for (UIView *view in topVC.view.subviews) {
            if (view.tag == 9527) {
                [self updateMenuAppearanceForDarkMode:(traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) menuContainer:view];
                break;
            }
        }
    }
}

%new
- (void)updateMenuAppearanceForDarkMode:(BOOL)isDarkMode menuContainer:(UIView *)overlayView {
    // 查找菜单容器及可能的毛玻璃效果视图
    UIView *menuContainer = nil;
    UIVisualEffectView *blurView = nil;
    
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            
            for (UIView *containerSubview in menuContainer.subviews) {
                if ([containerSubview isKindOfClass:[UIVisualEffectView class]]) {
                    blurView = (UIVisualEffectView *)containerSubview;
                    break;
                }
            }
            break;
        }
    }
    
    if (!blurView) return;
    
    // 获取保存的颜色，否则使用系统默认颜色
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBlurEffectColor"];
    UIColor *savedColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : nil;
    
    // 如果没有保存的颜色，根据当前模式使用默认颜色
    if (!savedColor) {
        UIBlurEffectStyle newStyle;
        if (@available(iOS 13.0, *)) {
            newStyle = isDarkMode ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        } else {
            newStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
        }
        
        // 应用新样式
        UIBlurEffect *newEffect = [UIBlurEffect effectWithStyle:newStyle];
        [UIView animateWithDuration:0.3 animations:^{
            [blurView setEffect:newEffect];
        }];
    } else {
        // 已有自定义颜色，调整其亮度以适应当前模式
        CGFloat h, s, b, a;
        [savedColor getHue:&h saturation:&s brightness:&b alpha:&a];
        
        UIColor *adjustedColor;
        if (isDarkMode && b > 0.5) {
            // 深色模式下，减少亮色的亮度
            adjustedColor = [UIColor colorWithHue:h saturation:s brightness:b * 0.7 alpha:a];
        } else if (!isDarkMode && b < 0.5) {
            // 浅色模式下，增加暗色的亮度
            adjustedColor = [UIColor colorWithHue:h saturation:s brightness:MIN(b * 1.3, 0.9) alpha:a];
        } else {
            adjustedColor = savedColor;
        }
        
        // 更新背景色视图
        UIView *colorView = [blurView.contentView viewWithTag:8888];
        if (colorView) {
            [UIView animateWithDuration:0.3 animations:^{
                colorView.backgroundColor = [adjustedColor colorWithAlphaComponent:0.3];
            }];
        }
    }
    
    // 更新文本和图标颜色
    [self updateMenuContentsForDarkMode:isDarkMode menuContainer:menuContainer];
}

%new
- (void)updateMenuContentsForDarkMode:(BOOL)isDarkMode menuContainer:(UIView *)menuContainer {
    // 遍历所有子视图，更新文本和图标颜色
    [self recursivelyUpdateView:menuContainer forDarkMode:isDarkMode];
}

%new
- (void)recursivelyUpdateView:(UIView *)view forDarkMode:(BOOL)isDarkMode {
    UIColor *textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
    UIColor *secondaryTextColor = isDarkMode ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor colorWithWhite:0.3 alpha:1.0];
    
    // 更新标签文本颜色
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        
        // 主要文本使用完全的黑/白
        if (label.font.pointSize >= 17) {
            label.textColor = textColor;
        } 
        // 次要文本（如副标题）使用较淡的颜色
        else {
            label.textColor = secondaryTextColor;
        }
    } 
    // 更新按钮文本颜色
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        [button setTitleColor:textColor forState:UIControlStateNormal];
    }
    
    // 递归处理所有子视图
    for (UIView *subview in view.subviews) {
        [self recursivelyUpdateView:subview forDarkMode:isDarkMode];
    }
}

%new
- (void)optimizeMenuPerformance {
    // 减少不必要的视图层次
    [self reduceViewHierarchyForActiveMenu];
    
    // 启用栅格化以提高滚动性能
    [self enableRasterizationForMenuItems];
    
    // 异步加载模块数据
    [self loadModuleDataAsynchronously];
}

%new
- (void)reduceViewHierarchyForActiveMenu {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    // 获取所有模块视图
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 只保留可见区域附近的模块视图渲染，其他视图简化处理
    CGRect visibleBounds = CGRectMake(0, scrollView.contentOffset.y, scrollView.bounds.size.width, scrollView.bounds.size.height);
    visibleBounds = CGRectInset(visibleBounds, 0, -100); // 上下扩展100点，提前渲染减少白屏
    
    for (UIView *moduleView in moduleViews) {
        if (CGRectIntersectsRect(moduleView.frame, visibleBounds)) {
            // 在可见区域，确保完全渲染
            moduleView.hidden = NO;
            for (UIView *subview in moduleView.subviews) {
                if ([subview isKindOfClass:[UIButton class]]) {
                    for (CALayer *layer in subview.layer.sublayers) {
                        layer.opacity = 1.0;
                    }
                }
                subview.hidden = NO;
            }
        } else {
            // 不在可见区域，简化渲染
            if (CGRectGetMinY(moduleView.frame) < CGRectGetMinY(visibleBounds) - 200 ||
                CGRectGetMaxY(moduleView.frame) > CGRectGetMaxY(visibleBounds) + 200) {
                // 距离可见区域很远的视图可以隐藏
                moduleView.hidden = YES;
            } else {
                // 稍远的视图简化渲染，但保持可见
                moduleView.hidden = NO;
                for (UIView *subview in moduleView.subviews) {
                    if ([subview isKindOfClass:[UIButton class]]) {
                        // 隐藏复杂的图层效果
                        for (CALayer *layer in subview.layer.sublayers) {
                            if (![layer isKindOfClass:[CAGradientLayer class]]) {
                                layer.opacity = 0.0;
                            }
                        }
                    }
                }
            }
        }
    }
}

%new
- (void)enableRasterizationForMenuItems {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    // 获取所有模块视图
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 为模块视图启用栅格化
    for (UIView *moduleView in moduleViews) {
        // 只对复杂UI的按钮组件启用栅格化
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 检查是否有多个子层或渐变
                BOOL hasComplexLayers = NO;
                for (CALayer *layer in button.layer.sublayers) {
                    if ([layer isKindOfClass:[CAGradientLayer class]]) {
                        hasComplexLayers = YES;
                        break;
                    }
                }
                
                if (button.subviews.count > 2 || hasComplexLayers) {
                    button.layer.shouldRasterize = YES;
                    button.layer.rasterizationScale = [UIScreen mainScreen].scale;
                }
            }
        }
    }
}

%new
- (void)loadModuleDataAsynchronously {
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(backgroundQueue, ^{
        // 在后台线程加载和处理模块数据
        NSArray<DYYYMenuModule *> *modules = [self createMenuModulesForCurrentContext];
        
        // 应用智能排序（如果启用）
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableSmartOrdering"]) {
            modules = [self applySmartOrderingToModules:modules];
        }
        
        // 回到主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            // 刷新菜单显示
            [self recreateMenuButtonsWithModules:modules];
        });
    });
}

%new
- (void)showVisualStyleSelector:(UIButton *)sender {
    UIAlertController *styleSheet = [UIAlertController alertControllerWithTitle:@"视觉风格"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 获取当前选择的风格
    DYYYMenuVisualStyle currentStyle = (DYYYMenuVisualStyle)[[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYMenuVisualStyle"];
    
    // 添加风格选项
    UIAlertAction *classicAction = [UIAlertAction actionWithTitle:@"默认" 
                                                            style:(currentStyle == DYYYMenuVisualStyleClassic) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [self changeVisualStyle:DYYYMenuVisualStyleClassic];
    }];
    
    UIAlertAction *neuomorphicAction = [UIAlertAction actionWithTitle:@"新UI风格" 
                                                                style:(currentStyle == DYYYMenuVisualStyleNeuomorphic) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        [self changeVisualStyle:DYYYMenuVisualStyleNeuomorphic];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    
    [styleSheet addAction:classicAction];
    [styleSheet addAction:neuomorphicAction];
    [styleSheet addAction:cancelAction];
    
    // 在iPad上设置源视图
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        styleSheet.popoverPresentationController.sourceView = sender;
        styleSheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    [[DYYYManager getActiveTopController] presentViewController:styleSheet animated:YES completion:nil];
}

%new
- (void)changeVisualStyle:(DYYYMenuVisualStyle)style {
    // 保存用户选择
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:@"DYYYMenuVisualStyle"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 重建菜单
    UIScrollView *scrollView = [self findScrollViewInTopViewController:[DYYYManager getActiveTopController]];
    if (!scrollView) return;
    
    // 获取模块数据
    NSArray<DYYYMenuModule *> *modules = [self createMenuModulesForCurrentContext];
    
    // 获取当前布局样式
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    DYYYMenuStyle layoutStyle = isListView ? DYYYMenuStyleList : DYYYMenuStyleCard;
    
    // 使用直接构建器实例化
    DYYYMenuStyleBuilder *builder = nil;
    BOOL isLayoutList = (layoutStyle == DYYYMenuStyleList);

    if (style == DYYYMenuVisualStyleNeuomorphic) {
        builder = [[DYYYNeuomorphicStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
    } else {
        if (isLayoutList) {
            builder = [[DYYYListStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        } else {
            builder = [[DYYYCardStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        }
    }
    builder.delegate = self;
    
    // 构建菜单
    [builder buildMenuWithAnimation:YES];
    
    // 字体规范化处理
    [self normalizeListViewFonts:scrollView];
    
    // 触感反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
    
    // 重置自动隐藏计时器
    [self resetHeaderControlVisibility];
}

%new
- (void)applyModernVisualStyle:(DYYYMenuStyleBuilder *)builder scrollView:(UIScrollView *)scrollView {
    // 在这里应用现代风格的通用特性
    scrollView.contentInset = UIEdgeInsetsMake(10, 0, 10, 0);
    
    // 对现有模块视图应用现代风格
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    for (UIView *moduleView in moduleViews) {
        // 查找按钮
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 添加磨砂效果
                UIVisualEffectView *blurEffect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
                blurEffect.frame = button.bounds;
                blurEffect.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                blurEffect.layer.cornerRadius = button.layer.cornerRadius;
                blurEffect.layer.masksToBounds = YES;
                [button insertSubview:blurEffect atIndex:0];
                
                // 更新阴影效果
                button.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.2].CGColor;
                button.layer.shadowOffset = CGSizeMake(0, 6);
                button.layer.shadowRadius = 12;
                button.layer.shadowOpacity = 0.3;
                
                // 调整子视图位置，确保在磨砂效果上方
                for (UIView *buttonSubview in button.subviews) {
                    if (buttonSubview != blurEffect) {
                        [button bringSubviewToFront:buttonSubview];
                    }
                }
            }
        }
    }
}

%new
- (void)applyModernVisualStyle:(UIScrollView *)scrollView {
    // 应用现代风格的通用特性
    scrollView.contentInset = UIEdgeInsetsMake(10, 0, 10, 0);
    
    // 对现有模块视图应用现代风格
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    for (UIView *moduleView in moduleViews) {
        // 查找按钮
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 添加磨砂效果
                UIVisualEffectView *blurEffect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
                blurEffect.frame = button.bounds;
                blurEffect.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                blurEffect.layer.cornerRadius = button.layer.cornerRadius;
                blurEffect.layer.masksToBounds = YES;
                [button insertSubview:blurEffect atIndex:0];
                
                // 更新阴影效果
                button.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.2].CGColor;
                button.layer.shadowOffset = CGSizeMake(0, 6);
                button.layer.shadowRadius = 12;
                button.layer.shadowOpacity = 0.3;
                
                // 调整子视图位置，确保在磨砂效果上方
                for (UIView *buttonSubview in button.subviews) {
                    if (buttonSubview != blurEffect) {
                        [button bringSubviewToFront:buttonSubview];
                    }
                }
            }
        }
    }
}

%new
- (UIColor *)getOptimalTextColorForBackground:(UIColor *)backgroundColor {
    CGFloat r, g, b, a;
    [backgroundColor getRed:&r green:&g blue:&b alpha:&a];
    
    // 计算亮度 (基于人眼对不同颜色的感知)
    CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    
    // 阈值0.5：亮度高于0.5使用深色文本，否则使用浅色文本
    return (luminance > 0.5) ? [UIColor colorWithWhite:0.1 alpha:1.0] : [UIColor colorWithWhite:0.95 alpha:1.0];
}

%new
- (void)applyTextColorForButton:(UIButton *)button withBackgroundColor:(UIColor *)backgroundColor {
    // 获取最佳文本颜色
    UIColor *textColor = [self getOptimalTextColorForBackground:backgroundColor];
    
    // 应用到按钮上的所有文本标签
    for (UIView *subview in button.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            
            // 根据字体大小区分主标题和副标题，应用不同深浅的颜色
            if (label.font.pointSize >= 16) {
                // 主标题
                label.textColor = textColor;
            } else {
                // 副标题 - 使用半透明版本
                label.textColor = [textColor colorWithAlphaComponent:0.7];
            }
        }
    }
    
    // 同时更新按钮自身的文本颜色
    [button setTitleColor:textColor forState:UIControlStateNormal];
}

%new
- (void)enhanceModernVisualStyle:(UIScrollView *)scrollView {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 确定当前是列表视图还是卡片视图
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    for (NSInteger i = 0; i < moduleViews.count; i++) {
        UIView *moduleView = moduleViews[i];
        
        // 查找按钮
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 清除现有效果
                for (UIView *existingEffectView in button.subviews) {
                    if ([existingEffectView isKindOfClass:[UIVisualEffectView class]]) {
                        [existingEffectView removeFromSuperview];
                    }
                }
                
                // 创建更强烈的磨砂效果
                UIBlurEffectStyle blurStyle;
                if (@available(iOS 13.0, *)) {
                    blurStyle = UIBlurEffectStyleSystemThinMaterialLight;
                } else {
                    blurStyle = UIBlurEffectStyleExtraLight;
                }
                
                UIVisualEffectView *blurEffect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
                blurEffect.frame = button.bounds;
                blurEffect.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                blurEffect.layer.cornerRadius = button.layer.cornerRadius;
                blurEffect.layer.masksToBounds = YES;
                [button insertSubview:blurEffect atIndex:0];
                
                // 添加多层次视觉效果，使磨砂风格更加突出
                UIView *gradientOverlay = [[UIView alloc] initWithFrame:button.bounds];
                gradientOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                gradientOverlay.layer.cornerRadius = button.layer.cornerRadius;
                gradientOverlay.layer.masksToBounds = YES;
                
                CAGradientLayer *shineLayer = [CAGradientLayer layer];
                shineLayer.frame = gradientOverlay.bounds;
                shineLayer.colors = @[
                    (id)[UIColor colorWithWhite:1.0 alpha:0.3].CGColor,
                    (id)[UIColor colorWithWhite:1.0 alpha:0.1].CGColor
                ];
                shineLayer.startPoint = CGPointMake(0, 0);
                shineLayer.endPoint = CGPointMake(1, 1);
                shineLayer.cornerRadius = button.layer.cornerRadius;
                [gradientOverlay.layer addSublayer:shineLayer];
                
                [blurEffect.contentView addSubview:gradientOverlay];
                
                // 查找模块关联数据
                DYYYMenuModule *module = objc_getAssociatedObject(button, "moduleData");
                if (module) {
                    // 添加彩色边框效果
                    CALayer *borderLayer = [CALayer layer];
                    borderLayer.frame = button.bounds;
                    borderLayer.cornerRadius = button.layer.cornerRadius;
                    borderLayer.borderWidth = 1.5;
                    borderLayer.borderColor = [[DYYYManager colorWithHexString:module.color] colorWithAlphaComponent:0.5].CGColor;
                    [button.layer addSublayer:borderLayer];
                    
                    // 添加图标光晕效果
                    for (UIView *iconView in button.subviews) {
                        if ([iconView isKindOfClass:[UIImageView class]]) {
                            // 为图标添加轻微的发光效果
                            iconView.layer.shadowColor = [DYYYManager colorWithHexString:module.color].CGColor;
                            iconView.layer.shadowOffset = CGSizeMake(0, 0);
                            iconView.layer.shadowOpacity = 0.8;
                            iconView.layer.shadowRadius = 6.0;
                            
                            // 确保图标始终在最前面
                            [button bringSubviewToFront:iconView];
                            break;
                        }
                    }
                    
                    // 根据背景设置最佳文本颜色
                    [self applyTextColorForButton:button withBackgroundColor:[UIColor colorWithWhite:0.95 alpha:1.0]];
                }
                
                // 卡片特有的装饰和阴影效果
                if (!isListView) {
                    // 更强的阴影效果
                    button.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.3].CGColor;
                    button.layer.shadowOffset = CGSizeMake(0, 8);
                    button.layer.shadowRadius = 16;
                    button.layer.shadowOpacity = 0.4;
                    
                    // 添加细微的移动动画，让卡片看起来更加"活"
                    CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
                    floatAnimation.fromValue = @(0);
                    floatAnimation.toValue = @(-2.0 - i * 0.2); // 卡片位置越高，浮动效果越明显
                    floatAnimation.duration = 2.0 + i * 0.1;
                    floatAnimation.autoreverses = YES;
                    floatAnimation.repeatCount = HUGE_VALF;
                    floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                    
                    // 添加动画延迟，使卡片不会同步浮动
                    floatAnimation.beginTime = CACurrentMediaTime() + i * 0.2;
                    
                    [button.layer addAnimation:floatAnimation forKey:@"floatAnimation"];
                }
                
                // 列表特有的装饰效果
                else {
                    // 增加列表项之间的分隔边距
                    moduleView.frame = CGRectInset(moduleView.frame, 0, 2);
                    
                    // 添加轻微的横向弹性动画
                    CABasicAnimation *elasticAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                    elasticAnimation.fromValue = @(0);
                    elasticAnimation.toValue = @(1.5);
                    elasticAnimation.duration = 1.8 + i * 0.2;
                    elasticAnimation.autoreverses = YES;
                    elasticAnimation.repeatCount = HUGE_VALF;
                    elasticAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                    elasticAnimation.beginTime = CACurrentMediaTime() + i * 0.15;
                    
                    [button.layer addAnimation:elasticAnimation forKey:@"elasticAnimation"];
                }
            }
        }
    }
    
    // 应用整体滚动视图效果优化
    scrollView.contentInset = UIEdgeInsetsMake(12, 0, 12, 0);
    scrollView.showsVerticalScrollIndicator = NO;
}

%new
- (UIView *)createNeuomorphicListItemForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index {
    // 查找正确的构建器对象
    UIScrollView *scrollView = [self findScrollViewInTopViewController:[DYYYManager getActiveTopController]];
    if (!scrollView) return nil;
    
    // 获取当前可能存在的DYYYNeuomorphicStyleBuilder实例
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return nil;
    
    // 寻找构建器实例
    id builder = objc_getAssociatedObject(scrollView, "styleBuilder");
    if (builder && [builder isKindOfClass:%c(DYYYNeuomorphicStyleBuilder)] && 
        [builder respondsToSelector:@selector(createNeuomorphicListItemForModule:atIndex:)]) {
        // 调用构建器的实际方法
        return [builder createNeuomorphicListItemForModule:module atIndex:index];
    }
    
    // 如果没找到正确的构建器，则创建一个临时的来处理请求
    DYYYNeuomorphicStyleBuilder *tempBuilder = [[%c(DYYYNeuomorphicStyleBuilder) alloc] initWithScrollView:scrollView 
                                                                                                   modules:@[module]];
    tempBuilder.delegate = self;
    return [tempBuilder createNeuomorphicListItemForModule:module atIndex:index];
}

%new
- (void)normalizeListViewFonts:(UIScrollView *)scrollView {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 获取菜单背景视图以判断深浅色模式
    UIView *menuContainer = scrollView.superview;
    BOOL isDarkMode = NO;
    
    if ([menuContainer isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *effectView = (UIVisualEffectView *)menuContainer;
        UIBlurEffectStyle style = [self inferVisualEffectStyle:effectView.effect];
        isDarkMode = (style == UIBlurEffectStyleDark);
        
        // 检查自定义背景色
        for (UIView *subview in effectView.contentView.subviews) {
            if (subview.tag == 8888) {
                CGFloat r = 0, g = 0, b = 0, a = 0;
                [subview.backgroundColor getRed:&r green:&g blue:&b alpha:&a];
                CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * b;
                isDarkMode = (luminance < 0.5);
                break;
            }
        }
    }
    
    // 根据深浅背景选择合适的文字颜色
    UIColor *textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
    
    // 检查是否为列表模式，列表模式优先使用黑色
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    if (isListView && !isDarkMode) {
        textColor = [UIColor blackColor]; // 列表模式默认使用黑色
    }
    
    UIFont *titleFont = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    
    for (UIView *moduleView in moduleViews) {
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 统一设置所有按钮内标签的字体
                for (UIView *buttonSubview in button.subviews) {
                    if ([buttonSubview isKindOfClass:[UILabel class]]) {
                        UILabel *label = (UILabel *)buttonSubview;
                        
                        // 确保主标签字体一致
                        if (label.frame.origin.x > 50 && label.frame.size.width > 100) {  // 这是标题标签
                            label.font = titleFont;
                            label.textColor = textColor; // 应用正确的文本颜色
                        }
                    }
                }
            }
        }
    }
}

%new
- (void)optimizeRenderPipeline {
    // 获取关键视图
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    // 应用高级GPU渲染优化
    CATransform3D perspectiveTransform = CATransform3DIdentity;
    perspectiveTransform.m34 = -1.0 / 900.0; // 精确的3D空间透视参数
    
    // 获取模块视图
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 应用渲染管线优化
    for (UIView *moduleView in moduleViews) {
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 高级渲染优化
                button.layer.cornerRadius = button.layer.cornerRadius; // 触发重新计算圆角路径
                button.layer.shouldRasterize = true;
                button.layer.rasterizationScale = [UIScreen mainScreen].scale;
                button.layer.allowsEdgeAntialiasing = true;
                button.layer.drawsAsynchronously = true;
                
                // 高效内存填充算法
                button.contentScaleFactor = [UIScreen mainScreen].scale;
                
                // 优化层次渲染
                for (CALayer *layer in button.layer.sublayers) {
                    if ([layer isKindOfClass:[CAGradientLayer class]]) {
                        // 提高渐变层的渲染性能
                        ((CAGradientLayer *)layer).drawsAsynchronously = true;
                    }
                    
                    // 修复: 使用字符串而不是装箱表达式
                    [layer setValue:@"RGBA8" forKey:@"contentsFormat"];
                }
            }
        }
    }
    
    // 提升滚动性能
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    if (@available(iOS 13.0, *)) {
        scrollView.automaticallyAdjustsScrollIndicatorInsets = NO;
    }
    
    // 预计算所有内容，减少滚动时重新计算
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    scrollView.layer.shouldRasterize = YES;
    scrollView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    [CATransaction commit];
    
    // 延迟恢复栅格化以避免内存占用
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        scrollView.layer.shouldRasterize = NO;
    });
}

%new
- (void)enhanceTouchResponsiveness {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIScrollView *scrollView = [self findScrollViewInView:[topVC.view viewWithTag:9527]];
    if (!scrollView) return;
    
    // 获取对象
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    for (UIView *moduleView in moduleViews) {
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 修复：使用正确的边距属性
                // 通过扩大内部内容区域来实现类似扩大触摸区域的效果
                button.contentEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
                
                // 优化触摸响应链
                [button setValue:@YES forKey:@"delaysTouchesBegan"];
                [button setValue:@0.01 forKey:@"touchDelay"];
                
                // 预先加载触感引擎，显著提升响应速度
                if (@available(iOS 13.0, *)) {
                    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
                    [generator prepare];
                    objc_setAssociatedObject(button, "feedbackGenerator", generator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
        }
    }
}

%new
- (void)applyContentParallaxEffect:(UIView *)parentView {
    UIScrollView *scrollView = [self findScrollViewInView:parentView];
    if (!scrollView) return;
    
    // 获取对象
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 添加滚动监听
    [scrollView removeObserver:self forKeyPath:@"contentOffset" context:NULL];
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
    
    // 设置初始状态
    [self updateParallaxEffectsForScrollView:scrollView];
}

%new
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([object isKindOfClass:[UIScrollView class]] && [keyPath isEqualToString:@"contentOffset"]) {
        [self updateParallaxEffectsForScrollView:(UIScrollView *)object];
    }
}

%new
- (void)updateParallaxEffectsForScrollView:(UIScrollView *)scrollView {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    CGFloat scrollOffset = scrollView.contentOffset.y;
    CGFloat screenHeight = scrollView.frame.size.height;
    
    // 高性能批量处理
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    for (UIView *moduleView in moduleViews) {
        // 计算每个模块的视差效果
        CGFloat modulePosition = moduleView.frame.origin.y + moduleView.frame.size.height/2;
        CGFloat distanceFromCenter = modulePosition - (scrollOffset + screenHeight/2);
        CGFloat normalizedDistance = distanceFromCenter / (screenHeight/2);
        
        // 计算高级变换
        CATransform3D transform = CATransform3DIdentity;
        transform.m34 = -1.0 / 1000;  // 透视效果
        
        // Z轴位移创造深度感
        CGFloat zPosition = -normalizedDistance * 20;
        transform = CATransform3DTranslate(transform, 0, 0, zPosition);
        
        // 轻微的倾斜
        CGFloat rotationAngle = normalizedDistance * 0.03;
        transform = CATransform3DRotate(transform, rotationAngle, 1, 0, 0);
        
        // 轻微的缩放
        CGFloat scale = 1.0 - ABS(normalizedDistance) * 0.02;
        transform = CATransform3DScale(transform, scale, scale, 1);
        
        // 应用高性能变换
        moduleView.layer.transform = transform;
    }
    
    [CATransaction commit];
}

%new
- (void)enhanceVisualContent {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 高效计算一次背景色亮度
    UIColor *backgroundColor = [UIColor clearColor];
    for (UIView *subview in overlayView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *visualEffectView = (UIVisualEffectView *)subview;
            for (UIView *effectSubview in visualEffectView.contentView.subviews) {
                if (effectSubview.tag == 8888) {
                    backgroundColor = effectSubview.backgroundColor;
                    break;
                }
            }
            break;
        }
    }
    
    // 高性能计算亮度
    CGFloat luminance = 0.5;
    CGFloat r, g, b, a;
    [backgroundColor getRed:&r green:&g blue:&b alpha:&a];
    luminance = (0.299 * r + 0.587 * g + 0.114 * b);
    
    // 智能文本颜色
    UIColor *textColor = (luminance > 0.5) ? [UIColor colorWithWhite:0.1 alpha:1] : [UIColor colorWithWhite:0.9 alpha:1];
    
    // 批量更新文本颜色 - 高效处理
    for (UIView *moduleView in moduleViews) {
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                for (UIView *buttonSubview in button.subviews) {
                    if ([buttonSubview isKindOfClass:[UILabel class]]) {
                        [(UILabel *)buttonSubview setTextColor:textColor];
                    } else if ([buttonSubview isKindOfClass:[UIImageView class]]) {
                        [(UIImageView *)buttonSubview setTintColor:textColor];
                    }
                }
            }
        }
    }
}

%new
- (void)optimizeUIKernelMechanics {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIScrollView *scrollView = [self findScrollViewInView:[topVC.view viewWithTag:9527]];
    if (!scrollView) return;
    
    // 应用高级物理模型到滚动视图
    if (@available(iOS 13.0, *)) {
        // 修复：使用简单的动画而不是UIPropertyAnimator
        [UIView animateWithDuration:0.2 animations:^{
            scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }];
    }
    
    // 通知系统触发UI更新
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    // 同步显示器刷新率
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(syncWithDisplayRefresh:)];
    // 强引用保存，便于退出时失效，避免 self 释放后仍回调
    objc_setAssociatedObject(self, "dyyy_displayLink_syncWith", displayLink, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (@available(iOS 15.0, *)) {
        displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 120, 120);
    }
    
    [CATransaction commit];
    
    // 优化核心动画处理部分
    [scrollView setValue:@(YES) forKey:@"_allowsRootLayerFlatteningWhenScrolling"];
}

%new
- (void)optimizeViewPerformance {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    // 1. 减少主线程负担
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // 提前准备核心资源
        UIImage *placeholderImage = [UIImage new];
        NSMutableDictionary *preloadedResources = [NSMutableDictionary dictionary];
        
        // 回到主线程优化UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyPerformanceOptimizations:overlayView withResources:preloadedResources];
        });
    });
    
    // 2. 应用关键渲染路径优化
    [self optimizeRenderPath:overlayView];
}

%new
- (void)applyPerformanceOptimizations:(UIView *)view withResources:(NSDictionary *)resources {
    // 找到滚动视图并优化
    UIScrollView *scrollView = [self findScrollViewInView:view];
    if (!scrollView) return;
    
    // 核心性能优化 - 预渲染关键路径内容
    scrollView.directionalLockEnabled = YES;
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    
    // 减少重绘次数，提高流畅度
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    // 滚动视图优化
    scrollView.layer.shouldRasterize = NO; // 滚动时栅格化反而会降低性能
    scrollView.layer.drawsAsynchronously = YES;
    
    // 使用异步渲染，减轻主线程压力
    for (UIView *subview in scrollView.subviews) {
        subview.layer.drawsAsynchronously = YES;
        
        // 对包含复杂内容的视图进行特别优化
        if (subview.subviews.count > 3) {
            // 减少不可见区域的渲染成本
            for (UIView *innerView in subview.subviews) {
                if ([innerView isKindOfClass:[UIImageView class]]) {
                    ((UIImageView *)innerView).contentMode = UIViewContentModeScaleAspectFill;
                }
            }
        }
    }
    
    [CATransaction commit];
    
    // 注册内存预警监听
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleMemoryWarning) 
                                                 name:UIApplicationDidReceiveMemoryWarningNotification 
                                               object:nil];
}

%new
- (void)optimizeRenderPath:(UIView *)rootView {
    UIScrollView *scrollView = [self findScrollViewInView:rootView];
    if (!scrollView) return;
    
    // 显示层绘制优化
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(syncRenderLoop:)];
    displayLink.preferredFramesPerSecond = 60;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(scrollView, "smoothRenderDisplayLink", displayLink, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 设置视觉预热
    [self preloadVisibleContent:scrollView];
    
    // 添加滚动优化监听器
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
}

// 清理新增的 KVO、CADisplayLink 与通知，避免对象释放后仍有主线程回调

- (void)dealloc {
    @try {
        UIView *rootView = self.view;
        UIScrollView *scrollView = [self findScrollViewInView:rootView];
        if (scrollView) {
            @try { [scrollView removeObserver:self forKeyPath:@"contentOffset"]; } @catch (__unused NSException *e) {}
            CADisplayLink *smoothLink = objc_getAssociatedObject(scrollView, "smoothRenderDisplayLink");
            if (smoothLink) {
                [smoothLink invalidate];
                objc_setAssociatedObject(scrollView, "smoothRenderDisplayLink", nil, OBJC_ASSOCIATION_ASSIGN);
            }
        }
    } @catch (__unused NSException *e) {}

    CADisplayLink *syncLink = objc_getAssociatedObject(self, "dyyy_displayLink_syncWith");
    if (syncLink) {
        [syncLink invalidate];
        objc_setAssociatedObject(self, "dyyy_displayLink_syncWith", nil, OBJC_ASSOCIATION_ASSIGN);
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)syncWithDisplayRefresh:(CADisplayLink *)displayLink {
    // 获取当前活动菜单
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    // 实时同步视图更新与显示刷新率
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    // 优化可见区域的渲染质量
    CGRect visibleRect = CGRectMake(scrollView.contentOffset.x, 
                                   scrollView.contentOffset.y, 
                                   scrollView.bounds.size.width, 
                                   scrollView.bounds.size.height);
    visibleRect = CGRectInset(visibleRect, 0, -100); // 上下额外预渲染区域
    
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    for (UIView *moduleView in moduleViews) {
        // 优先处理可见区域内的视图
        BOOL isVisible = CGRectIntersectsRect(moduleView.frame, visibleRect);
        if (isVisible) {
            // 确保可见区域内的视图高质量渲染
            moduleView.layer.shouldRasterize = NO;
            moduleView.alpha = 1.0;
        } else {
            // 非可见区域使用栅格化提升性能
            moduleView.layer.shouldRasterize = YES;
            moduleView.layer.rasterizationScale = [UIScreen mainScreen].scale;
        }
    }
}

%new
- (void)syncRenderLoop:(CADisplayLink *)displayLink {
    // 记录绘制时间
    static CFTimeInterval lastTimestamp = 0;
    CFTimeInterval timeDelta = lastTimestamp == 0 ? 0 : displayLink.timestamp - lastTimestamp;
    lastTimestamp = displayLink.timestamp;
    
    // 获取 scrollView：避免使用 assign 关联造成悬挂指针，这里每帧安全获取
    UIScrollView *scrollView = nil;
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (topVC) {
        UIView *overlayView = [topVC.view viewWithTag:9527];
        if (overlayView) {
            scrollView = [self findScrollViewInView:overlayView];
        }
    }
    if (!scrollView || !scrollView.window) {
        return;
    }
    
    // 动态优化可见区域内的模块
    CGRect visibleRect = CGRectMake(scrollView.contentOffset.x, 
                                    scrollView.contentOffset.y, 
                                    scrollView.bounds.size.width, 
                                    scrollView.bounds.size.height);
    
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 批量处理更新，减少重绘
    [CATransaction begin];
    [CATransaction setDisableActions:YES]; // 禁用隐式动画
    
    for (UIView *moduleView in moduleViews) {
        BOOL isVisible = CGRectIntersectsRect(moduleView.frame, visibleRect);
        if (isVisible) {
            // 优先级提升，提高可见区域的视觉质量
            if (moduleView.layer.shouldRasterize) {
                moduleView.layer.shouldRasterize = NO;
            }
            
            // 顺滑过渡
            if (moduleView.alpha < 1.0) {
                moduleView.alpha = 1.0;
            }
        } else if (!CGRectIntersectsRect(moduleView.frame, CGRectInset(visibleRect, -100, -200))) {
            // 远离可视区域的模块降低渲染优先级
            if (!moduleView.layer.shouldRasterize) {
                moduleView.layer.shouldRasterize = YES;
                moduleView.layer.rasterizationScale = [UIScreen mainScreen].scale;
            }
        }
    }
    
    [CATransaction commit];
}

%new
- (void)preloadVisibleContent:(UIScrollView *)scrollView {
    // 预先加载当前可见区域及即将滚动到的区域
    CGRect expandedVisibleRect = CGRectMake(0, scrollView.contentOffset.y - scrollView.bounds.size.height * 0.5, 
                                          scrollView.bounds.size.width, 
                                          scrollView.bounds.size.height * 2); // 上下多加载半屏
    
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    // 对可见区域和即将进入可见区域的模块进行预热
    NSMutableArray *viewsToPreload = [NSMutableArray array];
    for (UIView *moduleView in moduleViews) {
        if (CGRectIntersectsRect(moduleView.frame, expandedVisibleRect)) {
            [viewsToPreload addObject:moduleView];
        }
    }
    
    // 分批处理，避免一次性处理过多导致卡顿
    NSInteger batchSize = 3;
    for (NSInteger i = 0; i < viewsToPreload.count; i += batchSize) {
        NSInteger endIndex = MIN(i + batchSize, viewsToPreload.count);
        NSArray *batch = [viewsToPreload subarrayWithRange:NSMakeRange(i, endIndex - i)];
        
        // 使用适当延迟，错开处理时间
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i/batchSize * 0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (UIView *view in batch) {
                // 预热处理 - 触发布局计算
                [view setNeedsLayout];
                [view layoutIfNeeded];
                
                // 对按钮和图像进行特殊处理
                for (UIView *subview in view.subviews) {
                    if ([subview isKindOfClass:[UIButton class]]) {
                        UIButton *button = (UIButton *)subview;
                        // 预加载按钮状态
                        [button setNeedsDisplay];
                        
                        // 预热图像缓存
                        for (UIView *btnSubview in button.subviews) {
                            if ([btnSubview isKindOfClass:[UIImageView class]]) {
                                UIImageView *imageView = (UIImageView *)btnSubview;
                                [imageView setNeedsDisplay];
                            }
                        }
                    }
                }
            }
        });
    }
}

%new
- (void)handleMemoryWarning {
    // 内存预警时释放资源
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIScrollView *scrollView = [self findScrollViewInView:[topVC.view viewWithTag:9527]];
    
    if (scrollView) {
        // 清理非可见区域的缓存
        NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
        if (!moduleViews) return;
        
        CGRect visibleRect = CGRectMake(0, scrollView.contentOffset.y, 
                                      scrollView.bounds.size.width, 
                                      scrollView.bounds.size.height);
        
        for (UIView *moduleView in moduleViews) {
            if (!CGRectIntersectsRect(moduleView.frame, visibleRect)) {
                // 释放非可见视图的资源
                for (UIView *subview in moduleView.subviews) {
                    if ([subview isKindOfClass:[UIButton class]]) {
                        // 清理按钮上的过渡效果
                        subview.layer.shouldRasterize = NO;
                        
                        // 移除不必要的动画
                        [subview.layer removeAllAnimations];
                    }
                }
            }
        }
    }
    
    // 清理图像缓存
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

%new
- (void)optimizeGestureResponseTime {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIScrollView *scrollView = [self findScrollViewInView:[topVC.view viewWithTag:9527]];
    if (!scrollView) return;
    
    // 优化触摸响应 - 减少延迟
    scrollView.delaysContentTouches = NO;
    scrollView.canCancelContentTouches = YES;
    
    // 提高ScrollView的减速率，使滚动更流畅
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
}

%new
- (void)applyHighPerformanceTransforms {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIScrollView *scrollView = [self findScrollViewInView:[topVC.view viewWithTag:9527]];
    if (!scrollView) return;
    
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    for (UIView *moduleView in moduleViews) {
        // 子视图层优化
        moduleView.layer.masksToBounds = NO;
        
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)subview;
                
                // 启用更高效的渲染
                button.opaque = YES; // 减少混合
                button.layer.masksToBounds = YES;
                
                // 优化图像渲染
                for (UIView *btnSubview in button.subviews) {
                    if ([btnSubview isKindOfClass:[UIImageView class]]) {
                        UIImageView *imageView = (UIImageView *)btnSubview;
                        imageView.layer.minificationFilter = kCAFilterTrilinear;
                        imageView.layer.magnificationFilter = kCAFilterTrilinear;
                    }
                }
            }
        }
    }
}

%end
