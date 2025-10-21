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
#import "DYYYScreenshot.h" // 截图功能头文件
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>
#import "DYYYFloatSpeedButton.h" 
#import "DYYYPipPlayer.h"
#import "DYYYSettingsHelper.h"

// 外部符号声明
#ifdef __cplusplus
extern "C"
#endif
void showDYYYSettingsVC(UIViewController *rootVC);
extern FloatingSpeedButton *speedButton;
extern BOOL isFloatSpeedButtonEnabled;

// 底部栏高度获取函数声明
extern CGFloat getTabBarHeight(void);

@interface DYYYDraggableButton : UIButton
@property (nonatomic, assign) NSInteger originalIndex;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) CGPoint originalCenter;
@property (nonatomic, strong) UIView *dragPreviewView;
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation DYYYDraggableButton
@end

// 颜色圆圈图像生成函数声明
UIImage *createColorCircleImage(UIColor *color, CGSize size) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [color setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, size.width - 2, size.height - 2)];
    path.lineWidth = 1.0;
    [path fill];
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 菜单布局样式枚举
typedef NS_ENUM(NSInteger, DYYYMenuStyle) {
    DYYYMenuStyleCard = 0,
    DYYYMenuStyleList = 1
};

// MARK: - 视图模式枚举定义
typedef NS_ENUM(NSInteger, DYYYMenuVisualStyle) {
    DYYYMenuVisualStyleClassic = 0,     // 默认风格
    DYYYMenuVisualStyleNeuomorphic = 1, // 新UI风格
};


// MARK: - 模块配置协议
@protocol DYYYMenuModuleProtocol <NSObject>
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *color;
@property (nonatomic, copy) void (^action)(void);
@end

// MARK: - 模块数据模型
@interface DYYYMenuModule : NSObject <DYYYMenuModuleProtocol>
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *color;
@property (nonatomic, copy) void (^action)(void);
+ (instancetype)moduleWithTitle:(NSString *)title icon:(NSString *)icon color:(NSString *)color action:(void(^)(void))action;
@end

@implementation DYYYMenuModule
+ (instancetype)moduleWithTitle:(NSString *)title icon:(NSString *)icon color:(NSString *)color action:(void(^)(void))action {
    DYYYMenuModule *module = [[DYYYMenuModule alloc] init];
    module.title = title;
    module.icon = icon;
    module.color = color;
    module.action = action;
    return module;
}
@end

// MARK: - 视图样式构建器基类
@interface DYYYMenuStyleBuilder : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray<DYYYMenuModule *> *modules;
@property (nonatomic, strong) NSMutableArray *moduleViews;
@property (nonatomic, weak) id delegate;

- (instancetype)initWithScrollView:(UIScrollView *)scrollView modules:(NSArray<DYYYMenuModule *> *)modules;
- (void)buildMenuWithAnimation:(BOOL)animated;
- (void)clearExistingViews;

// 子类需要重写的方法
- (UIView *)createModuleViewForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index;
- (CGSize)calculateContentSize;
- (void)animateModuleViews:(NSArray *)views;
@end

@implementation DYYYMenuStyleBuilder

- (instancetype)initWithScrollView:(UIScrollView *)scrollView modules:(NSArray<DYYYMenuModule *> *)modules {
    if (self = [super init]) {
        _scrollView = scrollView;
        _modules = modules;
        _moduleViews = [NSMutableArray array];
    }
    return self;
}

- (void)buildMenuWithAnimation:(BOOL)animated {
    [self clearExistingViews];
    
    // 设置内容大小
    self.scrollView.contentSize = [self calculateContentSize];
    
    // 创建模块视图
    for (NSInteger i = 0; i < self.modules.count; i++) {
        DYYYMenuModule *module = self.modules[i];
        UIView *moduleView = [self createModuleViewForModule:module atIndex:i];
        
        [self.scrollView addSubview:moduleView];
        [self.moduleViews addObject:moduleView];
    }
    
    // 保存到scrollView
    objc_setAssociatedObject(self.scrollView, "moduleViews", self.moduleViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 执行动画
    if (animated) {
        [self animateModuleViews:self.moduleViews];
    }
}

- (void)clearExistingViews {
    NSArray *existingViews = objc_getAssociatedObject(self.scrollView, "moduleViews");
    for (UIView *view in existingViews) {
        [view removeFromSuperview];
    }
    [self.moduleViews removeAllObjects];
}

// 子类需要重写
- (UIView *)createModuleViewForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index {
    UIView *moduleView = nil;
    
    // 子类需要重写此方法
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Subclass must override createModuleViewForModule:atIndex:"
                                 userInfo:nil];
    
    return moduleView;
}

- (CGSize)calculateContentSize {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Subclass must override calculateContentSize"
                                 userInfo:nil];
}

- (void)animateModuleViews:(NSArray *)views {
    // 默认淡入动画
    for (NSInteger i = 0; i < views.count; i++) {
        UIView *view = views[i];
        view.alpha = 0;
        [UIView animateWithDuration:0.3 
                              delay:0.05 * i
                            options:UIViewAnimationOptionCurveEaseOut 
                         animations:^{
            view.alpha = 1;
        } completion:nil];
    }
}

@end

// MARK: - 卡片风格构建器
@interface DYYYCardStyleBuilder : DYYYMenuStyleBuilder
@end

@implementation DYYYCardStyleBuilder

- (CGSize)calculateContentSize {
    CGFloat width = self.scrollView.frame.size.width;
    CGFloat moduleHeight = 80;
    CGFloat spacing = 16;
    NSInteger rows = self.modules.count;
    return CGSizeMake(width, (moduleHeight + spacing) * rows + spacing);
}

