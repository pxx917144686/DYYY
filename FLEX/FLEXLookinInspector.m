#import "FLEXLookinInspector.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

@implementation FLEXLookinViewNode

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> %@ frame:%@", 
            NSStringFromClass([self class]), self, self.className, NSStringFromCGRect(self.frame)];
}

@end

@interface FLEXLookinInspector ()
@property (nonatomic, strong) UIWindow *inspectorWindow;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) NSMutableArray<FLEXLookinViewNode *> *mutableViewHierarchy;
@property (nonatomic, weak) UIView *mutableSelectedView;
@property (nonatomic, assign) BOOL mutableIsInspecting;
@property (nonatomic, strong) NSMutableDictionary *savedSnapshots;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;

// 3D视图相关属性
@property (nonatomic, strong) UIWindow *hierarchyWindow;
@property (nonatomic, assign) BOOL liveEditingEnabled;
@end

@implementation FLEXLookinInspector

+ (instancetype)sharedInstance {
    static FLEXLookinInspector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableViewHierarchy = [NSMutableArray new];
        _savedSnapshots = [NSMutableDictionary new];
        _viewMode = FLEXLookinViewModeHierarchy;
        [self setupGestures];
    }
    return self;
}

#pragma mark - Properties

- (NSArray<FLEXLookinViewNode *> *)viewHierarchy {
    return [self.mutableViewHierarchy copy];
}

- (UIView *)selectedView {
    return self.mutableSelectedView;
}

- (BOOL)isInspecting {
    return self.mutableIsInspecting;
}

#pragma mark - 检查控制

- (void)startInspecting {
    if (self.mutableIsInspecting) return;
    
    self.mutableIsInspecting = YES;
    
    // 创建检查器窗口
    [self createInspectorWindow];
    
    // 刷新层次结构
    [self refreshViewHierarchy];
    
    // 启用手势
    [self enableGestures];
    
    NSLog(@"Lookin检查器已启动");
}

- (void)stopInspecting {
    if (!self.mutableIsInspecting) return;
    
    self.mutableIsInspecting = NO;
    
    // 隐藏检查器窗口
    [self hideInspectorWindow];
    
    // 禁用手势
    [self disableGestures];
    
    // 清除选择
    [self clearSelection];
    
    NSLog(@"Lookin检查器已停止");
}

- (void)createInspectorWindow {
    if (self.inspectorWindow) return;
    
    self.inspectorWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.inspectorWindow.windowLevel = UIWindowLevelAlert + 200;
    self.inspectorWindow.backgroundColor = [UIColor clearColor];
    self.inspectorWindow.hidden = NO;
    
    // 创建覆盖层
    self.overlayView = [[UIView alloc] initWithFrame:self.inspectorWindow.bounds];
    self.overlayView.backgroundColor = [UIColor clearColor];
    [self.inspectorWindow addSubview:self.overlayView];
}

- (void)hideInspectorWindow {
    self.inspectorWindow.hidden = YES;
    self.inspectorWindow = nil;
    self.overlayView = nil;
}

#pragma mark - 手势设置

- (void)setupGestures {
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
}

- (void)enableGestures {
    [self.overlayView addGestureRecognizer:self.tapGesture];
    [self.overlayView addGestureRecognizer:self.panGesture];
}

- (void)disableGestures {
    [self.overlayView removeGestureRecognizer:self.tapGesture];
    [self.overlayView removeGestureRecognizer:self.panGesture];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.overlayView];
    UIView *hitView = [self findViewAtPoint:location];
    
    if (hitView) {
        [self selectView:hitView];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    // TODO: 实现拖拽选择功能
    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint location = [gesture locationInView:self.overlayView];
        UIView *hitView = [self findViewAtPoint:location];
        
        if (hitView && hitView != self.selectedView) {
            [self selectView:hitView];
        }
    }
}

#pragma mark - 视图选择

- (void)selectView:(UIView *)view {
    if (self.mutableSelectedView == view) return;
    
    // 清除之前的选择
    [self clearSelectionHighlight];
    
    self.mutableSelectedView = view;
    
    // 高亮选中的视图
    [self highlightSelectedView];
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(lookinInspector:didSelectView:)]) {
        [self.delegate lookinInspector:self didSelectView:view];
    }
}

