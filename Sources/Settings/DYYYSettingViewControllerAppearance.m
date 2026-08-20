//
//  DYYYSettingViewControllerAppearance.m
//  DYYY
//
//  设置页生命周期、外观、头像、搜索栏与 table 搭建。
//  含 UISwitch 未来感效果与图片选择代理两个辅助类。
//

#import "DYYYSettingViewController.h"
#import "DYYYSettingViewControllerPrivate.h"
#import "DYYYSettingSectionProvider.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYABTestHook.h"
#import "DYYYPaths.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>

// 添加图片选择器代理
@interface DYYYImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) void (^completionBlock)(NSDictionary *info);
@end

@implementation UISwitch (DYYY_FuturisticEffects)

- (void)applyFuturisticEffects {
    // 确保只应用一次效果
    if ([objc_getAssociatedObject(self, "DYYY_hasAppliedEffects") boolValue]) {
        return;
    }
    
    objc_setAssociatedObject(self, "DYYY_hasAppliedEffects", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 配置主容器视图和效果
    self.clipsToBounds = NO;
    
    // 1. 创建高光描边层 - 增大边框宽度和阴影
    CALayer *glowBorderLayer = [CALayer layer];
    glowBorderLayer.frame = CGRectInset(self.bounds, -4, -4); // 增大边框宽度
    glowBorderLayer.cornerRadius = self.bounds.size.height / 2 + 4;
    glowBorderLayer.shadowColor = self.isOn ? [UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:1.0].CGColor : [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
    glowBorderLayer.shadowOffset = CGSizeMake(0, 0);
    glowBorderLayer.shadowOpacity = self.isOn ? 0.8 : 0.3; // 默认立即显示阴影
    glowBorderLayer.shadowRadius = 5.0; // 增大阴影半径
    glowBorderLayer.masksToBounds = NO;
    
    // 2. 创建玻璃效果覆盖层 - 增加透明度使效果更明显
    UIVisualEffectView *glassEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    glassEffectView.frame = self.bounds;
    glassEffectView.clipsToBounds = YES;
    glassEffectView.layer.cornerRadius = self.bounds.size.height / 2;
    glassEffectView.alpha = 0.18; // 增加透明度
    glassEffectView.userInteractionEnabled = NO;
    
    // 3. 创建液体动画层
    CALayer *liquidLayer = [CALayer layer];
    liquidLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    liquidLayer.masksToBounds = YES;
    liquidLayer.cornerRadius = self.bounds.size.height / 2;
    liquidLayer.opacity = 0.0;
    
    // 创建液体渐变
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = liquidLayer.bounds;
    gradientLayer.cornerRadius = liquidLayer.cornerRadius;
    
    // 设置渐变颜色基于开关状态 - 使用更明亮的颜色
    UIColor *liquidColor = self.isOn ? 
        [UIColor colorWithRed:20/255.0 green:142/255.0 blue:255/255.0 alpha:0.8] : // 更亮的蓝色
        [UIColor colorWithWhite:0.85 alpha:0.8]; // 更亮的灰色
    UIColor *transparentColor = [liquidColor colorWithAlphaComponent:0.0];
    
    gradientLayer.colors = @[(id)liquidColor.CGColor, (id)transparentColor.CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1.0, 0.5);
    
    [liquidLayer addSublayer:gradientLayer];
    
    // 存储这些层以便后续更新
    objc_setAssociatedObject(self, "DYYY_glowBorderLayer", glowBorderLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "DYYY_glassEffectView", glassEffectView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "DYYY_liquidLayer", liquidLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "DYYY_gradientLayer", gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 层级顺序很重要：高光层在底部，玻璃效果在最上层
    [self.layer insertSublayer:glowBorderLayer atIndex:0]; // 高光层放在底部
    [self.layer addSublayer:liquidLayer]; // 液体层在中间
    [self addSubview:glassEffectView]; // 玻璃效果在最上层
    
    // 初始更新效果
    [self updateFuturisticEffectsWithState:self.isOn animated:NO];
    
    // 确保监听状态变化
    [self removeTarget:self action:@selector(futuristicSwitchValueChanged) forControlEvents:UIControlEventValueChanged];
    [self addTarget:self action:@selector(futuristicSwitchValueChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)futuristicSwitchValueChanged {
    [self updateFuturisticEffectsWithState:self.isOn animated:YES];
}

- (void)updateFuturisticEffectsWithState:(BOOL)isOn animated:(BOOL)animated {
    CALayer *glowBorderLayer = objc_getAssociatedObject(self, "DYYY_glowBorderLayer");
    CALayer *liquidLayer = objc_getAssociatedObject(self, "DYYY_liquidLayer");
    CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, "DYYY_gradientLayer");
    
    // 准备动画
    NSTimeInterval animDuration = animated ? 0.35 : 0.0;
    
    // 1. 更新高光边框颜色和不透明度
    UIColor *glowColor = isOn ? [UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:1.0] : [UIColor colorWithWhite:0.8 alpha:1.0];
    CGFloat glowOpacity = isOn ? 0.8 : 0.3;
    
    if (animated) {
        // 高光边框动画
        CABasicAnimation *shadowColorAnimation = [CABasicAnimation animationWithKeyPath:@"shadowColor"];
        shadowColorAnimation.toValue = (__bridge id)glowColor.CGColor;
        shadowColorAnimation.duration = animDuration;
        [glowBorderLayer addAnimation:shadowColorAnimation forKey:@"shadowColor"];
        
        CABasicAnimation *shadowOpacityAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        shadowOpacityAnimation.toValue = @(glowOpacity);
        shadowOpacityAnimation.duration = animDuration;
        [glowBorderLayer addAnimation:shadowOpacityAnimation forKey:@"shadowOpacity"];
    }
    
    glowBorderLayer.shadowColor = glowColor.CGColor;
    glowBorderLayer.shadowOpacity = glowOpacity;
    
    // 2. 触发液体动画效果
    if (animated) {
        // 设置液体颜色
        UIColor *liquidColor = isOn ? [UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:0.7] : [UIColor colorWithWhite:0.8 alpha:0.7];
        UIColor *transparentColor = [liquidColor colorWithAlphaComponent:0.0];
        
        // 更新渐变颜色
        gradientLayer.colors = @[(id)liquidColor.CGColor, (id)transparentColor.CGColor];
        
        // 液体波动动画
        [CATransaction begin];
        [CATransaction setAnimationDuration:animDuration];
        
        // 显示液体层
        liquidLayer.opacity = 1.0;
        
        // 液体流动动画
        CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position.x"];
        positionAnimation.fromValue = @(isOn ? -self.bounds.size.width : self.bounds.size.width * 2);
        positionAnimation.toValue = @(isOn ? self.bounds.size.width * 2 : -self.bounds.size.width);
        positionAnimation.duration = animDuration * 1.5;
        positionAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        
        [CATransaction setCompletionBlock:^{
            // 完成后隐藏液体层
            [UIView animateWithDuration:0.2 animations:^{
                liquidLayer.opacity = 0.0;
            }];
        }];
        
        [liquidLayer addAnimation:positionAnimation forKey:@"liquidFlow"];
        [CATransaction commit];
        
        // 添加脉冲效果
        CAKeyframeAnimation *pulseAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        pulseAnimation.values = @[@1.0, @1.03, @1.0];
        pulseAnimation.keyTimes = @[@0, @0.5, @1.0];
        pulseAnimation.duration = animDuration;
        pulseAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                          [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        [self.layer addAnimation:pulseAnimation forKey:@"pulse"];
    }
}

@end

@implementation DYYYImagePickerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    if (self.completionBlock) {
        self.completionBlock(info);
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation DYYYSettingViewController (Appearance)

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DYYY设置";
    self.expandedSections = [NSMutableSet set];
    self.expandedGroups = [NSMutableSet set];
    self.isSearching = NO;
    self.isKVOAdded = NO;
    
    // 隐藏顶部指示器条
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect = nil;
        appearance.shadowColor = nil;
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    // 初始化触觉反馈生成器
    self.feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self.feedbackGenerator prepare];
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backButtonTapped:)];
    self.navigationItem.leftBarButtonItem = backItem;
    
    [self setupAppearance];
    [self setupBackgroundColorView];
    [self setupAvatarView];
    [self setupSearchBar];
    [self setupTableView];
    [self setupSettingItems];
    [self setupSectionTitles];
    [self setupFooterLabel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBackgroundColorChanged) name:@"DYYYBackgroundColorChanged" object:nil];
    
    // 设置链接解析的默认值
    NSString *interfaceDownload = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (interfaceDownload == nil || [interfaceDownload stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@"https://api.qsy.ink/api/douyin?key=DYYY&url=" forKey:@"DYYYInterfaceDownload"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 初始化热更新数据（使用 DYYYABTestHook 统一接口）
    ensureABTestDataLoaded();

    [self ensureCustomAlbumSizeDefault];
}

- (void)ensureCustomAlbumSizeDefault {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL large = [defaults objectForKey:@"DYYYCustomAlbumSizeLarge"] ? [defaults boolForKey:@"DYYYCustomAlbumSizeLarge"] : NO;
    BOOL medium = [defaults objectForKey:@"DYYYCustomAlbumSizeMedium"] ? [defaults boolForKey:@"DYYYCustomAlbumSizeMedium"] : NO;
    BOOL small = [defaults objectForKey:@"DYYYCustomAlbumSizeSmall"] ? [defaults boolForKey:@"DYYYCustomAlbumSizeSmall"] : NO;

    // 如果都没设置过，默认“中”为YES，其它NO
    if (!large && !medium && !small) {
        [defaults setBool:NO forKey:@"DYYYCustomAlbumSizeLarge"];
        [defaults setBool:YES forKey:@"DYYYCustomAlbumSizeMedium"];
        [defaults setBool:NO forKey:@"DYYYCustomAlbumSizeSmall"];
        [defaults synchronize];
    } else {
        // 保证互斥：如果有多个为YES，只保留第一个为YES
        NSArray *keys = @[@"DYYYCustomAlbumSizeLarge", @"DYYYCustomAlbumSizeMedium", @"DYYYCustomAlbumSizeSmall"];
        NSMutableArray *onKeys = [NSMutableArray array];
        for (NSString *key in keys) {
            if ([defaults boolForKey:key]) {
                [onKeys addObject:key];
            }
        }
        if (onKeys.count > 1) {
            // 只保留第一个为YES，其它设为NO
            for (NSInteger i = 1; i < onKeys.count; i++) {
                [defaults setBool:NO forKey:onKeys[i]];
            }
            [defaults synchronize];
        }
    }
}

- (void)backButtonTapped:(id)sender {
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.isExiting = YES;
    
    self.isSearching = NO;
    self.searchBar.text = @"";
    self.filteredSections = nil;
    self.filteredSectionTitles = nil;
    [self.expandedSections removeAllObjects];
    
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
}

#pragma mark - Setup Methods

- (void)setupAppearance {
    if (self.navigationController) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
        self.navigationController.navigationBar.translucent = YES;
        self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
    }
}

- (void)setupBackgroundColorView {
    self.backgroundColorView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.backgroundColorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *savedColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor whiteColor]; // 默认白色
    self.backgroundColorView.backgroundColor = savedColor;
    [self.view insertSubview:self.backgroundColorView atIndex:0];
}

- (void)setupAvatarView {
    self.avatarContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 160)];
    self.avatarContainerView.backgroundColor = [UIColor clearColor];
    
    self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 100) / 2, 20, 100, 100)];
    self.avatarImageView.layer.cornerRadius = 50;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.backgroundColor = [UIColor systemGray4Color];
    
    NSString *avatarPath = [self avatarImagePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarPath]) {
        self.avatarImageView.image = [UIImage imageWithContentsOfFile:avatarPath];
    } else {
        self.avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
        self.avatarImageView.tintColor = [UIColor systemGrayColor];
    }
    
    [self.avatarContainerView addSubview:self.avatarImageView];
    
    self.avatarTapLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, 30)];
    NSString *customTapText = DYYYCachedString(@"DYYYAvatarTapText");
    self.avatarTapLabel.text = customTapText.length > 0 ? customTapText : @"pxx917144686";
    self.avatarTapLabel.textAlignment = NSTextAlignmentCenter;
    self.avatarTapLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    self.avatarTapLabel.textColor = [UIColor systemBlueColor];
    [self.avatarContainerView addSubview:self.avatarTapLabel];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)];
    self.avatarImageView.userInteractionEnabled = YES;
    [self.avatarImageView addGestureRecognizer:tapGesture];
}