- (UIView *)createModuleViewForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index {
    CGFloat menuWidth = self.scrollView.frame.size.width;
    CGFloat moduleWidth = menuWidth - 24;
    CGFloat moduleHeight = 80;
    CGFloat spacing = 16;
    
    // 创建卡片容器
    UIView *cardContainer = [[UIView alloc] initWithFrame:CGRectMake(12, spacing + index * (moduleHeight + spacing), moduleWidth, moduleHeight)];
    cardContainer.backgroundColor = [UIColor clearColor];
    cardContainer.tag = index + 100;
    
    // 创建可拖拽的卡片按钮
    DYYYDraggableButton *cardButton = [DYYYDraggableButton buttonWithType:UIButtonTypeCustom];
    cardButton.frame = cardContainer.bounds;
    cardButton.originalIndex = index;
    cardButton.currentIndex = index;
    cardButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.95];
    cardButton.layer.cornerRadius = 20;
    cardButton.layer.shadowColor = [UIColor blackColor].CGColor;
    cardButton.layer.shadowOffset = CGSizeMake(0, 8);
    cardButton.layer.shadowOpacity = 0.25;
    cardButton.layer.shadowRadius = 12;
    cardButton.clipsToBounds = NO;
    
    // 创建多层渐变背景
    CAGradientLayer *primaryGradient = [CAGradientLayer layer];
    primaryGradient.frame = cardButton.bounds;
    primaryGradient.cornerRadius = 20;
    primaryGradient.colors = @[
        (id)[DYYYManager colorWithHexString:module.color].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.1].CGColor
    ];
    primaryGradient.startPoint = CGPointMake(0, 0);
    primaryGradient.endPoint = CGPointMake(1, 1);
    [cardButton.layer insertSublayer:primaryGradient atIndex:0];
    
    // 玻璃效果边框
    CALayer *borderLayer = [CALayer layer];
    borderLayer.frame = cardButton.bounds;
    borderLayer.cornerRadius = 20;
    borderLayer.borderWidth = 1.5;
    borderLayer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    [cardButton.layer addSublayer:borderLayer];
    
    // 图标
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 28, 32, 32)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = [DYYYManager colorWithHexString:module.color];
    UIImage *icon = [UIImage systemImageNamed:module.icon];
    if (icon) {
        iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [cardButton addSubview:iconView];
    
    // 标题 - 修改为垂直居中对齐
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, moduleWidth - 110, moduleHeight)];
    titleLabel.text = module.title;
    titleLabel.textColor = [UIColor systemBlueColor]; // 修改为Apple蓝色
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textAlignment = NSTextAlignmentLeft; // 水平左对齐
    titleLabel.contentMode = UIViewContentModeCenter; // 垂直居中
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.8;
    [cardButton addSubview:titleLabel];
    
    // 右侧拖拽指示器
    UIImageView *dragIndicator = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]];
    dragIndicator.tintColor = [DYYYManager colorWithHexString:module.color];
    dragIndicator.contentMode = UIViewContentModeScaleAspectFit;
    dragIndicator.frame = CGRectMake(moduleWidth - 40, 30, 20, 20);
    dragIndicator.alpha = 0.7;
    [cardButton addSubview:dragIndicator];
    
    // 事件处理
    [cardButton addTarget:self.delegate action:@selector(handleModuleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [cardButton addTarget:self.delegate action:@selector(moduleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [cardButton addTarget:self.delegate action:@selector(moduleButtonTouchUpForCard:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    objc_setAssociatedObject(cardButton, "moduleAction", module.action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cardButton, "moduleData", module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 长按拖拽手势
    UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self.delegate action:@selector(handleModuleDrag:)];
    dragGesture.minimumPressDuration = 0.5;
    dragGesture.delaysTouchesBegan = YES;
    [cardButton addGestureRecognizer:dragGesture];
    
    [cardContainer addSubview:cardButton];
    return cardContainer;
}

- (void)animateModuleViews:(NSArray *)views {
    // 卡片特有的弹性进入动画
    for (NSInteger i = 0; i < views.count; i++) {
        UIView *view = views[i];
        view.alpha = 0;
        view.transform = CGAffineTransformMakeScale(0.8, 0.8);
        view.layer.shadowOpacity = 0;
        
        [UIView animateWithDuration:0.8
                              delay:0.1 * i
             usingSpringWithDamping:0.6
              initialSpringVelocity:0.8
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1;
            view.transform = CGAffineTransformIdentity;
            view.layer.shadowOpacity = 0.25;
        } completion:nil];
    }
}

@end

// MARK: - 列表风格构建器  
@interface DYYYListStyleBuilder : DYYYMenuStyleBuilder
@end

@implementation DYYYListStyleBuilder

- (CGSize)calculateContentSize {
    CGFloat width = self.scrollView.frame.size.width;
    CGFloat cellHeight = 56;
    return CGSizeMake(width, cellHeight * self.modules.count);
}

- (UIView *)createModuleViewForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index {
    CGFloat menuWidth = self.scrollView.frame.size.width;
    CGFloat cellHeight = 56;
    
    // 创建列表单元格容器
    UIView *cellContainer = [[UIView alloc] initWithFrame:CGRectMake(0, index * cellHeight, menuWidth, cellHeight)];
    cellContainer.backgroundColor = [UIColor clearColor];
    cellContainer.tag = index + 100;
    
    // 创建可拖拽的单元格按钮
    DYYYDraggableButton *cellButton = [DYYYDraggableButton buttonWithType:UIButtonTypeCustom];
    cellButton.frame = cellContainer.bounds;
    cellButton.originalIndex = index;
    cellButton.currentIndex = index;
    cellButton.backgroundColor = [UIColor clearColor];
    
    // 图标
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 16, 24, 24)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = [DYYYManager colorWithHexString:module.color];
    UIImage *icon = [UIImage systemImageNamed:module.icon];
    if (icon) {
        iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [cellButton addSubview:iconView];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 0, menuWidth - 120, cellHeight)];
    titleLabel.text = module.title;
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:17];
    [cellButton addSubview:titleLabel];
    
    // 右侧拖拽指示器
    UIImageView *dragIndicator = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]];
    dragIndicator.tintColor = [UIColor colorWithWhite:0.7 alpha:0.8];
    dragIndicator.contentMode = UIViewContentModeScaleAspectFit;
    dragIndicator.frame = CGRectMake(menuWidth - 50, 18, 20, 20);
    dragIndicator.alpha = 0.7;
    [cellButton addSubview:dragIndicator];
    
    // 分隔线
    if (index < self.modules.count - 1) {
        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(60, cellHeight - 0.5, menuWidth - 60, 0.5)];
        separator.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.3];
        [cellContainer addSubview:separator];
    }
    
    // 事件处理
    [cellButton addTarget:self.delegate action:@selector(handleModuleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [cellButton addTarget:self.delegate action:@selector(moduleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [cellButton addTarget:self.delegate action:@selector(moduleButtonTouchUpForIOS19:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    objc_setAssociatedObject(cellButton, "moduleAction", module.action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cellButton, "moduleData", module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 长按拖拽手势
    UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self.delegate action:@selector(handleModuleDrag:)];
    dragGesture.minimumPressDuration = 0.5;
    dragGesture.delaysTouchesBegan = YES;
    [cellButton addGestureRecognizer:dragGesture];
    
    [cellContainer addSubview:cellButton];
    return cellContainer;
}

- (void)animateModuleViews:(NSArray *)views {
    // 列表特有的从上到下淡入动画
    for (NSInteger i = 0; i < views.count; i++) {
        UIView *view = views[i];
        view.alpha = 0;
        view.transform = CGAffineTransformMakeTranslation(0, -10);
        
        [UIView animateWithDuration:0.4 
                              delay:0.03 * i
                            options:UIViewAnimationOptionCurveEaseOut 
                         animations:^{
            view.alpha = 1;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

@end

@interface DYYYNeuomorphicStyleBuilder : DYYYMenuStyleBuilder
- (UIView *)createNeuomorphicListItemForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index;
@end

@implementation DYYYNeuomorphicStyleBuilder

- (CGSize)calculateContentSize {
    CGFloat width = self.scrollView.frame.size.width;
    // 使用不同的高度计算方式，确保内容填充良好
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    if (isListView) {
        CGFloat cellHeight = 60; // 列表模式更紧凑
        return CGSizeMake(width, cellHeight * self.modules.count);
    } else {
        CGFloat cardHeight = 90; // 卡片模式更突出
        CGFloat verticalSpacing = 16;
        return CGSizeMake(width, (cardHeight + verticalSpacing) * self.modules.count + verticalSpacing);
    }
}

- (UIView *)createModuleViewForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index {
    CGFloat menuWidth = self.scrollView.frame.size.width;
    
    // 获取当前视图模式
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    // 根据视图模式使用不同设计参数
    CGFloat cellHeight, horizontalMargin;
    
    if (isListView) {
        // 列表模式
        cellHeight = 60;
        horizontalMargin = 15;
    } else {
        // 卡片模式
        cellHeight = 90;
        horizontalMargin = 18;
    }
    
    // 修复：列表模式创建容器时不使用垂直间距，确保无缝隙
    CGFloat yPosition = isListView ? (index * cellHeight) : (index * (cellHeight + 16) + 16);
    
    // 创建容器视图
    UIView *cellContainer = [[UIView alloc] initWithFrame:CGRectMake(0, yPosition, menuWidth, cellHeight)];
    cellContainer.backgroundColor = [UIColor clearColor];
    cellContainer.tag = index + 100;
    
    // 创建可拖拽按钮
    DYYYDraggableButton *cellButton = [DYYYDraggableButton buttonWithType:UIButtonTypeCustom];
    
    // 卡片尺寸计算 - 确保横向留出适当边距
    CGFloat buttonWidth = menuWidth - (horizontalMargin * 2);
    cellButton.frame = CGRectMake(horizontalMargin, 0, buttonWidth, cellHeight);
    cellButton.originalIndex = index;
    cellButton.currentIndex = index;
    
    // 提取模块颜色
    UIColor *moduleColor = [DYYYManager colorWithHexString:module.color];
    
    // 根据视图模式应用不同的风格
    if (isListView) {
        [self applyListItemStyle:cellButton withModuleColor:moduleColor];
    } else {
        [self applyCardStyle:cellButton withModuleColor:moduleColor index:index];
    }
    
    // 图标
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(20, (cellHeight - 28) / 2, 28, 28)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = moduleColor;  // 使用模块颜色
    UIImage *icon = [UIImage systemImageNamed:module.icon];
    if (icon) {
        iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [cellButton addSubview:iconView];
    
    // 为图标阴影效果增强层次感
    iconView.layer.shadowColor = moduleColor.CGColor;
    iconView.layer.shadowOffset = CGSizeMake(0, 1);
    iconView.layer.shadowRadius = 3.0;
    iconView.layer.shadowOpacity = 0.35;
    
    // 标题文本 - 修复颜色问题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 0, buttonWidth - 90, cellHeight)];
    titleLabel.text = module.title;
    
    // 确保列表模式使用深色文本颜色
    if (isListView) {
        titleLabel.textColor = [UIColor colorWithWhite:0.15 alpha:1.0];  // 强制深色文本
    } else {
        titleLabel.textColor = [UIColor colorWithWhite:0.15 alpha:1.0];  // 深色文本颜色
    }
    
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [cellButton addSubview:titleLabel];
    
    // 右侧拖拽指示器 - 使用圆点设计增强新拟态效果
    UIImageView *dragIndicator = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis"]];
    dragIndicator.tintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    dragIndicator.contentMode = UIViewContentModeScaleAspectFit;
    dragIndicator.frame = CGRectMake(buttonWidth - 36, (cellHeight - 20) / 2, 20, 20);
    [cellButton addSubview:dragIndicator];
    
    // 按钮事件处理
    [cellButton addTarget:self.delegate action:@selector(handleModuleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [cellButton addTarget:self.delegate action:@selector(moduleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [cellButton addTarget:self.delegate action:@selector(moduleButtonTouchUpForIOS19:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    objc_setAssociatedObject(cellButton, "moduleAction", module.action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cellButton, "moduleData", module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 长按拖拽手势
    UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self.delegate action:@selector(handleModuleDrag:)];
    dragGesture.minimumPressDuration = 0.5;
    dragGesture.delaysTouchesBegan = YES;
    [cellButton addGestureRecognizer:dragGesture];
    
    [cellContainer addSubview:cellButton];
    return cellContainer;
}

- (void)applyListItemStyle:(UIButton *)button withModuleColor:(UIColor *)moduleColor {
    // 列表风格设计
    button.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1.0];
    button.layer.cornerRadius = 12;
    
    // 获取按钮的索引和总数，用于确定位置
    NSInteger buttonIndex = 0;
    NSInteger totalButtons = 1;
    
    // 安全地获取按钮索引
    if ([button isKindOfClass:[DYYYDraggableButton class]]) {
        buttonIndex = ((DYYYDraggableButton *)button).originalIndex;
        
        // 尝试获取总按钮数
        NSArray *moduleViews = objc_getAssociatedObject(self.scrollView, "moduleViews");
        totalButtons = moduleViews ? moduleViews.count : 1;
    }
    
    button.layer.cornerRadius = 12;
    button.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    
    // 移除单独的外部阴影，只在整体容器上应用阴影
    button.layer.shadowOpacity = 0;
    
    // 左侧彩色指示器
    CALayer *colorIndicator = [CALayer layer];
    colorIndicator.frame = CGRectMake(0, 0, 6, button.bounds.size.height);
    colorIndicator.backgroundColor = [moduleColor colorWithAlphaComponent:0.8].CGColor;
    
    // 为左侧指示条正确的圆角
    colorIndicator.cornerRadius = 3; // 半径为宽度的一半
    
    // 只在左侧圆角，与按钮圆角保持一致
    colorIndicator.maskedCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
    
    [button.layer insertSublayer:colorIndicator atIndex:2];
    
    // 确保文本颜色始终为深色
    UIColor *textColor = [UIColor colorWithWhite:0.15 alpha:1.0];  // 强制深色
    
    // 获取所有标签并设置颜色
    for (UIView *subview in button.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = textColor;  // 强制设置深色文字
        }
    }
}

- (void)applyCardStyle:(UIButton *)button withModuleColor:(UIColor *)moduleColor index:(NSInteger)index {
    // 将卡片风格修改为与列表风格相似
    button.backgroundColor = [UIColor colorWithWhite:0.98 alpha:1.0];
    
    // 获取按钮的索引和总数
    NSInteger buttonIndex = index;
    NSInteger totalButtons = 1;
    
    // 尝试获取总按钮数
    NSArray *moduleViews = objc_getAssociatedObject(self.scrollView, "moduleViews");
    totalButtons = moduleViews ? moduleViews.count : 1;
    
    // 应用相同的圆角策略
    button.layer.cornerRadius = 12;
    if (buttonIndex == 0) {
        // 第一个按钮只保留上方圆角
        button.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    } else if (buttonIndex == totalButtons - 1) {
        // 最后一个按钮只保留下方圆角
        button.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else {
        // 中间按钮无圆角
        button.layer.cornerRadius = 0;
    }
    
    // 清除现有层
    for (CALayer *layer in [button.layer.sublayers copy]) {
        if (![layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
    
    // 设置柔和阴影效果
    button.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 3);
    button.layer.shadowOpacity = 0.5;
    button.layer.shadowRadius = 6;
    
    // 增大重叠区域消除缝隙
    CGRect frame = button.frame;
    frame.size.height += (buttonIndex < totalButtons - 1) ? 2 : 0;
    button.frame = frame;
    
    // 创建连接线效果
    if (buttonIndex < totalButtons - 1) {
        CALayer *connectionLine = [CALayer layer];
        connectionLine.frame = CGRectMake(6, button.bounds.size.height - 0.5, button.bounds.size.width - 6, 0.5);
        connectionLine.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.8].CGColor;
        [button.layer addSublayer:connectionLine];
        
        // 额外的连接器，确保没有缝隙
        CALayer *gapFiller = [CALayer layer];
        gapFiller.frame = CGRectMake(0, button.bounds.size.height - 2, button.bounds.size.width, 4);
        gapFiller.backgroundColor = button.backgroundColor.CGColor;
        gapFiller.zPosition = -1; // 放在最底层
        [button.layer addSublayer:gapFiller];
    }
    
    // 左侧彩色指示器
    CALayer *colorIndicator = [CALayer layer];
    CGFloat extraHeight = (buttonIndex < totalButtons - 1) ? 2 : 0;
    colorIndicator.frame = CGRectMake(0, 0, 6, button.bounds.size.height + extraHeight);
    colorIndicator.backgroundColor = [moduleColor colorWithAlphaComponent:0.8].CGColor;
    
    // 设置指示器圆角
    if (buttonIndex == 0) {
        colorIndicator.cornerRadius = 3;
        colorIndicator.maskedCorners = kCALayerMinXMinYCorner;
    } else if (buttonIndex == totalButtons - 1) {
        colorIndicator.cornerRadius = 3;
        colorIndicator.maskedCorners = kCALayerMinXMaxYCorner;
    } else {
        colorIndicator.cornerRadius = 0;
    }
    
    [button.layer insertSublayer:colorIndicator atIndex:2];
    
    // 顶部高光效果
    CAGradientLayer *topGradient = [CAGradientLayer layer];
    topGradient.frame = button.bounds;
    topGradient.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.4].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    topGradient.startPoint = CGPointMake(0.5, 0.0);
    topGradient.endPoint = CGPointMake(0.5, 0.5);
    
    topGradient.cornerRadius = button.layer.cornerRadius;
    topGradient.maskedCorners = button.layer.maskedCorners;
    
    [button.layer insertSublayer:topGradient atIndex:1];
    
    // 底部微妙的彩色渐变 (仅最后一项)
    if (buttonIndex == totalButtons - 1) {
        CAGradientLayer *bottomGradient = [CAGradientLayer layer];
        bottomGradient.frame = CGRectMake(0, button.bounds.size.height - 10, button.bounds.size.width, 10);
        bottomGradient.startPoint = CGPointMake(0, 1);
        bottomGradient.endPoint = CGPointMake(0, 0);
        bottomGradient.colors = @[
            (id)[moduleColor colorWithAlphaComponent:0.05].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        [button.layer insertSublayer:bottomGradient atIndex:1];
    }
    
    // 为每个卡片轻微的上下浮动动画
    if (buttonIndex < 10) {
        CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @(0);
        floatAnimation.toValue = @(-1.5);
        floatAnimation.duration = 3.0 + (buttonIndex % 3) * 0.4;
        floatAnimation.beginTime = CACurrentMediaTime() + buttonIndex * 0.15;
        floatAnimation.autoreverses = YES;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [button.layer addAnimation:floatAnimation forKey:@"floating"];
    }
    
    // 设置文本颜色
    UIColor *textColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    
    // 获取所有标签并设置颜色
    for (UIView *subview in button.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = textColor;
        }
    }
}

- (void)animateModuleViews:(NSArray *)views {
    // 入场动画
    for (NSInteger i = 0; i < views.count; i++) {
        UIView *view = views[i];
        view.alpha = 0;
        view.transform = CGAffineTransformMakeTranslation(0, 20);
        
        [UIView animateWithDuration:0.5 
                              delay:0.05 * i
             usingSpringWithDamping:0.7
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut 
                         animations:^{
            view.alpha = 1;
            view.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            for (UIView *subview in view.subviews) {
                if ([subview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)subview;
                    for (UIView *labelView in button.subviews) {
                        if ([labelView isKindOfClass:[UILabel class]]) {
                            UILabel *label = (UILabel *)labelView;
                            label.textColor = [UIColor colorWithWhite:0.15 alpha:1.0];
                        }
                    }
                }
            }
        }];
    }
}

@end

@implementation DYYYNeuomorphicStyleBuilder (ListViewFix)

- (UIView *)createNeuomorphicListItemForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index {
    CGFloat menuWidth = self.scrollView.frame.size.width;
    
    // 获取当前视图模式
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    // 根据视图模式使用不同参数
    CGFloat cellHeight;
    CGFloat verticalSpacing;
    CGFloat horizontalMargin;
    CGFloat verticalMargin;
    
    if (isListView) {
        // 列表模式参数
        cellHeight = 56;
        verticalSpacing = 0;
        horizontalMargin = 8;
        verticalMargin = 2;
    } else {
        // 卡片视图模式参数
        cellHeight = 80;
        verticalSpacing = 16;
        horizontalMargin = 12;
        verticalMargin = 0;
    }
    
    // 创建新拟态风格的列表单元格容器
    UIView *cellContainer = [[UIView alloc] initWithFrame:CGRectMake(0, index * cellHeight, menuWidth, cellHeight)];
    cellContainer.backgroundColor = [UIColor clearColor];
    cellContainer.tag = index + 100;
    
    // 创建可拖拽的新拟态按钮 - 使用适当的圆角
    DYYYDraggableButton *cellButton = [DYYYDraggableButton buttonWithType:UIButtonTypeCustom];
    
    // 为卡片模式使用更大的边距和圆角
    if (!isListView) {
        cellButton.frame = CGRectMake(16, 8, menuWidth - 32, cellHeight - 16);
        cellButton.layer.cornerRadius = 16; // 恢复圆角
    } else {
        cellButton.frame = CGRectMake(8, 2, menuWidth - 16, cellHeight - 4);
        cellButton.layer.cornerRadius = 10; // 列表模式使用较小圆角
    }
    
    cellButton.originalIndex = index;
    cellButton.currentIndex = index;
    
    // 新拟态风格背景
    cellButton.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0]; // 更浅的背景色
    
    // 顶部渐变效果以增强立体感
    CAGradientLayer *topGradient = [CAGradientLayer layer];
    topGradient.frame = cellButton.bounds;
    topGradient.cornerRadius = cellButton.layer.cornerRadius;
    topGradient.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.9].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.1].CGColor
    ];
    topGradient.locations = @[@0.0, @0.3];
    topGradient.startPoint = CGPointMake(0.0, 0.0);
    topGradient.endPoint = CGPointMake(0.0, 1.0);
    [cellButton.layer insertSublayer:topGradient atIndex:0];
    
    // 改进阴影效果
    cellButton.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.2].CGColor;
    cellButton.layer.shadowOffset = CGSizeMake(0, 3);
    cellButton.layer.shadowOpacity = 0.4;
    cellButton.layer.shadowRadius = 6;
    cellButton.clipsToBounds = NO;
    
    // 边框效果 - 使用半透明白色顶部边框增强立体感
    CALayer *borderLayer = [CALayer layer];
    borderLayer.frame = cellButton.bounds;
    borderLayer.cornerRadius = cellButton.layer.cornerRadius;
    borderLayer.masksToBounds = YES;
    borderLayer.borderWidth = 1.0;
    borderLayer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.8].CGColor;
    [cellButton.layer addSublayer:borderLayer];
    
    // 图标 - 调整位置和颜色
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(15, (!isListView ? 24 : 16), 24, 24)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    UIColor *iconColor = [DYYYManager colorWithHexString:module.color];
    iconView.tintColor = iconColor;
    UIImage *icon = [UIImage systemImageNamed:module.icon];
    if (icon) {
        iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [cellButton addSubview:iconView];
    
    // 为图标轻微发光效果
    iconView.layer.shadowColor = iconColor.CGColor;
    iconView.layer.shadowOffset = CGSizeMake(0, 0);
    iconView.layer.shadowOpacity = 0.5;
    iconView.layer.shadowRadius = 4.0;
    
    // 标题 - 改进字体和颜色
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, menuWidth - 110, cellHeight)];
    titleLabel.text = module.title;
    titleLabel.textColor = [UIColor colorWithWhite:0.2 alpha:1.0]; // 更深的文本颜色
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [cellButton addSubview:titleLabel];
    
    // 右侧拖拽指示器 - 优化样式
    UIImageView *dragIndicator = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]];
    dragIndicator.tintColor = [iconColor colorWithAlphaComponent:0.6];
    dragIndicator.contentMode = UIViewContentModeScaleAspectFit;
    dragIndicator.frame = CGRectMake(cellButton.frame.size.width - 40, (!isListView ? 28 : 18), 20, 20);
    dragIndicator.alpha = 0.7;
    [cellButton addSubview:dragIndicator];
    
    // 底部强调线 - 替代分隔线，更美观
    if (!isListView && index < 8) { // 防止过多视觉元素
        UIView *accentLine = [[UIView alloc] initWithFrame:CGRectMake(20, cellButton.frame.size.height - 3, 40, 2)];
        accentLine.backgroundColor = [iconColor colorWithAlphaComponent:0.6];
        accentLine.layer.cornerRadius = 1;
        [cellButton addSubview:accentLine];
    }
    
    // 事件处理
    [cellButton addTarget:self.delegate action:@selector(handleModuleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [cellButton addTarget:self.delegate action:@selector(moduleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [cellButton addTarget:self.delegate action:@selector(moduleButtonTouchUpForIOS19:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    objc_setAssociatedObject(cellButton, "moduleAction", module.action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cellButton, "moduleData", module, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 长按拖拽手势
    UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self.delegate action:@selector(handleModuleDrag:)];
    dragGesture.minimumPressDuration = 0.5;
    dragGesture.delaysTouchesBegan = YES;
    [cellButton addGestureRecognizer:dragGesture];
    
    // 轻微的悬浮动画效果（仅用于卡片模式）
    if (!isListView) {
        CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @(0);
        floatAnimation.toValue = @(-1.5);
        floatAnimation.duration = 2.0 + (index % 3) * 0.2; // 错开动画周期
        floatAnimation.autoreverses = YES;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [cellButton.layer addAnimation:floatAnimation forKey:@"floating"];
    }
    
    [cellContainer addSubview:cellButton];
    return cellContainer;
}

@end

@interface AWEPlayInteractionViewController (DYYYAdditions)
- (BOOL)isViewContainsButton:(UIView *)view button:(UIButton *)button;
- (void)applyViewModeChange:(BOOL)isListView;
- (void)applyPerformanceOptimizations:(UIView *)view withResources:(NSDictionary *)resources;
- (void)optimizeRenderPath:(UIView *)rootView;
- (void)preloadVisibleContent:(UIScrollView *)scrollView;
- (void)syncWithDisplayRefresh:(CADisplayLink *)displayLink;
- (void)syncRenderLoop:(CADisplayLink *)displayLink;

- (void)updateParallaxEffectsForScrollView:(UIScrollView *)scrollView;
- (void)normalizeListViewFonts:(UIScrollView *)scrollView;
- (void)updateHeaderControlsColorForBackground:(UIColor *)backgroundColor;
- (void)updateViewIconColors:(UIView *)view withColor:(UIColor *)color;

- (void)applySmartTextColorToAllMenuItems;
- (void)safelyUpdateUI:(void (^)(void))block;
- (UIBlurEffectStyle)inferVisualEffectStyle:(UIBlurEffect *)effect;
- (void)updateTextColorsInView:(UIView *)view withTextColor:(UIColor *)textColor;

- (void)enhanceModernVisualStyle:(UIScrollView *)scrollView;
- (UIColor *)getOptimalTextColorForBackground:(UIColor *)backgroundColor;
- (void)applyTextColorForButton:(UIButton *)button withBackgroundColor:(UIColor *)backgroundColor;

- (void)changeVisualStyle:(DYYYMenuVisualStyle)style;
- (void)showQuickActionsPanel;
- (void)handleQuickAction:(UITapGestureRecognizer *)gesture;
- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture;
- (void)hideQuickActionsPanel:(id)sender;

// 性能优化和异步加载相关的方法声明
- (void)optimizeMenuPerformance;
- (void)reduceViewHierarchyForActiveMenu;
- (void)enableRasterizationForMenuItems;
- (void)loadModuleDataAsynchronously;
- (NSArray<DYYYMenuModule *> *)applySmartOrderingToModules:(NSArray<DYYYMenuModule *> *)modules;
- (void)recreateMenuButtonsWithModules:(NSArray<DYYYMenuModule *> *)modules;

// 流体滚动相关方法声明
- (void)addParallaxEffectToModulesIn:(UIScrollView *)scrollView;
- (void)updateParallaxEffectForScrollView:(UIScrollView *)scrollView;

// 快捷操作面板相关方法声明
- (void)hideQuickActionsPanel:(id)sender;
- (void)autoHideQuickPanel:(NSTimer *)timer;
- (void)handleQuickPanelDrag:(UIPanGestureRecognizer *)gesture;


// 暗黑模式适配方法声明
- (void)updateMenuAppearanceForDarkMode:(BOOL)isDarkMode menuContainer:(UIView *)menuContainer;
- (void)updateMenuContentsForDarkMode:(BOOL)isDarkMode menuContainer:(UIView *)menuContainer;
- (void)recursivelyUpdateView:(UIView *)view forDarkMode:(BOOL)isDarkMode;

// 手势控制增强方法声明
- (void)handleMenuPinch:(UIPinchGestureRecognizer *)gesture;
- (void)handleMenuSwipeDown:(UISwipeGestureRecognizer *)gesture;
- (void)handleMenuDoubleTap:(UITapGestureRecognizer *)gesture;
- (UISegmentedControl *)findSegmentControlInView:(UIView *)rootView;
- (void)enhanceGestureControlsForMenu:(UIView *)menuContainer;

- (void)addMaterialEntranceCompleteEffect:(UIView *)container;
- (void)updateDragPosition:(DYYYDraggableButton *)button withTranslation:(CGPoint)translation;
- (void)enhanceCardHoverEffect:(UIButton *)button;
- (void)restoreCardNormalEffect:(UIButton *)button;
- (void)addBreathingEffectToHeaderView:(UIView *)headerView;
- (void)removeBreathingEffectFromHeaderView:(UIView *)headerView;
- (void)addVisualGuidanceToHeaderView:(UIView *)headerView;
- (void)removeVisualGuidanceFromHeaderView:(UIView *)headerView;
- (void)optimizeSpaceUtilizationAfterHeaderHidden;
- (void)restoreOriginalLayoutAfterHeaderShown;

- (void)handleModuleDrag:(UILongPressGestureRecognizer *)gesture;
- (void)startDragMode:(DYYYDraggableButton *)button;
- (void)updateDragPosition:(DYYYDraggableButton *)button withNewCenter:(CGPoint)newCenter;
- (void)finishDragMode:(DYYYDraggableButton *)button;
- (void)reorderModulesAfterDrag:(DYYYDraggableButton *)draggedButton;
- (void)saveModuleOrder:(NSArray<DYYYMenuModule *> *)modules;
- (UIView *)createDragPreviewForButton:(UIButton *)button;
- (NSInteger)findInsertionIndexForY:(CGFloat)yPosition inScrollView:(UIScrollView *)scrollView;
- (void)animateModuleReorderFromIndex:(NSInteger)fromIndex 
                              toIndex:(NSInteger)toIndex 
                        inScrollView:(UIScrollView *)scrollView 
                     excludingButton:(DYYYDraggableButton *)excludedButton;

// 拖拽相关方法声明
- (void)updateDragPositionWithLocation:(CGPoint)location button:(DYYYDraggableButton *)button scrollView:(UIScrollView *)scrollView;
- (void)reorderOtherButtonsFromIndex:(NSInteger)fromIndex 
                             toIndex:(NSInteger)toIndex 
                       inScrollView:(UIScrollView *)scrollView 
                    excludingButton:(DYYYDraggableButton *)excludedButton;
- (void)showDragPositionIndicatorAtY:(CGFloat)yPosition inScrollView:(UIScrollView *)scrollView;
- (void)hideDragPositionIndicator:(UIScrollView *)scrollView;
- (CGPoint)calculateCenterForIndex:(NSInteger)index isListView:(BOOL)isListView moduleView:(UIView *)moduleView;
- (void)updateModuleOrderAfterDrag:(DYYYDraggableButton *)draggedButton inScrollView:(UIScrollView *)scrollView;

// 头部控制区隐藏管理方法
- (void)setupHeaderAutoHideTimer;
- (void)invalidateHeaderAutoHideTimer;
- (void)hideHeaderControlsWithAnimation;
- (void)showHeaderControlsWithAnimation;
- (void)resetHeaderControlVisibility;

// 手势和视觉提示方法声明
- (void)addTapToShowGestureToMenuContainer:(UIView *)menuContainer;
- (void)removeTapToShowGestureFromMenuContainer:(UIView *)menuContainer;
- (void)handleTapToShowControls:(UITapGestureRecognizer *)gesture;
- (void)addVisualHintToMenuContainer:(UIView *)menuContainer;
- (void)removeVisualHintFromMenuContainer:(UIView *)menuContainer;
- (void)startDotsAnimationForContainer:(UIView *)dotsContainer;

// 创建菜单样式方法
- (void)createIOS19ListStyleMenuWithModules:(NSArray *)modules inScrollView:(UIScrollView *)scrollView moduleViews:(NSMutableArray *)moduleViews;
- (void)createCardStyleMenuWithModules:(NSArray *)modules inScrollView:(UIScrollView *)scrollView moduleViews:(NSMutableArray *)moduleViews;

- (void)applyContentParallaxEffect:(UIView *)parentView;
- (void)removeContentParallaxEffect:(UIView *)parentView;

- (void)applyFluentCardDecorator:(UIViewController *)viewController;
- (void)removeFluentCardDecorator:(UIViewController *)viewController;
- (void)enhanceVisibleCellsWithCardEffect:(UIViewController *)viewController;
- (void)restoreOriginalCellAppearance:(UIViewController *)viewController;
- (NSArray *)findVideoCellsInView:(UIView *)view;
- (void)applyFluentDesignToCell:(UIView *)cell;
- (void)applyCardStyleToCell:(UIView *)cell;
- (void)layoutDidUpdateNotification:(NSNotification *)notification;
- (void)createFluentDesignDraggableMenuWithAwemeModel:(AWEAwemeModel *)awemeModel touchPoint:(CGPoint)touchPoint;
- (void)dismissFluentMenu:(UITapGestureRecognizer *)gesture;
- (void)dismissFluentMenuByButton:(UIButton *)button;
- (void)handleModuleTap:(UITapGestureRecognizer *)gesture;
- (void)resetModulePositions:(UIButton *)sender;
- (void)showDYYYSettingPanelFromMenuButton:(UIButton *)button;
- (void)dismissDYYYSettingPanel:(UIButton *)button;
- (void)moduleButtonTouchDown:(UIButton *)sender;
- (void)handleModuleButtonTap:(UIButton *)sender;
- (void)resizeMenuPan:(UIPanGestureRecognizer *)pan;
- (void)customMenuButtonTapped:(UIButton *)button;
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification;
- (void)dyyy_handleSettingPanelPan:(UIPanGestureRecognizer *)pan;
- (void)toggleBlurStyle:(UIButton *)button;
- (void)showBlurColorPicker:(UIButton *)button;
- (void)updateBlurEffectWithColor:(UIColor *)color;
- (void)updateColorPickerButtonWithColor:(UIColor *)color;
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
- (void)refreshCurrentView;
- (void)showVideoDebugInfo:(AWEAwemeModel *)model;
- (void)dyyy_startCustomScreenshotProcess;
- (void)performScreenshotAction;

- (UIWindow *)getKeyWindow;
- (void)pauseCurrentVideo;
- (void)resumeCurrentVideo;
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
- (void)viewModeChanged:(UISegmentedControl *)segmentControl;

// 方法声明
- (void)recreateMenuButtonsForViewMode:(BOOL)isListView;
- (void)createMenuButtonsInScrollView:(UIScrollView *)scrollView forViewMode:(BOOL)isListView;

- (UIViewController *)findCurrentFeedViewController;
- (UIViewController *)searchForFeedControllerInViewController:(UIViewController *)vc;
- (UITableView *)findTableViewInViewController:(UIViewController *)vc;
- (UITableView *)findTableViewInView:(UIView *)view;
- (UICollectionView *)findCollectionViewInViewController:(UIViewController *)vc;
- (UICollectionView *)findCollectionViewInView:(UIView *)view;
- (void)switchToListMode:(UIViewController *)feedVC;
- (void)switchToCardMode:(UIViewController *)feedVC;

- (void)setGlobalFeedModeSettings:(BOOL)isListView;
- (void)forceResetLayoutWithManager:(id)manager isListView:(BOOL)isListView;
- (UIView *)findBackgroundViewIn:(UIView *)view;

// 方法声明
- (void)handleMenuContainerTap:(UITapGestureRecognizer *)gesture;
- (void)moduleButtonTouchUpForIOS19:(UIButton *)sender;
- (void)moduleButtonTouchUpForCard:(UIButton *)sender;

// 工厂模式相关方法
- (UIScrollView *)findScrollViewInTopViewController:(UIViewController *)topVC;
- (UIScrollView *)findScrollViewInView:(UIView *)view;
- (NSArray<DYYYMenuModule *> *)createMenuModulesForCurrentContext;
- (AWEAwemeModel *)getCurrentAwemeModel;
- (DYYYMenuModule *)createDownloadModuleForAweme:(AWEAwemeModel *)awemeModel;
- (DYYYMenuModule *)createScreenshotModule;
- (DYYYMenuModule *)createAudioModuleForAweme:(AWEAwemeModel *)awemeModel;
- (DYYYMenuModule *)createCopyTextModuleForAweme:(AWEAwemeModel *)awemeModel;
- (DYYYMenuModule *)createCommentModule;
- (DYYYMenuModule *)createLikeModule;
- (DYYYMenuModule *)createAdvancedModule;
- (BOOL)shouldShowDownloadModule;
- (BOOL)shouldShowScreenshotModule;
- (BOOL)shouldShowAudioModule;
- (BOOL)shouldShowCopyTextModule;
- (BOOL)shouldShowCommentModule;
- (BOOL)shouldShowLikeModule;
- (BOOL)shouldShowAdvancedModule;

// 按钮查找方法声明
- (UIView *)findCommentButtonInView:(UIView *)view;
- (UIView *)findLikeButtonInView:(UIView *)view;
- (UIView *)findShareButtonInView:(UIView *)view;
- (UIView *)findMoreButtonInView:(UIView *)view;

// 功能方法声明
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
- (void)showDislikeOnVideo;
- (void)dismissCurrentMenuPanel;
- (void)dismissCurrentMenuPanelWithCompletion:(void(^)(void))completion;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0));
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0));
#endif



@end

%hook AWEPlayInteractionViewController

- (void)viewDidLoad {
    %orig;
    
    // 设置默认值以确保功能默认启用
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 双击主开关默认值
    if (![defaults objectForKey:@"DYYYEnableDoubleTapMaster"]) {
        [defaults setBool:YES forKey:@"DYYYEnableDoubleTapMaster"];
    }
    
    // 如果是首次启动，设置默认值
    if (![defaults objectForKey:@"DYYYEnableDoubleOpenAlertController"]) {
        [defaults setBool:YES forKey:@"DYYYEnableDoubleOpenAlertController"];
    }
    
    if (![defaults objectForKey:@"DYYYEnableDoubleOpenComment"]) {
        [defaults setBool:NO forKey:@"DYYYEnableDoubleOpenComment"]; // 默认不直接打开评论
    }
    
    if (![defaults objectForKey:@"DYYYDouble"]) {
        [defaults setBool:NO forKey:@"DYYYDouble"]; // 默认不禁用双击点赞
    }
    
    // 设置双击操作的默认值
    if (![defaults objectForKey:@"DYYYDoubleTapDownload"]) {
        [defaults setBool:YES forKey:@"DYYYDoubleTapDownload"];
    }
    
    if (![defaults objectForKey:@"DYYYDoubleTapDownloadAudio"]) {
            [defaults setBool:YES forKey:@"DYYYDoubleTapDownloadAudio"];
        }
        
        if (![defaults objectForKey:@"DYYYDoubleInterfaceDownload"]) {
            [defaults setBool:YES forKey:@"DYYYDoubleInterfaceDownload"];
        }
        
        if (![defaults objectForKey:@"DYYYDoubleTapCopyDesc"]) {
        [defaults setBool:YES forKey:@"DYYYDoubleTapCopyDesc"];
    }
    
    if (![defaults objectForKey:@"DYYYDoubleTapComment"]) {
        [defaults setBool:YES forKey:@"DYYYDoubleTapComment"];
    }
    
    if (![defaults objectForKey:@"DYYYDoubleTapLike"]) {
        [defaults setBool:YES forKey:@"DYYYDoubleTapLike"];
    }
    
    if (![defaults objectForKey:@"DYYYDoubleTapPip"]) {
        [defaults setBool:YES forKey:@"DYYYDoubleTapPip"];
    }
    
    if (![defaults objectForKey:@"DYYYDoubleTapshowSharePanel"]) {
        [defaults setBool:YES forKey:@"DYYYDoubleTapshowSharePanel"];
    }
    
    if (![defaults objectForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {
            [defaults setBool:YES forKey:@"DYYYDoubleTapshowDislikeOnVideo"];
        }
        
        if (![defaults objectForKey:@"DYYYDoubleCreateVideo"]) {
            [defaults setBool:YES forKey:@"DYYYDoubleCreateVideo"];
        }
    
    // 接口显示清晰选项默认值
    if (![defaults objectForKey:@"DYYYShowAllVideoQuality"]) {
        [defaults setBool:YES forKey:@"DYYYShowAllVideoQuality"];
    }
    
    // 同步设置
    [defaults synchronize];
}

- (void)onVideoPlayerViewDoubleClicked:(id)arg1 {
    BOOL isSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDouble"];
    if (!isSwitchOn) {
        %orig;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (![self.parentViewController isKindOfClass:%c(AWEFeedCellViewController)]) {
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        CGRect frame = self.view.frame;
        frame.size.height = self.view.superview.frame.size.height - 83;
        self.view.frame = frame;
    }
}

- (void)onPlayer:(id)arg0 didDoubleClick:(id)arg1 {
    // 检查双击功能总开关
    BOOL isDoubleTapEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleTapMaster"];
    if (!isDoubleTapEnabled) {
        %orig; // 如果总开关关闭，执行原始双击逻辑
        return;
    }
    
    BOOL isPopupEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenAlertController"];
    BOOL isDirectCommentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenComment"];

    if (isDirectCommentEnabled) {
        [self performCommentAction];
        return;
    }

    if (isPopupEnabled) {
        AWEAwemeModel *awemeModel = nil;

        if ([self respondsToSelector:@selector(awemeModel)]) {
            awemeModel = [self performSelector:@selector(awemeModel)];
        } else if ([self respondsToSelector:@selector(currentAwemeModel)]) {
            awemeModel = [self performSelector:@selector(currentAwemeModel)];
        } else if ([self respondsToSelector:@selector(getAwemeModel)]) {
            awemeModel = [self performSelector:@selector(getAwemeModel)];
        }

        if (!awemeModel) {
            UIViewController *baseVC = [self valueForKey:@"awemeBaseViewController"];
            if (baseVC && [baseVC respondsToSelector:@selector(model)]) {
                awemeModel = [baseVC performSelector:@selector(model)];
            } else if (baseVC && [baseVC respondsToSelector:@selector(awemeModel)]) {
                awemeModel = [baseVC performSelector:@selector(awemeModel)];
            }
        }

        if (!awemeModel) {
            %orig;
            return;
        }

        [self createFluentDesignDraggableMenuWithAwemeModel:awemeModel touchPoint:[arg1 locationInView:self.view]];
        return;
    }

    %orig;
}

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
- (void)createFluentDesignDraggableMenuWithAwemeModel:(AWEAwemeModel *)awemeModel touchPoint:(CGPoint)touchPoint {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            [view removeFromSuperview];
        }
    }
    // 创建透明背景
    UIView *overlayView = [[UIView alloc] initWithFrame:topVC.view.bounds];
    overlayView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3]; // 半透明黑色背景
    overlayView.alpha = 0;
    overlayView.tag = 9527;

    // 监听背景色变化
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDYYYBackgroundColorChanged:) name:@"DYYYBackgroundColorChanged" object:nil];

    CGFloat menuHeight = 480;
    CGFloat menuWidth = topVC.view.bounds.size.width;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = topVC.view.safeAreaInsets.bottom;
    }
    
    // 移除底部栏高度限制，避免影响双击窗口显示
    // CGFloat tabBarHeight = getTabBarHeight();
    CGFloat totalBottomOffset = bottomSafe;

    UIView *menuContainer = [[UIView alloc] initWithFrame:CGRectMake(0, topVC.view.bounds.size.height, menuWidth, menuHeight + totalBottomOffset)];
    menuContainer.layer.cornerRadius = 20;
    menuContainer.clipsToBounds = YES;
    menuContainer.layer.masksToBounds = NO;
    menuContainer.backgroundColor = [UIColor whiteColor]; // 白色弹窗背景
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOffset = CGSizeMake(0, -10);
    menuContainer.layer.shadowRadius = 20;
    menuContainer.layer.shadowOpacity = 0.3;
    [overlayView addSubview:menuContainer];

    // 获取保存的颜色
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBlurEffectColor"];
    UIColor *blurColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : nil;
    
    // 决定毛玻璃效果风格和图标颜色
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleLight;
    
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    if (blurColor) {
        // 计算亮度值，使用感知亮度公式
        CGFloat brightness = 0;
        CGFloat r, g, b, a;
        if ([blurColor getRed:&r green:&g blue:&b alpha:&a]) {
            // 使用感知亮度公式计算亮度
            brightness = 0.299 * r + 0.587 * g + 0.114 * b;
        } else if ([blurColor getWhite:&brightness alpha:&a]) {
            // 灰度颜色处理
        }
        if (brightness < 0.5) {
            // 深色背景
            if (@available(iOS 13.0, *)) {
                blurStyle = UIBlurEffectStyleSystemMaterialDark;
            } else {
                blurStyle = UIBlurEffectStyleDark;
            }
        } else {
            // 浅色背景
            if (@available(iOS 13.0, *)) {
                blurStyle = UIBlurEffectStyleSystemMaterialLight;
            } else {
                blurStyle = UIBlurEffectStyleLight;
            }
        }
    } else {
        // 使用默认风格
        BOOL isModernStyle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableModern"];
        if (isModernStyle) {
            if (@available(iOS 13.0, *)) {
                blurStyle = UIBlurEffectStyleSystemMaterialDark;
            } else {
                blurStyle = UIBlurEffectStyleDark;
            }
        }
    }

    UIVisualEffectView *contentPanel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    contentPanel.frame = menuContainer.bounds;
    contentPanel.layer.cornerRadius = 20;
    contentPanel.clipsToBounds = YES;
    [menuContainer addSubview:contentPanel];
    
    // 背景色
    if (blurColor) {
        UIView *colorView = [[UIView alloc] initWithFrame:contentPanel.bounds];
        colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        colorView.backgroundColor = [blurColor colorWithAlphaComponent:0.3];
        colorView.tag = 8888;
        [contentPanel.contentView insertSubview:colorView atIndex:0];
    }
    
    // 更紧凑的头部视图，直接贴顶部
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 70)]; // 减少高度，从0开始
    headerView.tag = 60;
    [contentPanel.contentView addSubview:headerView];
    
    // 在头部区域视图模式切换器
    UISegmentedControl *viewModeSegment = [[UISegmentedControl alloc] initWithItems:@[@"卡片视图", @"列表视图"]];
    viewModeSegment.frame = CGRectMake(20, 35, menuWidth - 40, 30);
    viewModeSegment.selectedSegmentTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.85];
    [viewModeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    
    // 根据之前获取的设置设置选定索引
    if (isListView) {
        viewModeSegment.selectedSegmentIndex = 1; // 列表视图
    } else {
        viewModeSegment.selectedSegmentIndex = 0; // 卡片视图
    }

    // 动作处理方法
    [viewModeSegment addTarget:self action:@selector(viewModeChanged:) forControlEvents:UIControlEventValueChanged];
    [headerView addSubview:viewModeSegment];
    
    // 修改：按钮尺寸优化，更紧凑
    CGFloat buttonSize = 28; // 减小按钮尺寸
    CGFloat rightMargin = 20;
    CGFloat spacing = 8; // 按钮间距
    
    // 创建调整大小按钮（最大化/恢复）- 使用彩色图标
    UIButton *resizeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    resizeButton.frame = CGRectMake(menuWidth - rightMargin - buttonSize * 3 - spacing * 2, 5, buttonSize, buttonSize);
    resizeButton.clipsToBounds = YES;
    resizeButton.backgroundColor = [UIColor clearColor];

    // 创建图标视图 - 使用彩色图标而非template模式
    UIImageView *resizeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
    resizeImageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *resizeImage = [UIImage systemImageNamed:@"arrow.up.and.down.circle.fill"];
    resizeImageView.image = resizeImage; // 不使用renderingMode来保持原始颜色
    [resizeButton addSubview:resizeImageView];

    // 拖拽手势和点击事件
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeMenuPan:)];
    [resizeButton addGestureRecognizer:pan];
    [resizeButton addTarget:self action:@selector(customMenuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:resizeButton];

    // 在resizeButton旁边颜色选择按钮 - 使用彩色图标
    UIButton *colorPickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    colorPickerButton.frame = CGRectMake(menuWidth - rightMargin - buttonSize * 2 - spacing, 5, buttonSize, buttonSize);
    colorPickerButton.backgroundColor = [UIColor clearColor];
    colorPickerButton.clipsToBounds = YES;

    // 使用彩色图标
    UIImageView *toggleImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
    toggleImageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *toggleImage = [UIImage systemImageNamed:@"paintpalette.fill"]; // 取色器图标
    toggleImageView.image = toggleImage; // 不使用renderingMode来保持原始颜色
    [colorPickerButton addSubview:toggleImageView];

    // 点击事件
    [colorPickerButton addTarget:self action:@selector(showBlurColorPicker:) forControlEvents:UIControlEventTouchUpInside];
    colorPickerButton.tag = 200;
    [headerView addSubview:colorPickerButton];

    // 关闭按钮 - 使用彩色图标
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(menuWidth - rightMargin - buttonSize, 5, buttonSize, buttonSize);
    closeButton.backgroundColor = [UIColor clearColor];
    closeButton.clipsToBounds = YES;

    // 使用彩色图标
    UIImageView *closeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, buttonSize, buttonSize)];
    closeImageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *closeImage = [UIImage systemImageNamed:@"xmark.circle.fill"];
    closeImageView.image = closeImage; // 不使用renderingMode来保持原始颜色
    [closeButton addSubview:closeImageView];

    [closeButton addTarget:self action:@selector(dismissFluentMenuByButton:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeButton];

    // 菜单按钮（彩色）放在左侧 - 贴顶部放置
    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    menuButton.frame = CGRectMake(20, 5, 70, 26); // 减小高度，贴顶部
    [menuButton setTitle:@"菜单" forState:UIControlStateNormal];
    menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:14]; // 减小字体
    menuButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.85];
    [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    menuButton.layer.cornerRadius = 6; // 减小圆角
    menuButton.layer.shadowColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.3].CGColor;
    menuButton.layer.shadowOpacity = 0.5;
    menuButton.layer.shadowRadius = 6; // 减小阴影
    menuButton.layer.shadowOffset = CGSizeMake(0, 2);
    [menuButton addTarget:self action:@selector(showDYYYSettingPanelFromMenuButton:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:menuButton];

    // 视觉风格切换按钮
    UIButton *styleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    styleButton.frame = CGRectMake(100, 5, 60, 26);
    [styleButton setTitle:@"主题样式" forState:UIControlStateNormal];
    styleButton.titleLabel.font = [UIFont systemFontOfSize:14];
    styleButton.layer.cornerRadius = 6;
    styleButton.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.3];
    [styleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [styleButton addTarget:self action:@selector(showVisualStyleSelector:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:styleButton];

    // 确保按钮显示在最上层
    [headerView bringSubviewToFront:resizeButton];
    [headerView bringSubviewToFront:colorPickerButton];
    [headerView bringSubviewToFront:closeButton];
    [headerView bringSubviewToFront:menuButton];
    [headerView bringSubviewToFront:styleButton];

    BOOL isImageContent = (awemeModel.awemeType == 68);
    // 调整scrollView位置以适应新的headerView位置
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 70, menuWidth, menuHeight - 70)]; // 从Y=70开始
    scrollView.showsVerticalScrollIndicator = YES;
    scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [contentPanel.contentView addSubview:scrollView];

    // 获取模块数据
    NSArray<DYYYMenuModule *> *modules = [self createMenuModulesForCurrentContext];
    
    // 使用工厂创建对应样式的构建器
    DYYYMenuStyleBuilder *builder = nil;
    DYYYMenuVisualStyle visualStyle = (DYYYMenuVisualStyle)[[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYMenuVisualStyle"];
    if (visualStyle == DYYYMenuVisualStyleNeuomorphic) {
        builder = [[DYYYNeuomorphicStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
    } else {
        if (isListView) {
            builder = [[DYYYListStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        } else {
            builder = [[DYYYCardStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        }
    }
    builder.delegate = self;
    
    // 构建菜单
    [builder buildMenuWithAnimation:YES];
    
    // 字体规范化
    [self normalizeListViewFonts:scrollView];

    // 手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFluentMenu:)];
    [overlayView addGestureRecognizer:tapGesture];

    // 在创建菜单容器后为其点击手势，当用户点击菜单时显示头部控制区
    UITapGestureRecognizer *menuTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuContainerTap:)];
    menuTapGesture.cancelsTouchesInView = NO; // 不干扰其他触摸事件
    [menuContainer addGestureRecognizer:menuTapGesture];

    // 弹窗支持拖动
    UIPanGestureRecognizer *dragPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_handleSettingPanelPan:)];
    [menuContainer addGestureRecognizer:dragPan];
    
    // 下拉关闭手势（始终启用）
    UISwipeGestureRecognizer *swipeDownRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuSwipeDown:)];
    swipeDownRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [menuContainer addGestureRecognizer:swipeDownRecognizer];
    
    // 根据设置增强手势控制（包括双击菜单功能）
    BOOL enableCustomDoubleTap = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleTapMaster"];
    if (enableCustomDoubleTap) {
        [self enhanceGestureControlsForMenu:menuContainer];
    }

    [topVC.view addSubview:overlayView];

    [UIView animateWithDuration:0.3 animations:^{
        overlayView.alpha = 1;
    }];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect frame = menuContainer.frame;
        frame.origin.y = topVC.view.bounds.size.height - menuHeight;
        menuContainer.frame = frame;
    } completion:nil];
    
    // 在菜单显示后启动自动隐藏计时器
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupHeaderAutoHideTimer];
    });
}

