#import "FLEXRevealLikeInspector.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

@interface FLEXRevealLikeInspector ()
@property (nonatomic, strong) UIWindow *inspectorWindow;
@property (nonatomic, strong) UIView *hierarchy3DContainer;
@property (nonatomic, strong) UIView *constraintsOverlay;
@property (nonatomic, strong) UIView *measurementsOverlay;
@property (nonatomic, strong) NSMutableArray<UIView *> *viewLayers;
@property (nonatomic, strong) NSMutableDictionary *originalTransforms;
@property (nonatomic, assign) BOOL liveEditingEnabled;
@property (nonatomic, strong) UIView *mutableSelectedView;

@property (nonatomic, assign) BOOL isLiveEditingEnabled;
@property (nonatomic, strong) UIToolbar *editingToolbar;
@property (nonatomic, weak) UIView *editingView;
@end

@implementation FLEXRevealLikeInspector

+ (instancetype)sharedInstance {
    static FLEXRevealLikeInspector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _viewLayers = [NSMutableArray new];
        _originalTransforms = [NSMutableDictionary new];
        _liveEditingEnabled = NO;
        [self setupInspectorWindow];
    }
    return self;
}

- (UIView *)selectedView {
    return self.mutableSelectedView;
}

#pragma mark - 窗口设置

- (void)setupInspectorWindow {
    self.inspectorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.inspectorWindow.windowLevel = UIWindowLevelAlert + 200;
    self.inspectorWindow.backgroundColor = [UIColor clearColor];
    self.inspectorWindow.hidden = YES;
    
    // 添加手势识别
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handleTap:)];
    [self.inspectorWindow addGestureRecognizer:tapGesture];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] 
                                             initWithTarget:self 
                                             action:@selector(handlePinch:)];
    [self.inspectorWindow addGestureRecognizer:pinchGesture];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handlePan:)];
    [self.inspectorWindow addGestureRecognizer:panGesture];
}

#pragma mark - 3D视图层次结构

- (void)show3DViewHierarchy {
    if (self.isInspecting) return;
    
    self.isInspecting = YES;
    
    // 创建3D容器
    self.hierarchy3DContainer = [[UIView alloc] initWithFrame:self.inspectorWindow.bounds];
    self.hierarchy3DContainer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    [self.inspectorWindow addSubview:self.hierarchy3DContainer];
    
    // 显示窗口
    self.inspectorWindow.hidden = NO;
    
    // 构建3D层次结构
    [self build3DViewHierarchy];
    
    NSLog(@"3D视图层次结构已显示");
}

- (void)hide3DViewHierarchy {
    if (!self.isInspecting) return;
    
    self.isInspecting = NO;
    
    // 清理视图
    [self.hierarchy3DContainer removeFromSuperview];
    self.hierarchy3DContainer = nil;
    
    // 清理选择
    self.mutableSelectedView = nil;
    
    // 隐藏窗口
    self.inspectorWindow.hidden = YES;
    
    // 清理层次
    [self.viewLayers removeAllObjects];
    
    NSLog(@"3D视图层次结构已隐藏");
}

- (void)build3DViewHierarchy {
    UIWindow *keyWindow = [self getKeyWindow];
    if (!keyWindow) return;
    
    [self.viewLayers removeAllObjects];
    [self buildLayersForView:keyWindow.rootViewController.view depth:0];
    
    [self apply3DTransforms];
}

- (UIWindow *)getKeyWindow {
    // ✅ iOS兼容性处理
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIWindowScene *windowScene in connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        return window;
                    }
                }
            }
        }
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

- (void)buildLayersForView:(UIView *)view depth:(NSInteger)depth {
    // ✅ 修复逻辑运算符优先级警告
    if (!view || ([view isKindOfClass:[UIWindow class]] && view != [self getKeyWindow])) {
        return;
    }
    
    // 创建3D表示
    UIView *layer3D = [self create3DLayerForView:view depth:depth];
    [self.hierarchy3DContainer addSubview:layer3D];
    [self.viewLayers addObject:layer3D];
    
    // 关联原始视图
    objc_setAssociatedObject(layer3D, @"originalView", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        [self buildLayersForView:subview depth:depth + 1];
    }
}