- (void)setupSearchBar {
    // 创建一个容器视图来承载搜索栏和阴影效果
    // 减小搜索框高度，增加上边距使位置更合理
    UIView *searchContainer = [[UIView alloc] initWithFrame:CGRectMake(24, 165, self.view.bounds.size.width - 48, 40)];
    searchContainer.backgroundColor = [UIColor clearColor];
    searchContainer.tag = 1001;
    
    // 创建内层阴影容器（减小高度）
    UIView *innerShadowContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, searchContainer.frame.size.width, 36)];
    // 减小圆角，使按钮看起来更紧凑
    innerShadowContainer.layer.cornerRadius = 18;
    innerShadowContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    innerShadowContainer.layer.masksToBounds = NO;
    
    // 保持较小且锐利的环绕阴影
    innerShadowContainer.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.1].CGColor;
    innerShadowContainer.layer.shadowOffset = CGSizeMake(0, 1);
    innerShadowContainer.layer.shadowOpacity = 0.8;
    innerShadowContainer.layer.shadowRadius = 1.0;
    
    // 创建外层阴影容器
    UIView *outerShadowContainer = [[UIView alloc] initWithFrame:innerShadowContainer.frame];
    outerShadowContainer.layer.cornerRadius = 18;
    outerShadowContainer.backgroundColor = [UIColor clearColor];
    outerShadowContainer.layer.masksToBounds = NO;
    
    // 减小阴影效果，使整体更轻量
    outerShadowContainer.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
    outerShadowContainer.layer.shadowOffset = CGSizeMake(0, 2);
    outerShadowContainer.layer.shadowOpacity = 0.5;
    outerShadowContainer.layer.shadowRadius = 4;
    
    // 按照层次结构添加视图
    [searchContainer addSubview:outerShadowContainer];
    [searchContainer addSubview:innerShadowContainer];
    
    // 创建并配置搜索栏（减小尺寸）
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, innerShadowContainer.frame.size.width, 34)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索设置";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor clearColor];
    
    // 优化搜索框内部文本
    self.searchBar.searchTextField.backgroundColor = [UIColor clearColor];
    self.searchBar.searchTextField.font = [UIFont systemFontOfSize:14]; // 减小字体大小
    self.searchBar.searchTextField.textColor = [UIColor darkTextColor];
    
    // 调整内阴影效果
    UIView *textFieldContainer = self.searchBar.searchTextField.superview;
    textFieldContainer.layer.shadowColor = [UIColor colorWithWhite:0.8 alpha:0.4].CGColor;
    textFieldContainer.layer.shadowOffset = CGSizeMake(0, 1);
    textFieldContainer.layer.shadowOpacity = 0.3;
    textFieldContainer.layer.shadowRadius = 0.5;
    
    // 调整搜索图标位置，更紧凑
    UIOffset iconOffset = UIOffsetMake(20, 0);
    [self.searchBar setPositionAdjustment:iconOffset forSearchBarIcon:UISearchBarIconSearch];
    
    // 添加搜索栏到内层容器
    [innerShadowContainer addSubview:self.searchBar];
    
    // 保留水波纹效果
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(searchBarTapped:)];
    [innerShadowContainer addGestureRecognizer:tapGesture];
    
    // 将完整的搜索容器添加到表头视图
    [self.tableView.tableHeaderView addSubview:searchContainer];
    
    // 减小tableHeaderView的高度，使搜索区域更紧凑
    CGRect headerFrame = self.tableView.tableHeaderView.frame;
    headerFrame.size.height = 60; // 减小高度
    self.tableView.tableHeaderView.frame = headerFrame;
}

