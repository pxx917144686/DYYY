#import "FLEXLookinPreviewController.h"
#import "FLEXCompatibility.h"
#import <QuartzCore/QuartzCore.h>

@interface FLEXLookinPreviewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) NSArray<FLEXLookinDisplayItem *> *displayItems;
@property (nonatomic, strong) UISegmentedControl *dimensionControl;
@property (nonatomic, strong) UISlider *scaleSlider;
@end

@implementation FLEXLookinPreviewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Lookin 3D预览";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self setupControls];
    [self loadCurrentViewHierarchy];
}

- (void)setupUI {
    // 滚动容器
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.backgroundColor = [UIColor blackColor];
    self.scrollView.minimumZoomScale = 0.1;
    self.scrollView.maximumZoomScale = 3.0;
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];
    
    // 3D容器
    self.containerView = [[UIView alloc] init];
    [self.scrollView addSubview:self.containerView];
    
    // 布局约束
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:60],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.containerView.centerXAnchor constraintEqualToAnchor:self.scrollView.centerXAnchor],
        [self.containerView.centerYAnchor constraintEqualToAnchor:self.scrollView.centerYAnchor],
        [self.containerView.widthAnchor constraintEqualToConstant:400],
        [self.containerView.heightAnchor constraintEqualToConstant:600]
    ]];
}

- (void)setupControls {
    // 2D/3D切换
    self.dimensionControl = [[UISegmentedControl alloc] initWithItems:@[@"2D", @"3D"]];
    self.dimensionControl.selectedSegmentIndex = 1;
    [self.dimensionControl addTarget:self action:@selector(dimensionChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 缩放控制
    self.scaleSlider = [[UISlider alloc] init];
    self.scaleSlider.minimumValue = 0.1;
    self.scaleSlider.maximumValue = 2.0;
    self.scaleSlider.value = 1.0;
    [self.scaleSlider addTarget:self action:@selector(scaleChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 添加到导航栏
    UIStackView *controlStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.dimensionControl, self.scaleSlider]];
    controlStack.axis = UILayoutConstraintAxisHorizontal;
    controlStack.spacing = 10;
    controlStack.distribution = UIStackViewDistributionFillEqually;
    
    controlStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:controlStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [controlStack.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:10],
        [controlStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [controlStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [controlStack.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (void)loadCurrentViewHierarchy {
    // ✅ 独立获取当前应用的视图层次
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    NSMutableArray *items = [NSMutableArray array];
    
    [self buildDisplayItemsFromView:keyWindow.rootViewController.view items:items depth:0];
    
    self.displayItems = [items copy];
    [self renderWithDisplayItems:self.displayItems];
}

- (void)buildDisplayItemsFromView:(UIView *)view items:(NSMutableArray *)items depth:(NSInteger)depth {
    FLEXLookinDisplayItem *item = [[FLEXLookinDisplayItem alloc] init];
    item.view = view;
    item.title = NSStringFromClass([view class]);
    item.subtitle = [NSString stringWithFormat:@"<%p>", view];
    
    // 构建子项
    NSMutableArray *children = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        [self buildDisplayItemsFromView:subview items:children depth:depth + 1];
    }
    item.children = [children copy];
    
    [items addObject:item];
}

- (void)renderWithDisplayItems:(NSArray<FLEXLookinDisplayItem *> *)items {
    // 清除之前的渲染
    for (UIView *subview in self.containerView.subviews) {
        [subview removeFromSuperview];
    }
    
    // ✅ 纯iOS的3D渲染
    [self render3DHierarchy:items];
}

- (void)render3DHierarchy:(NSArray<FLEXLookinDisplayItem *> *)items {
    CGFloat zOffset = 0;
    
    for (FLEXLookinDisplayItem *item in items) {
        [self renderItem:item atZOffset:zOffset];
        zOffset += self.zInterspace;
        
        // 递归渲染子项
        [self renderChildItems:item.children parentZOffset:zOffset];
    }
}

- (void)renderItem:(FLEXLookinDisplayItem *)item atZOffset:(CGFloat)zOffset {
    if (!item.view) return;
    
    // 创建3D表示层
    UIView *renderView = [[UIView alloc] init];
    renderView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.3];
    renderView.layer.borderWidth = 1;
    renderView.layer.borderColor = [UIColor systemBlueColor].CGColor;
    
    // 计算frame（简化版本）
    CGRect frame = item.view.frame;
    CGFloat scale = self.previewScale;
    renderView.frame = CGRectMake(frame.origin.x * scale, 
                                 frame.origin.y * scale, 
                                 frame.size.width * scale, 
                                 frame.size.height * scale);
    
    // 应用3D变换
    if (self.previewDimension == FLEXLookinPreviewDimension3D) {
        CATransform3D transform = CATransform3DIdentity;
        transform.m34 = -1.0 / 1000.0; // 透视
        transform = CATransform3DRotate(transform, self.rotation.x, 1, 0, 0);
        transform = CATransform3DRotate(transform, self.rotation.y, 0, 1, 0);
        transform = CATransform3DTranslate(transform, 0, 0, zOffset);
        
        renderView.layer.transform = transform;
    }
    
    // 添加标签
    UILabel *label = [[UILabel alloc] init];
    label.text = item.title;
    label.font = [UIFont systemFontOfSize:8];
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    label.center = CGPointMake(renderView.frame.size.width / 2, renderView.frame.size.height / 2);
    [renderView addSubview:label];
    
    [self.containerView addSubview:renderView];
}

- (void)renderChildItems:(NSArray<FLEXLookinDisplayItem *> *)children parentZOffset:(CGFloat)parentZOffset {
    CGFloat childZOffset = parentZOffset;
    
    for (FLEXLookinDisplayItem *child in children) {
        childZOffset += self.zInterspace;
        [self renderItem:child atZOffset:childZOffset];
        
        // 递归渲染更深层的子项
        [self renderChildItems:child.children parentZOffset:childZOffset];
    }
}

#pragma mark - 控制事件

- (void)dimensionChanged:(UISegmentedControl *)sender {
    self.previewDimension = sender.selectedSegmentIndex;
    [self renderWithDisplayItems:self.displayItems];
}

- (void)scaleChanged:(UISlider *)sender {
    self.previewScale = sender.value;
    [self renderWithDisplayItems:self.displayItems];
}

- (void)setDimension:(FLEXLookinPreviewDimension)dimension animated:(BOOL)animated {
    self.previewDimension = dimension;
    self.dimensionControl.selectedSegmentIndex = dimension;
    [self renderWithDisplayItems:self.displayItems];
}

- (void)setRotation:(CGPoint)rotation animated:(BOOL)animated {
    self.rotation = rotation;
    [self renderWithDisplayItems:self.displayItems];
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.containerView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    // 缩放后重新居中内容
    [self centerContent];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // 可选：添加滚动时的逻辑
}

#pragma mark - 辅助方法

- (void)centerContent {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect contentsFrame = self.containerView.frame;
    
    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    } else {
        contentsFrame.origin.x = 0.0f;
    }
    
    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    } else {
        contentsFrame.origin.y = 0.0f;
    }
    
    self.containerView.frame = contentsFrame;
}

#pragma mark - 初始化默认值

- (instancetype)init {
    self = [super init];
    if (self) {
        _previewDimension = FLEXLookinPreviewDimension3D;
        _previewScale = 1.0;
        _rotation = CGPointMake(0.3, 0.3); // 默认旋转角度
        _translation = CGPointZero;
        _zInterspace = 20.0; // 3D层间距
    }
    return self;
}

@end