- (UIView *)create3DLayerForView:(UIView *)view depth:(NSInteger)depth {
    UIView *layer = [[UIView alloc] init];
    
    // 设置frame（缩放以适应3D显示）
    CGFloat scale = 0.3;
    CGRect scaledFrame = CGRectMake(view.frame.origin.x * scale,
                                   view.frame.origin.y * scale,
                                   view.frame.size.width * scale,
                                   view.frame.size.height * scale);
    layer.frame = scaledFrame;
    
    // 设置外观
    layer.backgroundColor = view.backgroundColor ?: [[UIColor systemBlueColor] colorWithAlphaComponent:0.3];
    layer.layer.borderWidth = 1;
    layer.layer.borderColor = [UIColor systemBlueColor].CGColor;
    
    // 添加标签
    UILabel *label = [[UILabel alloc] init];
    label.text = NSStringFromClass([view class]);
    label.font = [UIFont systemFontOfSize:8];
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    label.center = CGPointMake(layer.frame.size.width / 2, layer.frame.size.height / 2);
    [layer addSubview:label];
    
    return layer;
}

- (void)apply3DTransforms {
    for (NSInteger i = 0; i < self.viewLayers.count; i++) {
        UIView *layer = self.viewLayers[i];
        
        CATransform3D transform = CATransform3DIdentity;
        transform.m34 = -1.0 / 1000.0; // 透视
        
        // 应用旋转
        transform = CATransform3DRotate(transform, M_PI_4 / 2, 1, 0, 0);
        transform = CATransform3DRotate(transform, M_PI_4 / 4, 0, 1, 0);
        
        // Z轴偏移
        CGFloat zOffset = i * 20;
        transform = CATransform3DTranslate(transform, 0, 0, zOffset);
        
        layer.layer.transform = transform;
    }
}

#pragma mark - 手势处理

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (!self.isInspecting) return;
    
    CGPoint location = [gesture locationInView:self.hierarchy3DContainer];
    UIView *tappedView = [self.hierarchy3DContainer hitTest:location withEvent:nil];
    
    if (tappedView && tappedView != self.hierarchy3DContainer) {
        UIView *originalView = objc_getAssociatedObject(tappedView, @"originalView");
        if (originalView) {
            [self selectView:originalView];
        }
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    if (!self.isInspecting) return;
    
    static CGFloat initialScale = 1.0;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        initialScale = self.hierarchy3DContainer.transform.a;
    }
    
    CGFloat scale = initialScale * gesture.scale;
    scale = MAX(0.5, MIN(3.0, scale)); // 限制缩放范围
    
    self.hierarchy3DContainer.transform = CGAffineTransformMakeScale(scale, scale);
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!self.isInspecting) return;
    
    CGPoint translation = [gesture translationInView:self.inspectorWindow];
    
    // 应用平移
    self.hierarchy3DContainer.center = CGPointMake(
        self.hierarchy3DContainer.center.x + translation.x,
        self.hierarchy3DContainer.center.y + translation.y
    );
    
    [gesture setTranslation:CGPointZero inView:self.inspectorWindow];
}

- (void)selectView:(UIView *)view {
    self.mutableSelectedView = view;
    
    // 高亮显示
    [self highlightSelectedView:view];
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(revealInspector:didSelectView:)]) {
        [self.delegate revealInspector:self didSelectView:view];
    }
    
    NSLog(@"已选择视图: %@", NSStringFromClass([view class]));
}

- (void)highlightSelectedView:(UIView *)view {
    // 清除之前的高亮
    for (UIView *layer in self.viewLayers) {
        layer.layer.borderWidth = 1;
        layer.layer.borderColor = [UIColor systemBlueColor].CGColor;
    }
    
    // 高亮当前选择
    for (UIView *layer in self.viewLayers) {
        UIView *originalView = objc_getAssociatedObject(layer, @"originalView");
        if (originalView == view) {
            layer.layer.borderWidth = 3;
            layer.layer.borderColor = [UIColor systemRedColor].CGColor;
            break;
        }
    }
}

#pragma mark - 视图约束检查