// 添加搜索栏点击触觉反馈
- (void)searchBarTapped:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        // 执行水波纹动画
        CGPoint tapPoint = [gesture locationInView:gesture.view];
        [self addRippleEffectAtPoint:tapPoint inView:gesture.view];
        
        // 触发触觉反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 激活搜索栏
        [self.searchBar becomeFirstResponder];
    }
}

// 添加水波纹效果
- (void)addRippleEffectAtPoint:(CGPoint)point inView:(UIView *)view {
    // 创建波纹层
    CAShapeLayer *rippleLayer = [CAShapeLayer layer];
    rippleLayer.position = point;
    
    // 设置波纹路径
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:CGPointZero 
                                                             radius:10 
                                                          startAngle:0 
                                                            endAngle:2*M_PI 
                                                           clockwise:YES];
    rippleLayer.path = circlePath.CGPath;
    
    // 设置波纹外观
    rippleLayer.fillColor = [UIColor colorWithWhite:0.9 alpha:0.3].CGColor;
    rippleLayer.opacity = 1.0;
    
    // 添加到视图
    [view.layer addSublayer:rippleLayer];
    
    // 创建扩散动画
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @1.0;
    scaleAnimation.toValue = @15.0;
    
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @1.0;
    opacityAnimation.toValue = @0.0;
    
    // 组合动画
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = @[scaleAnimation, opacityAnimation];
    animationGroup.duration = 0.8;
    animationGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    // 完成后移除波纹层
    animationGroup.removedOnCompletion = YES;
    animationGroup.fillMode = kCAFillModeForwards;
    
    [rippleLayer addAnimation:animationGroup forKey:@"rippleEffect"];
    
    // 延时删除图层
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [rippleLayer removeFromSuperlayer];
    });
}