- (void)clearSelection {
    [self clearSelectionHighlight];
    self.mutableSelectedView = nil;
}

- (void)highlightSelectedView {
    if (!self.selectedView) return;
    
    UIView *keyWindow = [UIApplication sharedApplication].keyWindow;
    CGRect frame = [self.selectedView.superview convertRect:self.selectedView.frame toView:keyWindow];
    
    // 创建高亮边框
    UIView *highlightView = [[UIView alloc] initWithFrame:frame];
    highlightView.layer.borderWidth = 2;
    highlightView.layer.borderColor = [UIColor systemBlueColor].CGColor;
    highlightView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.2];
    highlightView.tag = 99999; // 特殊标签用于识别
    
    [self.overlayView addSubview:highlightView];
}

- (void)clearSelectionHighlight {
    // 移除所有高亮视图
    NSArray *subviews = [self.overlayView.subviews copy];
    for (UIView *view in subviews) {
        if (view.tag == 99999) {
            [view removeFromSuperview];
        }
    }
}

- (UIView *)findViewAtPoint:(CGPoint)point {
    UIView *keyWindow = [UIApplication sharedApplication].keyWindow;
    return [self findViewAtPoint:point inView:keyWindow];
}

- (UIView *)findViewAtPoint:(CGPoint)point inView:(UIView *)view {
    if (view.hidden || view.alpha < 0.01) return nil;
    if (view == self.inspectorWindow || view == self.overlayView) return nil;
    
    CGPoint localPoint = [view convertPoint:point fromView:[UIApplication sharedApplication].keyWindow];
    
    if (![view pointInside:localPoint withEvent:nil]) return nil;
    
    // 检查子视图（倒序，最前面的优先）
    for (UIView *subview in view.subviews.reverseObjectEnumerator) {
        UIView *hitView = [self findViewAtPoint:point inView:subview];
        if (hitView) return hitView;
    }
    
    return view;
}

#pragma mark - 层次分析

- (void)refreshViewHierarchy {
    [self.mutableViewHierarchy removeAllObjects];
    
    UIView *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow) {
        FLEXLookinViewNode *rootNode = [self createNodeForView:keyWindow depth:0];
        [self.mutableViewHierarchy addObject:rootNode];
        [self buildHierarchyForNode:rootNode];
    }
    
    // 通知代理
    if ([self.delegate respondsToSelector:@selector(lookinInspector:didUpdateHierarchy:)]) {
        [self.delegate lookinInspector:self didUpdateHierarchy:self.viewHierarchy];
    }
}

- (FLEXLookinViewNode *)createNodeForView:(UIView *)view depth:(NSInteger)depth {
    FLEXLookinViewNode *node = [[FLEXLookinViewNode alloc] init];
    node.view = view;
    node.frame = view.frame;
    node.bounds = view.bounds;
    node.transform = view.layer.transform;
    node.alpha = view.alpha;
    node.hidden = view.hidden;
    node.backgroundColor = view.backgroundColor;
    node.className = NSStringFromClass([view class]);
    node.depth = depth;
    node.children = [NSMutableArray new];
    
    return node;
}

- (void)buildHierarchyForNode:(FLEXLookinViewNode *)node {
    NSMutableArray *children = [NSMutableArray new];
    
    for (UIView *subview in node.view.subviews) {
        // 跳过检查器相关的视图
        if (subview == self.inspectorWindow || 
            [subview isDescendantOfView:self.inspectorWindow]) {
            continue;
        }
        
        FLEXLookinViewNode *childNode = [self createNodeForView:subview depth:node.depth + 1];
        childNode.parent = node;
        [children addObject:childNode];
        
        // 递归构建子层次
        [self buildHierarchyForNode:childNode];
    }
    
    node.children = [children copy];
}

- (FLEXLookinViewNode *)nodeForView:(UIView *)view {
    return [self findNodeForView:view inNodes:self.viewHierarchy];
}

