#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"

// 定义常量
#ifndef DYYY_IGNORE_GLOBAL_ALPHA_TAG
#define DYYY_IGNORE_GLOBAL_ALPHA_TAG 88888
#endif

// 前向声明 DYYYLayoutStateManager
@class DYYYLayoutStateManager;

@interface DYYYLayoutStateManager : NSObject
@property (nonatomic, assign) BOOL isLayoutInProgress;
@property (nonatomic, assign) BOOL isTabHeightUpdating;
@property (nonatomic, assign) NSTimeInterval lastLayoutTime;
+ (instancetype)sharedManager;
- (BOOL)canPerformLayoutOperation;
- (void)markLayoutStart;
- (void)markLayoutEnd;
@end

@implementation DYYYLayoutStateManager

+ (instancetype)sharedManager {
    static DYYYLayoutStateManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _isLayoutInProgress = NO;
        _isTabHeightUpdating = NO;
        _lastLayoutTime = 0;
    }
    return self;
}

- (BOOL)canPerformLayoutOperation {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    // 如果距离上次操作时间小于阈值，则不允许进行新的布局操作
    if (now - self.lastLayoutTime < 0.1) {
        return NO;
    }
    
    // 如果正在进行布局，则不允许重入
    if (self.isLayoutInProgress) {
        return NO;
    }
    
    return YES;
}

- (void)markLayoutStart {
    self.isLayoutInProgress = YES;
    self.lastLayoutTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)markLayoutEnd {
    self.isLayoutInProgress = NO;
}

- (void)temporarilyPausedLayoutForSettingChange {
    self.isLayoutInProgress = YES;
    
    // 自动恢复
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.isLayoutInProgress = NO;
    });
}

- (void)performSafeLayoutBlock:(void(^)(void))layoutBlock {
    if (self.isLayoutInProgress) {
        // 布局中，延迟执行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performSafeLayoutBlock:layoutBlock];
        });
        return;
    }
    
    [self markLayoutStart];
    @try {
        if (layoutBlock) {
            layoutBlock();
        }
    } @finally {
        [self markLayoutEnd];
    }
}

@end

@interface UIView (DYYYHelper)
- (UIViewController *)firstAvailableUIViewController;
@end

@implementation UIView (DYYYHelper)
- (UIViewController *)firstAvailableUIViewController {
    // 从视图向上查找第一个可用的视图控制器
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}
@end

@interface AWELiveProgressView : UIView
@end

static UIButton *speedButton = nil;

// 添加 tabHeight 变量声明
static CGFloat tabHeight = 0;