// 根据主题动态调整搜索栏颜色
- (void)handleBackgroundColorChanged {
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *savedColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor whiteColor];
    self.backgroundColorView.backgroundColor = savedColor;
    
    // 更新搜索栏背景色
    // 提取背景颜色的亮度
    CGFloat brightness = 0;
    [savedColor getWhite:&brightness alpha:NULL];
    
    // 根据背景亮度调整搜索栏色调
    UIView *searchContainer = [self.tableView.tableHeaderView viewWithTag:1001];
    if (!searchContainer) {
        return;
    }
    
    for (UIView *subview in searchContainer.subviews) {
        if (subview.layer.cornerRadius == 22) {
            if (brightness < 0.5) {
                // 深色背景下使用深色搜索栏
                subview.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
                self.searchBar.searchTextField.textColor = [UIColor whiteColor];
                self.searchBar.searchTextField.attributedPlaceholder = [[NSAttributedString alloc] 
                    initWithString:@"搜索设置" 
                    attributes:@{NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
            } else {
                // 浅色背景下使用浅色搜索栏
                subview.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
                self.searchBar.searchTextField.textColor = [UIColor darkTextColor];
                self.searchBar.searchTextField.attributedPlaceholder = [[NSAttributedString alloc] 
                    initWithString:@"搜索设置" 
                    attributes:@{NSForegroundColorAttributeName: [UIColor grayColor]}];
            }
        }
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    // 调整section头部间距，减小或移除这个设置
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 2; // 减小组头部之间的垂直距离
    }
    
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 204)];
    [self.tableView.tableHeaderView addSubview:self.avatarContainerView];
    [self.tableView.tableHeaderView addSubview:self.searchBar];
    self.searchBar.frame = CGRectMake(0, 160, self.view.bounds.size.width, 44);
    [self.view addSubview:self.tableView];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:longPress];
}

