#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"


static void DYYYUpdateBlurEffectForTraitCollection(UIView *view, UITraitCollection *traitCollection);
static void DYYYOptimizeBlurViewPerformance(UIVisualEffectView *blurView);
static void DYYYUpdateBlurEffectForView(UIView *containerView, float transparency, BOOL isDarkMode);

@interface AWEBaseListViewController (DYYYBlurEffect)
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency;
- (void)setTextColorAndShadowInView:(UIView *)view textColor:(UIColor *)textColor isDarkMode:(BOOL)isDarkMode transparency:(float)transparency;
- (void)applyBlurEffectIfNeeded;
@end

@interface AWECommentInputViewSwiftImpl_CommentInputContainerView (DYYYBlurEffect)
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency;
- (void)setTextColorAndShadowInView:(UIView *)view textColor:(UIColor *)textColor isDarkMode:(BOOL)isDarkMode transparency:(float)transparency;
@end

@interface AWEInnerNotificationWindow (DYYYBlurEffect)
- (void)setupBlurEffectForNotificationView;
- (void)findAndApplyBlurEffectToNotificationViews:(UIView *)parentView;
- (void)applyBlurEffectToView:(UIView *)containerView;
- (void)clearBackgroundRecursivelyInView:(UIView *)view exceptClass:(Class)exceptClass;
- (void)adjustTextColorInView:(UIView *)view darkMode:(BOOL)isDarkMode;
- (void)setLabelsColorWhiteInView:(UIView *)view;
- (void)clearBackgroundRecursivelyInView:(UIView *)view;
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency;
@end

@interface AWEUserActionSheetView (DYYYBlurEffect)
- (void)applyBlurEffectAndWhiteText;
- (void)setTextColorWhiteRecursivelyInView:(UIView *)view;
@property(nonatomic, strong) UIView *containerView;
@end

// MARK: - 配置常量和工具函数
static NSString * const kDYYYCommentBlurEnabledKey = @"DYYYisEnableCommentBlur";
static NSString * const kDYYYCommentBlurTransparentKey = @"DYYYCommentBlurTransparent";
static NSString * const kDYYYSheetBlurEnabledKey = @"DYYYisEnableSheetBlur";
static NSString * const kDYYYSheetBlurTransparentKey = @"DYYYSheetBlurTransparent";
static NSString * const kDYYYNotificationEnabledKey = @"DYYYEnableNotificationTransparency";
static NSString * const kDYYYNotificationCornerRadiusKey = @"DYYYNotificationCornerRadius";

// 获取用户设置的透明度值
static float DYYYGetUserTransparency(NSString *key, float defaultValue) {
    float value = [[[NSUserDefaults standardUserDefaults] objectForKey:key] floatValue];
    return (value <= 0 || value > 1) ? defaultValue : value;
}

// 检查功能是否启用
static BOOL DYYYIsFunctionEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

// 简单日志函数
static void DYYYLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"[DYYY] %@", message);
}

// 定义一个共享的颜色配置函数
static void DYYYConfigureSharedBlurAppearance(UIVisualEffectView *blurView, float transparency, BOOL isDarkMode) {
    // 统一设置透明度
    blurView.alpha = transparency;
    
    // 统一设置覆盖层颜色
    for (UIView *subview in blurView.contentView.subviews) {
        if ([subview isKindOfClass:[UIView class]] && ![subview isKindOfClass:[UIVisualEffectView class]]) {
            // 对于深色/浅色模式使用相同的颜色处理逻辑
            CGFloat overlayAlpha = isDarkMode ? 0.2 : 0.1;
            subview.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:overlayAlpha];
        }
    }
}