%new
- (void)dismissFluentMenu:(UITapGestureRecognizer *)gesture {
    UIView *overlayView = gesture.view;
    CGPoint location = [gesture locationInView:overlayView];
    UIView *menuContainer = nil;
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            break;
        }
    }
    if (menuContainer && !CGRectContainsPoint(menuContainer.frame, location)) {
        [UIView animateWithDuration:0.3 animations:^{
            overlayView.alpha = 0;
            CGRect frame = menuContainer.frame;
            frame.origin.y = overlayView.bounds.size.height;
            menuContainer.frame = frame;
        } completion:^(BOOL finished) {
            [overlayView removeFromSuperview];
        }];
    }
}

%new
- (void)dismissFluentMenuByButton:(UIButton *)button {
    UIView *headerView = button.superview;
    if (!headerView) return;
    
    UIView *contentPanel = headerView.superview;
    if (!contentPanel) return;
    
    // 找到menuContainer和overlayView
    UIView *menuContainer = nil;
    UIView *overlayView = nil;
    UIView *currentView = contentPanel;
    
    // 遍历视图层次结构以正确找到overlayView
    while (currentView) {
        if (currentView.tag == 9527) {
            overlayView = currentView;
            break;
        }
        
        if (currentView.layer.cornerRadius == 20) {
            menuContainer = currentView;
        }
        
        currentView = currentView.superview;
    }
    
    if (!overlayView) return;
    if (!menuContainer) menuContainer = contentPanel.superview;
    
    // 移除通知观察者以防止内存泄漏和后续事件处理
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYBackgroundColorChanged" object:nil];
    
    // 设置用户交互为NO，防止动画期间的触摸事件
    overlayView.userInteractionEnabled = NO;
    
    [UIView animateWithDuration:0.25 animations:^{
        overlayView.alpha = 0;
        
        if (menuContainer) {
            CGRect frame = menuContainer.frame;
            frame.origin.y = overlayView.bounds.size.height;
            menuContainer.frame = frame;
        }
    } completion:^(BOOL finished) {
        // 确保在主线程中执行视图移除
        dispatch_async(dispatch_get_main_queue(), ^{
            [overlayView removeFromSuperview];
        });
    }];
}

%new
- (void)customMenuButtonTapped:(UIButton *)button {
    UIView *headerView = button.superview;
    UIView *contentPanel = headerView.superview.superview;
    UIView *menuContainer = contentPanel.superview;
    UIView *overlayView = menuContainer.superview;
    CGFloat maxHeight = overlayView.bounds.size.height - 80;
    CGFloat defaultHeight = 480; // 默认高度
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = overlayView.safeAreaInsets.bottom;
    }
    
    // 检查当前是否是最大化状态
    BOOL isMaximized = (menuContainer.frame.size.height >= (maxHeight + safeBottom - 10)); // 允许小误差
    
    // 获取按钮上的图标视图
    UIImageView *resizeImageView = nil;
    for (UIView *subview in button.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            resizeImageView = (UIImageView *)subview;
            break;
        }
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        CGRect frame = menuContainer.frame;
        if (isMaximized) {
            // 恢复到默认大小
            frame.origin.y = overlayView.bounds.size.height - defaultHeight;
            frame.size.height = defaultHeight + safeBottom;
            
            // 启动自动隐藏计时器
            [self setupHeaderAutoHideTimer];
        } else {
            // 最大化
            frame.origin.y = overlayView.bounds.size.height - maxHeight;
            frame.size.height = maxHeight + safeBottom;
            
            // 最大化时取消自动隐藏，确保控件保持可见
            [self invalidateHeaderAutoHideTimer];
            [self showHeaderControlsWithAnimation];
        }
        
        // 图标变更 - 使用彩色图标
        if (resizeImageView) {
            UIImage *newImage;
            if (isMaximized) {
                // 恢复到默认大小 - 使用向上下箭头图标
                newImage = [UIImage systemImageNamed:@"arrow.up.and.down.circle.fill"];
            } else {
                // 最大化 - 使用向下箭头图标
                newImage = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
            }
            resizeImageView.image = newImage; // 直接使用彩色图标
        }
        
        menuContainer.frame = frame;
        contentPanel.frame = menuContainer.bounds;
        
        // 同步scrollView高度
        UIScrollView *scrollView = nil;
        UIView *realContentView = contentPanel;
        if ([contentPanel isKindOfClass:[UIVisualEffectView class]]) {
            realContentView = ((UIVisualEffectView *)contentPanel).contentView;
        }
        for (UIView *sub in realContentView.subviews) {
            if ([sub isKindOfClass:[UIScrollView class]]) {
                scrollView = (UIScrollView *)sub;
                break;
            }
        }
        if (scrollView) {
            CGFloat headerHeight = headerView.frame.size.height;
            CGFloat scrollH = menuContainer.frame.size.height - headerHeight;
            scrollView.frame = CGRectMake(0, headerHeight, menuContainer.frame.size.width, MAX(0, scrollH));
        }
    }];
    
    // 执行触感反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
}

%new
- (void)resizeMenuPan:(UIPanGestureRecognizer *)pan {
    // 开始拖动时重置显示状态
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self resetHeaderControlVisibility];
    }
    
    UIView *resizeBtn = pan.view;
    UIView *headerView = resizeBtn.superview;
    UIView *contentPanel = headerView.superview.superview;
    UIView *menuContainer = contentPanel.superview;
    UIView *overlayView = menuContainer.superview;
    CGPoint translation = [pan translationInView:overlayView];
    static CGFloat startHeight = 0;
    
    // 修正：获取真实内容视图并使用它查找scrollView
    UIView *realContentView = contentPanel;
    if ([contentPanel isKindOfClass:[UIVisualEffectView class]]) {
        realContentView = ((UIVisualEffectView *)contentPanel).contentView;
    }
    
    // 查找scrollView并使用它
    UIScrollView *scrollView = nil;
    for (UIView *sub in realContentView.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) {
            scrollView = (UIScrollView *)sub;
            break;
        }
    }
    
    CGFloat minHeight = 240;
    CGFloat maxHeight = overlayView.bounds.size.height - 80;
    CGFloat headerHeight = headerView.frame.size.height;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = overlayView.safeAreaInsets.bottom;
    }
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        startHeight = menuContainer.frame.size.height;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat newHeight = startHeight - translation.y;
        newHeight = MAX(minHeight, MIN(newHeight, maxHeight));
        
        CGRect frame = menuContainer.frame;
        frame.size.height = newHeight + safeBottom; 
        frame.origin.y = overlayView.bounds.size.height - newHeight;
        menuContainer.frame = frame;
        
        contentPanel.frame = menuContainer.bounds;
        
        // 调整滚动视图的高度
        if (scrollView) {
            scrollView.frame = CGRectMake(0, headerHeight, menuContainer.frame.size.width, newHeight - headerHeight);
        }
    }
}

%new
- (void)showDYYYSettingPanelFromMenuButton:(UIButton *)button {
    // 复用 DYYY.xm 里 UIWindow 的双指长按弹窗逻辑
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (topVC) {
        // 使用 DYYYSettings.xm 中的 showDYYYSettingsVC 函数
        extern void showDYYYSettingsVC(UIViewController *rootVC);
        showDYYYSettingsVC(topVC);
        return;
    }
}