- (void)setupSettingItems {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *sections = [DYYYSettingSectionProvider defaultSections];

        if (!DYYYGlassOSAvailable()) {
            NSMutableArray *filteredSections = [NSMutableArray array];
            for (NSArray *section in sections) {
                NSMutableArray *filtered = [NSMutableArray array];
                for (DYYYSettingItem *item in section) {
                    // 子分组标题行 key 为 nil，直接保留（containsObject:nil 不安全）
                    if (item.type == DYYYSettingItemTypeGroupHeader ||
                        ![DYYYGlassGatedKeySet() containsObject:item.key]) {
                        [filtered addObject:item];
                    }
                }
                // 清理玻璃项全被过滤后空挂的子分组标题
                NSMutableArray *cleaned = [NSMutableArray array];
                for (NSUInteger i = 0; i < filtered.count; i++) {
                    DYYYSettingItem *item = filtered[i];
                    if (item.type == DYYYSettingItemTypeGroupHeader) {
                        BOOL hasContent = NO;
                        for (NSUInteger j = i + 1; j < filtered.count; j++) {
                            if (((DYYYSettingItem *)filtered[j]).type == DYYYSettingItemTypeGroupHeader) {
                                break;
                            }
                            hasContent = YES;
                            break;
                        }
                        if (!hasContent) {
                            continue; // 空子分组标题丢弃
                        }
                    }
                    [cleaned addObject:item];
                }
                [filteredSections addObject:cleaned];
            }
            sections = [filteredSections copy];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.isExiting) {
                return;
            }

            strongSelf.settingSections = sections;
            strongSelf.filteredSections = sections;
            strongSelf.filteredSectionTitles = [strongSelf.sectionTitles mutableCopy];
            if (strongSelf.tableView) {
                [strongSelf.tableView reloadData];
            }
            
            // 设置备份功能
            [strongSelf setupBackupFunctions];
        });
    });
}