// 更精准的标签栏高度计算（每次都重新计算，不缓存）
static CGFloat getTabBarHeight(void) {
    DYYYLayoutStateManager *stateManager = [DYYYLayoutStateManager sharedManager];
    
    // 如果正在更新中，返回缓存值
    if (stateManager.isTabHeightUpdating) {
        return tabHeight > 0 ? tabHeight : 83.0;
    }
    
    static CGFloat cachedHeight = 83.0;
    static NSTimeInterval lastUpdateTime = 0;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    // 增加缓存时间到2秒，减少频繁计算
    if (now - lastUpdateTime < 2.0) {
        return cachedHeight;
    }

    // 标记正在更新
    stateManager.isTabHeightUpdating = YES;
    
    CGFloat measuredHeight = 83.0;
    @try {
        UIWindow *keyWindow = [DYYYManager getActiveWindow];
        if (!keyWindow || !keyWindow.rootViewController || !keyWindow.rootViewController.view) {
            measuredHeight = cachedHeight;
            goto cleanup;
        }

        // 确保视图已经完成布局
        if (keyWindow.rootViewController.view.frame.size.height < 100) {
            measuredHeight = cachedHeight;
            goto cleanup;
        }

        // 查找TabBar - 使用更安全的遍历方式
        NSArray *subviews = [keyWindow.rootViewController.view.subviews copy];
        for (UIView *subview in subviews) {
            @try {
                NSString *className = NSStringFromClass([subview class]);
                if ([className containsString:@"TabBar"] && subview.frame.size.height > 0) {
                    CGFloat h = subview.frame.size.height;
                    if (h >= 30 && h <= 120) {
                        measuredHeight = h;
                        NSLog(@"[DYYY] 安全测量标签栏高度: %f", h);
                        break;
                    }
                }
            } @catch (NSException *innerException) {
                continue; // 跳过有问题的子视图
            }
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 获取TabBar高度异常: %@", exception);
        measuredHeight = cachedHeight;
    }

cleanup:
    cachedHeight = measuredHeight;
    lastUpdateTime = now;
    tabHeight = measuredHeight;
    stateManager.isTabHeightUpdating = NO;
    
    return measuredHeight;
}

// 初始化 tabHeight
static void initializeTabHeight(void) __attribute__((constructor));
static void initializeTabHeight(void) {
    tabHeight = getTabBarHeight();
}

static void DYYYUpdateBlurEffectForTraitCollection(UIView *view, UITraitCollection *traitCollection);
static void DYYYOptimizeBlurViewPerformance(UIVisualEffectView *blurView);
static void DYYYUpdateBlurEffectForView(UIView *containerView, float transparency, BOOL isDarkMode);
static void DYYYRemoveBlurViewsWithTag(UIView *view, NSInteger tag);

@interface AWEBaseListViewController (DYYYBlurEffect)
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency;
- (void)setTextColorAndShadowInView:(UIView *)view textColor:(UIColor *)textColor isDarkMode:(BOOL)isDarkMode transparency:(float)transparency;
- (void)applyBlurEffectIfNeeded;
- (void)dyyySettingChanged:(NSNotification *)note;
@end

@interface AWECommentInputViewSwiftImpl_CommentInputContainerView (DYYYBlurEffect)
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency;
- (void)setTextColorAndShadowInView:(UIView *)view textColor:(UIColor *)textColor isDarkMode:(BOOL)isDarkMode transparency:(float)transparency;
- (void)dyyySettingChanged:(NSNotification *)note;
@end

@interface AWEInnerNotificationWindow (DYYYBlurEffect)
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency;
- (void)setupBlurEffectForNotificationView;
- (void)findAndApplyBlurEffectToNotificationViews:(UIView *)parentView;
- (void)findAndApplyBlurEffectToNotificationViews:(UIView *)parentView depth:(int)depth;
- (void)applyBlurEffectToView:(UIView *)containerView;
- (void)clearBackgroundRecursivelyInView:(UIView *)view exceptClass:(Class)exceptClass;
- (void)adjustTextColorInView:(UIView *)view darkMode:(BOOL)isDarkMode;
- (void)setLabelsColorWhiteInView:(UIView *)view;
- (void)clearBackgroundRecursivelyInView:(UIView *)view;
@end

@interface AWEUserActionSheetView (DYYYBlurEffect)
- (void)applyBlurEffectAndWhiteText;
- (void)setTextColorWhiteRecursivelyInView:(UIView *)view;
@property(nonatomic, strong) UIView *containerView;
@end

@interface AWEPlayInteractionViewController (DYYYBlurEffect)
- (void)performSafeLayoutAdjustment;
@end

@interface AWEAwemeDetailNaviBarContainerView : UIView
@end

// MARK: - 配置常量和工具函数
static NSString * const kDYYYCommentBlurEnabledKey = @"DYYYisEnableCommentBlur";
static NSString * const kDYYYCommentBlurTransparentKey = @"DYYYCommentBlurTransparent";
static NSString * const kDYYYSheetBlurEnabledKey = @"DYYYisEnableSheetBlur";
static NSString * const kDYYYSheetBlurTransparentKey = @"DYYYSheetBlurTransparent";
static NSString * const kDYYYNotificationEnabledKey = @"DYYYEnableNotificationTransparency";
static NSString * const kDYYYNotificationTransparentKey = @"DYYYNotificationBlurTransparent";
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

// 定义共享的颜色配置函数
static void DYYYConfigureSharedBlurAppearance(UIVisualEffectView *blurView, float transparency, BOOL isDarkMode) {
    if (!blurView) return;
    
    blurView.alpha = transparency;
    
    // 检查 contentView 是否存在
    if (!blurView.contentView) return;
    
    for (UIView *subview in blurView.contentView.subviews) {
        if ([subview isKindOfClass:[UIView class]] && ![subview isKindOfClass:[UIVisualEffectView class]]) {
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
    if (!view || transparency <= 0) return;

    @try {
        // 检查视图是否还有效
        if (view.superview == nil) {
            return;
        }

        BOOL isDarkMode = [DYYYManager isDarkMode];

        // 移除现有的毛玻璃视图
        for (UIView *subview in [view.subviews copy]) {
            if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 9999) {
                [subview removeFromSuperview];
            }
        }

        // 创建新的毛玻璃视图
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = view.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.tag = 9999;
        blurView.alpha = transparency;

        // 添加颜色覆盖层，提升观感
        UIView *overlayView = [[UIView alloc] initWithFrame:view.bounds];
        CGFloat overlayAlpha = isDarkMode ? 0.2 : 0.1;
        overlayView.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:overlayAlpha];
        overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [blurView.contentView addSubview:overlayView];

        // 性能优化
        DYYYOptimizeBlurViewPerformance(blurView);

        // 插入到最底层
        [view insertSubview:blurView atIndex:0];

        // 文本增强
        DYYYEnhanceTextForBlurEffect(view, transparency, isDarkMode);

    } @catch (NSException *exception) {
        NSLog(@"应用毛玻璃效果失败: %@", exception);
    }
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
    // 统一调用安全移除
    DYYYRemoveBlurViewsWithTag(containerView, 9999);
    DYYYRemoveBlurViewsWithTag(containerView, 999);

    // 创建新效果
    UIVisualEffectView *blurView = DYYYCreateBlurEffectView(containerView, transparency, isDarkMode);

    // 应用性能优化
    DYYYOptimizeBlurViewPerformance(blurView);

    // 插入视图
    [containerView insertSubview:blurView atIndex:0];

    // 提升文本可读性
    DYYYEnhanceTextForBlurEffect(containerView, transparency, isDarkMode);
}

// 安全遍历和移除子视图，防止数组越界和野指针
static void DYYYRemoveBlurViewsWithTag(UIView *view, NSInteger tag) {
    if (!view) return;
    NSArray *subviewsCopy = [view.subviews copy];
    for (UIView *subview in subviewsCopy) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == tag) {
            @try {
                [subview removeFromSuperview];
            } @catch (__unused NSException *e) {
                // 防止野指针崩溃
            }
        }
    }
}