// MARK: - 性能优化相关函数
static void DYYYSetupViewHierarchyForBlur(UIView *view, BOOL preserveSpecialViews) {
    if (!view) return;
    
    // 跳过特殊视图
    if (preserveSpecialViews) {
        if ([view isKindOfClass:[UIImageView class]] || 
            [view isKindOfClass:[UILabel class]] ||
            [view isKindOfClass:[UIButton class]] ||
            [view isKindOfClass:[UIVisualEffectView class]]) {
            return;
        }
    }
    
    // 设置背景透明
    view.backgroundColor = [UIColor clearColor];
    
    // 标记层，避免重复处理
    static NSMapTable *processedViews;
    if (!processedViews) {
        processedViews = [NSMapTable weakToStrongObjectsMapTable];
    }
    
    if ([processedViews objectForKey:view]) {
        return;
    }
    
    [processedViews setObject:@YES forKey:view];
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        DYYYSetupViewHierarchyForBlur(subview, preserveSpecialViews);
    }
}

// 通过运行时检查视图类型
static BOOL DYYYIsViewEligibleForBlur(UIView *view, NSArray *classNamePatterns) {
    if (!view) return NO;
    
    NSString *className = NSStringFromClass([view class]);
    for (NSString *pattern in classNamePatterns) {
        if ([className containsString:pattern]) {
            return YES;
        }
    }
    return NO;
}

// MARK: - 通用文本增强函数
static void DYYYEnhanceTextForBlurEffect(UIView *view, float transparency, BOOL isDarkMode) {
    if (!view) return;
    
    // 检查是否为评论内容视图，如果是则跳过文本颜色处理
    NSString *viewClassName = NSStringFromClass([view class]);
    if ([viewClassName containsString:@"AWEComment"] && 
        [viewClassName containsString:@"Content"]) {
        return;
    }
    
    // 根据透明度计算合适的文本颜色
    CGFloat textAlpha = transparency < 0.3 ? 1.0 : (transparency < 0.6 ? 0.95 : 0.9);
    UIColor *textColor = isDarkMode ? 
                         [UIColor colorWithWhite:1.0 alpha:textAlpha] : 
                         [UIColor colorWithWhite:0.0 alpha:textAlpha];
    
    // 递归设置文本颜色和阴影
    for (UIView *subview in view.subviews) {
        // 跳过特定的视图类型，避免修改关键UI元素
        NSString *subviewClassName = NSStringFromClass([subview class]);
        if ([subviewClassName containsString:@"AWEComment"] && 
            ([subviewClassName containsString:@"Content"] || 
             [subviewClassName containsString:@"Cell"] || 
             [subviewClassName containsString:@"Text"])) {
            continue;
        }
        
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            // 不修改已有特定颜色的标签
            if (![label.textColor isEqual:[UIColor blackColor]] && 
                ![label.textColor isEqual:[UIColor whiteColor]]) {
                continue;
            }
            
            label.textColor = textColor;
            
            // 透明度低时添加阴影增强可读性
            if (transparency < 0.4) {
                label.shadowColor = isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];
                label.shadowOffset = CGSizeMake(0.5, 0.5);
            } else {
                label.shadowColor = nil;
                label.shadowOffset = CGSizeZero;
            }
        } 
        else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            // 检查按钮是否有自定义颜色
            UIColor *currentColor = [button titleColorForState:UIControlStateNormal];
            if (![currentColor isEqual:[UIColor blackColor]] && 
                ![currentColor isEqual:[UIColor whiteColor]]) {
                continue;
            }
            
            [button setTitleColor:textColor forState:UIControlStateNormal];
            
            if (transparency < 0.4) {
                button.titleLabel.shadowColor = isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];
                button.titleLabel.shadowOffset = CGSizeMake(0.5, 0.5);
            } else {
                button.titleLabel.shadowColor = nil;
                button.titleLabel.shadowOffset = CGSizeZero;
            }
        }
        else if ([subview isKindOfClass:[UITextField class]] || 
                 [subview isKindOfClass:[UITextView class]]) {
            // 检查输入框是否有自定义颜色
            UIColor *currentColor = [(id)subview textColor];
            if (![currentColor isEqual:[UIColor blackColor]] && 
                ![currentColor isEqual:[UIColor whiteColor]]) {
                continue;
            }
            
            [(id)subview setTextColor:textColor];
        }
        
        // 递归处理子视图
        if (subview.subviews.count > 0) {
            DYYYEnhanceTextForBlurEffect(subview, transparency, isDarkMode);
        }
    }
}