%new
- (void)dismissDYYYSettingPanel:(UIButton *)button {
    [button.superview.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

%new
- (void)dyyy_handleSettingPanelPan:(UIPanGestureRecognizer *)pan {
    UIView *menuContainer = pan.view;
    UIView *overlayView = menuContainer.superview;
    static CGFloat startY = 0;
    static CGFloat startOriginY = 0;
    static BOOL isDragging = NO;
    CGFloat minY = overlayView.bounds.size.height - menuContainer.frame.size.height;
    CGFloat maxY = overlayView.bounds.size.height - 100; // 最多拖到屏幕底部上方100px

    if (pan.state == UIGestureRecognizerStateBegan) {
        // 拖动开始时，确保头部控件可见
        [self resetHeaderControlVisibility];
        
        startY = [pan locationInView:overlayView].y;
        startOriginY = menuContainer.frame.origin.y;
        isDragging = YES;
    } else if (pan.state == UIGestureRecognizerStateChanged && isDragging) {
        CGFloat currentY = [pan locationInView:overlayView].y;
        CGFloat deltaY = currentY - startY;
        CGFloat newOriginY = startOriginY + deltaY;
        newOriginY = MAX(minY, MIN(newOriginY, maxY));
        CGRect frame = menuContainer.frame;
        frame.origin.y = newOriginY;
        menuContainer.frame = frame;
    } else if ((pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) && isDragging) {
        CGFloat velocityY = [pan velocityInView:overlayView].y;
        CGFloat currentOriginY = menuContainer.frame.origin.y;
        CGFloat threshold = overlayView.bounds.size.height - menuContainer.frame.size.height / 2;
        
        if (velocityY > 800 || currentOriginY > threshold) {
            [UIView animateWithDuration:0.25 animations:^{
                CGRect frame = menuContainer.frame;
                frame.origin.y = overlayView.bounds.size.height;
                menuContainer.frame = frame;
                overlayView.alpha = 0;
            } completion:^(BOOL finished) {
                [overlayView removeFromSuperview];
            }];
        } else {
            [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
                CGRect frame = menuContainer.frame;
                frame.origin.y = minY;
                menuContainer.frame = frame;
            } completion:nil];
        }
        isDragging = NO;
    }
}

%new
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            // 保持半透明黑色背景
            view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
            break;
        }
    }
}

%new
- (void)showBlurColorPicker:(UIButton *)button {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        // 从用户默认设置中获取当前的毛玻璃背景色
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBlurEffectColor"];
        UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
        picker.selectedColor = currentColor;
        picker.delegate = (id)self;
        
        // 实时更新 - 开启连续更新模式
        picker.supportsAlpha = YES;
        
        // 设置标题和说明
        picker.title = @"选择毛玻璃效果颜色";
        
        // 使用半屏模式弹出（适配不同设备）
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            picker.modalPresentationStyle = UIModalPresentationPopover;
            picker.popoverPresentationController.sourceView = button;
            picker.popoverPresentationController.sourceRect = button.bounds;
        } else {
            picker.modalPresentationStyle = UIModalPresentationPageSheet;
        }
        
        // 执行触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 呈现颜色选择器视图控制器
        [[DYYYManager getActiveTopController] presentViewController:picker animated:YES completion:nil];
    } else {
        // iOS 14以下的设备，使用替代的选择器
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择毛玻璃效果样式"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 预定义颜色选项
        NSArray<NSDictionary *> *colors = @[
            @{@"name": @"浅色", @"color": [UIColor whiteColor]},
            @{@"name": @"深色", @"color": [UIColor darkGrayColor]},
            @{@"name": @"蓝色", @"color": [UIColor systemBlueColor]},
            @{@"name": @"红色", @"color": [UIColor systemRedColor]},
            @{@"name": @"绿色", @"color": [UIColor systemGreenColor]},
            @{@"name": @"紫色", @"color": [UIColor systemPurpleColor]},
            @{@"name": @"橙色", @"color": [UIColor systemOrangeColor]},
            @{@"name": @"粉色", @"color": [UIColor systemPinkColor]},
            @{@"name": @"黄色", @"color": [UIColor systemYellowColor]},
            @{@"name": @"青色", @"color": [UIColor cyanColor]}
        ];
        
        for (NSDictionary *colorInfo in colors) {
            NSString *name = colorInfo[@"name"];
            UIColor *color = colorInfo[@"color"];
            UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // 应用所选颜色
                [self updateBlurEffectWithColor:color];
                
                // 保存用户选择
                NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
                [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBlurEffectColor"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // 立即更新颜色选择按钮
                [self updateColorPickerButtonWithColor:color];
                
                // 触感反馈
                if (@available(iOS 10.0, *)) {
                    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                    [generator prepare];
                    [generator impactOccurred];
                }
            }];
            
            // 颜色指示图标
            UIImage *colorImage = createColorCircleImage(color, CGSizeMake(20, 20));
            [action setValue:colorImage forKey:@"image"];
            [alert addAction:action];
        }
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = button;
            alert.popoverPresentationController.sourceRect = button.bounds;
        }
        
        [[DYYYManager getActiveTopController] presentViewController:alert animated:YES completion:nil];
    }
}

%new
- (void)updateBlurEffectWithColor:(UIColor *)color {
    // 获取视图层次
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            for (UIView *subview in view.subviews) {
                // 查找毛玻璃效果视图
                if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                    
                    // 处理不同的颜色以创建不同风格的毛玻璃效果
                    UIBlurEffect *blurEffect;
                    
                    // 确定最合适的模糊效果风格
                    UIBlurEffectStyle style = UIBlurEffectStyleLight;
                    CGFloat brightness = 0;
                    CGFloat r, g, b, a;
                    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
                        // 使用感知亮度公式计算亮度
                        brightness = 0.299 * r + 0.587 * g + 0.114 * b;
                    } else if ([color getWhite:&brightness alpha:&a]) {
                        // 灰度颜色处理
                    }
                    
                    if (brightness < 0.5) {
                        // 深色
                        if (@available(iOS 13.0, *)) {
                            style = UIBlurEffectStyleSystemMaterialDark;
                        } else {
                            style = UIBlurEffectStyleDark;
                        }
                    } else {
                        // 浅色
                        if (@available(iOS 13.0, *)) {
                            style = UIBlurEffectStyleSystemMaterialLight;
                        } else {
                            style = UIBlurEffectStyleLight;
                        }
                    }
                    
                    blurEffect = [UIBlurEffect effectWithStyle:style];
                    
                    // 保存模糊效果样式以便后续检测
                    objc_setAssociatedObject(blurEffect, "blurStyleNumber", @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    
                    // 应用新的毛玻璃效果
                    [UIView transitionWithView:blurView 
                                      duration:0.2
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                                        [blurView setEffect:blurEffect];
                                        
                                        // 一个背景色层让毛玻璃效果带有所选颜色
                                        UIView *colorView = [blurView viewWithTag:8888];
                                        if (!colorView) {
                                            colorView = [[UIView alloc] initWithFrame:blurView.bounds];
                                            colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                                            colorView.tag = 8888;
                                            [blurView.contentView insertSubview:colorView atIndex:0];
                                        }
                                        colorView.backgroundColor = [color colorWithAlphaComponent:0.3];
                                    } 
                                    completion:^(BOOL finished) {
                                        // 背景颜色变化后立即重新应用智能文本颜色
                                        [self applySmartTextColorToAllMenuItems];
                                        
                                        // 立即更新所有头部控件颜色
                                        [self updateHeaderControlsColorForBackground:color];
                                    }];
                    
                    // 立即更新颜色选择按钮
                    [self updateColorPickerButtonWithColor:color];
                    
                    break;
                }
            }
            break;
        }
    }
}

%new
- (void)updateHeaderControlsColorForBackground:(UIColor *)backgroundColor {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    
    // 计算背景亮度决定图标颜色
    CGFloat brightness = 0;
    CGFloat r, g, b, a;
    if ([backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
        // 使用感知亮度公式计算亮度
        brightness = 0.299 * r + 0.587 * g + 0.114 * b;
    } else if ([backgroundColor getWhite:&brightness alpha:&a]) {
        // 灰度颜色处理
    }
    
    // 如果无法用getWhite获取亮度，尝试用RGB计算
    if (brightness == 0) {
        CGFloat r, g, b, a;
        if ([backgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
            brightness = 0.299 * r + 0.587 * g + 0.114 * b;
        }
    }
    
    // 根据背景亮度选择图标颜色
    UIColor *iconColor;
    if (brightness > 0.7) {
        // 浅色背景用深色图标
        iconColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    } else if (brightness < 0.3) {
        // 深色背景用浅色图标
        iconColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    } else {
        // 中等亮度背景用对比度较高的颜色
        iconColor = brightness > 0.5 ? [UIColor colorWithWhite:0.15 alpha:1.0] : [UIColor colorWithWhite:0.85 alpha:1.0];
    }
    
    // 查找并更新所有头部控件
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            for (UIView *subview in view.subviews) {
                if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                    for (UIView *contentView in blurView.contentView.subviews) {
                        if (contentView.tag == 60) { // 头部视图tag
                            [self updateViewIconColors:contentView withColor:iconColor];
                            break;
                        }
                    }
                    break;
                }
            }
            break;
        }
    }
}

%new
- (void)updateViewIconColors:(UIView *)view withColor:(UIColor *)color {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            
            // 只更新按钮中明确使用模板模式的图标
            for (UIView *buttonSubview in button.subviews) {
                if ([buttonSubview isKindOfClass:[UIImageView class]]) {
                    UIImageView *imageView = (UIImageView *)buttonSubview;
                    // 检查图标是否使用了模板模式
                    if (imageView.image && imageView.image.renderingMode == UIImageRenderingModeAlwaysTemplate) {
                        imageView.tintColor = color;
                    }
                    // 不处理其他渲染模式的图像，保留其原始颜色
                }
            }
            
            // 只处理模板模式的按钮图片
            if (button.currentImage && button.currentImage.renderingMode == UIImageRenderingModeAlwaysTemplate) {
                button.tintColor = color;
            }
            
            // 更新按钮文字颜色（如菜单按钮）
            [button setTitleColor:color forState:UIControlStateNormal];
        } else if ([subview isKindOfClass:[UISegmentedControl class]]) {
            UISegmentedControl *segmentControl = (UISegmentedControl *)subview;
            
            // 更新段控制器的文字颜色
            if (@available(iOS 13.0, *)) {
                [segmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: color} forState:UIControlStateNormal];
            } else {
                segmentControl.tintColor = color;
            }
        }
        
        // 递归处理子视图
        [self updateViewIconColors:subview withColor:color];
    }
}

%new
- (void)updateColorPickerButtonWithColor:(UIColor *)color {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            for (UIView *subview in view.subviews) {
                // 找到按钮容器
                if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                    for (UIView *contentView in blurView.contentView.subviews) {
                        if (contentView.tag == 60) {
                            for (UIView *headerSubview in contentView.subviews) {
                                if ([headerSubview isKindOfClass:[UIButton class]] && headerSubview.tag == 200) { // 颜色选择按钮
                                    UIButton *colorButton = (UIButton *)headerSubview;
                                    
                                    // 计算背景亮度
                                    CGFloat brightness = 0;
                                    CGFloat r, g, b, a;
                                    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
                                        // 使用感知亮度公式计算亮度
                                        brightness = 0.299 * r + 0.587 * g + 0.114 * b;
                                    } else if ([color getWhite:&brightness alpha:&a]) {
                                        // 灰度颜色处理
                                    }
                                    
                                    // 如果无法用getWhite获取亮度，尝试用RGB计算
                                    if (brightness == 0) {
                                        CGFloat r, g, b, a;
                                        if ([color getRed:&r green:&g blue:&b alpha:&a]) {
                                            brightness = 0.299 * r + 0.587 * g + 0.114 * b;
                                        }
                                    }
                                    
                                    // 更新按钮图标颜色 - 根据背景色亮度自动调整
                                    for (UIView *btnSubview in colorButton.subviews) {
                                        if ([btnSubview isKindOfClass:[UIImageView class]]) {
                                            UIImageView *imageView = (UIImageView *)btnSubview;
                                            
                                            // 根据背景色亮度选择对比色
                                            if (brightness > 0.7) {
                                                // 浅色背景用深色图标
                                                imageView.tintColor = [UIColor colorWithWhite:0.2 alpha:1.0];
                                            } else if (brightness < 0.3) {
                                                // 深色背景用浅色图标
                                                imageView.tintColor = [UIColor colorWithWhite:0.9 alpha:1.0];
                                            } else {
                                                // 中等亮度背景用对比度较高的颜色
                                                imageView.tintColor = brightness > 0.5 ? 
                                                    [UIColor colorWithWhite:0.15 alpha:1.0] : 
                                                    [UIColor colorWithWhite:0.85 alpha:1.0];
                                            }
                                        }
                                    }
                                    
                                    // 移除原有的渐变背景，改为简单的颜色指示器
                                    for (CALayer *layer in [colorButton.layer.sublayers copy]) {
                                        if ([layer isKindOfClass:[CAGradientLayer class]]) {
                                            [layer removeFromSuperlayer];
                                        }
                                    }
                                    
                                    // 颜色指示器 - 在按钮下方一个小色条
                                    CALayer *colorIndicator = [CALayer layer];
                                    colorIndicator.frame = CGRectMake(2, colorButton.bounds.size.height - 4, colorButton.bounds.size.width - 4, 2);
                                    colorIndicator.backgroundColor = color.CGColor;
                                    colorIndicator.cornerRadius = 1;
                                    [colorButton.layer addSublayer:colorIndicator];
                                    
                                    break;
                                }
                            }
                            break;
                        }
                    }
                    break;
                }
            }
            break;
        }
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
%new
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    if (@available(iOS 14.0, *)) {
        UIColor *color = viewController.selectedColor;
        
        // 立即应用颜色效果
        [self updateBlurEffectWithColor:color];
        
        // 保存用户选择
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
        [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBlurEffectColor"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 立即更新颜色选择按钮的外观
        [self updateColorPickerButtonWithColor:color];
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
            [generator prepare];
            [generator selectionChanged];
        }
    }
}

%new
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    // 颜色选择器关闭时，确保使用最终选择的颜色
    if (@available(iOS 14.0, *)) {
        UIColor *finalColor = viewController.selectedColor;
        [self updateBlurEffectWithColor:finalColor];
        
        // 保存用户选择
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:finalColor];
        [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBlurEffectColor"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
#endif



%new
- (void)viewModeChanged:(UISegmentedControl *)segmentControl {
    // 获取当前索引
    NSInteger selectedIndex = segmentControl.selectedSegmentIndex;
    
    // 只区分列表视图和卡片视图
    BOOL isListView = (selectedIndex == 1);
    
    // 触感反馈
    if (@available(iOS 10.0, *)) {
        UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
        [generator prepare];
        [generator selectionChanged];
    }
    
    // 视觉反馈
    [UIView animateWithDuration:0.15 animations:^{
        segmentControl.alpha = 0.7;
        segmentControl.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            segmentControl.alpha = 1.0;
            segmentControl.transform = CGAffineTransformIdentity;
        }];
    }];
    
    // 设置标志 - 只更新视图模式，不改变视觉风格
    [[NSUserDefaults standardUserDefaults] setBool:isListView forKey:@"DYYYListViewMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 应用视图模式变化
    [self applyViewModeChange:isListView];
}