static void DYYYSetViewsTransparentWithDepth(UIView *view, BOOL skipSpecialViews, int depth) {
    if (!view || depth > 10) return; // 限制最大递归深度
    if (skipSpecialViews) {
        if ([view isKindOfClass:[UIImageView class]] ||
            [view isKindOfClass:[UILabel class]] ||
            [view isKindOfClass:[UIButton class]] ||
            [view isKindOfClass:[UIVisualEffectView class]]) {
            return;
        }
    }
    view.backgroundColor = [UIColor clearColor];
    for (UIView *subview in view.subviews) {
        DYYYSetViewsTransparentWithDepth(subview, skipSpecialViews, depth + 1);
    }
}

static float DYYYGetUserTransparencySafe(NSString *key, float defaultValue) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    float result = defaultValue;
    if ([value respondsToSelector:@selector(floatValue)]) {
        result = [value floatValue];
    }
    if (result <= 0 || result > 1) result = defaultValue;
    return result;
}

// 智能判断是否为"评论输入相关视图"而不是手动字符串匹配
static BOOL DYYYIsCommentInputRelatedView(UIView *view) {
    if (!view) return NO;
    static NSArray *patterns = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        patterns = @[@"CommentInput", @"CommentBar", @"CommentPanel", @"CommentContainer"];
    });
    NSString *className = NSStringFromClass([view class]);
    for (NSString *pattern in patterns) {
        if ([className containsString:pattern]) return YES;
    }
    return NO;
}

// 智能判断是否为"弹幕"相关视图
static BOOL DYYYIsDanmuLabel(UIView *view) {
    if (![view isKindOfClass:[UILabel class]]) return NO;
    UILabel *label = (UILabel *)view;
    return [label.text containsString:@"弹幕"];
}

// 智能判断是否为"白色背景"视图
static BOOL DYYYIsWhiteBackgroundView(UIView *view) {
    if (!view || !view.backgroundColor) return NO;
    CGFloat r=0,g=0,b=0,a=0;
    if ([view.backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
        return (r > 0.95 && g > 0.95 && b > 0.95 && a > 0.1);
    }
    return NO;
}

// 界面稳定性检查函数
static BOOL DYYYIsInterfaceStable(UIViewController *viewController) {
    if (!viewController || !viewController.view) {
        return NO;
    }
    
    // 检查视图是否已经显示
    if (!viewController.view.window) {
        return NO;
    }
    
    // 检查视图大小是否合理
    CGRect bounds = viewController.view.bounds;
    if (CGRectIsEmpty(bounds) || bounds.size.height < 100) {
        return NO;
    }
    
    // 检查视图控制器是否处于转场中
    if (viewController.transitionCoordinator) {
        return NO;
    }
    
    return YES;
}

static void DYYYApplyBlurEffectSafely(UIView *view, float transparency) {
    if (!view || transparency <= 0) return;
    
    // 保存原始状态，用于失败时恢复
    UIColor *originalBgColor = view.backgroundColor;
    NSArray *originalSubviews = [view.subviews copy];
    
    @try {
        DYYYApplyBlurEffect(view, transparency);
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 应用毛玻璃效果失败: %@", exception);
        
        // 还原视图状态
        view.backgroundColor = originalBgColor;
        
        // 移除可能添加的毛玻璃视图
        for (UIView *subview in [view.subviews copy]) {
            if (![originalSubviews containsObject:subview] && 
                [subview isKindOfClass:[UIVisualEffectView class]]) {
                [subview removeFromSuperview];
            }
        }
    }
}

// 为 AWEUserActionSheetView 添加毛玻璃效果
%hook AWEUserActionSheetView

- (void)layoutSubviews {    
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableSheetBlur"]) {
        [self applyBlurEffectAndWhiteText];
    }
}