- (FLEXLookinViewNode *)findNodeForView:(UIView *)view inNodes:(NSArray<FLEXLookinViewNode *> *)nodes {
    for (FLEXLookinViewNode *node in nodes) {
        if (node.view == view) {
            return node;
        }
        
        FLEXLookinViewNode *foundNode = [self findNodeForView:view inNodes:node.children];
        if (foundNode) {
            return foundNode;
        }
    }
    return nil;
}

- (NSArray<FLEXLookinViewNode *> *)flattenedHierarchy {
    NSMutableArray *flattened = [NSMutableArray new];
    [self flattenNodes:self.viewHierarchy intoArray:flattened];
    return [flattened copy];
}

- (void)flattenNodes:(NSArray<FLEXLookinViewNode *> *)nodes intoArray:(NSMutableArray *)array {
    for (FLEXLookinViewNode *node in nodes) {
        [array addObject:node];
        [self flattenNodes:node.children intoArray:array];
    }
}

#pragma mark - 快照功能

- (UIImage *)captureViewSnapshot:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return snapshot;
}

- (void)saveHierarchySnapshot:(NSString *)name {
    NSMutableDictionary *snapshot = [NSMutableDictionary new];
    snapshot[@"name"] = name;
    snapshot[@"timestamp"] = [NSDate date];
    snapshot[@"hierarchy"] = [self serializeHierarchy:self.viewHierarchy];
    
    self.savedSnapshots[name] = snapshot;
    
    NSLog(@"已保存快照: %@", name);
}

- (NSArray *)loadSavedSnapshots {
    return [self.savedSnapshots.allValues sortedArrayUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]
    ]];
}

- (NSArray *)serializeHierarchy:(NSArray<FLEXLookinViewNode *> *)nodes {
    NSMutableArray *serialized = [NSMutableArray new];
    
    for (FLEXLookinViewNode *node in nodes) {
        NSMutableDictionary *nodeDict = [NSMutableDictionary new];
        nodeDict[@"className"] = node.className;
        nodeDict[@"frame"] = NSStringFromCGRect(node.frame);
        nodeDict[@"bounds"] = NSStringFromCGRect(node.bounds);
        nodeDict[@"alpha"] = @(node.alpha);
        nodeDict[@"hidden"] = @(node.hidden);
        nodeDict[@"depth"] = @(node.depth);
        
        if (node.backgroundColor) {
            nodeDict[@"backgroundColor"] = [self colorToHexString:node.backgroundColor];
        }
        
        if (node.children.count > 0) {
            nodeDict[@"children"] = [self serializeHierarchy:node.children];
        }
        
        [serialized addObject:nodeDict];
    }
    
    return [serialized copy];
}

#pragma mark - 对比功能

- (void)compareWithSnapshot:(NSString *)snapshotName {
    NSDictionary *snapshot = self.savedSnapshots[snapshotName];
    if (!snapshot) {
        NSLog(@"快照不存在: %@", snapshotName);
        return;
    }
    
    // 刷新当前层次结构
    [self refreshViewHierarchy];
    
    // 对比差异
    NSArray *changes = [self findChangedViewsBetweenSnapshot:snapshotName];
    
    // 高亮变化的视图
    [self highlightChangedViews:changes];
    
    NSLog(@"发现 %lu 个变化", (unsigned long)changes.count);
}

- (NSArray *)findChangedViewsBetweenSnapshot:(NSString *)snapshotName {
    NSDictionary *snapshot = self.savedSnapshots[snapshotName];
    if (!snapshot) return @[];
    
    NSArray *savedHierarchy = snapshot[@"hierarchy"];
    NSArray *currentHierarchy = [self serializeHierarchy:self.viewHierarchy];
    
    return [self compareHierarchy:currentHierarchy withSaved:savedHierarchy];
}

- (NSArray *)compareHierarchy:(NSArray *)current withSaved:(NSArray *)saved {
    NSMutableArray *changes = [NSMutableArray new];
    
    // 简单的对比实现 - 可以进一步优化
    if (current.count != saved.count) {
        [changes addObject:@{@"type": @"count_changed", @"current": @(current.count), @"saved": @(saved.count)}];
    }
    
    // TODO: 实现更详细的对比逻辑
    
    return [changes copy];
}