- (void)showViewConstraints:(UIView *)view {
    if (!view) return;
    
    [self hideViewConstraints]; // 清除之前的约束显示
    
    // 创建约束覆盖层
    self.constraintsOverlay = [[UIView alloc] initWithFrame:[self getKeyWindow].bounds];
    self.constraintsOverlay.backgroundColor = [UIColor clearColor];
    self.constraintsOverlay.userInteractionEnabled = NO;
    
    // 绘制约束线
    [self drawConstraintsForView:view];
    
    // 添加到窗口
    [[self getKeyWindow] addSubview:self.constraintsOverlay];
    
    NSLog(@"约束显示已启用");
}

- (void)hideViewConstraints {
    if (self.constraintsOverlay) {
        [self.constraintsOverlay removeFromSuperview];
        self.constraintsOverlay = nil;
        NSLog(@"约束显示已隐藏");
    }
}

- (void)drawConstraintsForView:(UIView *)view {
    if (!view.superview) return;
    
    NSArray *constraints = view.superview.constraints;
    
    for (NSLayoutConstraint *constraint in constraints) {
        if (constraint.firstItem == view || constraint.secondItem == view) {
            [self drawConstraintLine:constraint];
            [self addConstraintLabel:constraint];
        }
    }
}

- (void)drawConstraintLine:(NSLayoutConstraint *)constraint {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor systemOrangeColor];
    
    // 简化的约束线绘制
    CGRect firstFrame = [(UIView *)constraint.firstItem frame];
    
    // ✅ 修复：只在需要时声明和使用 secondFrame
    CGRect lineFrame;
    
    // 根据约束类型绘制线条
    switch (constraint.firstAttribute) {
        case NSLayoutAttributeTop:
        case NSLayoutAttributeBottom: {
            lineFrame = CGRectMake(firstFrame.origin.x, firstFrame.origin.y, firstFrame.size.width, 2);
            
            // 如果有第二个视图，计算相对位置
            if (constraint.secondItem) {
                CGRect secondFrame = [(UIView *)constraint.secondItem frame];
                CGFloat midY = (firstFrame.origin.y + secondFrame.origin.y) / 2;
                lineFrame = CGRectMake(firstFrame.origin.x, midY, firstFrame.size.width, 2);
            }
            break;
        }
        case NSLayoutAttributeLeft:
        case NSLayoutAttributeRight: {
            lineFrame = CGRectMake(firstFrame.origin.x, firstFrame.origin.y, 2, firstFrame.size.height);
            
            // 如果有第二个视图，计算相对位置
            if (constraint.secondItem) {
                CGRect secondFrame = [(UIView *)constraint.secondItem frame];
                CGFloat midX = (firstFrame.origin.x + secondFrame.origin.x) / 2;
                lineFrame = CGRectMake(midX, firstFrame.origin.y, 2, firstFrame.size.height);
            }
            break;
        }
        case NSLayoutAttributeWidth:
        case NSLayoutAttributeHeight: {
            // 尺寸约束用虚线表示
            lineFrame = CGRectMake(firstFrame.origin.x, firstFrame.origin.y, firstFrame.size.width, firstFrame.size.height);
            line.alpha = 0.5;
            line.layer.borderWidth = 1;
            line.layer.borderColor = [UIColor systemOrangeColor].CGColor;
            line.backgroundColor = [UIColor clearColor];
            break;
        }
        default:
            lineFrame = CGRectMake(firstFrame.origin.x, firstFrame.origin.y, 2, 2);
            break;
    }
    
    line.frame = lineFrame;
    [self.constraintsOverlay addSubview:line];
}

- (void)addConstraintLabel:(NSLayoutConstraint *)constraint {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:10];
    label.textColor = [UIColor systemOrangeColor];
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    
    // 简化的约束描述
    NSString *description = [NSString stringWithFormat:@"%@ %@ %.1f",
                           [self stringFromLayoutAttribute:constraint.firstAttribute],
                           [self stringFromLayoutRelation:constraint.relation],
                           constraint.constant];
    
    label.text = description;
    [label sizeToFit];
    
    // 定位标签
    CGRect firstFrame = [(UIView *)constraint.firstItem frame];
    label.center = CGPointMake(CGRectGetMidX(firstFrame), CGRectGetMidY(firstFrame));
    
    [self.constraintsOverlay addSubview:label];
}