%new
- (void)applyBlurEffectAndWhiteText {
    // 应用毛玻璃效果到容器视图
    if (self.containerView) {
        self.containerView.backgroundColor = [UIColor clearColor];

        for (UIView *subview in self.containerView.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 9999) {
                [subview removeFromSuperview];
            }
        }

        // 动态获取用户设置的透明度
        float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSheetBlurTransparent"] floatValue];
        if (userTransparency <= 0 || userTransparency > 1) {
            userTransparency = 0.9; // 默认值0.9
        }

        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.frame = self.containerView.bounds;
        blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurEffectView.alpha = userTransparency; // 设置为用户自定义透明度
        blurEffectView.tag = 9999;

        [self.containerView insertSubview:blurEffectView atIndex:0];

        [self setTextColorWhiteRecursivelyInView:self.containerView];
    }
}

%new
- (void)setTextColorWhiteRecursivelyInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if (![subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.backgroundColor = [UIColor clearColor];
        }

        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = [UIColor whiteColor];
        }

        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }

        [self setTextColorWhiteRecursivelyInView:subview];
    }
}
%end

// MARK: - 评论区毛玻璃效果
%hook AWEBaseListViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYSettingChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dyyySettingChanged:) name:@"DYYYSettingChanged" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYSettingChanged" object:nil];
    %orig;
}

%new
- (void)dyyySettingChanged:(NSNotification *)note {
    static NSTimeInterval lastHandleTime = 0;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    // 防止频繁处理通知
    if (now - lastHandleTime < 1.0) {
        return;
    }
    
    lastHandleTime = now;
    DYYYLayoutStateManager *stateManager = [DYYYLayoutStateManager sharedManager];
    
    if (stateManager.isLayoutInProgress) {
        // 延迟处理，避免布局冲突
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            tabHeight = getTabBarHeight();
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self isViewLoaded] && self.view.window) {
                    [self.view setNeedsLayout];
                }
            });
        });
        return;
    }
    
    // 仅更新tabHeight值，不立即应用UI变更
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        tabHeight = getTabBarHeight();
        
        // 延迟应用UI变更
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if ([self isViewLoaded] && self.view.window) {
                [self.view setNeedsLayout];
                [self.view layoutIfNeeded];
            }
        });
    });
}

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
    if (DYYYGetBool(@"DYYYisEnableCommentBlur") && [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {
        // 动态获取用户设置的透明度
        float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
        if (userTransparency <= 0 || userTransparency > 1) {
            userTransparency = 0.9;
        }

        // 应用毛玻璃效果
               [DYYYUtils applyBlurEffectToView:self.view transparency:userTransparency blurViewTag:999];

        [DYYYUtils clearBackgroundRecursivelyInView:self.view];
    }
}

%new
- (void)dyyyApplyBlurEffect {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"] &&
        [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {

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

        // 检查当前界面是否为深色模式
        BOOL isDarkMode = NO;
        if (@available(iOS 13.0, *)) {
            isDarkMode = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        } else {
            // iOS 13 以下版本，根据状态栏样式判断
            isDarkMode = ([UIApplication sharedApplication].statusBarStyle == UIStatusBarStyleLightContent);
        }

        UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;

        float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
        if (userTransparency <= 0 || userTransparency > 1) {
            userTransparency = 0.5; // 默认值0.5
        }

        if (!existingBlurView) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
            UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurEffectView.frame = self.view.bounds;
            blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            blurEffectView.alpha = userTransparency;
            blurEffectView.tag = 999;

            UIView *overlayView = [[UIView alloc] initWithFrame:self.view.bounds];
            CGFloat alpha = isDarkMode ? 0.2 : 0.1;
            overlayView.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:alpha];
            overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [blurEffectView.contentView addSubview:overlayView];

            [self.view insertSubview:blurEffectView atIndex:0];
        } else {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
            [existingBlurView setEffect:blurEffect];

            existingBlurView.alpha = userTransparency;

            for (UIView *subview in existingBlurView.contentView.subviews) {
                if (subview.tag != 999) {
                    CGFloat alpha = isDarkMode ? 0.2 : 0.1;
                    subview.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:alpha];
                }
            }

            [self.view insertSubview:existingBlurView atIndex:0];
        }
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if ([self respondsToSelector:@selector(dyyyApplyBlurEffect)]) {
        [self performSelector:@selector(dyyyApplyBlurEffect) withObject:nil afterDelay:0];
    }
    [self applyBlurEffectIfNeeded];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([self respondsToSelector:@selector(dyyyApplyBlurEffect)]) {
        [self performSelector:@selector(dyyyApplyBlurEffect) withObject:nil afterDelay:0];
    }
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([self respondsToSelector:@selector(dyyyApplyBlurEffect)]) {
        [self performSelector:@selector(dyyyApplyBlurEffect) withObject:nil afterDelay:0];
    }
}