// MARK: - 工厂模式相关方法
%new
- (void)recreateMenuButtonsForViewMode:(BOOL)isListView {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIScrollView *scrollView = [self findScrollViewInTopViewController:topVC];
    
    if (!scrollView) return;
    
    // 获取模块数据
    NSArray<DYYYMenuModule *> *modules = [self createMenuModulesForCurrentContext];
    
    // 使用工厂创建对应样式的构建器
    DYYYMenuStyleBuilder *builder = nil;
    DYYYMenuVisualStyle visualStyle = (DYYYMenuVisualStyle)[[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYMenuVisualStyle"];
    BOOL currentListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];

    if (visualStyle == DYYYMenuVisualStyleNeuomorphic) {
        builder = [[DYYYNeuomorphicStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
    } else {
        if (isListView) {
            builder = [[DYYYListStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        } else {
            builder = [[DYYYCardStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        }
    }
    builder.delegate = self;
    
    // 构建菜单
    [builder buildMenuWithAnimation:YES];
}

%new
- (UIScrollView *)findScrollViewInTopViewController:(UIViewController *)topVC {
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            return [self findScrollViewInView:view];
        }
    }
    return nil;
}

%new
- (UIScrollView *)findScrollViewInView:(UIView *)view {
    if ([view isKindOfClass:[UIScrollView class]]) {
        return (UIScrollView *)view;
    }
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *contentSubview in blurView.contentView.subviews) {
                if ([contentSubview isKindOfClass:[UIScrollView class]]) {
                    return (UIScrollView *)contentSubview;
                }
            }
        }
        
        UIScrollView *result = [self findScrollViewInView:subview];
        if (result) return result;
    }
    return nil;
}

%new
- (void)performScreenshotAction {
    // 直接调用DYYYScreenshot.h中声明的截图方法
    [self dyyy_startCustomScreenshotProcess];
}

%new
- (NSArray<DYYYMenuModule *> *)createMenuModulesForCurrentContext {
    AWEAwemeModel *awemeModel = [self getCurrentAwemeModel];
    if (!awemeModel) return @[];
    
    NSMutableArray<DYYYMenuModule *> *menuModules = [NSMutableArray array];
    BOOL isImageContent = (awemeModel.awemeType == 68);
    
    // 下载功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownload"] ||
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownload"]) {
        
        BOOL isLivePhoto = NO;
        AWEImageAlbumImageModel *currentImageModel = nil;
        
        if (isImageContent) {
            if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
            } else {
                currentImageModel = awemeModel.albumImages.firstObject;
            }
            isLivePhoto = (currentImageModel && currentImageModel.clipVideo != nil);
        }
        
        DYYYMenuModule *downloadModule = [DYYYMenuModule moduleWithTitle:isLivePhoto ? @"保存实况照片" : (isImageContent ? @"保存图片" : @"保存视频")
                                                                     icon:isLivePhoto ? @"livephoto" : @"arrow.down.circle"
                                                                    color:isLivePhoto ? @"#FF2D55" : @"#0078D7"
                                                                   action:^{
            // 下载功能不需要额外延迟，因为已经在 handleModuleButtonTap 中处理了
            if (isImageContent) {
                AWEImageAlbumImageModel *currentImageModel = nil;
                if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                    currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
                } else {
                    currentImageModel = awemeModel.albumImages.firstObject;
                }
                
                if (currentImageModel && currentImageModel.clipVideo != nil) {
                    // 实况照片下载逻辑
                    NSURL *imageURL = nil;
                    for (NSString *urlString in currentImageModel.urlList) {
                        NSURL *url = [NSURL URLWithString:urlString];
                        NSString *pathExtension = [url.path.lowercaseString pathExtension];
                        if (![pathExtension isEqualToString:@"image"]) {
                            imageURL = url;
                            break;
                        }
                    }
                    
                    if (!imageURL && currentImageModel.urlList.count > 0) {
                        imageURL = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                    }
                    
                    // 获取视频URL
                    NSURL *videoURL = nil;
                    if ([currentImageModel.clipVideo respondsToSelector:@selector(playURL)]) {
                        id playURL = [currentImageModel.clipVideo playURL];
                        if ([playURL respondsToSelector:@selector(getDYYYSrcURLDownload)]) {
                            videoURL = [playURL getDYYYSrcURLDownload];
                        } else if ([playURL respondsToSelector:@selector(originURLList)]) {
                            NSArray *urlList = [playURL originURLList];
                            if (urlList && urlList.count > 0) {
                                videoURL = [NSURL URLWithString:urlList.firstObject];
                            }
                        }
                    }
                    
                    if (imageURL && videoURL) {
                        [DYYYManager downloadLivePhoto:imageURL
                                              videoURL:videoURL
                                            completion:^{
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [DYYYManager showToast:@"实况照片已保存到相册"];
                                                });
                                            }];
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [DYYYManager showToast:@"无法获取实况照片资源"];
                        });
                    }
                } else if (currentImageModel && currentImageModel.urlList.count > 0) {
                    // 普通图片下载
                    NSURL *imageURL = nil;
                    for (NSString *urlString in currentImageModel.urlList) {
                        NSURL *url = [NSURL URLWithString:urlString];
                        NSString *pathExtension = [url.path.lowercaseString pathExtension];
                        if (![pathExtension isEqualToString:@"image"]) {
                            imageURL = url;
                            break;
                        }
                    }
                    
                    if (!imageURL && currentImageModel.urlList.count > 0) {
                        imageURL = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                    }
                    
                    if (imageURL) {
                        [DYYYManager downloadMedia:imageURL mediaType:MediaTypeImage completion:^(BOOL success){
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (success) {
                                } else {
                                    [DYYYManager showToast:@"图片保存失败"];
                                }
                            });
                        }];
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [DYYYManager showToast:@"无法获取图片资源"];
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [DYYYManager showToast:@"没有可用的图片资源"];
                    });
                }
            } else {
                AWEVideoModel *videoModel = awemeModel.video;
                if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                    NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                    [DYYYManager downloadMedia:url mediaType:MediaTypeVideo completion:^(BOOL success){
                        if (success) {
                        }
                    }];
                }
            }
        }];
        [menuModules addObject:downloadModule];
        
        // 批量下载模块
        if (isImageContent && awemeModel.albumImages.count > 1) {
            BOOL hasLivePhoto = NO;
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.clipVideo != nil) {
                    hasLivePhoto = YES;
                    break;
                }
            }
            
            DYYYMenuModule *downloadAllModule = [DYYYMenuModule moduleWithTitle:hasLivePhoto ? @"保存所有实况照片" : @"保存所有图片"
                                                                            icon:hasLivePhoto ? @"rectangle.stack" : @"square.grid.2x2"
                                                                           color:hasLivePhoto ? @"#FF9500" : @"#00B7C3"
                                                                          action:^{
                if (hasLivePhoto) {
                    NSMutableArray *livePhotos = [NSMutableArray array];
                    for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                        if (imageModel.clipVideo != nil && imageModel.urlList.count > 0) {
                            NSURL *photoURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                            NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                            [livePhotos addObject:@{@"imageURL": photoURL.absoluteString, @"videoURL": videoURL.absoluteString}];
                        }
                    }
                    if (livePhotos.count > 0) {
                        [DYYYManager downloadAllLivePhotos:livePhotos];
                    } else {
                        [DYYYManager showToast:@"没有发现可下载的实况照片"];
                    }
                } else {
                    NSMutableArray *imageURLs = [NSMutableArray array];
                    for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                        if (imageModel.urlList.count > 0) {
                            [imageURLs addObject:imageModel.urlList.firstObject];
                        }
                    }
                    [DYYYManager downloadAllImages:imageURLs];
                }
            }];
            [menuModules addObject:downloadAllModule];
        }
    }

    if (!isImageContent && [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnablePipPlayer"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnablePipPlayer"]) {
        
        DYYYMenuModule *pipModule = [DYYYMenuModule moduleWithTitle:@"小窗播放"
                                                                icon:@"pip.enter"
                                                               color:@"#007AFF"
                                                              action:^{
            // 获取当前视频模型
            AWEVideoModel *videoModel = awemeModel.video;
            if (videoModel) {
                // 使用正确的类名和方法
                DYYYPipManager *pipManager = [DYYYPipManager sharedManager];
                [pipManager createPipWithAwemeModel:awemeModel];
            }
        }];
        [menuModules addObject:pipModule];
    }   

    // 音频保存功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownloadAudio"] ||
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownloadAudio"]) {
        
        DYYYMenuModule *audioModule = [DYYYMenuModule moduleWithTitle:@"保存音频"
                                                                icon:@"music.note"
                                                               color:@"#E3008C"
                                                              action:^{
            AWEMusicModel *musicModel = awemeModel.music;
            if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
                NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
                [DYYYManager downloadMedia:url mediaType:MediaTypeAudio completion:^(BOOL success){
                    if (success) {
                    }
                }];
            }
        }];
        [menuModules addObject:audioModule];
    }    
    
    // 截图功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableScreenshot"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableScreenshot"]) {
        
        DYYYMenuModule *screenshotModule = [DYYYMenuModule moduleWithTitle:@"截图功能"
                                                                      icon:@"camera.viewfinder"
                                                                     color:@"#4CAF50"
                                                                    action:^{
            [self dyyy_startCustomScreenshotProcess];
        }];
        [menuModules addObject:screenshotModule];
    }
    
    // 视频数据修改模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableVideoStatsCustom"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableVideoStatsCustom"]) {
        
        DYYYMenuModule *videoStatsModule = [DYYYMenuModule moduleWithTitle:@"自定义视频数据"
                                                                     icon:@"number.circle"
                                                                    color:@"#E91E63"
                                                                   action:^{
            // 调用统计数据修改弹窗
            showVideoStatsEditAlert(self);
            
            // 触发震动反馈
            if (@available(iOS 10.0, *)) {
                UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [generator impactOccurred];
            }
        }];
        [menuModules addObject:videoStatsModule];
    }

    // API解析下载功能模块
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleInterfaceDownload"] && apiKey.length > 0) {
        
        DYYYMenuModule *apiModule = [DYYYMenuModule moduleWithTitle:@"解析下载"
                                                              icon:@"network"
                                                             color:@"#4A5568"
                                                            action:^{
            NSString *shareLink = [awemeModel valueForKey:@"shareURL"];
            if (shareLink.length > 0) {
                [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
            } else {
                [DYYYManager showToast:@"无法获取分享链接"];
            }
        }];
        [menuModules addObject:apiModule];
    }
    
    // 复制文案功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapCopyDesc"] ||
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapCopyDesc"]) {
        
        DYYYMenuModule *copyTextModule = [DYYYMenuModule moduleWithTitle:@"复制文案"
                                                                    icon:@"doc.on.doc"
                                                                   color:@"#5C2D91"
                                                                  action:^{
            NSString *descText = [awemeModel valueForKey:@"descriptionString"];
            if (descText && descText.length > 0) {
                [[UIPasteboard generalPasteboard] setString:descText];
            } else {
                [DYYYManager showToast:@"没有可复制的文案"];
            }
        }];
        [menuModules addObject:copyTextModule];
    }
    
    // FLEX调试功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFLEX"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableFLEX"]) {
        
        DYYYMenuModule *flexModule = [DYYYMenuModule moduleWithTitle:@"FLEX调试"
                                                                icon:@"hammer.circle.fill"  // 修复图标
                                                               color:@"#FF9500"
                                                              action:^{
            // 显示FLEX调试界面
            Class flexManagerClass = %c(FLEXManager);
            if (flexManagerClass) {
                id flexManager = [flexManagerClass sharedManager];
                if ([flexManager respondsToSelector:@selector(showExplorer)]) {
                    [flexManager showExplorer];
                } else {
                    [DYYYManager showToast:@"FLEX功能暂不可用"];
                }
            } else {
                [DYYYManager showToast:@"FLEX未安装或不可用"];
            }
        }];
        [menuModules addObject:flexModule];
    }
    
    // 评论功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapComment"] ||
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapComment"]) {
        
        DYYYMenuModule *commentModule = [DYYYMenuModule moduleWithTitle:@"打开评论"
                                                                   icon:@"text.bubble"
                                                                  color:@"#107C10"
                                                                 action:^{
            [self performCommentAction];
        }];
        [menuModules addObject:commentModule];
    }
    
    // 点赞功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapLike"] ||
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapLike"]) {
        
        DYYYMenuModule *likeModule = [DYYYMenuModule moduleWithTitle:@"点赞视频"
                                                                icon:@"heart"
                                                               color:@"#D83B01"
                                                              action:^{
            [self performLikeAction];
        }];
        [menuModules addObject:likeModule];
    }
    
    // 分享功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowSharePanel"] ||
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowSharePanel"]) {
        
        DYYYMenuModule *shareModule = [DYYYMenuModule moduleWithTitle:@"分享视频"
                                                                 icon:@"square.and.arrow.up"
                                                                color:@"#FFB900"
                                                               action:^{
            [self showSharePanel];
        }];
        [menuModules addObject:shareModule];
    }
    
    // 小窗播放功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapPip"]) {
        
        AWEAwemeModel *awemeModel = [self getCurrentAwemeModel];
        BOOL isImageContent = (awemeModel && awemeModel.awemeType == 68);
        
        if (!isImageContent) {
            DYYYMenuModule *pipModule = [DYYYMenuModule moduleWithTitle:@"小窗播放"
                                                                   icon:@"pip.enter"
                                                                  color:@"#FF9500"
                                                                 action:^{
                AWEAwemeModel *currentAwemeModel = [self getCurrentAwemeModel];
                if (!currentAwemeModel) {
                    [DYYYManager showToast:@"无法获取当前视频"];
                    return;
                }
                
                DYYYPipManager *pipManager = [DYYYPipManager sharedManager];
                [pipManager createPipWithAwemeModel:currentAwemeModel];
                [DYYYManager showToast:@"已开启小窗播放"];
            }];
            [menuModules addObject:pipModule];
        }
    }
    
    // 制作视频功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleCreateVideo"]) {
        
        DYYYMenuModule *createVideoModule = [DYYYMenuModule moduleWithTitle:@"制作视频"
                                                                       icon:@"video.badge.plus"
                                                                      color:@"#FF6B35"
                                                                     action:^{
            AWEAwemeModel *awemeModel = [self getCurrentAwemeModel];
            if (!awemeModel) {
                [DYYYManager showToast:@"无法获取当前视频"];
                return;
            }
            
            BOOL isImageContent = (awemeModel.awemeType == 68);
            if (isImageContent) {
                // 图片内容：收集所有图片URL用于制作视频
                NSMutableArray *imageURLs = [NSMutableArray array];
                for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                    if (imageModel.urlList.count > 0) {
                        [imageURLs addObject:imageModel.urlList.firstObject];
                    }
                }
                
                if (imageURLs.count > 0) {
                    [DYYYManager createVideoFromMedia:imageURLs
                                           livePhotos:nil
                                               bgmURL:nil
                                             progress:^(NSInteger current, NSInteger total, NSString *status) {
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     float progress = total > 0 ? (float)current / (float)total : 0.0f;
                                                     [DYYYManager showToast:[NSString stringWithFormat:@"制作进度: %.0f%% - %@", progress * 100, status ?: @"处理中"]];
                                                 });
                                             }
                                           completion:^(BOOL success, NSString *message) {
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   if (success) {
                                                       [DYYYManager showToast:message ?: @"视频制作完成"];
                                                   } else {
                                                       [DYYYManager showToast:message ?: @"视频制作失败"];
                                                   }
                                               });
                                           }];
                } else {
                    [DYYYManager showToast:@"没有可用的图片资源"];
                }
            } else {
                // 视频内容：提示用户此功能主要用于图片
                [DYYYManager showToast:@"制作视频功能主要用于图片内容"];
            }
        }];
        [menuModules addObject:createVideoModule];
    }
    
    // 触发面板功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {
        
        DYYYMenuModule *dislikeModule = [DYYYMenuModule moduleWithTitle:@"触发面板"
                                                                   icon:@"ellipsis"
                                                                  color:@"#767676"
                                                                 action:^{
            [self showDislikeOnVideo];
        }];
        [menuModules addObject:dislikeModule];
    }
    

    
    // 读取上次保存的顺序并应用
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModuleOrder"];
    if (savedOrder && [savedOrder isKindOfClass:[NSArray class]] && savedOrder.count == menuModules.count) {
        NSMutableArray *orderedModules = [NSMutableArray arrayWithCapacity:menuModules.count];
        for (NSNumber *indexNumber in savedOrder) {
            NSInteger index = [indexNumber integerValue];
            if (index >= 0 && index < menuModules.count) {
                [orderedModules addObject:menuModules[index]];
            }
        }
        if (orderedModules.count == menuModules.count) {
            return orderedModules;
        }
    }
    
    return menuModules;
}

%new
- (void)refreshCurrentView {
    // 刷新当前视图的实现
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (topVC && [topVC.view respondsToSelector:@selector(setNeedsLayout)]) {
        [topVC.view setNeedsLayout];
        [topVC.view layoutIfNeeded];
    }
    
    // 发送刷新通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYRefreshCurrentView" object:nil];
}

%new
- (void)performCommentAction {
    // 查找评论按钮并触发点击
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *commentButton = [self findCommentButtonInView:topVC.view];
    
    if (commentButton && [commentButton respondsToSelector:@selector(sendActionsForControlEvents:)]) {
        [(UIButton *)commentButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    } else {
        // 尝试通过通知或其他方式触发评论
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AWECommentPanelShow" object:nil];
    }
}

%new
- (void)performLikeAction {
    // 查找点赞按钮并触发点击
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *likeButton = [self findLikeButtonInView:topVC.view];
    
    if (likeButton && [likeButton respondsToSelector:@selector(sendActionsForControlEvents:)]) {
        [(UIButton *)likeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
    } else {
        [DYYYManager showToast:@"未找到点赞按钮"];
    }
}

%new
- (void)showSharePanel {
    // 查找分享按钮并触发点击
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *shareButton = [self findShareButtonInView:topVC.view];
    
    if (shareButton && [shareButton respondsToSelector:@selector(sendActionsForControlEvents:)]) {
        [(UIButton *)shareButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    } else {
        // 备用方案：获取分享链接
        AWEAwemeModel *awemeModel = [self getCurrentAwemeModel];
        if (awemeModel) {
            NSString *shareURL = [awemeModel valueForKey:@"shareURL"];
            if (shareURL) {
                [[UIPasteboard generalPasteboard] setString:shareURL];
            } else {
                [DYYYManager showToast:@"无法获取分享链接"];
            }
        }
    }
}

%new
- (void)showDislikeOnVideo {
    // 查找更多选项按钮（三个点）并触发点击
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *moreButton = [self findMoreButtonInView:topVC.view];
    
    if (moreButton && [moreButton respondsToSelector:@selector(sendActionsForControlEvents:)]) {
        [(UIButton *)moreButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    } else {
        [DYYYManager showToast:@"未找到操作面板按钮"];
    }
}

%new
- (void)showVideoDebugInfo:(AWEAwemeModel *)model {
    if (!model) return;
    
    NSMutableString *info = [NSMutableString string];
    
    // 使用 KVC 安全访问属性
    NSString *awemeId = [model valueForKey:@"awemeId"];
    NSString *authorName = @"未知";
    if (model.author && [model.author respondsToSelector:@selector(nickname)]) {
        authorName = model.author.nickname ?: @"未知";
    }
    
    [info appendFormat:@"视频ID: %@\n", awemeId ?: @"未知"];
    [info appendFormat:@"作者: %@\n", authorName];
    
    // 安全访问视频时长
    if (model.video) {
        NSNumber *duration = [model.video valueForKey:@"duration"];
        if (duration) {
            [info appendFormat:@"时长: %.1f秒\n", duration.floatValue];
        } else {
            [info appendFormat:@"时长: 未知\n"];
        }
    }
    
    // 安全访问统计数据
    if (model.statistics) {
        NSNumber *diggCount = [model.statistics valueForKey:@"diggCount"];
        NSNumber *commentCount = [model.statistics valueForKey:@"commentCount"];
        NSNumber *shareCount = [model.statistics valueForKey:@"shareCount"];
        
        [info appendFormat:@"点赞数: %ld\n", diggCount ? diggCount.longValue : 0];
        [info appendFormat:@"评论数: %ld\n", commentCount ? commentCount.longValue : 0];
        [info appendFormat:@"分享数: %ld\n", shareCount ? shareCount.longValue : 0];
    }
    
    [info appendFormat:@"类型: %@\n", model.awemeType == 68 ? @"图集" : @"视频"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"视频信息"
                                                                   message:info
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIPasteboard generalPasteboard] setString:info];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:copyAction];
    [alert addAction:cancelAction];
    
    [[DYYYManager getActiveTopController] presentViewController:alert animated:YES completion:nil];
}

%new
- (UIView *)findCommentButtonInView:(UIView *)view {
    // 递归查找评论按钮
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *imageName = button.currentImage.description.lowercaseString;
            NSString *className = NSStringFromClass([subview class]).lowercaseString;
            
            if ([imageName containsString:@"comment"] || 
                [className containsString:@"comment"] ||
                [imageName containsString:@"bubble"]) {
                return subview;
            }
        }
        
        UIView *found = [self findCommentButtonInView:subview];
        if (found) return found;
    }
    return nil;
}

%new
- (UIView *)findLikeButtonInView:(UIView *)view {
    // 递归查找点赞按钮
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *imageName = button.currentImage.description.lowercaseString;
            NSString *className = NSStringFromClass([subview class]).lowercaseString;
            
            if ([imageName containsString:@"like"] || 
                [imageName containsString:@"heart"] ||
                [className containsString:@"like"] ||
                [className containsString:@"digg"]) {
                return subview;
            }
        }
        
        UIView *found = [self findLikeButtonInView:subview];
        if (found) return found;
    }
    return nil;
}

%new
- (UIView *)findShareButtonInView:(UIView *)view {
    // 递归查找分享按钮
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *imageName = button.currentImage.description.lowercaseString;
            NSString *className = NSStringFromClass([subview class]).lowercaseString;
            
            if ([imageName containsString:@"share"] || 
                [className containsString:@"share"] ||
                [imageName containsString:@"arrow"]) {
                return subview;
            }
        }
        
        UIView *found = [self findShareButtonInView:subview];
        if (found) return found;
    }
    return nil;
}

%new
- (UIView *)findMoreButtonInView:(UIView *)view {
    // 递归查找更多选项按钮
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *imageName = button.currentImage.description.lowercaseString;
            NSString *className = NSStringFromClass([subview class]).lowercaseString;
            
            if ([imageName containsString:@"more"] || 
                [imageName containsString:@"ellipsis"] ||
                [imageName containsString:@"dot"] ||
                [className containsString:@"more"]) {
                return subview;
            }
        }
        
        UIView *found = [self findMoreButtonInView:subview];
        if (found) return found;
    }
    return nil;
}

// 按钮事件处理方法
%new
- (void)handleModuleButtonTap:(UIButton *)sender {
    if ([sender isKindOfClass:[DYYYDraggableButton class]]) {
        DYYYDraggableButton *dragButton = (DYYYDraggableButton *)sender;
        if (dragButton.isDragging) return; // 如果正在拖拽，不执行点击事件
    }
    
    // 重置自动隐藏计时器
    [self resetHeaderControlVisibility];
    
    // 获取按钮关联的动作并执行
    void (^action)(void) = objc_getAssociatedObject(sender, "moduleAction");
    if (action) {
        // 延迟执行功能，先关闭面板
        [self dismissCurrentMenuPanel];
        
        // 稍微延迟执行功能，确保面板关闭动画完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            action();
        });
    }
    
    // 触感反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
}

// 通用的面板关闭方法
%new
- (void)dismissCurrentMenuPanel {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    
    // 查找当前显示的菜单面板
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            // 找到菜单容器
            UIView *menuContainer = nil;
            for (UIView *subview in view.subviews) {
                if (subview.layer.cornerRadius == 20) {
                    menuContainer = subview;
                    break;
                }
            }
            
            // 移除通知观察者
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYBackgroundColorChanged" object:nil];
            
            // 关闭动画
            [UIView animateWithDuration:0.25 animations:^{
                view.alpha = 0;
                if (menuContainer) {
                    CGRect frame = menuContainer.frame;
                    frame.origin.y = view.bounds.size.height;
                    menuContainer.frame = frame;
                }
            } completion:^(BOOL finished) {
                [view removeFromSuperview];
            }];
            
            break;
        }
    }
}

%new 
- (void)moduleButtonTouchDown:(UIButton *)sender {
    // 重置自动隐藏计时器
    [self resetHeaderControlVisibility];
    
    // 获取当前视图模式
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    if (isListView) {
        // 列表模式：渐变高亮效果
        UIView *cellContainer = sender.superview;
        if (cellContainer) {
            // 找到背景视图
            UIView *backgroundView = nil;
            for (UIView *subview in cellContainer.subviews) {
                if ([subview isKindOfClass:[UIView class]] && subview != sender) {
                    backgroundView = subview;
                    break;
                }
            }
            
            // 如果没有背景视图，创建一个
            if (!backgroundView) {
                backgroundView = [[UIView alloc] initWithFrame:cellContainer.bounds];
                backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                backgroundView.backgroundColor = [UIColor clearColor];
                backgroundView.tag = 1001; // 标记为高亮背景
                [cellContainer insertSubview:backgroundView atIndex:0];
            }
            
            // 创建渐变层
            CAGradientLayer *highlightGradient = [CAGradientLayer layer];
            highlightGradient.frame = backgroundView.bounds;
            highlightGradient.colors = @[
                (id)[UIColor colorWithWhite:1 alpha:0.15].CGColor,
                (id)[UIColor colorWithWhite:1 alpha:0.05].CGColor
            ];
            highlightGradient.startPoint = CGPointMake(0, 0);
            highlightGradient.endPoint = CGPointMake(1, 1);
            highlightGradient.cornerRadius = 8; // 轻微圆角
            
            // 清除之前的渐变
            [backgroundView.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
            [backgroundView.layer addSublayer:highlightGradient];
            
            // 应用显示动画
            backgroundView.alpha = 0;
            [UIView animateWithDuration:0.2 animations:^{
                backgroundView.alpha = 1;
            }];
        }
    } else {
        // 卡片模式：立体感和光泽效果
        [self enhanceCardHoverEffect:sender];
    }
    
    // 触感反馈优化 - 使用更轻微的触感
    if (@available(iOS 13.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [generator prepare];
        [generator impactOccurred];
    } else if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

%new
- (AWEAwemeModel *)getCurrentAwemeModel {
    if ([self respondsToSelector:@selector(awemeModel)]) {
        return [self performSelector:@selector(awemeModel)];
    } else if ([self respondsToSelector:@selector(currentAwemeModel)]) {
        return [self performSelector:@selector(currentAwemeModel)];
    }
    return nil;
}

// 模块创建方法
%new
- (DYYYMenuModule *)createDownloadModuleForAweme:(AWEAwemeModel *)awemeModel {
    BOOL isImageContent = (awemeModel.awemeType == 68);
    return [DYYYMenuModule moduleWithTitle:isImageContent ? @"保存图片" : @"保存视频"
                                      icon:@"arrow.down.circle"
                                     color:@"#0078D7"
                                    action:^{
        [DYYYManager showToast:@"下载功能已触发"];
    }];
}

%new
- (DYYYMenuModule *)createScreenshotModule {
    return [DYYYMenuModule moduleWithTitle:@"截图功能"
                                      icon:@"camera.viewfinder"
                                     color:@"#4CAF50"
                                    action:^{
        [self dyyy_startCustomScreenshotProcess];
    }];
}

%new
- (DYYYMenuModule *)createAudioModuleForAweme:(AWEAwemeModel *)awemeModel {
    return [DYYYMenuModule moduleWithTitle:@"保存音频"
                                      icon:@"music.note"
                                     color:@"#E3008C"
                                    action:^{
        [DYYYManager showToast:@"音频下载已触发"];
    }];
}

%new
- (DYYYMenuModule *)createVideoStatsModifyModule {
    return [DYYYMenuModule moduleWithTitle:@"自定义视频数据"
                                      icon:@"number.circle.fill"
                                     color:@"#FF6B8B"
                                    action:^{
        AWEAwemeModel *awemeModel = [self getCurrentAwemeModel];
        if (awemeModel) {
            // 打开视频数据编辑界面
            UIViewController *viewController = [DYYYManager getActiveTopController];
            if (viewController) {
                showVideoStatsEditAlert(viewController);
            }
        } else {
            [DYYYManager showToast:@"无法获取当前视频"];
        }
    }];
}

%new
- (DYYYMenuModule *)createCopyTextModuleForAweme:(AWEAwemeModel *)awemeModel {
    return [DYYYMenuModule moduleWithTitle:@"复制文案"
                                      icon:@"doc.on.doc"
                                     color:@"#5C2D91"
                                    action:^{
        NSString *descText = [awemeModel valueForKey:@"descriptionString"];
        [[UIPasteboard generalPasteboard] setString:descText];
        [DYYYManager showToast:@"文案已复制到剪贴板"];
    }];
}

%new
- (DYYYMenuModule *)createCommentModule {
    return [DYYYMenuModule moduleWithTitle:@"打开评论"
                                      icon:@"text.bubble"
                                     color:@"#107C10"
                                    action:^{
        [self performCommentAction];
    }];
}

%new
- (DYYYMenuModule *)createLikeModule {
    return [DYYYMenuModule moduleWithTitle:@"点赞视频"
                                      icon:@"heart"
                                     color:@"#D83B01"
                                    action:^{
        [self performLikeAction];
    }];
}

// 功能开关检查方法
%new
- (BOOL)shouldShowDownloadModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownload"];
}

%new
- (BOOL)shouldShowScreenshotModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableScreenshot"];
}

%new
- (BOOL)shouldShowAudioModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownloadAudio"];
}