- (void)setupFooterLabel {
    // 创建一个容器视图，用于包含文本和按钮
    UIView *footerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    
    // 创建文本标签
    self.footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 40)];
    self.footerLabel.text = @"DYYY++ (修改2025-10-05)";
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    self.footerLabel.font = [UIFont systemFontOfSize:14];
    self.footerLabel.textColor = [UIColor secondaryLabelColor];
    self.footerLabel.numberOfLines = 2;
    [footerContainer addSubview:self.footerLabel];
    
    // 创建"看看源代码"按钮 - 增强动画效果
    UIButton *sourceCodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sourceCodeButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 50, 200, 40);
    sourceCodeButton.layer.cornerRadius = 20;
    sourceCodeButton.clipsToBounds = YES;
    sourceCodeButton.tag = 101;
    
    // 创建渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = CGRectMake(0, 0, 200, 40);
    gradientLayer.cornerRadius = 20;
    gradientLayer.colors = @[(id)[UIColor systemBlueColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1, 0.5);
    [sourceCodeButton.layer insertSublayer:gradientLayer atIndex:0];
    
    // 添加动画效果
    CABasicAnimation *gradientAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
    gradientAnimation.fromValue = @[(id)[UIColor systemBlueColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
    gradientAnimation.toValue = @[(id)[UIColor systemPurpleColor].CGColor, (id)[UIColor systemBlueColor].CGColor];
    gradientAnimation.duration = 3.0;
    gradientAnimation.autoreverses = YES;
    gradientAnimation.repeatCount = HUGE_VALF;
    [gradientLayer addAnimation:gradientAnimation forKey:@"gradientAnimation"];
    
    [sourceCodeButton setTitle:@"👉 看看源代码！" forState:UIControlStateNormal];
    [sourceCodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sourceCodeButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    
    // 添加阴影效果
    sourceCodeButton.layer.shadowColor = [UIColor blackColor].CGColor;
    sourceCodeButton.layer.shadowOffset = CGSizeMake(0, 2);
    sourceCodeButton.layer.shadowRadius = 4;
    sourceCodeButton.layer.shadowOpacity = 0.3;
    
    [sourceCodeButton addTarget:self action:@selector(showSourceCodePopup) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加按下效果
    [sourceCodeButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [sourceCodeButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    
    [footerContainer addSubview:sourceCodeButton];
    
    // 设置容器为表格底部视图
    self.tableView.tableFooterView = footerContainer;
}

- (void)setupSectionTitles {
    self.sectionTitles = [NSMutableArray arrayWithObjects:
                          @"播放",
                          @"手势与快捷",
                          @"页面设置",
                          @"内容与过滤",
                          @"互动",
                          @"数据与维护",
                          nil];
}

#pragma mark - Avatar Handling

- (void)avatarTapped:(UITapGestureRecognizer *)gesture {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusAuthorized) {
                UIImagePickerController *picker = [[UIImagePickerController alloc] init];
                picker.delegate = self;
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                picker.allowsEditing = YES;
                [self presentViewController:picker animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法访问相册"
                                                                               message:@"请在设置中允许访问相册"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *selectedImage = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (!selectedImage) {
        [DYYYManager showToast:@"无法获取所选图片"];
        return;
    }
    
    BOOL isCustomAlbumPicker = [objc_getAssociatedObject(picker, "isCustomAlbumPicker") boolValue];
    if (isCustomAlbumPicker) {
        NSString *customAlbumImagePath = [self saveCustomAlbumImage:selectedImage];
        if (customAlbumImagePath) {
            [[NSUserDefaults standardUserDefaults] setObject:customAlbumImagePath forKey:@"DYYYCustomAlbumImagePath"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [DYYYManager showToast:@"自定义相册图片已设置"];
            [self.tableView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
        } else {
            [DYYYManager showToast:@"保存自定义相册图片失败"];
        }
    } else {
        NSString *avatarPath = [self avatarImagePath];
        NSData *imageData = UIImageJPEGRepresentation(selectedImage, 0.8);
        [imageData writeToFile:avatarPath atomically:YES];
        self.avatarImageView.image = selectedImage;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)avatarImagePath {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documentsPath stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
}

- (NSString *)saveCustomAlbumImage:(UIImage *)image {
    NSString *dyyyFolder = [DYYYPaths iconsDir];
    
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolder 
                              withIntermediateDirectories:YES 
                                               attributes:nil 
                                                    error:&error];
    if (error) {
        return nil;
    }
    
    NSString *imagePath = [dyyyFolder stringByAppendingPathComponent:@"custom_album_image.png"];
    NSData *imageData = UIImagePNGRepresentation(image);
    if ([imageData writeToFile:imagePath atomically:YES]) {
        return imagePath;
    }
    
    return nil;
}

#pragma mark - Dealloc

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.tableView) {
        self.tableView.delegate = nil;
        self.tableView.dataSource = nil;
    }
    if (self.searchBar) {
        self.searchBar.delegate = nil;
    }
}

@end