- (void)highlightChangedViews:(NSArray *)changes {
    // TODO: 实现变化视图的高亮显示
}

#pragma mark - 辅助方法

- (NSString *)colorToHexString:(UIColor *)color {
    if (!color) return @"#000000";
    
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    return [NSString stringWithFormat:@"#%02X%02X%02X", 
            (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}

#pragma mark - 3D视图层次显示

- (void)show3DViewHierarchy {
    if (!self.isInspecting) return;
    
    // 创建3D层次视图窗口
    if (!self.hierarchyWindow) {
        self.hierarchyWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.hierarchyWindow.windowLevel = UIWindowLevelAlert - 10;
        self.hierarchyWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        
        // 添加手势控制
        [self setup3DGestures];
    }
    
    self.hierarchyWindow.hidden = NO;
    [self render3DHierarchy];
}

- (void)hide3DViewHierarchy {
    self.hierarchyWindow.hidden = YES;
}

- (void)setup3DGestures {
    // 旋转手势
    UIPanGestureRecognizer *rotationGesture = [[UIPanGestureRecognizer alloc] 
                                              initWithTarget:self 
                                              action:@selector(handleRotationGesture:)];
    [self.hierarchyWindow addGestureRecognizer:rotationGesture];
    
    // 缩放手势
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] 
                                             initWithTarget:self 
                                             action:@selector(handlePinchGesture:)];
    [self.hierarchyWindow addGestureRecognizer:pinchGesture];
    
    // 点击选择手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handle3DTapGesture:)];
    [self.hierarchyWindow addGestureRecognizer:tapGesture];
}

- (void)render3DHierarchy {
    // 清除之前的3D视图
    [self.hierarchyWindow.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // 为每个视图创建3D表示
    for (FLEXLookinViewNode *node in self.viewHierarchy) {
        [self create3DRepresentationForNode:node];
    }
}

- (UIView *)create3DRepresentationForNode:(FLEXLookinViewNode *)node {
    if (!node.view || node.view.hidden || node.view.alpha < 0.01) return nil;
    
    // 创建3D视图容器
    UIView *container3D = [[UIView alloc] init];
    container3D.backgroundColor = [UIColor clearColor];
    
    // 创建视图快照
    UIView *snapshot = [self createSnapshotOfView:node.view];
    [container3D addSubview:snapshot];
    
    // 应用3D变换
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / 500.0; // 透视效果
    
    // 根据层次深度应用Z轴偏移
    CGFloat zOffset = node.depth * 20.0;
    transform = CATransform3DTranslate(transform, 0, 0, zOffset);
    
    container3D.layer.transform = transform;
    container3D.frame = node.frame;
    
    // 添加到3D窗口
    [self.hierarchyWindow addSubview:container3D];
    
    // 处理子视图
    for (FLEXLookinViewNode *childNode in node.children) {
        [self create3DRepresentationForNode:childNode];
    }
    
    return container3D;
}

- (UIView *)createSnapshotOfView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageView *snapshotView = [[UIImageView alloc] initWithImage:snapshotImage];
    snapshotView.frame = view.bounds;
    snapshotView.contentMode = UIViewContentModeScaleAspectFit;
    
    // 添加边框以便于识别
    snapshotView.layer.borderWidth = 1;
    snapshotView.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.5].CGColor;
    
    return snapshotView;
}

#pragma mark - 3D手势处理

- (void)handleRotationGesture:(UIPanGestureRecognizer *)gesture {
    static CGPoint lastTranslation;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        lastTranslation = CGPointZero;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:self.hierarchyWindow];
        CGPoint delta = CGPointMake(translation.x - lastTranslation.x, translation.y - lastTranslation.y);
        
        // 应用旋转到所有3D视图
        for (UIView *view in self.hierarchyWindow.subviews) {
            CATransform3D currentTransform = view.layer.transform;
            CATransform3D rotation = CATransform3DRotate(CATransform3DIdentity, 
                                                       delta.y * 0.01, 1, 0, 0);
            rotation = CATransform3DRotate(rotation, delta.x * 0.01, 0, 1, 0);
            view.layer.transform = CATransform3DConcat(currentTransform, rotation);
        }
        
        lastTranslation = translation;
    }
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)gesture {
    static CGFloat lastScale = 1.0;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        lastScale = 1.0;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat deltaScale = gesture.scale / lastScale;
        
        // 应用缩放到所有3D视图
        for (UIView *view in self.hierarchyWindow.subviews) {
            CATransform3D currentTransform = view.layer.transform;
            CATransform3D scale = CATransform3DScale(CATransform3DIdentity, deltaScale, deltaScale, deltaScale);
            view.layer.transform = CATransform3DConcat(currentTransform, scale);
        }
        
        lastScale = gesture.scale;
    }
}

