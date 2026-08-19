//
//  DYYYPlayInteractionMenuHooks.xm
//  DYYY
//
//  拖拽菜单创建、排序、关闭和手势 hook（拆分自 AWEPlayInteractionViewController.xm）。
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

    UIView *menuContainer = [[UIView alloc] initWithFrame:CGRectMake(0, topVC.view.bounds.size.height, menuWidth, menuHeight + bottomSafe)];
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
    
    // 在头部区域添加视图模式切换器
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

    // 添加动作处理方法
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

    // 添加拖拽手势和点击事件
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeMenuPan:)];
    [resizeButton addGestureRecognizer:pan];
    [resizeButton addTarget:self action:@selector(customMenuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:resizeButton];

    // 在resizeButton旁边添加颜色选择按钮 - 使用彩色图标
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

    // 添加点击事件
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

    // 添加视觉风格切换按钮
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
    
    // 添加字体规范化
    [self normalizeListViewFonts:scrollView];

    // 添加手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFluentMenu:)];
    [overlayView addGestureRecognizer:tapGesture];

    // 在创建菜单容器后为其添加点击手势，当用户点击菜单时显示头部控制区
    UITapGestureRecognizer *menuTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuContainerTap:)];
    menuTapGesture.cancelsTouchesInView = NO; // 不干扰其他触摸事件
    [menuContainer addGestureRecognizer:menuTapGesture];

    // 弹窗支持拖动
    UIPanGestureRecognizer *dragPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_handleSettingPanelPan:)];
    [menuContainer addGestureRecognizer:dragPan];

    [topVC.view addSubview:overlayView];

    [UIView animateWithDuration:0.3 animations:^{
        overlayView.alpha = 1;
    }];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect frame = menuContainer.frame;
        frame.origin.y = topVC.view.bounds.size.height - menuHeight - bottomSafe;
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
        UIViewController *settingVC = [[NSClassFromString(@"DYYYSettingViewController") alloc] init];
        if (settingVC) {
            BOOL isIPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
            if (@available(iOS 15.0, *)) {
                if (!isIPad) {
                    settingVC.modalPresentationStyle = UIModalPresentationPageSheet;
                } else {
                    settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
                }
            } else {
                settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
            }

            // 全屏时加关闭按钮
            if (settingVC.modalPresentationStyle == UIModalPresentationFullScreen) {
                UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
                [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
                closeButton.translatesAutoresizingMaskIntoConstraints = NO;
                [settingVC.view addSubview:closeButton];
                [NSLayoutConstraint activateConstraints:@[
                    [closeButton.trailingAnchor constraintEqualToAnchor:settingVC.view.trailingAnchor constant:-10],
                    [closeButton.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:40],
                    [closeButton.widthAnchor constraintEqualToConstant:80],
                    [closeButton.heightAnchor constraintEqualToConstant:40]
                ]];
                [closeButton addTarget:self action:@selector(dismissDYYYSettingPanel:) forControlEvents:UIControlEventTouchUpInside];
            }

            // 顶部小横条
            UIView *handleBar = [[UIView alloc] init];
            handleBar.backgroundColor = [UIColor whiteColor];
            handleBar.layer.cornerRadius = 2.5;
            handleBar.translatesAutoresizingMaskIntoConstraints = NO;
            [settingVC.view addSubview:handleBar];
            [NSLayoutConstraint activateConstraints:@[
                [handleBar.centerXAnchor constraintEqualToAnchor:settingVC.view.centerXAnchor],
                [handleBar.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:8],
                [handleBar.widthAnchor constraintEqualToConstant:40],
                [handleBar.heightAnchor constraintEqualToConstant:5]
            ]];

            [topVC presentViewController:settingVC animated:YES completion:nil];
        }
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
        
        // 添加预定义颜色选项
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
            
            // 添加颜色指示图标
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
                                        
                                        // 添加一个背景色层让毛玻璃效果带有所选颜色
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
                                    
                                    // 添加颜色指示器 - 在按钮下方添加一个小色条
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

    // 添加音频保存功能模块
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

    // 添加API解析下载功能模块
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
    
#ifndef DYYY_RELEASE_BUILD
    // FLEX调试功能模块（发布版不含 FLEX，隐藏菜单项）
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFLEX"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableFLEX"]) {
        
        DYYYMenuModule *flexModule = [DYYYMenuModule moduleWithTitle:@"FLEX调试"
                                                                icon:@"hammer.circle.fill"  // 修复图标
                                                               color:@"#FF9500"
                                                              action:^{
            // 显示FLEX调试界面
            Class flexManagerClass = %c(DYYYFLEXManager);
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
#endif
    
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
    
    // 触发面板功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowDislikeOnVideo"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {
        
        DYYYMenuModule *dislikeModule = [DYYYMenuModule moduleWithTitle:@"触发面板"
                                                                   icon:@"ellipsis"
                                                                  color:@"#767676"
                                                                 action:^{
            [self showDislikeOnVideo];
        }];
        [menuModules addObject:dislikeModule];
    }
    
    // 高级设置功能模块
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableAdvancedSettings"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableAdvancedSettings"]) {
        
        DYYYMenuModule *advancedSettingsModule = [DYYYMenuModule moduleWithTitle:@"其他功能"
                                                                            icon:@"gearshape.2.fill"
                                                                           color:@"#007AFF"
                                                                          action:^{
            UIViewController *topVC = [DYYYManager getActiveTopController];
            if (topVC) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"高级设置" 
                                                                              message:@"选择高级功能" 
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
                
                // 清除设置选项
                [alert addAction:[UIAlertAction actionWithTitle:@"清除设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [DYYYBottomAlertView showAlertWithTitle:@"清除设置"
                        message:@"请选择要清除的设置类型"
                        confirmButton:@"清除插件设置"
                        cancelButton:@"清除抖音设置"
                        confirmBlock:^{
                          // 清除插件设置的确认对话框
                          [DYYYBottomAlertView showAlertWithTitle:@"清除插件设置"
                                          message:@"确定要清除所有插件设置吗？\n这将无法恢复！"
                                     confirmButton:@"确定"
                                      cancelButton:@"取消"
                                      confirmBlock:^{
                                          // 获取所有以DYYY开头的NSUserDefaults键值并清除
                                          NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                                          NSDictionary *allDefaults = [defaults dictionaryRepresentation];

                                          for (NSString *key in allDefaults.allKeys) {
                                              if ([key hasPrefix:@"DYYY"]) {
                                                  [defaults removeObjectForKey:key];
                                              }
                                          }
                                          [defaults synchronize];

                                          // 显示成功提示
                                          [DYYYManager showToast:@"插件设置已清除，请重启应用"];
                                      }
                                       cancelBlock:nil];
                        }
                        cancelBlock:^{
                          // 清除抖音设置的确认对话框
                          [DYYYBottomAlertView showAlertWithTitle:@"清除抖音设置"
                                          message:@"确定要清除抖音所有设置吗？\n这将无法恢复，应用会自动退出！"
                                     confirmButton:@"确定"
                                      cancelButton:@"取消"
                                      confirmBlock:^{
                                          NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
                                          if (paths.count > 0) {
                                              NSString *preferencesPath = [paths.firstObject stringByAppendingPathComponent:@"Preferences"];
                                              NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
                                              NSString *plistPath = [preferencesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleIdentifier]];

                                              NSError *error = nil;
                                              [[NSFileManager defaultManager] removeItemAtPath:plistPath error:&error];

                                              if (!error) {
                                                  [DYYYManager showToast:@"抖音设置已清除，应用即将退出"];

                                                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                    exit(0);
                                                  });
                                              } else {
                                                  [DYYYManager showToast:[NSString stringWithFormat:@"清除失败: %@", error.localizedDescription]];
                                              }
                                          }
                                      }
                                       cancelBlock:nil];
                        }];
                }]];
                
                // 清理缓存选项
                [alert addAction:[UIAlertAction actionWithTitle:@"清理缓存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [DYYYBottomAlertView showAlertWithTitle:@"清理缓存"
                                    message:@"确定清除所有缓存？"
                                confirmButton:@"确定"
                              cancelButton:@"取消"
                                 confirmBlock:^{
                                    NSFileManager *fileManager = [NSFileManager defaultManager];
                                    NSUInteger totalSize = 0;

                                    // 临时目录
                                    NSString *tempDir = NSTemporaryDirectory();

                                    // Library目录下的缓存目录
                                    NSArray<NSString *> *customDirs = @[ @"Caches", @"BDByteCast", @"kitelog" ];
                                    NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;

                                    NSMutableArray<NSString *> *allPaths = [NSMutableArray arrayWithObject:tempDir];
                                    for (NSString *sub in customDirs) {
                                        NSString *fullPath = [libraryDir stringByAppendingPathComponent:sub];
                                        if ([fileManager fileExistsAtPath:fullPath]) {
                                            [allPaths addObject:fullPath];
                                        }
                                    }

                                    // 遍历所有目录并清理
                                    for (NSString *basePath in allPaths) {
                                        totalSize += [DYYYUtils clearDirectoryContents:basePath];
                                    }

                                    float sizeInMB = totalSize / 1024.0 / 1024.0;
                                    NSString *toastMsg = [NSString stringWithFormat:@"已清理 %.2f MB 的缓存", sizeInMB];
                                    [DYYYManager showToast:toastMsg];
                                 }
                                  cancelBlock:nil];
                }]];
                
                // 刷新视图选项
                [alert addAction:[UIAlertAction actionWithTitle:@"刷新视图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self refreshCurrentView];
                    [DYYYManager showToast:@"视图已刷新"];
                }]];
                
                // 视频信息选项
                [alert addAction:[UIAlertAction actionWithTitle:@"视频信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self showVideoDebugInfo:awemeModel];
                }]];
                
                // 强制关闭广告选项
                [alert addAction:[UIAlertAction actionWithTitle:@"强制关闭广告" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYBlockAllAds"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [DYYYManager showToast:@"已强制关闭广告，重启App生效"];
                }]];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                
                // iPad 弹出样式适配
                if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                    alert.popoverPresentationController.sourceView = topVC.view;
                    alert.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2, 
                                                                              topVC.view.bounds.size.height / 2, 
                                                                              0, 0);
                }
                
                [topVC presentViewController:alert animated:YES completion:nil];
            }
        }];
        [menuModules addObject:advancedSettingsModule];
    }
    
    // 直接返回按代码生成的原始顺序（保存索引重排逻辑会导致全部显示首个模块的 bug）
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