// MARK: - 毛玻璃效果工具函数
static UIVisualEffectView *DYYYCreateBlurEffectView(UIView *containerView, float transparency, BOOL isDarkMode) {
    if (!containerView) return nil;
    
    // 验证透明度参数
    transparency = (transparency <= 0 || transparency > 1) ? 0.5 : transparency;
    
    UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    
    blurEffectView.frame = containerView.bounds;
    blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurEffectView.alpha = transparency;
    blurEffectView.tag = 9999;
    
    // 添加颜色覆盖层
    UIView *overlayView = [[UIView alloc] initWithFrame:containerView.bounds];
    CGFloat overlayAlpha = isDarkMode ? 0.2 : 0.1;
    overlayView.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:overlayAlpha];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [blurEffectView.contentView addSubview:overlayView];
    
    return blurEffectView;
}

// 应用毛玻璃效果的统一接口
static void DYYYApplyBlurEffect(UIView *view, float transparency) {
    if (!view) return;
    
    // 移除已存在的毛玻璃效果
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 9999) {
            [subview removeFromSuperview];
        }
    }
    
    // 设置背景透明
    view.backgroundColor = [UIColor clearColor];
    
    // 创建并应用毛玻璃效果
    BOOL isDarkMode = [DYYYManager isDarkMode];
    UIVisualEffectView *blurEffectView = DYYYCreateBlurEffectView(view, transparency, isDarkMode);
    
    // 插入到视图层次底部
    [view insertSubview:blurEffectView atIndex:0];
}

// MARK: - 递归设置子视图透明背景的工具函数
static void DYYYSetViewsTransparent(UIView *view, BOOL skipSpecialViews) {
    if (!view) return;
    
    // 可选择性跳过特定类型的视图
    if (skipSpecialViews) {
        if ([view isKindOfClass:[UIImageView class]] || 
            [view isKindOfClass:[UILabel class]] ||
            [view isKindOfClass:[UIButton class]] ||
            [view isKindOfClass:[UIVisualEffectView class]]) {
            return;
        }
    }
    
    // 设置当前视图背景透明
    view.backgroundColor = [UIColor clearColor];
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        DYYYSetViewsTransparent(subview, skipSpecialViews);
    }
}

// MARK: - 兼容性函数（保持向后兼容）
static void DYYYAddCustomViewToParent(UIView *view, CGFloat transparency) {
    DYYYApplyBlurEffect(view, transparency);
}

// 第二个重载函数的兼容性实现
static void DYYYAddCustomViewToParent2(UIView *parentView, float transparency) {
    DYYYApplyBlurEffect(parentView, transparency);
}

// MARK: - 专门用于评论输入框的毛玻璃效果
static void DYYYApplyCommentInputBlur(UIView *view) {
    // 获取用户设置的透明度
    float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
    if (userTransparency <= 0 || userTransparency > 1) {
        userTransparency = 0.5;
    }
    
    // 应用毛玻璃效果
    DYYYApplyBlurEffect(view, userTransparency);
    
    // 设置子视图背景透明（保留文本控件可见性）
    DYYYSetViewsTransparent(view, YES);
}

// MARK: - 评论区毛玻璃效果
%hook AWEBaseListViewController