- (NSString *)stringFromLayoutAttribute:(NSLayoutAttribute)attribute {
    switch (attribute) {
        case NSLayoutAttributeLeft: return @"L";
        case NSLayoutAttributeRight: return @"R";
        case NSLayoutAttributeTop: return @"T";
        case NSLayoutAttributeBottom: return @"B";
        case NSLayoutAttributeWidth: return @"W";
        case NSLayoutAttributeHeight: return @"H";
        case NSLayoutAttributeCenterX: return @"CX";
        case NSLayoutAttributeCenterY: return @"CY";
        default: return @"?";
    }
}

- (NSString *)stringFromLayoutRelation:(NSLayoutRelation)relation {
    switch (relation) {
        case NSLayoutRelationEqual: return @"=";
        case NSLayoutRelationLessThanOrEqual: return @"≤";
        case NSLayoutRelationGreaterThanOrEqual: return @"≥";
        default: return @"=";
    }
}

#pragma mark - 视图测量

- (void)showViewMeasurements:(UIView *)view {
    [self hideViewMeasurements]; // 清除之前的测量
    
    if (!view) return;
    
    // 创建测量覆盖层
    self.measurementsOverlay = [[UIView alloc] initWithFrame:[self getKeyWindow].bounds];  // ✅ 使用正确的属性名
    self.measurementsOverlay.backgroundColor = [UIColor clearColor];
    self.measurementsOverlay.userInteractionEnabled = NO;
    
    // 添加尺寸标注
    [self addDimensionLabelsForView:view];
    
    // 添加边距标注  
    [self addMarginLabelsForView:view];
    
    // 添加到窗口
    [[self getKeyWindow] addSubview:self.measurementsOverlay];
}

- (void)hideViewMeasurements {
    if (self.measurementsOverlay) {
        [self.measurementsOverlay removeFromSuperview];
        self.measurementsOverlay = nil;
        NSLog(@"测量显示已隐藏");
    }
}

- (void)addDimensionLabelsForView:(UIView *)view {
    CGRect frame = [view.superview convertRect:view.frame toView:nil];
    
    // 宽度标注
    UILabel *widthLabel = [self createMeasurementLabel];
    widthLabel.text = [NSString stringWithFormat:@"%.1f", frame.size.width];
    widthLabel.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMaxY(frame) + 15);
    [self.measurementsOverlay addSubview:widthLabel];
    
    // 高度标注
    UILabel *heightLabel = [self createMeasurementLabel];
    heightLabel.text = [NSString stringWithFormat:@"%.1f", frame.size.height];
    heightLabel.center = CGPointMake(CGRectGetMaxX(frame) + 15, CGRectGetMidY(frame));
    heightLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    [self.measurementsOverlay addSubview:heightLabel];
}

- (void)addMarginLabelsForView:(UIView *)view {
    if (!view.superview) return;
    
    CGRect viewFrame = [view.superview convertRect:view.frame toView:nil];
    CGRect superFrame = [view.superview convertRect:view.superview.bounds toView:nil];
    
    // 上边距
    if (viewFrame.origin.y > superFrame.origin.y) {
        UILabel *topLabel = [self createMeasurementLabel];
        topLabel.text = [NSString stringWithFormat:@"%.1f", viewFrame.origin.y - superFrame.origin.y];
        topLabel.center = CGPointMake(CGRectGetMidX(viewFrame), (superFrame.origin.y + viewFrame.origin.y) / 2);
        [self.measurementsOverlay addSubview:topLabel];
    }
    
    // 左边距
    if (viewFrame.origin.x > superFrame.origin.x) {
        UILabel *leftLabel = [self createMeasurementLabel];
        leftLabel.text = [NSString stringWithFormat:@"%.1f", viewFrame.origin.x - superFrame.origin.x];
        leftLabel.center = CGPointMake((superFrame.origin.x + viewFrame.origin.x) / 2, CGRectGetMidY(viewFrame));
        [self.measurementsOverlay addSubview:leftLabel];
    }
}