%new
- (BOOL)shouldShowCopyTextModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapCopyDesc"];
}

%new
- (BOOL)shouldShowCommentModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapComment"];
}

%new
- (BOOL)shouldShowLikeModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapLike"];
}

%new
- (BOOL)shouldShowAdvancedModule {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableAdvancedSettings"];
}

%new
- (void)setupHeaderAutoHideTimer {
    // 清除已有计时器
    [self invalidateHeaderAutoHideTimer];
    
    // 创建新计时器 - 4秒后自动隐藏
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.1
                                                     target:self
                                                   selector:@selector(hideHeaderControlsWithAnimation)
                                                   userInfo:nil
                                                    repeats:NO];
    
    // 保存计时器引用
    objc_setAssociatedObject(self, "headerAutoHideTimer", timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)invalidateHeaderAutoHideTimer {
    NSTimer *existingTimer = objc_getAssociatedObject(self, "headerAutoHideTimer");
    if (existingTimer) {
        [existingTimer invalidate];
        objc_setAssociatedObject(self, "headerAutoHideTimer", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)resetHeaderControlVisibility {
    // 取消任何已设置的自动隐藏计时器
    [self invalidateHeaderAutoHideTimer];
    
    // 显示控制按钮
    [self showHeaderControlsWithAnimation];
    
    // 设置新的自动隐藏计时器
    [self setupHeaderAutoHideTimer];
}

%new
- (void)showHeaderControlsWithAnimation {
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
    
    // 获取菜单容器
    UIView *menuContainer = nil;
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            break;
        }
    }
    
    if (!menuContainer) return;
    
    // 查找头部控制区
    UIView *headerView = nil;
    UIScrollView *scrollView = nil;
    
    // 遍历查找headerView和scrollView
    for (UIView *subview in menuContainer.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
            for (UIView *contentView in effectView.contentView.subviews) {
                if (contentView.tag == 60) { // 头部视图tag
                    headerView = contentView;
                } else if ([contentView isKindOfClass:[UIScrollView class]]) {
                    scrollView = (UIScrollView *)contentView;
                }
            }
        }
    }
    
    if (!headerView) return;
    
    // 移除menuContainer上的点击手势
    [self removeTapToShowGestureFromMenuContainer:menuContainer];
    
    // 更新控件状态
    objc_setAssociatedObject(headerView, "controlsHidden", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 查找所有需要显示的控制按钮，包括菜单按钮
    NSMutableArray *allButtonsToShow = [NSMutableArray array];
    
    for (UIView *subview in headerView.subviews) {
        if ([subview isKindOfClass:[UIButton class]] || [subview isKindOfClass:[UISegmentedControl class]]) {
            [allButtonsToShow addObject:subview];
            subview.userInteractionEnabled = YES; // 恢复交互
        }
    }
    
    // 重置按钮位置，为动画做准备
    for (UIView *button in allButtonsToShow) {
        button.transform = CGAffineTransformMakeTranslation(0, -10);
    }
    
    // 执行显示动画
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // 显示所有按钮和控件
        for (UIView *button in allButtonsToShow) {
            button.alpha = 1.0;
            button.transform = CGAffineTransformIdentity;
        }
        
        // 修改：恢复headerView原始高度
        CGRect headerFrame = headerView.frame;
        headerFrame.size.height = 70; // 恢复原始高度
        headerView.frame = headerFrame;
        
        // 同时调整scrollView位置和高度
        if (scrollView) {
            CGRect scrollFrame = scrollView.frame;
            scrollFrame.origin.y = headerFrame.size.height;
            scrollFrame.size.height = menuContainer.bounds.size.height - headerFrame.size.height;
            scrollView.frame = scrollFrame;
        }
    } completion:^(BOOL finished) {
        // 在按钮完全显示后，恢复内容的原始布局
        [self restoreOriginalLayoutAfterHeaderShown];
    }];
    
    // 重启自动隐藏计时器
    [self setupHeaderAutoHideTimer];
}

%new
- (void)addTapToShowGestureToMenuContainer:(UIView *)menuContainer {
    // 为menuContainer点击手势来重新显示控件
    UITapGestureRecognizer *tapToShowGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapToShowControls:)];
    tapToShowGesture.cancelsTouchesInView = NO; // 不干扰其他触摸事件
    [menuContainer addGestureRecognizer:tapToShowGesture];
    
    // 标记手势以便后续移除
    objc_setAssociatedObject(menuContainer, "tapToShowGesture", tapToShowGesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 视觉提示，告诉用户可以点击显示控件
    [self addVisualHintToMenuContainer:menuContainer];
}

%new
- (void)removeTapToShowGestureFromMenuContainer:(UIView *)menuContainer {
    UITapGestureRecognizer *tapGesture = objc_getAssociatedObject(menuContainer, "tapToShowGesture");
    if (tapGesture) {
        [menuContainer removeGestureRecognizer:tapGesture];
        objc_setAssociatedObject(menuContainer, "tapToShowGesture", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 移除视觉提示
    [self removeVisualHintFromMenuContainer:menuContainer];
}

%new
- (void)handleTapToShowControls:(UITapGestureRecognizer *)gesture {
    // 重新显示控件
    [self showHeaderControlsWithAnimation];
    
    // 触感反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

%new
- (void)addVisualHintToMenuContainer:(UIView *)menuContainer {
    // 修复：确保在menuContainer的contentView中提示
    UIView *targetView = menuContainer;
    
    // 如果menuContainer包含UIVisualEffectView，获取其contentView
    for (UIView *subview in menuContainer.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            targetView = ((UIVisualEffectView *)subview).contentView;
            break;
        }
    }
    
    // 在顶部三个圆点提示，可以点击显示控件
    CGFloat containerWidth = targetView.bounds.size.width;
    CGFloat dotSize = 8; // 增大圆点尺寸
    CGFloat spacing = 10; // 增大间距
    CGFloat totalWidth = dotSize * 3 + spacing * 2;
    
    // 修复：创建容器视图，放在更靠上的位置
    UIView *dotsContainer = [[UIView alloc] initWithFrame:CGRectMake((containerWidth - totalWidth)/2, 5, totalWidth, dotSize)];
    dotsContainer.tag = 8080; // 标记用于后续查找和移除
    dotsContainer.backgroundColor = [UIColor clearColor]; // 调试用
    dotsContainer.alpha = 0;
    
    // 创建三个圆点
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(i * (dotSize + spacing), 0, dotSize, dotSize)];
        dot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9]; // 增加不透明度
        dot.layer.cornerRadius = dotSize / 2;
        
        // 微妙的阴影
        dot.layer.shadowColor = [UIColor blackColor].CGColor;
        dot.layer.shadowOffset = CGSizeMake(0, 1);
        dot.layer.shadowRadius = 3;
        dot.layer.shadowOpacity = 0.4;
        
        [dotsContainer addSubview:dot];
    }
    
    // 修复：到正确的父视图
    [targetView addSubview:dotsContainer];
    
    // 确保提示在最上层显示
    [targetView bringSubviewToFront:dotsContainer];
    
    // 渐显动画
    [UIView animateWithDuration:0.4 animations:^{
        dotsContainer.alpha = 1.0;
    }];
    
    // 循环的脉动动画 - 依次点亮每个圆点
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startDotsAnimationForContainer:dotsContainer];
    });
}

%new
- (void)startDotsAnimationForContainer:(UIView *)dotsContainer {
    NSArray *dots = dotsContainer.subviews;
    if (dots.count != 3) return;
    
    // 为每个圆点创建依次点亮的动画
    for (NSInteger i = 0; i < dots.count; i++) {
        UIView *dot = dots[i];
        
        // 创建缩放和透明度动画
        CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
        animationGroup.duration = 1.8; // 总动画时长
        animationGroup.repeatCount = HUGE_VALF;
        animationGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // 缩放动画
        CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scaleAnimation.fromValue = @1.0;
        scaleAnimation.toValue = @1.4;
        scaleAnimation.duration = 0.3;
        scaleAnimation.autoreverses = YES;
        scaleAnimation.beginTime = i * 0.2; // 每个圆点延迟0.2秒
        
        // 透明度动画
        CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacityAnimation.fromValue = @0.8;
        opacityAnimation.toValue = @1.0;
        opacityAnimation.duration = 0.3;
        opacityAnimation.autoreverses = YES;
        opacityAnimation.beginTime = i * 0.2;
        
        animationGroup.animations = @[scaleAnimation, opacityAnimation];
        [dot.layer addAnimation:animationGroup forKey:@"dotPulse"];
    }
}

%new
- (void)removeVisualHintFromMenuContainer:(UIView *)menuContainer {
    // 修复：在正确的视图层次中查找并移除圆点提示
    UIView *targetView = menuContainer;
    
    // 如果menuContainer包含UIVisualEffectView，获取其contentView
    for (UIView *subview in menuContainer.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            targetView = ((UIVisualEffectView *)subview).contentView;
            break;
        }
    }
    
    UIView *dotsContainer = [targetView viewWithTag:8080];
    if (dotsContainer) {
        // 停止所有动画
        for (UIView *dot in dotsContainer.subviews) {
            [dot.layer removeAllAnimations];
        }
        
        [UIView animateWithDuration:0.3 animations:^{
            dotsContainer.alpha = 0;
            dotsContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            [dotsContainer removeFromSuperview];
        }];
    }
}

%new
- (void)hideHeaderControlsWithAnimation {
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
    
    // 获取菜单容器
    UIView *menuContainer = nil;
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            break;
        }
    }
    
    if (!menuContainer) return;
    
    // 查找头部控制区
    UIView *headerView = nil;
    UIScrollView *scrollView = nil;
    
    // 遍历查找headerView和scrollView
    for (UIView *subview in menuContainer.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
            for (UIView *contentView in effectView.contentView.subviews) {
                if (contentView.tag == 60) { // 头部视图tag
                    headerView = contentView;
                } else if ([contentView isKindOfClass:[UIScrollView class]]) {
                    scrollView = (UIScrollView *)contentView;
                }
            }
        }
    }
    
    if (!headerView) return;
    
    // 保存控件状态
    objc_setAssociatedObject(headerView, "controlsHidden", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 查找所有需要隐藏的控制按钮，包括菜单按钮
    NSMutableArray *allButtonsToHide = [NSMutableArray array];
    
    for (UIView *subview in headerView.subviews) {
        if ([subview isKindOfClass:[UIButton class]] || [subview isKindOfClass:[UISegmentedControl class]]) {
            [allButtonsToHide addObject:subview]; // 隐藏所有按钮，包括菜单按钮
        }
    }
    
    // 执行隐藏动画
    [UIView animateWithDuration:0.5 
                          delay:0 
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        // 隐藏所有按钮和控件
        for (UIView *button in allButtonsToHide) {
            button.alpha = 0.0;
            button.transform = CGAffineTransformMakeTranslation(0, -10);
        }
        
        // 修改：调整headerView高度到20，留出显示圆点的空间
        CGRect headerFrame = headerView.frame;
        headerFrame.size.height = 20; // 保留小部分高度用于显示圆点
        headerView.frame = headerFrame;
        
        // 调整scrollView占据剩余空间
        if (scrollView) {
            CGRect scrollFrame = scrollView.frame;
            scrollFrame.origin.y = 20; // 从headerView底部开始
            scrollFrame.size.height = menuContainer.bounds.size.height - 20; // 剩余高度
            scrollView.frame = scrollFrame;
        }
    } completion:^(BOOL finished) {
        // 确保所有按钮完全不可交互
        for (UIView *button in allButtonsToHide) {
            button.userInteractionEnabled = NO;
        }
        
        // 在按钮完全隐藏后，调整内容布局以优化空间利用
        [self optimizeSpaceUtilizationAfterHeaderHidden];
        
        // 为整个menuContainer点击手势来重新显示控件
        [self addTapToShowGestureToMenuContainer:menuContainer];
    }];
}

%new
- (void)handleMenuContainerTap:(UITapGestureRecognizer *)gesture {
    // 获取点击位置
    CGPoint tapPoint = [gesture locationInView:gesture.view];
    
    // 查找头部控件区域
    UIView *menuContainer = gesture.view;
    if (!menuContainer) return;
    
    // 获取当前控件的显示/隐藏状态
    UIView *headerView = nil;
    
    // 查找头部控制区域
    for (UIView *contentView in menuContainer.subviews) {
        UIView *realContentView = contentView;
        if ([contentView isKindOfClass:[UIVisualEffectView class]]) {
            realContentView = [(UIVisualEffectView *)contentView contentView];
        }
        
        for (UIView *subview in realContentView.subviews) {
            if (subview.tag == 60) { // 头部视图标签
                headerView = subview;
                break;
            }
        }
        
        if (headerView) break;
    }
    
    if (!headerView) return;
    
    NSNumber *controlsHidden = objc_getAssociatedObject(headerView, "controlsHidden");
    BOOL isHidden = controlsHidden ? [controlsHidden boolValue] : NO;
    
    // 点击上部区域时才处理显示/隐藏逻辑
    CGFloat headerHeight = isHidden ? 50 : 90; // 根据当前状态获取header高度
    if (tapPoint.y <= headerHeight) {
        if (isHidden) {
            // 如果控件当前是隐藏的，显示它们
            [self showHeaderControlsWithAnimation];
        } else {
            // 如果控件当前是显示的，重置自动隐藏计时器
            [self resetHeaderControlVisibility];
        }
        
        // 应用轻微触感反馈提示用户操作已被接收
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
    }
}

%new
- (void)moduleButtonTouchUpForIOS19:(UIButton *)sender {
    if ([sender isKindOfClass:[DYYYDraggableButton class]]) {
        DYYYDraggableButton *dragButton = (DYYYDraggableButton *)sender;
        if (dragButton.isDragging) return; // 如果正在拖拽，不执行点击事件
    }
    
    // 列表风格按钮触摸结束处理
    UIView *cellContainer = sender.superview;
    if (cellContainer) {
        // 获取背景视图
        UIView *backgroundView = [cellContainer viewWithTag:1001];
        if (backgroundView) {
            [UIView animateWithDuration:0.2 animations:^{
                backgroundView.alpha = 0;
            } completion:^(BOOL finished) {
                [backgroundView.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
            }];
        }
    }
}

%new
- (void)moduleButtonTouchUpForCard:(UIButton *)sender {
    if ([sender isKindOfClass:[DYYYDraggableButton class]]) {
        DYYYDraggableButton *dragButton = (DYYYDraggableButton *)sender;
        if (dragButton.isDragging) return; // 如果正在拖拽，不执行点击事件
    }
    
    // 卡片风格按钮触摸结束处理 
    [self restoreCardNormalEffect:sender];
}

%new
- (void)applyCardStyleToCell:(UIView *)cell {
    [UIView animateWithDuration:0.2 animations:^{
        cell.layer.cornerRadius = 12.0;
        cell.layer.shadowColor = [UIColor blackColor].CGColor;
        cell.layer.shadowOffset = CGSizeMake(0, 3);
        cell.layer.shadowRadius = 6.0;
        cell.layer.shadowOpacity = 0.15;
    }];
}

%new
- (void)handleModuleDrag:(UILongPressGestureRecognizer *)gesture {
    DYYYDraggableButton *draggedButton = (DYYYDraggableButton *)gesture.view;
    UIScrollView *scrollView = nil;
    
    // 查找ScrollView
    UIView *currentView = draggedButton.superview;
    while (currentView && ![currentView isKindOfClass:[UIScrollView class]]) {
        currentView = currentView.superview;
    }
    scrollView = (UIScrollView *)currentView;
    
    if (!scrollView) return;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            [self startDragMode:draggedButton];
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            // 获取手势在scrollView中的位置
            CGPoint currentLocation = [gesture locationInView:scrollView];
            [self updateDragPositionWithLocation:currentLocation button:draggedButton scrollView:scrollView];
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self finishDragMode:draggedButton];
            break;
            
        default:
            break;
    }
}

%new
- (void)updateDragPosition:(DYYYDraggableButton *)button withNewCenter:(CGPoint)newCenter {
    if (!button.isDragging) return;
    
    // 只更新预览视图位置，不移动原始按钮
    if (button.dragPreviewView) {
        button.dragPreviewView.center = newCenter;
    }
    
    // 检查是否需要重新排序
    UIScrollView *scrollView = nil;
    UIView *currentView = button.superview;
    while (currentView && ![currentView isKindOfClass:[UIScrollView class]]) {
        currentView = currentView.superview;
    }
    scrollView = (UIScrollView *)currentView;
    
    if (scrollView) {
        NSInteger newIndex = [self findInsertionIndexForY:newCenter.y inScrollView:scrollView];
        if (newIndex != button.currentIndex && newIndex >= 0) {
            NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
            if (moduleViews && newIndex < moduleViews.count) {
                [self animateModuleReorderFromIndex:button.currentIndex 
                                            toIndex:newIndex 
                                      inScrollView:scrollView 
                                   excludingButton:button];
                button.currentIndex = newIndex;
            }
        }
    }
}

%new
- (void)startDragMode:(DYYYDraggableButton *)button {
    button.isDragging = YES;
    
    // 触感反馈优化
    if (@available(iOS 13.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
        [generator prepare];
        [generator impactOccurred];
    } else if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
    
    // 保存原始中心点
    button.originalCenter = button.superview.center;
    
    // 创建拖拽预览视图
    button.dragPreviewView = [self createDragPreviewForButton:button];
    if (button.dragPreviewView) {
        // 设置预览视图的初始位置
        button.dragPreviewView.center = button.superview.center;
        
        // 将预览视图到scrollView的父视图，确保不被裁剪
        UIScrollView *scrollView = nil;
        UIView *currentView = button.superview;
        while (currentView && ![currentView isKindOfClass:[UIScrollView class]]) {
            currentView = currentView.superview;
        }
        scrollView = (UIScrollView *)currentView;
        
        if (scrollView && scrollView.superview) {
            [scrollView.superview addSubview:button.dragPreviewView];
            
            // 修改2: 保存初始X坐标以供拖动时使用
            objc_setAssociatedObject(button, "fixedDragX", @(button.dragPreviewView.center.x), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            // 拖拽开始的放大动画
            button.dragPreviewView.transform = CGAffineTransformMakeScale(0.9, 0.9);
            button.dragPreviewView.alpha = 0.8;
            
            [UIView animateWithDuration:0.25 
                                  delay:0 
                 usingSpringWithDamping:0.7 
                  initialSpringVelocity:0.5 
                                options:UIViewAnimationOptionCurveEaseOut 
                             animations:^{
                button.dragPreviewView.transform = CGAffineTransformMakeScale(1.05, 1.05);
                button.dragPreviewView.alpha = 1.0;
                button.dragPreviewView.layer.shadowOpacity = 0.5;
                button.dragPreviewView.layer.shadowRadius = 16;
            } completion:nil];
        }
    }
    
    // 完全隐藏原始按钮
    [UIView animateWithDuration:0.2 animations:^{
        button.superview.alpha = 0.0;
    }];
    
    // 禁用ScrollView滚动
    UIScrollView *scrollView = nil;
    UIView *view = button.superview;
    while (view && ![view isKindOfClass:[UIScrollView class]]) {
        view = view.superview;
    }
    if ([view isKindOfClass:[UIScrollView class]]) {
        ((UIScrollView *)view).scrollEnabled = NO;
    }
}

%new
- (void)updateDragPositionWithLocation:(CGPoint)location button:(DYYYDraggableButton *)button scrollView:(UIScrollView *)scrollView {
    if (!button.isDragging || !button.dragPreviewView) return;
    
    // 计算预览视图在父视图中的位置
    CGPoint previewLocation = [scrollView convertPoint:location toView:scrollView.superview];
    
    // 修改: 固定X轴位置，只允许Y轴移动
    CGFloat fixedX = button.dragPreviewView.center.x;
    
    // 更新预览视图位置，但只改变Y坐标
    button.dragPreviewView.center = CGPointMake(fixedX, previewLocation.y);
    
    // 检查是否需要重新排序
    NSInteger newIndex = [self findInsertionIndexForY:location.y inScrollView:scrollView];
    if (newIndex != button.currentIndex && newIndex >= 0) {
        NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
        if (moduleViews && newIndex < moduleViews.count) {
            // 4: 显示拖动位置指示器
            UIView *targetModuleView = moduleViews[newIndex];
            [self showDragPositionIndicatorAtY:targetModuleView.frame.origin.y inScrollView:scrollView];
            
            // 更新其他按钮的位置
            [self reorderOtherButtonsFromIndex:button.currentIndex 
                                       toIndex:newIndex 
                                 inScrollView:scrollView 
                              excludingButton:button];
            button.currentIndex = newIndex;
        }
    }
}

%new
- (void)reorderOtherButtonsFromIndex:(NSInteger)fromIndex 
                             toIndex:(NSInteger)toIndex 
                       inScrollView:(UIScrollView *)scrollView 
                    excludingButton:(DYYYDraggableButton *)excludedButton {
    
    NSMutableArray *moduleViews = [objc_getAssociatedObject(scrollView, "moduleViews") mutableCopy];
    if (!moduleViews) return;
    
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    // 为避免重叠，先记录所有需要移动的视图
    NSMutableDictionary *viewsToMove = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 0; i < moduleViews.count; i++) {
        UIView *moduleView = moduleViews[i];
        
        // 跳过正在拖拽的按钮
        BOOL isExcluded = NO;
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[DYYYDraggableButton class]]) {
                DYYYDraggableButton *checkButton = (DYYYDraggableButton *)subview;
                if (checkButton == excludedButton) {
                    isExcluded = YES;
                    break;
                }
            }
        }
        if (isExcluded) continue;
        
        // 计算新位置
        NSInteger targetIndex = i;
        if (fromIndex < toIndex) {
            // 向下拖拽
            if (i > fromIndex && i <= toIndex) {
                targetIndex = i - 1;
            }
        } else {
            // 向上拖拽
            if (i >= toIndex && i < fromIndex) {
                targetIndex = i + 1;
            }
        }
        
        if (i != targetIndex) {
            // 记录需要移动的视图和目标位置
            CGPoint targetCenter = [self calculateCenterForIndex:targetIndex isListView:isListView moduleView:moduleView];
            viewsToMove[@(i)] = @{@"view": moduleView, @"center": [NSValue valueWithCGPoint:targetCenter]};
        }
    }
    
    // 分批次执行动画，避免重叠
    [UIView animateWithDuration:0.25 animations:^{
        // 先移动所有向上移动的视图
        [viewsToMove enumerateKeysAndObjectsUsingBlock:^(NSNumber *index, NSDictionary *info, BOOL *stop) {
            UIView *view = info[@"view"];
            CGPoint center = [info[@"center"] CGPointValue];
            view.center = center;
        }];
    }];
}

