//
//  DYYYMenuComponents.m
//  DYYY
//
//  播放页菜单组件实现（拆分自 AWEPlayInteractionViewController.xm）。
//

#import "DYYYMenuComponents.h"
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "DYYYUtils.h"

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
    
    // 添加玻璃效果边框
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
    
    // 添加长按拖拽手势
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
    
    // 添加长按拖拽手势
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
    
    // 添加图标
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(20, (cellHeight - 28) / 2, 28, 28)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = moduleColor;  // 使用模块颜色
    UIImage *icon = [UIImage systemImageNamed:module.icon];
    if (icon) {
        iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [cellButton addSubview:iconView];
    
    // 为图标添加阴影效果增强层次感
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
    
    // 添加长按拖拽手势
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
    
    // 为左侧指示条添加正确的圆角
    colorIndicator.cornerRadius = 3; // 半径为宽度的一半
    
    // 只在左侧添加圆角，与按钮圆角保持一致
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
        
        // 添加额外的连接器，确保没有缝隙
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
    
    // 为每个卡片添加轻微的上下浮动动画
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
    
    // 添加顶部渐变效果以增强立体感
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
    
    // 为图标添加轻微发光效果
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
    
    // 添加长按拖拽手势
    UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self.delegate action:@selector(handleModuleDrag:)];
    dragGesture.minimumPressDuration = 0.5;
    dragGesture.delaysTouchesBegan = YES;
    [cellButton addGestureRecognizer:dragGesture];
    
    // 添加轻微的悬浮动画效果（仅用于卡片模式）
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