// MARK: - 用于文本增强的函数
%new
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency {
    // 根据透明度自动调整文本颜色的对比度
    // 当透明度很低时，需要更强的文本对比度
    
    BOOL isDarkMode = [DYYYManager isDarkMode];
    CGFloat textAlpha = 1.0;
    UIColor *textColor;
    
    // 当透明度较低时增加文本对比度
    if (transparency < 0.3) {
        textAlpha = 1.0; // 文本完全不透明
        textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor]; // 高对比度颜色
    } else if (transparency < 0.6) {
        textAlpha = 0.95;
        textColor = isDarkMode ? [UIColor colorWithWhite:1.0 alpha:textAlpha] : 
                              [UIColor colorWithWhite:0.0 alpha:textAlpha];
    } else {
        textAlpha = 0.9;
        textColor = isDarkMode ? [UIColor colorWithWhite:0.9 alpha:textAlpha] : 
                              [UIColor colorWithWhite:0.1 alpha:textAlpha];
    }
    
    // 为文本元素添加阴影以增强可读性
    [self setTextColorAndShadowInView:containerView textColor:textColor isDarkMode:isDarkMode transparency:transparency];
}

%new
- (void)setTextColorAndShadowInView:(UIView *)view textColor:(UIColor *)textColor isDarkMode:(BOOL)isDarkMode transparency:(float)transparency {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = textColor;
            
            // 根据透明度和模式添加阴影
            if (transparency < 0.4) {
                // 低透明度下添加文字阴影增强可读性
                label.shadowColor = isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];
                label.shadowOffset = CGSizeMake(0.5, 0.5);
            } else {
                label.shadowColor = nil;
                label.shadowOffset = CGSizeZero;
            }
        } 
        else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitleColor:textColor forState:UIControlStateNormal];
            
            // 设置按钮标题阴影
            if (transparency < 0.4) {
                button.titleLabel.shadowColor = isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];
                button.titleLabel.shadowOffset = CGSizeMake(0.5, 0.5);
            } else {
                button.titleLabel.shadowColor = nil;
                button.titleLabel.shadowOffset = CGSizeZero;
            }
        }
        else if ([subview isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)subview;
            textField.textColor = textColor;
        }
        else if ([subview isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)subview;
            textView.textColor = textColor;
        }
        
        // 递归处理子视图
        if (subview.subviews.count > 0) {
            [self setTextColorAndShadowInView:subview textColor:textColor isDarkMode:isDarkMode transparency:transparency];
        }
    }
}

%new
- (void)applyBlurEffectIfNeeded {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"] &&
        [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {

        @try {
            self.view.backgroundColor = [UIColor clearColor];
            for (UIView *subview in self.view.subviews) {
                if (![subview isKindOfClass:[UIVisualEffectView class]]) {
                    subview.backgroundColor = [UIColor clearColor];
                }
            }

            UIVisualEffectView *existingBlurView = nil;
            for (UIView *subview in self.view.subviews) {
                if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
                    existingBlurView = (UIVisualEffectView *)subview;
                    break;
                }
            }

            BOOL isDarkMode = [DYYYManager isDarkMode];
            UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;

            // 使用统一的透明度值
            float userTransparency = DYYYGetUserTransparency(@"DYYYCommentBlurTransparent", 0.5);

            if (!existingBlurView) {
                UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
                UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
                blurEffectView.frame = self.view.bounds;
                blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                blurEffectView.tag = 999;

                // 创建一个覆盖层
                UIView *overlayView = [[UIView alloc] initWithFrame:self.view.bounds];
                overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [blurEffectView.contentView addSubview:overlayView];
                
                // 使用共享配置函数
                DYYYConfigureSharedBlurAppearance(blurEffectView, userTransparency, isDarkMode);

                [self.view insertSubview:blurEffectView atIndex:0];
            } else {
                UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
                [existingBlurView setEffect:blurEffect];
                
                // 使用共享配置函数
                DYYYConfigureSharedBlurAppearance(existingBlurView, userTransparency, isDarkMode);

                [self.view insertSubview:existingBlurView atIndex:0];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"[DYYY] Exception in applyBlurEffectIfNeeded: %@", exception);
        }
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self applyBlurEffectIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self applyBlurEffectIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self applyBlurEffectIfNeeded];
}