%new
- (CGPoint)calculateCenterForIndex:(NSInteger)index isListView:(BOOL)isListView moduleView:(UIView *)moduleView {
    if (isListView) {
        CGFloat cellHeight = 56;
        CGFloat y = index * cellHeight + cellHeight / 2;
        return CGPointMake(moduleView.center.x, y);
    } else {
        CGFloat moduleHeight = 80;
        CGFloat spacing = 16;
        CGFloat y = spacing + index * (moduleHeight + spacing) + moduleHeight / 2;
        return CGPointMake(moduleView.center.x, y);
    }
}

%new
- (void)updateDragPosition:(DYYYDraggableButton *)button withTranslation:(CGPoint)translation {
    if (!button.isDragging) return;
    
    // 更新按钮位置
    CGPoint newCenter = CGPointMake(button.originalCenter.x, button.originalCenter.y + translation.y);
    button.superview.center = newCenter;
    
    // 更新预览视图位置
    if (button.dragPreviewView) {
        button.dragPreviewView.center = newCenter;
    }
    
    // 检查是否需要重新排序
    UIScrollView *scrollView = nil;
    UIView *currentView = button.superview;
    while (currentView && ![currentView isKindOfClass:[UIScrollView class]]) {
        currentView = currentView.superview;
    }
    scrollView = (UIScrollView *)currentView;
    
    if (scrollView) {
        NSInteger newIndex = [self findInsertionIndexForY:newCenter.y inScrollView:scrollView];
        if (newIndex != button.currentIndex && newIndex >= 0) {
            [self animateModuleReorderFromIndex:button.currentIndex 
                                        toIndex:newIndex 
                                  inScrollView:scrollView 
                               excludingButton:button];
            button.currentIndex = newIndex;
        }
    }
}

%new
- (void)finishDragMode:(DYYYDraggableButton *)button {
    if (!button.isDragging) return;
    button.isDragging = NO;
    
    // 触感反馈
    if (@available(iOS 13.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [generator prepare];
        [generator impactOccurred];
    } else if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
    
    // 重新启用ScrollView滚动
    UIScrollView *scrollView = nil;
    UIView *currentView = button.superview;
    while (currentView && ![currentView isKindOfClass:[UIScrollView class]]) {
        currentView = currentView.superview;
    }
    if ([currentView isKindOfClass:[UIScrollView class]]) {
        ((UIScrollView *)currentView).scrollEnabled = YES;
        
        // 5: 隐藏拖动指示器
        [self hideDragPositionIndicator:(UIScrollView *)currentView];
    }
    
    // 计算最终位置
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    CGPoint finalCenter = [self calculateCenterForIndex:button.currentIndex isListView:isListView moduleView:button.superview];
    
    // 动画到最终位置
    [UIView animateWithDuration:0.3 
                          delay:0 
         usingSpringWithDamping:0.7 
          initialSpringVelocity:0.5 
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        // 将预览视图移动到最终位置
        if (button.dragPreviewView) {
            // 转换到正确的坐标系统
            CGPoint targetCenter = [button.superview.superview convertPoint:finalCenter toView:button.dragPreviewView.superview];
            // 保持X坐标不变，只更新Y坐标
            button.dragPreviewView.center = CGPointMake(button.dragPreviewView.center.x, targetCenter.y);
            button.dragPreviewView.transform = CGAffineTransformIdentity;
            button.dragPreviewView.layer.shadowOpacity = 0.3;
        }
    } completion:^(BOOL finished) {
        // 显示原始按钮
        button.superview.center = finalCenter;
        [UIView animateWithDuration:0.2 animations:^{
            button.superview.alpha = 1.0;
            
            // 隐藏预览视图
            if (button.dragPreviewView) {
                button.dragPreviewView.alpha = 0;
            }
        } completion:^(BOOL finished) {
            // 移除预览视图
            if (button.dragPreviewView) {
                [button.dragPreviewView removeFromSuperview];
                button.dragPreviewView = nil;
            }
            
            // 更新模块顺序并保存
            [self updateModuleOrderAfterDrag:button inScrollView:scrollView];
            
            // 成功完成触感反馈
            if (@available(iOS 10.0, *)) {
                UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
                [generator prepare];
                [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
            }
        }];
    }];
}

%new
- (void)updateModuleOrderAfterDrag:(DYYYDraggableButton *)draggedButton inScrollView:(UIScrollView *)scrollView {
    NSMutableArray *moduleViews = [objc_getAssociatedObject(scrollView, "moduleViews") mutableCopy];
    if (!moduleViews) return;
    
    // 重新排序 moduleViews 数组
    UIView *draggedContainer = draggedButton.superview;
    [moduleViews removeObject:draggedContainer];
    [moduleViews insertObject:draggedContainer atIndex:draggedButton.currentIndex];
    
    // 更新所有按钮的索引
    for (NSInteger i = 0; i < moduleViews.count; i++) {
        UIView *moduleView = moduleViews[i];
        for (UIView *subview in moduleView.subviews) {
            if ([subview isKindOfClass:[DYYYDraggableButton class]]) {
                DYYYDraggableButton *button = (DYYYDraggableButton *)subview;
                button.originalIndex = i;
                button.currentIndex = i;
                break;
            }
        }
    }
    
    // 保存更新后的数组
    objc_setAssociatedObject(scrollView, "moduleViews", moduleViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 修改3: 创建和保存排序索引数组，确保下次启动时保持同样的顺序
    NSMutableArray *orderArray = [NSMutableArray array];
    for (NSInteger i = 0; i < moduleViews.count; i++) {
        [orderArray addObject:@(i)];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:orderArray forKey:@"DYYYModuleOrder"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}

%new
- (void)showDragPositionIndicatorAtY:(CGFloat)yPosition inScrollView:(UIScrollView *)scrollView {
    // 移除现有指示器
    UIView *existingIndicator = [scrollView viewWithTag:9999];
    if (existingIndicator) {
        [existingIndicator removeFromSuperview];
    }
    
    // 创建新的指示线
    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, yPosition - 1, scrollView.frame.size.width, 2)];
    indicator.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.7];
    indicator.tag = 9999;
    
    // 轻微发光效果
    indicator.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0].CGColor;
    indicator.layer.shadowOffset = CGSizeMake(0, 0);
    indicator.layer.shadowRadius = 3.0;
    indicator.layer.shadowOpacity = 0.8;
    
    [scrollView addSubview:indicator];
    
    // 微小的动画
    indicator.transform = CGAffineTransformMakeScale(0.95, 1.0);
    [UIView animateWithDuration:0.2 animations:^{
        indicator.transform = CGAffineTransformIdentity;
    }];
}

%new
- (void)hideDragPositionIndicator:(UIScrollView *)scrollView {
    UIView *indicator = [scrollView viewWithTag:9999];
    if (indicator) {
        [UIView animateWithDuration:0.15 animations:^{
            indicator.alpha = 0;
        } completion:^(BOOL finished) {
            [indicator removeFromSuperview];
        }];
    }
}

%new
- (UIView *)createDragPreviewForButton:(UIButton *)button {
    // 创建容器视图的完整拷贝
    UIView *originalContainer = button.superview;
    UIView *preview = [[UIView alloc] initWithFrame:originalContainer.frame];
    preview.backgroundColor = originalContainer.backgroundColor;
    preview.alpha = 0;
    
    // 创建按钮的拷贝
    UIButton *buttonCopy = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonCopy.frame = button.frame;
    buttonCopy.backgroundColor = button.backgroundColor;
    buttonCopy.layer.cornerRadius = button.layer.cornerRadius;
    
    // 复制渐变背景
    for (CALayer *layer in button.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            CAGradientLayer *originalGradient = (CAGradientLayer *)layer;
            CAGradientLayer *gradientCopy = [CAGradientLayer layer];
            gradientCopy.frame = buttonCopy.bounds;
            gradientCopy.cornerRadius = buttonCopy.layer.cornerRadius;
            gradientCopy.colors = originalGradient.colors;
            gradientCopy.startPoint = originalGradient.startPoint;
            gradientCopy.endPoint = originalGradient.endPoint;
            [buttonCopy.layer insertSublayer:gradientCopy atIndex:0];
        }
        if ([layer isKindOfClass:[CALayer class]] && layer != button.layer.sublayers.firstObject) {
            CALayer *layerCopy = [CALayer layer];
            layerCopy.frame = layer.frame;
            layerCopy.cornerRadius = layer.cornerRadius;
            layerCopy.borderWidth = layer.borderWidth;
            layerCopy.borderColor = layer.borderColor;
            [buttonCopy.layer addSublayer:layerCopy];
        }
    }
    
    // 复制按钮的子视图
    for (UIView *subview in button.subviews) {
        UIView *subviewCopy = nil;
        
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *originalImageView = (UIImageView *)subview;
            UIImageView *imageViewCopy = [[UIImageView alloc] initWithFrame:originalImageView.frame];
            imageViewCopy.image = originalImageView.image;
            imageViewCopy.contentMode = originalImageView.contentMode;
            imageViewCopy.tintColor = originalImageView.tintColor;
            subviewCopy = imageViewCopy;
        } else if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *originalLabel = (UILabel *)subview;
            UILabel *labelCopy = [[UILabel alloc] initWithFrame:originalLabel.frame];
            labelCopy.text = originalLabel.text;
            labelCopy.font = originalLabel.font;
            labelCopy.textColor = originalLabel.textColor;
            labelCopy.textAlignment = originalLabel.textAlignment;
            subviewCopy = labelCopy;
        }
        
        if (subviewCopy) {
            [buttonCopy addSubview:subviewCopy];
        }
    }
    
    [preview addSubview:buttonCopy];
    
    // 阴影效果
    preview.layer.shadowColor = [UIColor blackColor].CGColor;
    preview.layer.shadowOffset = CGSizeMake(0, 8);
    preview.layer.shadowRadius = 16;
    preview.layer.shadowOpacity = 0.3;
    
    return preview;
}

%new
- (NSInteger)findInsertionIndexForY:(CGFloat)yPosition inScrollView:(UIScrollView *)scrollView {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews || moduleViews.count == 0) return -1;
    
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    if (isListView) {
        CGFloat cellHeight = 56;
        NSInteger index = (NSInteger)(yPosition / cellHeight);
        return MAX(0, MIN(index, moduleViews.count - 1));
    } else {
        CGFloat moduleHeight = 80;
        CGFloat spacing = 16;
        CGFloat totalItemHeight = moduleHeight + spacing;
        NSInteger index = (NSInteger)((yPosition - spacing/2) / totalItemHeight);
        return MAX(0, MIN(index, moduleViews.count - 1));
    }
}

%new
- (void)animateModuleReorderFromIndex:(NSInteger)fromIndex 
                              toIndex:(NSInteger)toIndex 
                        inScrollView:(UIScrollView *)scrollView 
                     excludingButton:(DYYYDraggableButton *)excludedButton {
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    CGFloat itemHeight = isListView ? 56 : (80 + 16);
    CGFloat offset = isListView ? 0 : 16;
    
    // 从高位置到低位置移动 (向上移动项目)
    if (fromIndex > toIndex) {
        for (NSInteger i = toIndex; i < fromIndex; i++) {
            if (i >= moduleViews.count) continue;
            
            UIView *moduleView = moduleViews[i];
            // 跳过拖拽中的按钮
            if ([self isViewContainsButton:moduleView button:excludedButton]) continue;
            
            CGFloat newY = offset + (i + 1) * itemHeight;
            if (isListView) {
                newY += itemHeight / 2;
            } else {
                newY += (80 / 2);
            }
            
            [UIView animateWithDuration:0.25 animations:^{
                moduleView.center = CGPointMake(moduleView.center.x, newY);
            }];
        }
    } 
    // 从低位置到高位置移动 (向下移动项目)
    else if (fromIndex < toIndex) {
        for (NSInteger i = fromIndex + 1; i <= toIndex; i++) {
            if (i >= moduleViews.count) continue;
            
            UIView *moduleView = moduleViews[i];
            // 跳过拖拽中的按钮
            if ([self isViewContainsButton:moduleView button:excludedButton]) continue;
            
            CGFloat newY = offset + (i - 1) * itemHeight;
            if (isListView) {
                newY += itemHeight / 2;
            } else {
                newY += (80 / 2);
            }
            
            [UIView animateWithDuration:0.25 animations:^{
                moduleView.center = CGPointMake(moduleView.center.x, newY);
            }];
        }
    }
}

- (BOOL)isViewContainsButton:(UIView *)view button:(UIButton *)button {
    for (UIView *subview in view.subviews) {
        if (subview == button) return YES;
        if ([subview isKindOfClass:[UIButton class]] && 
            [subview isKindOfClass:[DYYYDraggableButton class]] && 
            ((DYYYDraggableButton *)subview).isDragging) {
            return YES;
        }
    }
    return NO;
}

%new
- (void)saveModuleOrder:(NSArray<DYYYMenuModule *> *)modules {
    NSMutableArray *orderArray = [NSMutableArray array];
    for (NSInteger i = 0; i < modules.count; i++) {
        [orderArray addObject:@(i)];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:orderArray forKey:@"DYYYModuleOrder"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

%new
- (void)dismissCurrentMenuPanelWithCompletion:(void(^)(void))completion {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) {
        if (completion) completion();
        return;
    }
    
    // 查找当前显示的菜单面板
    BOOL foundPanel = NO;
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            foundPanel = YES;
            // 找到菜单容器
            UIView *menuContainer = nil;
            for (UIView *subview in view.subviews) {
                if (subview.layer.cornerRadius == 20) {
                    menuContainer = subview;
                    break;
                }
            }
            
            // 移除通知观察者
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYBackgroundColorChanged" object:nil];
            
            // 关闭动画
            [UIView animateWithDuration:0.25 animations:^{
                view.alpha = 0;
                if (menuContainer) {
                    CGRect frame = menuContainer.frame;
                    frame.origin.y = view.bounds.size.height;
                    menuContainer.frame = frame;
                }
            } completion:^(BOOL finished) {
                [view removeFromSuperview];
                if (completion) completion();
            }];
            
            break;
        }
    }
    
    if (!foundPanel && completion) {
        completion();
    }
}

// 为按钮交互功能提供无延迟关闭
%new
- (DYYYMenuModule *)createCommentModuleWithInstantClose {
    return [DYYYMenuModule moduleWithTitle:@"打开评论"
                                      icon:@"text.bubble"
                                     color:@"#107C10"
                                    action:^{
        // 评论功能：立即关闭面板并执行操作
        [self dismissCurrentMenuPanel];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performCommentAction];
        });
    }];
}

%new
- (DYYYMenuModule *)createLikeModuleWithInstantClose {
    return [DYYYMenuModule moduleWithTitle:@"点赞视频"
                                      icon:@"heart"
                                     color:@"#D83B01"
                                    action:^{
        // 点赞功能：立即关闭面板并执行操作
        [self dismissCurrentMenuPanel];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performLikeAction];
        });
    }];
}

%new
- (DYYYMenuModule *)createShareModuleWithInstantClose {
    return [DYYYMenuModule moduleWithTitle:@"分享视频"
                                      icon:@"square.and.arrow.up"
                                     color:@"#FFB900"
                                    action:^{
        // 分享功能：立即关闭面板并执行操作
        [self dismissCurrentMenuPanel];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSharePanel];
        });
    }];
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
                    
                    // 缩放动画
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
                    
                    // 缩放动画
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
- (UIImage *)screenshotEntireScreen {
    @try {
        // 获取当前窗口
        UIWindow *keyWindow = DYYY_findKeyWindow();
        if (!keyWindow) {
            return nil;
        }
        
        return [DYYYScreenshot captureFullScreenshot:keyWindow];
    } @catch (NSException *exception) {
        NSLog(@"DYYY截图失败：%@", exception);
        return nil;
    }
}

%new
- (UIImage *)dyyy_cropImage:(UIImage *)image toRect:(CGRect)cropRect {
    return [DYYYScreenshot cropImage:image toRect:cropRect];
}

%new
- (void)dyyy_presentShareSheetWithImage:(UIImage *)image fromView:(UIView *)sourceView {
    [DYYYScreenshot presentShareSheetWithImage:image fromView:sourceView];
}

%new
- (void)dyyy_startCustomScreenshotProcess {
    NSLog(@"DYYY截图: AWEPlayInteractionViewController.dyyy_startCustomScreenshotProcess 被调用");
    
    // 确保在主线程执行UI操作
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = DYYY_findKeyWindow();
        if (!keyWindow) {
            [DYYYManager showToast:@"无法获取窗口进行截图"];
            return;
        }
        
        NSLog(@"DYYY截图: 开始抖音视频截图流程");
        
        // 获取当前播放的视频视图和播放状态
        id playerView = nil;
        @try {
            playerView = [self valueForKey:@"playerView"];
        } @catch (NSException *exception) {
            NSLog(@"DYYY截图: 无法获取playerView: %@", exception);
        }
        
        BOOL wasPlaying = YES;
        
        // 尝试暂停视频播放
        @try {
            if (playerView && [playerView respondsToSelector:@selector(isPaused)]) {
                NSNumber *isPausedNumber = [playerView performSelector:@selector(isPaused)];
                wasPlaying = ![isPausedNumber boolValue];
                if (wasPlaying && [playerView respondsToSelector:@selector(pause)]) {
                    [playerView performSelector:@selector(pause)];
                    NSLog(@"DYYY截图: 暂停了视频播放");
                }
            } else if (playerView && [playerView respondsToSelector:@selector(pause)]) {
                [playerView performSelector:@selector(pause)];
                NSLog(@"DYYY截图: 使用备用方法暂停视频");
            }
        } @catch (NSException *exception) {
            NSLog(@"DYYY截图: 暂停视频失败: %@", exception);
        }
        
        // 等待一小段时间确保暂停生效
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 先截取全屏图像
            UIImage *initialScreenshot = [DYYYScreenshot captureFullScreenshot:keyWindow];
            if (!initialScreenshot) {
                NSLog(@"DYYY截图: 获取全屏截图失败");
                [DYYYManager showToast:@"无法获取屏幕截图"];
                // 恢复视频播放
                if (wasPlaying && playerView && [playerView respondsToSelector:@selector(play)]) {
                    [playerView performSelector:@selector(play)];
                }
                return;
            }
            
            NSLog(@"DYYY截图: 成功获取到屏幕截图，尺寸: %.0f x %.0f", initialScreenshot.size.width, initialScreenshot.size.height);
            
            // 显示选择区域视图
            DYYYScreenshotSelectionView *selectionView = [[DYYYScreenshotSelectionView alloc] initWithFrame:keyWindow.bounds completion:^(CGRect selectedRect, BOOL cancelled) {
                NSLog(@"DYYY截图回调: cancelled=%d, rect=%@", cancelled, NSStringFromCGRect(selectedRect));
                
                // 确保在主线程中恢复视频播放
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (wasPlaying && playerView && [playerView respondsToSelector:@selector(play)]) {
                        [playerView performSelector:@selector(play)];
                        NSLog(@"DYYY截图: 恢复视频播放");
                    }
                });
                
                if (cancelled) {
                    [DYYYManager showToast:@"已取消截图"];
                    return;
                }
                
                if (CGRectIsEmpty(selectedRect) || selectedRect.size.width < 10 || selectedRect.size.height < 10) {
                    [DYYYManager showToast:@"截图区域太小"];
                    return;
                }
                
                // 使用已经捕获的高质量屏幕截图进行裁剪
                UIImage *croppedImage = [DYYYScreenshot cropImage:initialScreenshot toRect:selectedRect];
                if (croppedImage) {
                    NSLog(@"DYYY截图: 成功裁剪图片，尺寸: %.0f x %.0f", croppedImage.size.width, croppedImage.size.height);
                    // 使用主线程显示分享sheet
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [DYYYScreenshot presentShareSheetWithImage:croppedImage fromView:keyWindow];
                    });
                } else {
                    NSLog(@"DYYY截图: 裁剪图片失败");
                    [DYYYManager showToast:@"截图处理失败"];
                }
            }];
            
            if (selectionView) {
                // 确保视图被到窗口最上层
                NSLog(@"DYYY截图: 显示选择区域界面");
                [keyWindow addSubview:selectionView];
                [keyWindow bringSubviewToFront:selectionView];
            } else {
                NSLog(@"DYYY截图: 创建选择视图失败");
                [DYYYManager showToast:@"创建截图界面失败"];
                // 恢复视频播放
                if (wasPlaying && playerView && [playerView respondsToSelector:@selector(play)]) {
                    [playerView performSelector:@selector(play)];
                }
            }
        });
        
        // 设置一个定时器确保即使回调失败也会恢复视频播放
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (wasPlaying && playerView && [playerView respondsToSelector:@selector(play)]) {
                [playerView performSelector:@selector(play)];
                NSLog(@"DYYY截图: 安全机制恢复视频播放");
            }
        });
    });
}

%new
- (UIWindow *)getKeyWindow {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
}

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
    // 在顶部向下箭头指示
    UIImageView *arrowIndicator = [[UIImageView alloc] initWithFrame:CGRectMake((headerView.bounds.size.width - 20)/2, headerView.bounds.size.height - 25, 20, 15)];
    arrowIndicator.image = [UIImage systemImageNamed:@"chevron.down"];
    arrowIndicator.tintColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    arrowIndicator.tag = 9090; // 标记用于后续移除
    [headerView addSubview:arrowIndicator];
    
    // 脉动动画
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
    
    // 滚动监听
    scrollView.delegate = (id<UIScrollViewDelegate>)self;
    
    // 保存原始内容边距
    objc_setAssociatedObject(scrollView, "originalInsets", [NSValue valueWithUIEdgeInsets:scrollView.contentInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 拉伸效果
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
        // 为每个模块3D变换准备
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
- (void)enhanceGestureControlsForMenu:(UIView *)menuContainer {
    // 拖拽速度感知
    UIPanGestureRecognizer *dragSpeedRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuDragWithVelocitySensing:)];
    dragSpeedRecognizer.maximumNumberOfTouches = 1;
    [menuContainer addGestureRecognizer:dragSpeedRecognizer];
    
    // 二指缩放手势
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPinch:)];
    [menuContainer addGestureRecognizer:pinchRecognizer];
    
    // 快速点击手势（双击切换视图模式）
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuDoubleTap:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    [menuContainer addGestureRecognizer:doubleTapRecognizer];
}