- (UILabel *)createMeasurementLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = [UIColor systemRedColor];
    label.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.cornerRadius = 4;
    label.layer.masksToBounds = YES;
    return label;
}

- (void)addCrossHairsForView:(UIView *)view {
    CGRect frame = [view.superview convertRect:view.frame toView:nil];
    
    // 水平十字线
    UIView *horizontalLine = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetMidY(frame), [UIScreen mainScreen].bounds.size.width, 1)];
    horizontalLine.backgroundColor = [UIColor systemRedColor];
    [self.measurementsOverlay addSubview:horizontalLine];
    
    // 垂直十字线
    UIView *verticalLine = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMidX(frame), 0, 1, [UIScreen mainScreen].bounds.size.height)];
    verticalLine.backgroundColor = [UIColor systemRedColor];
    [self.measurementsOverlay addSubview:verticalLine];
}

#pragma mark - 实时编辑功能

- (void)enableLiveEditing {
    self.liveEditingEnabled = YES;
    
    // 为选中的视图添加编辑手势
    if (self.selectedView) {
        [self addEditingGesturesToView:self.selectedView];
    }
}

- (void)disableLiveEditing {
    self.liveEditingEnabled = NO;
    
    // 移除编辑手势
    if (self.selectedView) {
        [self removeEditingGesturesFromView:self.selectedView];
    }
}

- (void)addEditingGesturesToView:(UIView *)view {
    // 添加拖拽手势用于移动
    UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] 
                                          initWithTarget:self 
                                          action:@selector(handleMoveGesture:)];
    moveGesture.minimumNumberOfTouches = 1;
    moveGesture.maximumNumberOfTouches = 1;
    [view addGestureRecognizer:moveGesture];
    
    // 添加捏合手势用于缩放
    UIPinchGestureRecognizer *scaleGesture = [[UIPinchGestureRecognizer alloc] 
                                             initWithTarget:self 
                                             action:@selector(handleScaleGesture:)];
    [view addGestureRecognizer:scaleGesture];
    
    // 添加长按手势显示编辑菜单
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc]
                                                     initWithTarget:self
                                                     action:@selector(handleLongPressGesture:)];
    [view addGestureRecognizer:longPressGesture];
}

- (void)removeEditingGesturesFromView:(UIView *)view {
    NSArray *gestures = view.gestureRecognizers.copy;
    for (UIGestureRecognizer *gesture in gestures) {
        if (gesture.view == view && 
            ([gesture isKindOfClass:[UIPanGestureRecognizer class]] ||
             [gesture isKindOfClass:[UIPinchGestureRecognizer class]] ||
             [gesture isKindOfClass:[UILongPressGestureRecognizer class]])) {
            [view removeGestureRecognizer:gesture];
        }
    }
}

- (void)handleMoveGesture:(UIPanGestureRecognizer *)gesture {
    if (!self.liveEditingEnabled) return;
    
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:view.superview];
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
        [gesture setTranslation:CGPointZero inView:view.superview];
        
        // 刷新3D视图
        [self refresh3DViewHierarchy];
    }
}

- (void)handleScaleGesture:(UIPinchGestureRecognizer *)gesture {
    if (!self.liveEditingEnabled) return;
    
    UIView *view = gesture.view;
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        view.transform = CGAffineTransformScale(view.transform, gesture.scale, gesture.scale);
        gesture.scale = 1.0;
        
        // 刷新3D视图
        [self refresh3DViewHierarchy];
    }
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (!self.liveEditingEnabled || gesture.state != UIGestureRecognizerStateBegan) return;
    
    self.editingView = gesture.view;
    [self showLiveEditingPanelForView:gesture.view];
}

- (void)selectViewForEditing:(UIView *)view {
    self.editingView = view;
    
    // 高亮显示正在编辑的视图
    [self highlightEditingView:view];
    
    // 显示编辑提示
    [self showEditingHint];
}