// 添加通用的面板关闭方法

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
    // 为menuContainer添加点击手势来重新显示控件
    UITapGestureRecognizer *tapToShowGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapToShowControls:)];
    tapToShowGesture.cancelsTouchesInView = NO; // 不干扰其他触摸事件
    [menuContainer addGestureRecognizer:tapToShowGesture];
    
    // 标记手势以便后续移除
    objc_setAssociatedObject(menuContainer, "tapToShowGesture", tapToShowGesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 添加视觉提示，告诉用户可以点击显示控件
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
    // 修复：确保在menuContainer的contentView中添加提示
    UIView *targetView = menuContainer;
    
    // 如果menuContainer包含UIVisualEffectView，获取其contentView
    for (UIView *subview in menuContainer.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            targetView = ((UIVisualEffectView *)subview).contentView;
            break;
        }
    }
    
    // 在顶部添加三个圆点提示，可以点击显示控件
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
        
        // 添加微妙的阴影
        dot.layer.shadowColor = [UIColor blackColor].CGColor;
        dot.layer.shadowOffset = CGSizeMake(0, 1);
        dot.layer.shadowRadius = 3;
        dot.layer.shadowOpacity = 0.4;
        
        [dotsContainer addSubview:dot];
    }
    
    // 修复：添加到正确的父视图
    [targetView addSubview:dotsContainer];
    
    // 确保提示在最上层显示
    [targetView bringSubviewToFront:dotsContainer];
    
    // 渐显动画
    [UIView animateWithDuration:0.4 animations:^{
        dotsContainer.alpha = 1.0;
    }];
    
    // 添加循环的脉动动画 - 依次点亮每个圆点
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
        
        // 为整个menuContainer添加点击手势来重新显示控件
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
        
        // 将预览视图添加到scrollView的父视图，确保不被裁剪
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
            
            // 添加拖拽开始的放大动画
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
            // 添加4: 显示拖动位置指示器
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
        
        // 添加5: 隐藏拖动指示器
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
    
    // 添加轻微发光效果
    indicator.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0].CGColor;
    indicator.layer.shadowOffset = CGSizeMake(0, 0);
    indicator.layer.shadowRadius = 3.0;
    indicator.layer.shadowOpacity = 0.8;
    
    [scrollView addSubview:indicator];
    
    // 添加微小的动画
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
    
    // 添加阴影效果
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
- (void)enhanceGestureControlsForMenu:(UIView *)menuContainer {
    // 添加拖拽速度感知
    UIPanGestureRecognizer *dragSpeedRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuDragWithVelocitySensing:)];
    dragSpeedRecognizer.maximumNumberOfTouches = 1;
    [menuContainer addGestureRecognizer:dragSpeedRecognizer];
    
    // 添加二指缩放手势
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPinch:)];
    [menuContainer addGestureRecognizer:pinchRecognizer];
    
    // 添加轻扫关闭手势
    UISwipeGestureRecognizer *swipeDownRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuSwipeDown:)];
    swipeDownRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [menuContainer addGestureRecognizer:swipeDownRecognizer];
    
    // 添加快速点击手势（双击切换视图模式）
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
- (void)handleMenuDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        // 获取当前视图模式并切换
        BOOL isListView = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYListViewMode"];
        
        // 简化为两种模式切换：卡片 <-> 列表
        BOOL nextModeIsListView = !isListView;
        
        // 查找段选择器并更新
        UIViewController *topVC = [DYYYManager getActiveTopController];
        for (UIView *view in topVC.view.subviews) {
            if (view.tag == 9527) {
                for (UIView *subview in view.subviews) {
                    if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                        UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
                        for (UIView *contentView in effectView.contentView.subviews) {
                            if (contentView.tag == 60) { // 头部视图tag
                                for (UIView *headerSubview in contentView.subviews) {
                                    if ([headerSubview isKindOfClass:[UISegmentedControl class]]) {
                                        UISegmentedControl *segmentControl = (UISegmentedControl *)headerSubview;
                                        segmentControl.selectedSegmentIndex = nextModeIsListView ? 1 : 0;
                                        [self viewModeChanged:segmentControl];
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [generator prepare];
            [generator impactOccurred];
        }
    }
}

%new
- (void)showQuickActionsPanel {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    
    // 创建一个小型浮动面板
    UIView *quickPanel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, topVC.view.bounds.size.width - 40, 60)];
    quickPanel.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    quickPanel.layer.cornerRadius = 15;
    quickPanel.alpha = 0;
    quickPanel.tag = 9528; // 不同于主菜单的标签
    
    // 添加模糊效果
    UIVisualEffectView *blurEffect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurEffect.frame = quickPanel.bounds;
    blurEffect.layer.cornerRadius = 15;
    blurEffect.clipsToBounds = YES;
    [quickPanel addSubview:blurEffect];
    
    // 创建快捷按钮
    NSArray *quickActions = @[
        @{@"icon": @"arrow.down.circle.fill", @"color": @"#0078D7", @"action": @"download"},
        @{@"icon": @"camera.viewfinder", @"color": @"#4CAF50", @"action": @"screenshot"},
        @{@"icon": @"text.bubble.fill", @"color": @"#107C10", @"action": @"comment"},
        @{@"icon": @"heart.fill", @"color": @"#D83B01", @"action": @"like"},
        @{@"icon": @"square.and.arrow.up.fill", @"color": @"#FFB900", @"action": @"share"}
    ];
    
    CGFloat buttonSize = 40;
    CGFloat spacing = (quickPanel.bounds.size.width - buttonSize * quickActions.count) / (quickActions.count + 1);
    
    for (NSInteger i = 0; i < quickActions.count; i++) {
        NSDictionary *actionInfo = quickActions[i];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(spacing + i * (buttonSize + spacing), 10, buttonSize, buttonSize);
        button.layer.cornerRadius = buttonSize / 2;
        
        // 设置图标
        UIImage *icon = [UIImage systemImageNamed:actionInfo[@"icon"]];
        [button setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];
        
        // 设置背景色
        button.backgroundColor = [DYYYManager colorWithHexString:actionInfo[@"color"]];
        
        // 设置阴影
        button.layer.shadowColor = [UIColor blackColor].CGColor;
        button.layer.shadowOffset = CGSizeMake(0, 2);
        button.layer.shadowRadius = 4;
        button.layer.shadowOpacity = 0.3;
        
        // 设置动作标识符
        button.tag = i;
        [button addTarget:self action:@selector(handleQuickAction:) forControlEvents:UIControlEventTouchUpInside];
        
        [blurEffect.contentView addSubview:button];
    }
    
    // 添加手势识别器来拖动面板
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleQuickPanelDrag:)];
    [quickPanel addGestureRecognizer:panGesture];
    
    // 添加单击手势来关闭面板
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideQuickActionsPanel:)];
    tapGesture.cancelsTouchesInView = NO;
    [quickPanel addGestureRecognizer:tapGesture];
    
    [topVC.view addSubview:quickPanel];
    
    // 显示动画
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        quickPanel.alpha = 1.0;
        quickPanel.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:nil];
    
    // 设置自动消失计时器
    [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(autoHideQuickPanel:) userInfo:quickPanel repeats:NO];
}

%new
- (void)handleQuickAction:(UIButton *)sender {
    NSArray *actions = @[@"download", @"screenshot", @"comment", @"like", @"share"];
    NSString *action = actions[sender.tag];
    
    // 执行相应操作
    if ([action isEqualToString:@"download"]) {
        AWEAwemeModel *model = [self getCurrentAwemeModel];
        // 执行下载操作
    } 
    else if ([action isEqualToString:@"screenshot"]) {
        [self dyyy_startCustomScreenshotProcess];
    }
    else if ([action isEqualToString:@"comment"]) {
        [self performCommentAction];
    }
    else if ([action isEqualToString:@"like"]) {
        [self performLikeAction];
    }
    else if ([action isEqualToString:@"share"]) {
        [self showSharePanel];
    }
    
    // 关闭快捷面板
    [self hideQuickActionsPanel:nil];
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
    
    // 添加字体规范化处理
    [self normalizeListViewFonts:scrollView];
    
    // 添加智能文字颜色更新
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self applySmartTextColorToAllMenuItems];
    });
}

%end