%end

// MARK: - 评论输入框毛玻璃效果
%hook AWECommentInputViewSwiftImpl_CommentInputContainerView

- (void)didMoveToWindow {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dyyySettingChanged:) name:@"DYYYSettingChanged" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYSettingChanged" object:nil];
    %orig;
}

%new
- (void)dyyySettingChanged:(NSNotification *)note {
    // 只更新tabHeight值，不进行全局刷新
    tabHeight = getTabBarHeight();
    
    // 对于UIView子类，直接检查window并刷新自身
    if (self.window) {
        [self setNeedsLayout];
    }
}

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
        // 优先处理评论输入相关视图的毛玻璃和弹幕逻辑
        for (UIView *subview in self.subviews) {
            if (DYYYIsCommentInputRelatedView(subview)) {
                BOOL containsDanmu = NO;
                for (UIView *innerSubview in subview.subviews) {
                    if (DYYYIsDanmuLabel(innerSubview)) {
                        containsDanmu = YES;
                        break;
                    }
                }
                if (containsDanmu) {
                    // 弹幕相关处理（可根据需要自定义）
                    // 这里可插入弹幕专用的背景或样式
                } else {
                    for (UIView *innerSubview in subview.subviews) {
                        if ([innerSubview isKindOfClass:[UIView class]]) {
                            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBarTransparent"]) {
                                if (DYYYIsWhiteBackgroundView(innerSubview)) {
                                    float userTransparency = DYYYGetUserTransparency(@"DYYYCommentBlurTransparent", 0.95);
                                    DYYYAddCustomViewToParent(innerSubview, userTransparency);
                                }
                            } else {
                                float userTransparency = DYYYGetUserTransparency(@"DYYYCommentBlurTransparent", 0.95);
                                DYYYAddCustomViewToParent(innerSubview, userTransparency);
                            }
                            break;
                        }
                    }
                }
            }
        }

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
    static NSDate *lastUpdateTime = nil;
    NSDate *now = [NSDate date];

    // 更新间隔小于0.2秒，跳过部分处理
    if (lastUpdateTime && [now timeIntervalSinceDate:lastUpdateTime] < 0.5) {
        %orig;
        return;
    }
    lastUpdateTime = now;

    // 只处理特定类型的视图
    NSString *className = NSStringFromClass([self class]);
    static NSArray *targetClassPatterns;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        targetClassPatterns = @[@"AWEComment", @"AWEFeedProgress", @"AWEPlayInteraction"];
    });

    BOOL shouldProcess = NO;
    for (NSString *pattern in targetClassPatterns) {
        if ([className containsString:pattern]) {
            shouldProcess = YES;
            break;
        }
    }

    if (!shouldProcess) {
        %orig;
        return;
    }

    @try {
        %orig;

        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
            if (self.frame.size.height == tabHeight && tabHeight > 0) {
                UIViewController *vc = [self firstAvailableUIViewController];
                if ([vc isKindOfClass:NSClassFromString(@"AWEMixVideoPanelDetailTableViewController")] || [vc isKindOfClass:NSClassFromString(@"AWECommentInputViewController")]) {
                    self.backgroundColor = [UIColor clearColor];
                }
            }
        }

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
                                // 防止数组越界和野指针
                                if (innerSubview.subviews.count > 0) {
                                    UIView *firstSubview = innerSubview.subviews.firstObject;
                                    if (firstSubview) {
                                        [firstSubview removeFromSuperview];
                                    }
                                }

                                UIView *whiteBackgroundView = [[UIView alloc] initWithFrame:innerSubview.bounds];
                                whiteBackgroundView.backgroundColor = [UIColor whiteColor];
                                whiteBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                                [innerSubview addSubview:whiteBackgroundView];
                                break;
                            }
                        }
                    } else {
                        for (UIView *innerSubview in subview.subviews) {
                            if ([innerSubview isKindOfClass:[UIView class]]) {
                                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBarTransparent"]) {
                                    // 检查背景颜色
                                    UIColor *bgColor = innerSubview.backgroundColor;
                                    if (bgColor) {
                                        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
                                        BOOL isWhite = NO;

                                        if ([bgColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
                                            isWhite = (red > 0.95 && green > 0.95 && blue > 0.95);
                                            // 如果背景是透明的，则不处理
                                            if (alpha < 0.1) {
                                                break;
                                            }
                                        }

                                        // 只有当背景是白色时才应用毛玻璃效果
                                        if (isWhite) {
                                            float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"]
                                                floatValue];
                                            if (userTransparency <= 0 || userTransparency > 1) {
                                                userTransparency = 0.95;
                                            }
                                            DYYYAddCustomViewToParent(innerSubview, userTransparency);
                                        }
                                    }
                                } else {
                                    float userTransparency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCommentBlurTransparent"] floatValue];
                                    if (userTransparency <= 0 || userTransparency > 1) {
                                        userTransparency = 0.95;
                                    }
                                    DYYYAddCustomViewToParent(innerSubview, userTransparency);
                                }
                                break;
                            }
                        }
                    }
                }
            }
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"] || [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {

            UIViewController *vc = [self firstAvailableUIViewController];
            if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                BOOL shouldHideSubview = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"] ||
                             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"];

                if (shouldHideSubview) {
                    for (UIView *subview in self.subviews) {
                        if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor && CGColorEqualToColor(subview.backgroundColor.CGColor, [UIColor blackColor].CGColor)) {
                            subview.hidden = YES;
                        }
                    }
                }
            }
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
            if ([className isEqualToString:@"AWECommentInputViewSwiftImpl.CommentInputContainerView"]) {
                for (UIView *subview in self.subviews) {
                    if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor) {
                        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
                        [subview.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];

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
    } @catch (NSException *e) {
        NSLog(@"[DYYY] layoutSubviews异常: %@", e);
    }
}