- (void)editBackgroundColor {
    if (!self.editingView) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择背景颜色" 
                                                                   message:nil 
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 预设颜色选项
    NSArray *colors = @[
        @{@"name": @"红色", @"color": [UIColor redColor]},
        @{@"name": @"绿色", @"color": [UIColor greenColor]},
        @{@"name": @"蓝色", @"color": [UIColor blueColor]},
        @{@"name": @"黄色", @"color": [UIColor yellowColor]},
        @{@"name": @"透明", @"color": [UIColor clearColor]},
    ];
    
    for (NSDictionary *colorInfo in colors) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:colorInfo[@"name"] 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction *action) {
            [self modifyView:self.editingView properties:@{@"backgroundColor": colorInfo[@"color"]}];
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)modifyView:(UIView *)view properties:(NSDictionary *)properties {
    if (!view || !properties) return;
    
    for (NSString *property in properties.allKeys) {
        id value = properties[property];
        
        if ([property isEqualToString:@"backgroundColor"] && [value isKindOfClass:[UIColor class]]) {
            view.backgroundColor = value;
        } else if ([property isEqualToString:@"alpha"] && [value isKindOfClass:[NSNumber class]]) {
            view.alpha = [value floatValue];
        } else if ([property isEqualToString:@"hidden"] && [value isKindOfClass:[NSNumber class]]) {
            view.hidden = [value boolValue];
        }
        // 可以添加更多属性支持
    }
    
    // 刷新3D显示
    [self refresh3DViewHierarchy];
    
    NSLog(@"视图属性已修改: %@", properties);
}

- (void)showLiveEditingPanelForView:(UIView *)view {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑视图"
                                                                   message:[NSString stringWithFormat:@"编辑 %@", NSStringFromClass([view class])]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *backgroundAction = [UIAlertAction actionWithTitle:@"背景颜色" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self editBackgroundColor];
    }];
    
    UIAlertAction *frameAction = [UIAlertAction actionWithTitle:@"Frame" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self editFrame];
    }];
    
    UIAlertAction *alphaAction = [UIAlertAction actionWithTitle:@"透明度" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self editAlpha];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:backgroundAction];
    [alert addAction:frameAction];
    [alert addAction:alphaAction];
    [alert addAction:cancelAction];
    
    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)editFrame {
    // 实现Frame编辑
    NSLog(@"编辑Frame功能");
}

- (void)editAlpha {
    // 实现透明度编辑
    NSLog(@"编辑透明度功能");
}

#pragma mark - 辅助方法

- (void)highlightEditingView:(UIView *)view {
    // 实现编辑视图高亮
    view.layer.borderWidth = 2;
    view.layer.borderColor = [UIColor systemRedColor].CGColor;
}

- (void)showEditingHint {
    // 实现编辑提示
    NSLog(@"显示编辑提示");
}

- (void)refresh3DViewHierarchy {
    if (self.isInspecting) {
        [self build3DViewHierarchy];
    }
}

- (UIViewController *)topViewController {
    UIViewController *topController = [self getKeyWindow].rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

#pragma mark - 视图捕获和截图

- (UIImage *)captureViewHierarchy3D {
    if (!self.hierarchy3DContainer) return nil;
    
    UIGraphicsBeginImageContextWithOptions(self.hierarchy3DContainer.bounds.size, NO, 0);
    [self.hierarchy3DContainer.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)exportViewHierarchyDescription {
    UIWindow *keyWindow = [self getKeyWindow];
    if (!keyWindow) return;
    
    NSString *description = [self descriptionForView:keyWindow.rootViewController.view depth:0];
    
    // 保存到剪贴板
    [UIPasteboard generalPasteboard].string = description;
    
    NSLog(@"视图层次结构已导出到剪贴板");
}

- (NSString *)descriptionForView:(UIView *)view depth:(NSInteger)depth {
    NSMutableString *description = [NSMutableString string];
    
    // 添加缩进
    for (NSInteger i = 0; i < depth; i++) {
        [description appendString:@"  "];
    }
    
    // 添加视图信息
    [description appendFormat:@"%@ (%@)\n", 
     NSStringFromClass([view class]), 
     NSStringFromCGRect(view.frame)];
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        [description appendString:[self descriptionForView:subview depth:depth + 1]];
    }
    
    return description;
}

@end