- (void)handle3DTapGesture:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.hierarchyWindow];
    
    // 找到点击的3D视图
    UIView *hitView = [self.hierarchyWindow hitTest:location withEvent:nil];
    if (hitView && hitView != self.hierarchyWindow) {
        // 找到对应的原始视图
        UIView *originalView = [self findOriginalViewFor3DView:hitView];
        if (originalView) {
            [self selectView:originalView];
            
            // 高亮选中的3D视图
            [self highlight3DView:hitView];
        }
    }
}

- (UIView *)findOriginalViewFor3DView:(UIView *)view3D {
    // 这里需要建立3D视图和原始视图的映射关系
    // 简化实现，通过frame匹配
    for (FLEXLookinViewNode *node in [self flattenHierarchy:self.viewHierarchy]) {
        if (CGRectEqualToRect(node.frame, view3D.frame)) {
            return node.view;
        }
    }
    return nil;
}

- (void)highlight3DView:(UIView *)view3D {
    // 清除之前的高亮
    [self clearAll3DHighlights];
    
    // 添加高亮效果
    view3D.layer.borderWidth = 3;
    view3D.layer.borderColor = [UIColor systemRedColor].CGColor;
    view3D.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.3];
}

- (void)clearAll3DHighlights {
    for (UIView *view in self.hierarchyWindow.subviews) {
        view.layer.borderWidth = 1;
        view.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.5].CGColor;
        view.backgroundColor = [UIColor clearColor];
    }
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
    UIPinchGestureRecognizer *resizeGesture = [[UIPinchGestureRecognizer alloc] 
                                              initWithTarget:self 
                                              action:@selector(handleResizeGesture:)];
    [view addGestureRecognizer:resizeGesture];
}

- (void)removeEditingGesturesFromView:(UIView *)view {
    NSArray *gestures = [view.gestureRecognizers copy];
    for (UIGestureRecognizer *gesture in gestures) {
        if ([gesture isKindOfClass:[UIPanGestureRecognizer class]] ||
            [gesture isKindOfClass:[UIPinchGestureRecognizer class]]) {
            [view removeGestureRecognizer:gesture];
        }
    }
}

- (void)handleMoveGesture:(UIPanGestureRecognizer *)gesture {
    if (!self.liveEditingEnabled) return;
    
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:view.superview];
    
    CGRect newFrame = view.frame;
    newFrame.origin.x += translation.x;
    newFrame.origin.y += translation.y;
    
    view.frame = newFrame;
    [gesture setTranslation:CGPointZero inView:view.superview];
    
    // 更新3D视图
    [self render3DHierarchy];
}

- (void)handleResizeGesture:(UIPinchGestureRecognizer *)gesture {
    if (!self.liveEditingEnabled) return;
    
    UIView *view = gesture.view;
    CGFloat scale = gesture.scale;
    
    CGRect newFrame = view.frame;
    newFrame.size.width *= scale;
    newFrame.size.height *= scale;
    
    view.frame = newFrame;
    gesture.scale = 1.0;
    
    // 更新3D视图
    [self render3DHierarchy];
}

#pragma mark - 辅助方法

- (NSArray<FLEXLookinViewNode *> *)flattenHierarchy:(NSArray<FLEXLookinViewNode *> *)hierarchy {
    NSMutableArray *flattened = [NSMutableArray new];
    
    for (FLEXLookinViewNode *node in hierarchy) {
        [flattened addObject:node];
        if (node.children.count > 0) {
            [flattened addObjectsFromArray:[self flattenHierarchy:node.children]];
        }
    }
    
    return flattened;
}

@end