- (void)setFrame:(CGRect)frame {
    // 使用状态管理器检查
    DYYYLayoutStateManager *stateManager = [DYYYLayoutStateManager sharedManager];
    
    // 检查防重入标记
    static void *DYYYFrameKey = &DYYYFrameKey;
    if (objc_getAssociatedObject(self, DYYYFrameKey)) {
        %orig(frame);
        return;
    }
    
    // 如果布局操作过于频繁，延迟执行
    if (![stateManager canPerformLayoutOperation]) {
        %orig(frame);
        return;
    }
    
    objc_setAssociatedObject(self, DYYYFrameKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [stateManager markLayoutStart];
    
    @try {
        NSString *className = NSStringFromClass([self class]);
        
        // 只处理特定的关键视图类型
        static NSArray *criticalClasses = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            criticalClasses = @[@"AWEPlayInteraction", @"AWEAwemePlayVideo", @"AWEDPlayerFeedPlayer"];
        });
        
        BOOL isCriticalClass = NO;
        for (NSString *pattern in criticalClasses) {
            if ([className containsString:pattern]) {
                isCriticalClass = YES;
                break;
            }
        }
        
        if (!isCriticalClass) {
            %orig(frame);
            return;
        }
        
        BOOL enableFS = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"];
        
        if (!enableFS) {
            %orig(frame);
            return;
        }
        
        // 验证视图控制器
        UIViewController *vc = [self firstAvailableUIViewController];
        if (!vc) {
            %orig(frame);
            return;
        }
        
        Class PlayVCClass1 = NSClassFromString(@"AWEAwemePlayVideoViewController");
        Class PlayVCClass2 = NSClassFromString(@"AWEDPlayerFeedPlayerViewController");
        
        BOOL isPlayVC = ((PlayVCClass1 && [vc isKindOfClass:PlayVCClass1]) || 
                         (PlayVCClass2 && [vc isKindOfClass:PlayVCClass2]));
        
        if (!isPlayVC) {
            %orig(frame);
            return;
        }
        
        // 直接处理frame调整逻辑，不调用新方法
        CGRect adjustedFrame = frame;
        
        // 确保有有效的superview
        if (self.superview) {
            CGRect superFrame = self.superview.frame;
            
            // 验证superview的frame是否有效
            if (!CGRectIsEmpty(superFrame) && superFrame.size.height >= 100) {
                // 只在合理的情况下调整frame
                if (adjustedFrame.origin.x == 0 && adjustedFrame.origin.y == 0) {
                    CGFloat currentTabHeight = tabHeight > 0 ? tabHeight : 83.0;
                    CGFloat heightDiff = superFrame.size.height - adjustedFrame.size.height;
                    
                    // 只有当差值接近tabHeight时才调整
                    if (fabs(heightDiff - currentTabHeight) < 2.0 && heightDiff > 10) {
                        adjustedFrame.size.height = superFrame.size.height;
                        NSLog(@"[DYYY] 安全调整frame: %@ -> %@", 
                              NSStringFromCGRect(frame), NSStringFromCGRect(adjustedFrame));
                    }
                }
            }
        }
        
        %orig(adjustedFrame);
        
    } @catch (NSException *e) {
        NSLog(@"[DYYY] setFrame安全异常处理: %@", e);
        %orig(frame); // 发生异常时使用原始frame
    } @finally {
        objc_setAssociatedObject(self, DYYYFrameKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [stateManager markLayoutEnd];
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
- (void)findAndApplyBlurEffectToNotificationViews:(UIView *)parentView depth:(int)depth {
    // 最大递归深度限制
    if (depth > 5) return;
    
    for (UIView *subview in parentView.subviews) {
        // 原有检查逻辑...
        
        // 限制递归深度的递归
        if (subview.subviews.count > 0) {
            [self findAndApplyBlurEffectToNotificationViews:subview depth:depth+1];
        }
    }
}

%new
- (void)applyBlurEffectToView:(UIView *)containerView {
    if (!containerView) return;

    // 检查功能是否启用
    if (!DYYYIsFunctionEnabled(kDYYYNotificationEnabledKey)) return;

    // 统一调用安全移除
    DYYYRemoveBlurViewsWithTag(containerView, 999);

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

    // 使用正确的透明度键名
    NSString *transparencyKey = @"DYYYNotificationBlurTransparent";
    float transparency = DYYYGetUserTransparency(transparencyKey, 0.7);
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

%new
- (void)adjustTextVisibilityForBlurEffect:(UIView *)containerView transparency:(float)transparency {
    BOOL isDarkMode = NO;
    if (@available(iOS 13.0, *)) {
        isDarkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    } else {
        isDarkMode = [DYYYManager isDarkMode];
    }
    
    CGFloat textAlpha = 1.0;
    UIColor *textColor;
    
    if (transparency < 0.3) {
        textAlpha = 1.0;
        textColor = isDarkMode ? [UIColor whiteColor] : [UIColor blackColor];
    } else if (transparency < 0.6) {
        textAlpha = 0.95;
        textColor = isDarkMode ? [UIColor colorWithWhite:1.0 alpha:textAlpha] : 
                              [UIColor colorWithWhite:0.0 alpha:textAlpha];
    } else {
        textAlpha = 0.9;
        textColor = isDarkMode ? [UIColor colorWithWhite:0.9 alpha:textAlpha] : 
                              [UIColor colorWithWhite:0.1 alpha:textAlpha];
    }
    
    [self setLabelsColorWhiteInView:containerView];
}

%new
- (void)clearBackgroundRecursivelyInView:(UIView *)view exceptClass:(Class)exceptClass {
    for (UIView *subview in view.subviews) {
        if (exceptClass && [subview isKindOfClass:exceptClass]) {
            continue;
        }
        subview.backgroundColor = [UIColor clearColor];
        [self clearBackgroundRecursivelyInView:subview exceptClass:exceptClass];
    }
}

%new
- (void)setLabelsColorWhiteInView:(UIView *)view {
    if (!view) return;
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = [UIColor whiteColor];
            // 添加阴影增强可读性
            label.shadowColor = [UIColor blackColor];
            label.shadowOffset = CGSizeMake(0.5, 0.5);
        } else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        
        // 递归处理
        if (subview.subviews.count > 0) {
            [self setLabelsColorWhiteInView:subview];
        }
    }
}

%new
- (void)findAndApplyBlurEffectToNotificationViews:(UIView *)parentView {
    [self findAndApplyBlurEffectToNotificationViews:parentView depth:0];
}

%end



// 顶栏透明度
%hook AWEFeedTopBarContainer
- (void)layoutSubviews {
	%orig;
	[self applyDYYYTransparency];
}
- (void)didMoveToSuperview {
	%orig;
	[self applyDYYYTransparency];
}
%new
- (void)applyDYYYTransparency {
	// 如果启用了纯净模式，不做任何处理
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnablePure"]) {
		return;
	}

	NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
	if (transparentValue && transparentValue.length > 0) {
		CGFloat alphaValue = [transparentValue floatValue];
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			CGFloat finalAlpha = (alphaValue < 0.011) ? 0.011 : alphaValue;
			UIColor *backgroundColor = self.backgroundColor;
			if (backgroundColor) {
				CGFloat r, g, b, a;
				if ([backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
					self.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:finalAlpha * a];
				}
			}
			[(UIView *)self setAlpha:finalAlpha];
			for (UIView *subview in self.subviews) {
				subview.alpha = 1.0;
			}
		}
	}
}
%end