%end

// MARK: - 评论输入框毛玻璃效果
%hook AWECommentInputViewSwiftImpl_CommentInputContainerView

%new
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency {
    // 检查是否为特定的评论控制器
    if (![NSStringFromClass([self class]) containsString:@"AWECommentPanelContainer"]) {
        return;
    }
    
    BOOL isDarkMode = [DYYYManager isDarkMode];
    CGFloat textAlpha = 1.0;
    UIColor *textColor;
    
    // 当透明度较低时增加文本对比度
    if (transparency < 0.3) {
        textAlpha = 1.0; // 文本完全不透明
        textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor]; // 高对比度颜色
    } else if (transparency < 0.6) {
        textAlpha = 0.95;
        textColor = isDarkMode ? [UIColor colorWithWhite:1.0 alpha:textAlpha] : 
                              [UIColor colorWithWhite:0.0 alpha:textAlpha];
    } else {
        textAlpha = 0.9;
        textColor = isDarkMode ? [UIColor colorWithWhite:0.9 alpha:textAlpha] : 
                              [UIColor colorWithWhite:0.1 alpha:textAlpha];
    }
    
    // 仅处理非内容视图的文本元素
    [self setTextColorAndShadowInView:containerView textColor:textColor isDarkMode:isDarkMode transparency:transparency];
}

%new
- (void)setTextColorAndShadowInView:(UIView *)view textColor:(UIColor *)textColor isDarkMode:(BOOL)isDarkMode transparency:(float)transparency {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = textColor;
            
            if (transparency < 0.4) {
                label.shadowColor = isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];
                label.shadowOffset = CGSizeMake(0.5, 0.5);
            } else {
                label.shadowColor = nil;
                label.shadowOffset = CGSizeZero;
            }
        } 
        else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitleColor:textColor forState:UIControlStateNormal];
            
            if (transparency < 0.4) {
                button.titleLabel.shadowColor = isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];
                button.titleLabel.shadowOffset = CGSizeMake(0.5, 0.5);
            } else {
                button.titleLabel.shadowColor = nil;
                button.titleLabel.shadowOffset = CGSizeZero;
            }
        }
        else if ([subview isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)subview;
            textField.textColor = textColor;
        }
        else if ([subview isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)subview;
            textView.textColor = textColor;
        }
        
        if (subview.subviews.count > 0) {
            [self setTextColorAndShadowInView:subview textColor:textColor isDarkMode:isDarkMode transparency:transparency];
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        // 使用与评论区相同的透明度配置
        float userTransparency = DYYYGetUserTransparency(@"DYYYCommentBlurTransparent", 0.5);
        
        BOOL isDarkMode = [DYYYManager isDarkMode];
        UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
        
        // 移除已有的毛玻璃效果
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
                [subview removeFromSuperview];
            }
        }
        
        // 设置背景为透明
        self.backgroundColor = [UIColor clearColor];
        
        // 创建并添加毛玻璃效果
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.frame = self.bounds;
        blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurEffectView.tag = 999;
        
        // 添加覆盖层
        UIView *overlayView = [[UIView alloc] initWithFrame:self.bounds];
        overlayView.userInteractionEnabled = NO;
        overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [blurEffectView.contentView addSubview:overlayView];
        
        // 使用共享配置函数确保一致性
        DYYYConfigureSharedBlurAppearance(blurEffectView, userTransparency, isDarkMode);
        
        // 插入到视图层次最底部
        [self insertSubview:blurEffectView atIndex:0];
        
        // 确保内容控件和文本保持可见
        for (UIView *subview in self.subviews) {
            if (![subview isKindOfClass:[UIVisualEffectView class]]) {
                [subview setBackgroundColor:[UIColor clearColor]];
            }
        }
        
        // 应用文本增强处理
        [self adjustTextVisibilityForBlurEffect:self transparency:userTransparency];
    }
}