%new
- (void)handleMenuPinch:(UIPinchGestureRecognizer *)gesture {
    static CGFloat initialScale = 1.0;
    UIView *menuContainer = gesture.view;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        initialScale = 1.0;
        // 重置计时器和显示控件
        [self resetHeaderControlVisibility];
    }
    else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat scale = 1.0 - (initialScale - gesture.scale) * 0.1;
        scale = MAX(0.8, MIN(scale, 1.2));
        
        // 视觉反馈 - 缩放效果
        CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
        menuContainer.transform = transform;
        
        // 检测是否足够收缩来关闭菜单
        if (scale < 0.85) {
            [self dismissCurrentMenuPanelWithCompletion:nil];
        }
    }
    else if (gesture.state == UIGestureRecognizerStateEnded || 
             gesture.state == UIGestureRecognizerStateCancelled) {
        // 回弹动画
        [UIView animateWithDuration:0.3 
                              delay:0 
             usingSpringWithDamping:0.7 
              initialSpringVelocity:0.3 
                            options:UIViewAnimationOptionCurveEaseOut 
                         animations:^{
            menuContainer.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

%new
- (void)handleMenuSwipeDown:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        [self dismissCurrentMenuPanelWithCompletion:nil];
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
    }
}

%new
- (UISegmentedControl *)findSegmentControlInView:(UIView *)rootView {
    @try {
        if (!rootView) return nil;
        
        // 递归查找段选择器控件
        for (UIView *view in rootView.subviews) {
            if ([view isKindOfClass:[UISegmentedControl class]]) {
                return (UISegmentedControl *)view;
            }
            
            // 递归查找子视图
            UISegmentedControl *found = [self findSegmentControlInView:view];
            if (found) {
                return found;
            }
        }
        
        return nil;
    } @catch (NSException *exception) {
        return nil;
    }
}

%new
- (void)handleMenuDoubleTap:(UITapGestureRecognizer *)gesture {
    @try {
        if (gesture.state != UIGestureRecognizerStateRecognized) {
            return;
        }
        
        // 显示3/4屏幕的快捷功能面板
        [self showQuickActionsPanel];
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [generator prepare];
            [generator impactOccurred];
        }
        
    } @catch (NSException *exception) {
        [DYYYManager showToast:@"双击功能出现错误"];
    }
}

%new
- (void)showQuickActionsPanel {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    
    // 检查是否已经存在面板
    UIView *existingPanel = [topVC.view viewWithTag:9528];
    if (existingPanel) {
        [self hideQuickActionsPanel:nil];
        return;
    }
    
    CGFloat screenHeight = topVC.view.bounds.size.height;
    CGFloat screenWidth = topVC.view.bounds.size.width;
    
    // 获取底部安全区域
    CGFloat bottomSafeArea = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafeArea = topVC.view.safeAreaInsets.bottom;
    }
    
    // 使用4/6屏幕高度 (约2/3)
    CGFloat panelHeight = screenHeight * 0.67;
    
    // 创建背景遮罩
    UIView *backgroundMask = [[UIView alloc] initWithFrame:topVC.view.bounds];
    backgroundMask.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    backgroundMask.alpha = 0;
    backgroundMask.tag = 9527;
    
    // 点击背景关闭手势
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideQuickActionsPanel:)];
    [backgroundMask addGestureRecognizer:backgroundTap];
    
    // 创建主面板
    UIView *quickPanel = [[UIView alloc] initWithFrame:CGRectMake(0, screenHeight, screenWidth, panelHeight)];
    quickPanel.backgroundColor = [UIColor systemBackgroundColor];
    quickPanel.layer.cornerRadius = 20;
    quickPanel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    quickPanel.tag = 9528;
    
    // 阴影
    quickPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    quickPanel.layer.shadowOffset = CGSizeMake(0, -2);
    quickPanel.layer.shadowRadius = 10;
    quickPanel.layer.shadowOpacity = 0.3;
    
    // 创建顶部拖拽指示器
    UIView *dragIndicator = [[UIView alloc] initWithFrame:CGRectMake((screenWidth - 40) / 2, 8, 40, 4)];
    dragIndicator.backgroundColor = [UIColor systemGray3Color];
    dragIndicator.layer.cornerRadius = 2;
    [quickPanel addSubview:dragIndicator];
    
    // 创建标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 30, screenWidth - 40, 30)];
    titleLabel.text = @"快捷功能";
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [quickPanel addSubview:titleLabel];
    
    // 创建功能按钮网格
    NSArray *quickActions = @[
        @{@"title": @"保存视频", @"icon": @"arrow.down.circle.fill", @"color": @"#007AFF", @"action": @"download"},
        @{@"title": @"截图功能", @"icon": @"camera.viewfinder", @"color": @"#34C759", @"action": @"screenshot"},
        @{@"title": @"小窗播放", @"icon": @"pip.enter", @"color": @"#FF9500", @"action": @"pip"},
        @{@"title": @"保存音频", @"icon": @"music.note", @"color": @"#AF52DE", @"action": @"audio"},
        @{@"title": @"截图功能", @"icon": @"camera.fill", @"color": @"#FF3B30", @"action": @"photo"},
        @{@"title": @"视图切换", @"icon": @"rectangle.grid.1x2.fill", @"color": @"#5856D6", @"action": @"viewmode"}
    ];
    
    CGFloat buttonWidth = (screenWidth - 60) / 3; // 3列布局
    CGFloat buttonHeight = 80;
    CGFloat startY = 80;
    
    for (NSInteger i = 0; i < quickActions.count; i++) {
        NSDictionary *actionInfo = quickActions[i];
        NSInteger row = i / 3;
        NSInteger col = i % 3;
        
        CGFloat x = 20 + col * buttonWidth;
        CGFloat y = startY + row * (buttonHeight + 20);
        
        UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(x, y, buttonWidth - 10, buttonHeight)];
        buttonContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        buttonContainer.layer.cornerRadius = 12;
        buttonContainer.tag = i;
        
        // 点击手势
        UITapGestureRecognizer *buttonTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleQuickAction:)];
        [buttonContainer addGestureRecognizer:buttonTap];
        
        // 图标
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake((buttonWidth - 10 - 30) / 2, 15, 30, 30)];
        UIImage *icon = [UIImage systemImageNamed:actionInfo[@"icon"]];
        iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        iconView.tintColor = [DYYYManager colorWithHexString:actionInfo[@"color"]];
        [buttonContainer addSubview:iconView];
        
        // 标题
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 50, buttonWidth - 20, 20)];
        titleLabel.text = actionInfo[@"title"];
        titleLabel.font = [UIFont systemFontOfSize:12];
        titleLabel.textColor = [UIColor labelColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [buttonContainer addSubview:titleLabel];
        
        [quickPanel addSubview:buttonContainer];
    }
    
    // 下拉手势
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [quickPanel addGestureRecognizer:panGesture];
    
    [topVC.view addSubview:backgroundMask];
    [topVC.view addSubview:quickPanel];
    
    // 显示动画 - 考虑底部安全区域
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        backgroundMask.alpha = 1.0;
        quickPanel.frame = CGRectMake(0, screenHeight - panelHeight - bottomSafeArea, screenWidth, panelHeight);
    } completion:nil];
}

%new
- (void)handleQuickAction:(UITapGestureRecognizer *)gesture {
    UIView *buttonContainer = gesture.view;
    NSInteger actionIndex = buttonContainer.tag;
    
    NSArray *actions = @[@"download", @"screenshot", @"pip", @"audio", @"photo", @"viewmode"];
    NSString *action = actions[actionIndex];
    
    // 执行相应操作
    if ([action isEqualToString:@"download"]) {
        AWEAwemeModel *model = [self getCurrentAwemeModel];
        if (model) {
            [DYYYManager showToast:@"开始下载视频"];
            // 执行下载操作
        }
    } 
    else if ([action isEqualToString:@"screenshot"]) {
        [self dyyy_startCustomScreenshotProcess];
    }
    else if ([action isEqualToString:@"pip"]) {
        [DYYYManager showToast:@"启动小窗播放"];
        // 执行小窗播放
    }
    else if ([action isEqualToString:@"audio"]) {
        [DYYYManager showToast:@"开始保存音频"];
        // 执行音频保存
    }
    else if ([action isEqualToString:@"photo"]) {
        [DYYYManager showToast:@"开始截图"];
        // 执行截图功能
    }
    else if ([action isEqualToString:@"viewmode"]) {
        // 切换视图模式
        BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
        BOOL nextModeIsListView = !isListView;
        [[NSUserDefaults standardUserDefaults] setBool:nextModeIsListView forKey:@"DYYYListViewMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [DYYYManager showToast:nextModeIsListView ? @"已切换到列表模式" : @"已切换到卡片模式"];
    }
    
    // 关闭快捷面板
    [self hideQuickActionsPanel:nil];
}

%new
- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    UIView *quickPanel = [gesture.view viewWithTag:9528];
    if (!quickPanel) return;
    
    CGPoint translation = [gesture translationInView:quickPanel];
    CGPoint velocity = [gesture velocityInView:quickPanel];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            // 记录初始位置
            break;
            
        case UIGestureRecognizerStateChanged: {
            // 只允许向下拖拽
            if (translation.y > 0) {
                quickPanel.transform = CGAffineTransformMakeTranslation(0, translation.y);
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            // 判断是否应该关闭面板
            BOOL shouldDismiss = translation.y > 100 || velocity.y > 500;
            
            if (shouldDismiss) {
                [self hideQuickActionsPanel:nil];
            } else {
                // 回弹到原位置
                [UIView animateWithDuration:0.3 animations:^{
                    quickPanel.transform = CGAffineTransformIdentity;
                }];
            }
            break;
        }
            
        default:
            break;
    }
}

%new
- (void)hideQuickActionsPanel:(id)sender {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *quickPanel = [topVC.view viewWithTag:9528];
    
    if (quickPanel) {
        [UIView animateWithDuration:0.2 animations:^{
            quickPanel.alpha = 0;
            quickPanel.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            [quickPanel removeFromSuperview];
        }];
    }
}

%new
- (void)autoHideQuickPanel:(NSTimer *)timer {
    UIView *quickPanel = (UIView *)timer.userInfo;
    if (quickPanel && [quickPanel superview]) {
        [UIView animateWithDuration:0.3 animations:^{
            quickPanel.alpha = 0;
            quickPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            [quickPanel removeFromSuperview];
        }];
    }
}

%new
- (void)handleQuickPanelDrag:(UIPanGestureRecognizer *)gesture {
    UIView *panelView = gesture.view;
    static CGPoint startLocation;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            startLocation = panelView.center;
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint translation = [gesture translationInView:panelView.superview];
            panelView.center = CGPointMake(startLocation.x + translation.x, startLocation.y + translation.y);
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            CGPoint velocity = [gesture velocityInView:panelView.superview];
            if (sqrt(velocity.x*velocity.x + velocity.y*velocity.y) > 1000) {
                // 如果速度很快，认为是甩动关闭
                [self hideQuickActionsPanel:nil];
            } else {
                // 边界检查，确保面板不会超出屏幕
                UIView *superview = panelView.superview;
                CGFloat minX = panelView.frame.size.width/2;
                CGFloat maxX = superview.frame.size.width - minX;
                CGFloat minY = panelView.frame.size.height/2;
                CGFloat maxY = superview.frame.size.height - minY;
                
                CGPoint finalCenter = panelView.center;
                finalCenter.x = MAX(minX, MIN(finalCenter.x, maxX));
                finalCenter.y = MAX(minY, MIN(finalCenter.y, maxY));
                
                [UIView animateWithDuration:0.3 animations:^{
                    panelView.center = finalCenter;
                }];
            }
            break;
        }
            
        default:
            break;
    }
}

%new
- (void)setupSmartModuleOrdering {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *usageStats;
    
    // 尝试读取现有使用统计
    NSData *statsData = [defaults objectForKey:@"DYYYModuleUsageStats"];
    if (statsData) {
        usageStats = [NSKeyedUnarchiver unarchiveObjectWithData:statsData];
    } else {
        usageStats = [NSMutableDictionary dictionary];
    }
    
    // 存储使用统计引用
    objc_setAssociatedObject(self, "moduleUsageStats", usageStats, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)recordModuleUsage:(NSString *)moduleTitle {
    NSMutableDictionary *usageStats = objc_getAssociatedObject(self, "moduleUsageStats");
    if (!usageStats) return;
    
    // 更新使用计数
    NSNumber *currentCount = usageStats[moduleTitle];
    NSInteger newCount = currentCount ? [currentCount integerValue] + 1 : 1;
    usageStats[moduleTitle] = @(newCount);
    
    // 更新最后使用时间
    NSMutableDictionary *lastUsed = usageStats[@"lastUsed"] ?: [NSMutableDictionary dictionary];
    lastUsed[moduleTitle] = [NSDate date];
    usageStats[@"lastUsed"] = lastUsed;
    
    // 保存更新后的统计
    NSData *statsData = [NSKeyedArchiver archivedDataWithRootObject:usageStats];
    [[NSUserDefaults standardUserDefaults] setObject:statsData forKey:@"DYYYModuleUsageStats"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

%new
- (NSArray<DYYYMenuModule *> *)applySmartOrderingToModules:(NSArray<DYYYMenuModule *> *)modules {
    NSMutableDictionary *usageStats = objc_getAssociatedObject(self, "moduleUsageStats");
    if (!usageStats || ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableSmartOrdering"]) {
        return modules;
    }
    
    // 创建带有使用统计的模块数组
    NSMutableArray *modulesWithStats = [NSMutableArray array];
    for (DYYYMenuModule *module in modules) {
        NSMutableDictionary *moduleInfo = [NSMutableDictionary dictionary];
        moduleInfo[@"module"] = module;
        
        // 获取使用计数
        NSNumber *count = usageStats[module.title] ?: @0;
        moduleInfo[@"count"] = count;
        
        // 获取最后使用时间
        NSDate *lastUsed = ((NSDictionary *)usageStats[@"lastUsed"])[module.title];
        moduleInfo[@"lastUsed"] = lastUsed ?: [NSDate distantPast];
        
        [modulesWithStats addObject:moduleInfo];
    }
    
    // 基于权重排序
    [modulesWithStats sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDictionary *info1 = (NSDictionary *)obj1;
        NSDictionary *info2 = (NSDictionary *)obj2;
        
        // 计算权重：使用次数 + 时间衰减因子
        NSInteger count1 = [info1[@"count"] integerValue];
        NSInteger count2 = [info2[@"count"] integerValue];
        
        NSDate *lastUsed1 = info1[@"lastUsed"];
        NSDate *lastUsed2 = info2[@"lastUsed"];
        
        // 计算时间衰减因子（最近使用的权重更高）
        NSTimeInterval timeFactor1 = [[NSDate date] timeIntervalSinceDate:lastUsed1] / 86400.0; // 转换为天
        NSTimeInterval timeFactor2 = [[NSDate date] timeIntervalSinceDate:lastUsed2] / 86400.0;
        
        // 时间衰减公式
        CGFloat recency1 = exp(-0.1 * timeFactor1); // 指数衰减
        CGFloat recency2 = exp(-0.1 * timeFactor2);
        
        // 最终权重
        CGFloat weight1 = count1 * 0.7 + recency1 * 30;
        CGFloat weight2 = count2 * 0.7 + recency2 * 30;
        
        // 降序排序
        if (weight1 > weight2) {
            return NSOrderedAscending;
        } else if (weight1 < weight2) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
    // 提取排序后的模块
    NSMutableArray *sortedModules = [NSMutableArray array];
    for (NSDictionary *info in modulesWithStats) {
        [sortedModules addObject:info[@"module"]];
    }
    
    return sortedModules;
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
- (void)recreateMenuButtonsWithModules:(NSArray<DYYYMenuModule *> *)modules {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = [topVC.view viewWithTag:9527];
    if (!overlayView) return;
    
    UIScrollView *scrollView = [self findScrollViewInView:overlayView];
    if (!scrollView) return;
    
    // 使用传入的模块数据重新创建菜单按钮
    BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
    
    // 使用工厂创建对应样式的构建器
    DYYYMenuStyle style = isListView ? DYYYMenuStyleList : DYYYMenuStyleCard;
    DYYYMenuStyleBuilder *builder = nil;
    DYYYMenuVisualStyle visualStyle = (DYYYMenuVisualStyle)[[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYMenuVisualStyle"];
    BOOL isListLayout = (style == DYYYMenuStyleList);

    if (visualStyle == DYYYMenuVisualStyleNeuomorphic) {
        builder = [[DYYYNeuomorphicStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
    } else {
        if (isListView) {
            builder = [[DYYYListStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        } else {
            builder = [[DYYYCardStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
        }
    }
    builder.delegate = self;
    
    // 构建菜单
    [builder buildMenuWithAnimation:YES];
}

%new
- (void)showVisualStyleSelector:(UIButton *)sender {
    UIAlertController *styleSheet = [UIAlertController alertControllerWithTitle:@"视觉风格"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 获取当前选择的风格
    DYYYMenuVisualStyle currentStyle = (DYYYMenuVisualStyle)[[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYMenuVisualStyle"];
    
    // 风格选项
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
                
                // 磨砂效果
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
                
                // 磨砂效果
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
                
                // 多层次视觉效果，使磨砂风格更加突出
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
                    // 彩色边框效果
                    CALayer *borderLayer = [CALayer layer];
                    borderLayer.frame = button.bounds;
                    borderLayer.cornerRadius = button.layer.cornerRadius;
                    borderLayer.borderWidth = 1.5;
                    borderLayer.borderColor = [[DYYYManager colorWithHexString:module.color] colorWithAlphaComponent:0.5].CGColor;
                    [button.layer addSublayer:borderLayer];
                    
                    // 图标光晕效果
                    for (UIView *iconView in button.subviews) {
                        if ([iconView isKindOfClass:[UIImageView class]]) {
                            // 为图标轻微的发光效果
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
                    
                    // 细微的移动动画，让卡片看起来更加"活"
                    CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
                    floatAnimation.fromValue = @(0);
                    floatAnimation.toValue = @(-2.0 - i * 0.2); // 卡片位置越高，浮动效果越明显
                    floatAnimation.duration = 2.0 + i * 0.1;
                    floatAnimation.autoreverses = YES;
                    floatAnimation.repeatCount = HUGE_VALF;
                    floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                    
                    // 动画延迟，使卡片不会同步浮动
                    floatAnimation.beginTime = CACurrentMediaTime() + i * 0.2;
                    
                    [button.layer addAnimation:floatAnimation forKey:@"floatAnimation"];
                }
                
                // 列表特有的装饰效果
                else {
                    // 增加列表项之间的分隔边距
                    moduleView.frame = CGRectInset(moduleView.frame, 0, 2);
                    
                    // 轻微的横向弹性动画
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
    
    // 滚动监听
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
    
    // 滚动优化监听器
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

%new
- (void)applyViewModeChange:(BOOL)isListView {
    // 重建菜单
    UIScrollView *scrollView = [self findScrollViewInTopViewController:[DYYYManager getActiveTopController]];
    if (!scrollView) return;
    
    // 获取模块数据
    NSArray<DYYYMenuModule *> *modules = [self createMenuModulesForCurrentContext];
    
    // 创建构建器
    DYYYMenuStyleBuilder *builder = nil;
    DYYYMenuVisualStyle visualStyle = (DYYYMenuVisualStyle)[[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYMenuVisualStyle"];
    
    if (visualStyle == DYYYMenuVisualStyleNeuomorphic) {
        builder = [[DYYYNeuomorphicStyleBuilder alloc] initWithScrollView:scrollView modules:modules];
    } else {
        if (isListView) {
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
    
    // 智能文字颜色更新
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self applySmartTextColorToAllMenuItems];
    });
}

%new
- (void)pauseCurrentVideo {
    @try {
        // 获取当前的视频播放器
        id playerView = nil;
        if ([self respondsToSelector:@selector(playerView)]) {
            playerView = [self valueForKey:@"playerView"];
        }
        
        if (playerView) {
            // 尝试暂停视频
            if ([playerView respondsToSelector:@selector(pause)]) {
                [playerView performSelector:@selector(pause)];
                NSLog(@"DYYY: 成功暂停视频播放");
            }
        } else {
            // 备用：通过模型暂停
            if ([self respondsToSelector:@selector(model)]) {
                id model = [self valueForKey:@"model"];
                if (model && [model respondsToSelector:@selector(pause)]) {
                    [model performSelector:@selector(pause)];
                    NSLog(@"DYYY: 通过模型暂停视频播放");
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY: 暂停视频失败: %@", exception);
    }
}

%new
- (void)resumeCurrentVideo {
    @try {
        // 在LiquidGlass模式下，确保视频能够恢复播放
        BOOL liquidGlassEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"];
        
        // 获取当前的视频播放器
        id playerView = nil;
        if ([self respondsToSelector:@selector(playerView)]) {
            playerView = [self valueForKey:@"playerView"];
        }
        
        if (playerView) {
            // 尝试恢复视频播放
            if ([playerView respondsToSelector:@selector(play)]) {
                [playerView performSelector:@selector(play)];
                NSLog(@"DYYY: 成功恢复视频播放");
            }
        } else {
            // 备用方案：通过模型恢复播放
            if ([self respondsToSelector:@selector(model)]) {
                id model = [self valueForKey:@"model"];
                if (model && [model respondsToSelector:@selector(play)]) {
                    [model performSelector:@selector(play)];
                    NSLog(@"DYYY: 通过模型恢复视频播放");
                }
            }
        }
        
        // 在LiquidGlass模式下，确保自动播放状态
        if (liquidGlassEnabled && [self respondsToSelector:@selector(setIsAutoPlay:)]) {
            [self performSelector:@selector(setIsAutoPlay:) withObject:@YES];
        }
    } @catch (NSException *exception) {
        NSLog(@"DYYY: 恢复视频播放失败: %@", exception);
    }
}

%end