%hook AWEFeedContainerContentView
- (void)setAlpha:(CGFloat)alpha {
    // 纯净模式功能
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnablePure"]) {
        %orig(0.0);

        static dispatch_source_t timer = nil;
        static int attempts = 0;

        if (timer) {
            dispatch_source_cancel(timer);
            timer = nil;
        }

        void (^tryFindAndSetPureMode)(void) = ^{
          UIWindow *keyWindow = [DYYYManager getActiveWindow];

          if (keyWindow && keyWindow.rootViewController) {
              UIViewController *feedVC = [self findViewController:keyWindow.rootViewController ofClass:NSClassFromString(@"AWEFeedTableViewController")];
              if (feedVC) {
                  @try {
                      [feedVC setValue:@YES forKey:@"pureMode"];
                  } @catch (__unused NSException *e) {
                      // 防止KVC崩溃
                  }
                  if (timer) {
                      dispatch_source_cancel(timer);
                      timer = nil;
                  }
                  attempts = 0;
                  return;
              }
          }

          attempts++;
          if (attempts >= 10) {
              if (timer) {
                  dispatch_source_cancel(timer);
                  timer = nil;
              }
              attempts = 0;
          }
        };

        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(timer, tryFindAndSetPureMode);
        dispatch_resume(timer);

        tryFindAndSetPureMode();
        return;
    }

	// 原来的透明度设置逻辑，保持不变
	NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
	if (transparentValue && transparentValue.length > 0) {
		CGFloat alphaValue = [transparentValue floatValue];
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			%orig(alphaValue);
		} else {
			%orig(1.0);
		}
	} else {
		%orig(1.0);
	}
}