%end

// MARK: - 评论输入框背景控制
%hook AWECommentInputViewSwiftImpl_CommentInputBackgroundView

- (void)layoutSubviews {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        // 保持完全透明，确保上层的毛玻璃效果可见
        self.backgroundColor = [UIColor clearColor];
        
        // 确保所有子视图也是透明的
        for (UIView *subview in self.subviews) {
            if (![subview isKindOfClass:[UIVisualEffectView class]]) {
                [subview setBackgroundColor:[UIColor clearColor]];
            }
        }
    }
}

%end

// MARK: - 文本框容器处理
%hook AWETextViewContainer

- (void)layoutSubviews {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        float userTransparency = DYYYGetUserTransparency(@"DYYYCommentBlurTransparent", 0.5);
        BOOL isDarkMode = [DYYYManager isDarkMode];
        
        // 使用更一致的背景处理方式
        if (isDarkMode) {
            // 深色模式下使用相同的背景色调
            self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:userTransparency * 0.7];
        } else {
            // 浅色模式下使用相同的背景色调
            self.backgroundColor = [UIColor colorWithWhite:0.95 alpha:userTransparency * 0.7];
        }
    }
}

%end

// MARK: - 统一输入框和键盘样式
%hook AWECommentInputViewSwiftImpl_CommentInputBar

- (void)layoutSubviews {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        // 设置输入框背景透明
        self.backgroundColor = [UIColor clearColor];
        
        // 遍历所有子视图设置透明
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                continue;
            }
            
            // 保持控件可见，背景透明
            if ([subview isKindOfClass:[UIButton class]] || 
                [subview isKindOfClass:[UITextField class]] ||
                [subview isKindOfClass:[UITextView class]]) {
                continue;
            }
            
            // 其他视图背景透明
            subview.backgroundColor = [UIColor clearColor];
        }
    }
}

%end

// MARK: - UIView毛玻璃处理
%hook UIView

- (void)layoutSubviews {
    %orig;
    
    // 只针对特定视图处理，避免范围过大
    NSString *className = NSStringFromClass([self class]);
    BOOL shouldApplyEffects = 
        [className containsString:@"AWECommentInput"] ||
        [className containsString:@"AWECommentPanel"] ||
        [className containsString:@"AWEInnerNotification"];
    
    // 如果不是目标类型，直接返回，避免不必要的处理
    if (!shouldApplyEffects) {
        return;
    }
    
    // 以下部分保留原有的特定逻辑
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer")]) {
                BOOL containsDanmu = NO;

                for (UIView *innerSubview in subview.subviews) {
                    if ([innerSubview isKindOfClass:[UILabel class]] && [((UILabel *)innerSubview).text containsString:@"弹幕"]) {
                        containsDanmu = YES;
                        break;
                    }
                }
                if (containsDanmu) {
                    UIView *parentView = subview.superview;
                    for (UIView *innerSubview in parentView.subviews) {
                        if ([innerSubview isKindOfClass:[UIView class]]) {
                            // 确保视图索引有效，避免崩溃
                            if (innerSubview.subviews.count > 0) {
                                [innerSubview.subviews[0] removeFromSuperview];
                                
                                UIView *whiteBackgroundView = [[UIView alloc] initWithFrame:innerSubview.bounds];
                                whiteBackgroundView.backgroundColor = [UIColor whiteColor];
                                whiteBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                                [innerSubview addSubview:whiteBackgroundView];
                            }
                            break;
                        }
                    }
                } else {
                    for (UIView *innerSubview in subview.subviews) {
                        if ([innerSubview isKindOfClass:[UIView class]]) {
                            float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
                            if (userTransparency <= 0 || userTransparency > 1) {
                                userTransparency = 0.95;
                            }
                            DYYYAddCustomViewToParent(innerSubview, userTransparency);
                            break;
                        }
                    }
                }
            }
        }
    }
    
    // 特定的评论容器视图处理
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        if ([className isEqualToString:@"AWECommentInputViewSwiftImpl.CommentInputContainerView"]) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor) {
                    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
                    
                    // 安全处理颜色提取，避免崩溃
                    if ([subview.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
                        if ((red == 22 / 255.0 && green == 22 / 255.0 && blue == 22 / 255.0) || (red == 1.0 && green == 1.0 && blue == 1.0)) {
                            float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
                            if (userTransparency <= 0 || userTransparency > 1) {
                                userTransparency = 0.95;
                            }
                            DYYYAddCustomViewToParent(subview, userTransparency);
                        }
                    }
                }
            }
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    
    // 仅在深色模式状态变更时更新，且限制处理范围
    if (@available(iOS 13.0, *)) {
        UITraitCollection *currentTraitCollection = self.traitCollection;
        if ([previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:currentTraitCollection]) {
            
            // 仅处理特定视图
            NSString *className = NSStringFromClass([self class]);
            if ([className containsString:@"AWECommentInput"] ||
                [className containsString:@"AWEBaseList"] ||
                [className containsString:@"AWEInnerNotification"] || 
                [className containsString:@"AWEUserActionSheet"]) {
                
                // 延迟执行以确保视图层次已完成更新
                dispatch_async(dispatch_get_main_queue(), ^{
                    DYYYUpdateBlurEffectForTraitCollection(self, currentTraitCollection);
                });
            }
        }
    }
}