%new
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass {
    if (!vc)
        return nil;
    if ([vc isKindOfClass:targetClass])
        return vc;

    // 递归查找子视图控制器
    for (UIViewController *childVC in vc.childViewControllers) {
        UIViewController *foundVC = [self findViewController:childVC ofClass:targetClass];
        if (foundVC)
            return foundVC;
    }
    
    return nil;
}

%end




/**
 * @hook AWEAwemeDetailNaviBarContainerView
 * @description 修改视图透明度的钩子函数
 * 
 * 该方法会在原始layoutSubviews执行后运行，从用户默认设置中获取全局透明度值，
 * 并将该透明度应用于所有子视图（除了特定标记的视图）。
 * 
 * 透明度值需在0.0到1.0之间才会生效，且只会修改已经可见的视图（alpha>0）。
 * 被标记为DYYY_IGNORE_GLOBAL_ALPHA_TAG的视图和当前类的实例将被忽略。
 */
%hook AWEAwemeDetailNaviBarContainerView

- (void)layoutSubviews {
	%orig;

	NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
	if (transparentValue.length > 0) {
		CGFloat alphaValue = transparentValue.floatValue;
		if (alphaValue >= 0.0 && alphaValue <= 1.0) {
			for (UIView *subview in self.subviews) {
				if (subview.tag != DYYY_IGNORE_GLOBAL_ALPHA_TAG && ![NSStringFromClass([subview class]) isEqualToString:NSStringFromClass([self class])]) {
					if (subview.alpha > 0) {
						subview.alpha = alphaValue;
					}
				}
			}
		}
	}
}

%end