%end

// MARK: - 应用内推送毛玻璃效果
%hook AWEInnerNotificationWindow

- (id)initWithFrame:(CGRect)frame {
    id orig = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNotificationTransparency"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupBlurEffectForNotificationView];
        });
    }
    return orig;
}

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNotificationTransparency"]) {
        [self setupBlurEffectForNotificationView];
    }
}

- (void)didMoveToWindow {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNotificationTransparency"]) {
        [self setupBlurEffectForNotificationView];
    }
}

- (void)didAddSubview:(UIView *)subview {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNotificationTransparency"] && 
        [NSStringFromClass([subview class]) containsString:@"AWEInnerNotificationContainerView"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupBlurEffectForNotificationView];
        });
    }
}

%new
- (void)setupBlurEffectForNotificationView {
    // 遍历查找通知容器视图
    [self findAndApplyBlurEffectToNotificationViews:self];
}

%new
- (void)findAndApplyBlurEffectToNotificationViews:(UIView *)parentView {
    for (UIView *subview in parentView.subviews) {
        // 检查是否是通知容器视图
        if ([NSStringFromClass([subview class]) containsString:@"AWEInnerNotificationContainerView"] ||
            [NSStringFromClass([subview class]) containsString:@"InnerNotification"]) {
            [self applyBlurEffectToView:subview];
        }
        
        // 递归搜索子视图
        if (subview.subviews.count > 0) {
            [self findAndApplyBlurEffectToNotificationViews:subview];
        }
    }
}

%new
- (void)applyBlurEffectToView:(UIView *)containerView {
    if (!containerView) return;

    // 检查功能是否启用
    if (!DYYYIsFunctionEnabled(kDYYYNotificationEnabledKey)) return;

    // 移除现有的毛玻璃效果
    for (UIView *subview in containerView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
            [subview removeFromSuperview];
        }
    }

    // 设置容器视图为透明
    containerView.backgroundColor = [UIColor clearColor];

    // 获取用户设置的圆角半径
    float cornerRadius = DYYYGetUserTransparency(kDYYYNotificationCornerRadiusKey, 12.0);
    
    // 应用圆角
    containerView.layer.cornerRadius = cornerRadius;
    containerView.layer.masksToBounds = YES;

    // 判断当前的界面模式
    BOOL isDarkMode = NO;
    if (@available(iOS 13.0, *)) {
        isDarkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    } else {
        isDarkMode = [DYYYManager isDarkMode];
    }
    
    // 创建毛玻璃效果
    UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];

    // 设置毛玻璃视图属性
    blurView.frame = containerView.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.tag = 999;
    blurView.layer.cornerRadius = cornerRadius;
    blurView.layer.masksToBounds = YES;

    // 获取用户设置的透明度
    float transparency = DYYYGetUserTransparency(kDYYYNotificationEnabledKey, 0.7);
    blurView.alpha = transparency;

    // 添加额外的颜色调整层
    UIView *overlayView = [[UIView alloc] initWithFrame:containerView.bounds];
    overlayView.userInteractionEnabled = NO;
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlayView.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:(isDarkMode ? 0.2 : 0.1)];
    [blurView.contentView addSubview:overlayView];

    // 优化性能
    DYYYOptimizeBlurViewPerformance(blurView);

    // 插入毛玻璃视图到最底层
    [containerView insertSubview:blurView atIndex:0];

    // 递归设置子视图背景透明
    [self clearBackgroundRecursivelyInView:containerView exceptClass:[UIVisualEffectView class]];
    
    // 应用文本增强处理
    [self adjustTextVisibilityForBlurEffect:containerView transparency:transparency];
}

%end

// MARK: - 暗黑模式适配增强
static void DYYYUpdateBlurEffectForTraitCollection(UIView *view, UITraitCollection *traitCollection) {
    if (!view) return;
    
    // 查找现有的毛玻璃效果视图
    UIVisualEffectView *blurView = nil;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && (subview.tag == 9999 || subview.tag == 999)) {
            blurView = (UIVisualEffectView *)subview;
            break;
        }
    }
    
    if (!blurView) return;
    
    // 根据当前特征集合确定是否为深色模式
    BOOL isDarkMode = NO;
    if (@available(iOS 13.0, *)) {
        isDarkMode = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    } else {
        isDarkMode = [DYYYManager isDarkMode];
    }
    
    // 更新毛玻璃效果样式
    UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    blurView.effect = blurEffect;
    
    // 更新覆盖层颜色
    for (UIView *subview in blurView.contentView.subviews) {
        CGFloat overlayAlpha = isDarkMode ? 0.2 : 0.1;
        subview.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:overlayAlpha];
    }
    
    // 更新文本颜色
    float transparency = blurView.alpha;
    DYYYEnhanceTextForBlurEffect(view, transparency, isDarkMode);
}

// MARK: - 性能优化扩展
static void DYYYOptimizeBlurViewPerformance(UIVisualEffectView *blurView) {
    if (!blurView) return;
    
    // 检查是否需要减少模糊效果的绘制质量以提高性能
    BOOL isLowPowerMode = NO;
    if (@available(iOS 9.0, *)) {
        isLowPowerMode = [NSProcessInfo processInfo].lowPowerModeEnabled;
    }
    
    if (isLowPowerMode) {
        // 在低电量模式下降低模糊质量
        blurView.alpha = MIN(blurView.alpha, 0.7);
    }
    
    // 设置更佳的绘制模式
    blurView.layer.shouldRasterize = YES;
    blurView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    blurView.layer.drawsAsynchronously = YES;
}

// MARK: - 统一的更新处理接口
static void DYYYUpdateBlurEffectForView(UIView *containerView, float transparency, BOOL isDarkMode) {
    // 移除现有效果
    for (UIView *subview in containerView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && (subview.tag == 9999 || subview.tag == 999)) {
            [subview removeFromSuperview];
        }
    }
    
    // 创建新效果
    UIVisualEffectView *blurView = DYYYCreateBlurEffectView(containerView, transparency, isDarkMode);
    
    // 应用性能优化
    DYYYOptimizeBlurViewPerformance(blurView);
    
    // 插入视图
    [containerView insertSubview:blurView atIndex:0];
    
    // 提升文本可读性
    DYYYEnhanceTextForBlurEffect(containerView, transparency, isDarkMode);
}