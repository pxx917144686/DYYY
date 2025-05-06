//
//  FLEXExplorerViewController.m
//  Flipboard
//
//  创建者：Ryan Olson，日期：4/4/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXExplorerViewController.h"
#import "FLEXExplorerToolbarItem.h"
#import "FLEXUtility.h"
#import "FLEXWindow.h"
#import "FLEXTabList.h"
#import "FLEXNavigationController.h"
#import "FLEXHierarchyViewController.h"
#import "FLEXGlobalsViewController.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXNetworkMITMViewController.h"
#import "FLEXTabsViewController.h"
#import "FLEXWindowManagerController.h"
#import "FLEXViewControllersViewController.h"
#import "NSUserDefaults+FLEX.h"

typedef NS_ENUM(NSUInteger, FLEXExplorerMode) {
    FLEXExplorerModeDefault,
    FLEXExplorerModeSelect,
    FLEXExplorerModeMove
};

@interface FLEXExplorerViewController () <FLEXHierarchyDelegate, UIAdaptivePresentationControllerDelegate>

/// 跟踪当前活动的工具/模式
@property (nonatomic) FLEXExplorerMode currentMode;

/// 用于在移动模式下拖动视图的手势识别器
@property (nonatomic) UIPanGestureRecognizer *movePanGR;

/// 用于显示所选视图附加详情的手势识别器
@property (nonatomic) UITapGestureRecognizer *detailsTapGR;

/// 仅在移动平移手势进行中有效。
@property (nonatomic) CGRect selectedViewFrameBeforeDragging;

/// 仅在工具栏拖动平移手势进行中有效。
@property (nonatomic) CGRect toolbarFrameBeforeDragging;

/// 仅在选定视图平移手势进行中有效。
@property (nonatomic) CGFloat selectedViewLastPanX;

/// 选择点处层级中所有可见视图的边框。
/// 键是带有相应视图（非保留）的 NSValue。
@property (nonatomic) NSDictionary<NSValue *, UIView *> *outlineViewsForVisibleViews;

/// 选择点处的实际视图，最深层的视图在最后。
@property (nonatomic) NSArray<UIView *> *viewsAtTapPoint;

/// 我们当前用覆盖层高亮显示并显示详情的视图。
@property (nonatomic) UIView *selectedView;

/// 一个彩色的透明覆盖层，用于指示视图已被选中。
@property (nonatomic) UIView *selectedViewOverlay;

/// 用于在 iOS 10+ 上驱动视图选择更改
@property (nonatomic, readonly) UISelectionFeedbackGenerator *selectionFBG API_AVAILABLE(ios(10.0));

/// self.view.window 作为 \c FLEXWindow
@property (nonatomic, readonly) FLEXWindow *window;

/// 我们正在进行 KVO 的所有视图。用于帮助我们正确清理。
@property (nonatomic) NSMutableSet<UIView *> *observedViews;

/// 用于保留目标应用的 UIMenuController 项目。
@property (nonatomic) NSArray<UIMenuItem *> *appMenuItems;

@end

@implementation FLEXExplorerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.observedViews = [NSMutableSet new];
    }
    return self;
}

- (void)dealloc {
    for (UIView *view in _observedViews) {
        [self stopObservingView:view];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 工具栏
    _explorerToolbar = [FLEXExplorerToolbar new];

    // 使工具栏初始位于视图顶部任何栏的下方。
    CGFloat toolbarOriginY = NSUserDefaults.standardUserDefaults.flex_toolbarTopMargin;

    CGRect safeArea = [self viewSafeArea];
    CGSize toolbarSize = [self.explorerToolbar sizeThatFits:CGSizeMake(
        CGRectGetWidth(self.view.bounds), CGRectGetHeight(safeArea)
    )];
    [self updateToolbarPositionWithUnconstrainedFrame:CGRectMake(
        CGRectGetMinX(safeArea), toolbarOriginY, toolbarSize.width, toolbarSize.height
    )];
    self.explorerToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                            UIViewAutoresizingFlexibleBottomMargin |
                                            UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.explorerToolbar];
    [self setupToolbarActions];
    [self setupToolbarGestures];
    
    // 视图选择
    UITapGestureRecognizer *selectionTapGR = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleSelectionTap:)
    ];
    [self.view addGestureRecognizer:selectionTapGR];
    
    // 视图移动
    self.movePanGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMovePan:)];
    self.movePanGR.enabled = self.currentMode == FLEXExplorerModeMove;
    [self.view addGestureRecognizer:self.movePanGR];
    
    // 反馈
    if (@available(iOS 10.0, *)) {
        _selectionFBG = [UISelectionFeedbackGenerator new];
    }
    
    // 观察键盘以便将自身移开
    [NSNotificationCenter.defaultCenter
        addObserver:self
        selector:@selector(keyboardShown:)
        name:UIKeyboardWillShowNotification
        object:nil
    ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateButtonStates];
}


#pragma mark - 旋转

- (UIViewController *)viewControllerForRotationAndOrientation {
    UIViewController *viewController = FLEXUtility.appKeyWindow.rootViewController;
    // 混淆选择器 _viewControllerForSupportedInterfaceOrientations
    NSString *viewControllerSelectorString = [@[
        @"_vie", @"wContro", @"llerFor", @"Supported", @"Interface", @"Orientations"
    ] componentsJoinedByString:@""];
    SEL viewControllerSelector = NSSelectorFromString(viewControllerSelectorString);
    if ([viewController respondsToSelector:viewControllerSelector]) {
        viewController = [viewController valueForKey:viewControllerSelectorString];
    }
    
    return viewController;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // 在我找到更好的解决方案之前，先注释掉这部分代码
//    if (self.window.isKeyWindow) {
//        [self.window resignKeyWindow];
//    }
    
    UIViewController *viewControllerToAsk = [self viewControllerForRotationAndOrientation];
    UIInterfaceOrientationMask supportedOrientations = FLEXUtility.infoPlistSupportedInterfaceOrientationsMask;
    // 我们通过名称检查它的类，因为对于在运行时定义两次的同一个类，使用 isKindOfClass 会失败；
    // 这里的目标是避免在我从 tweak dylib 中使用 FLEX 检查自身时递归调用 -supportedInterfaceOrientations
    if (viewControllerToAsk && ![NSStringFromClass([viewControllerToAsk class]) hasPrefix:@"FLEX"]) {
        supportedOrientations = [viewControllerToAsk supportedInterfaceOrientations];
    }
    
    // UIViewController 文档指出此方法不能返回零。
    // 如果我们无法获取支持的界面方向的有效值，
    // 则默认为全部支持。
    if (supportedOrientations == 0) {
        supportedOrientations = UIInterfaceOrientationMaskAll;
    }
    
    return supportedOrientations;
}

- (BOOL)shouldAutorotate {
    UIViewController *viewControllerToAsk = [self viewControllerForRotationAndOrientation];
    BOOL shouldAutorotate = YES;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        shouldAutorotate = [viewControllerToAsk shouldAutorotate];
    }
    return shouldAutorotate;
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        for (UIView *outlineView in self.outlineViewsForVisibleViews.allValues) {
            outlineView.hidden = YES;
        }
        self.selectedViewOverlay.hidden = YES;
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        for (UIView *view in self.viewsAtTapPoint) {
            NSValue *key = [NSValue valueWithNonretainedObject:view];
            UIView *outlineView = self.outlineViewsForVisibleViews[key];
            outlineView.frame = [self frameInLocalCoordinatesForView:view];
            if (self.currentMode == FLEXExplorerModeSelect) {
                outlineView.hidden = NO;
            }
        }

        if (self.selectedView) {
            self.selectedViewOverlay.frame = [self frameInLocalCoordinatesForView:self.selectedView];
            self.selectedViewOverlay.hidden = NO;
        }
    }];
}


#pragma mark - Setter 重写

- (void)setSelectedView:(UIView *)selectedView {
    if (![_selectedView isEqual:selectedView]) {
        if (![self.viewsAtTapPoint containsObject:_selectedView]) {
            [self stopObservingView:_selectedView];
        }
        
        _selectedView = selectedView;
        
        [self beginObservingView:selectedView];

        // 更新工具栏和选定覆盖层
        self.explorerToolbar.selectedViewDescription = [FLEXUtility
            descriptionForView:selectedView includingFrame:YES
        ];
        self.explorerToolbar.selectedViewOverlayColor = [FLEXUtility
            consistentRandomColorForObject:selectedView
        ];

        if (selectedView) {
            if (!self.selectedViewOverlay) {
                self.selectedViewOverlay = [UIView new];
                [self.view addSubview:self.selectedViewOverlay];
                self.selectedViewOverlay.layer.borderWidth = 1.0;
            }
            UIColor *outlineColor = [FLEXUtility consistentRandomColorForObject:selectedView];
            self.selectedViewOverlay.backgroundColor = [outlineColor colorWithAlphaComponent:0.2];
            self.selectedViewOverlay.layer.borderColor = outlineColor.CGColor;
            self.selectedViewOverlay.frame = [self.view convertRect:selectedView.bounds fromView:selectedView];
            
            // 确保选定覆盖层位于所有其他子视图的前面
            // 除了工具栏，它应该始终保持在顶部。
            [self.view bringSubviewToFront:self.selectedViewOverlay];
            [self.view bringSubviewToFront:self.explorerToolbar];
        } else {
            [self.selectedViewOverlay removeFromSuperview];
            self.selectedViewOverlay = nil;
        }
        
        // 一些按钮状态取决于我们是否有选定视图。
        [self updateButtonStates];
    }
}

- (void)setViewsAtTapPoint:(NSArray<UIView *> *)viewsAtTapPoint {
    if (![_viewsAtTapPoint isEqual:viewsAtTapPoint]) {
        for (UIView *view in _viewsAtTapPoint) {
            if (view != self.selectedView) {
                [self stopObservingView:view];
            }
        }
        
        _viewsAtTapPoint = viewsAtTapPoint;
        
        for (UIView *view in viewsAtTapPoint) {
            [self beginObservingView:view];
        }
    }
}

- (void)setCurrentMode:(FLEXExplorerMode)currentMode {
    if (_currentMode != currentMode) {
        _currentMode = currentMode;
        switch (currentMode) {
            case FLEXExplorerModeDefault:
                [self removeAndClearOutlineViews];
                self.viewsAtTapPoint = nil;
                self.selectedView = nil;
                break;
                
            case FLEXExplorerModeSelect:
                // 确保轮廓视图未隐藏，以防我们来自移动模式。
                for (NSValue *key in self.outlineViewsForVisibleViews) {
                    UIView *outlineView = self.outlineViewsForVisibleViews[key];
                    outlineView.hidden = NO;
                }
                break;
                
            case FLEXExplorerModeMove:
                // 隐藏所有轮廓视图以专注于选定视图，
                // 它是唯一会移动的视图。
                for (NSValue *key in self.outlineViewsForVisibleViews) {
                    UIView *outlineView = self.outlineViewsForVisibleViews[key];
                    outlineView.hidden = YES;
                }
                break;
        }
        self.movePanGR.enabled = currentMode == FLEXExplorerModeMove;
        [self updateButtonStates];
    }
}


#pragma mark - 视图跟踪

- (void)beginObservingView:(UIView *)view {
    // 如果我们已经在观察此视图或没有可观察的内容，则返回。
    if (!view || [self.observedViews containsObject:view]) {
        return;
    }
    
    for (NSString *keyPath in self.viewKeyPathsToTrack) {
        [view addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }
    
    [self.observedViews addObject:view];
}

- (void)stopObservingView:(UIView *)view {
    if (!view) {
        return;
    }
    
    for (NSString *keyPath in self.viewKeyPathsToTrack) {
        [view removeObserver:self forKeyPath:keyPath];
    }
    
    [self.observedViews removeObject:view];
}

- (NSArray<NSString *> *)viewKeyPathsToTrack {
    static NSArray<NSString *> *trackedViewKeyPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *frameKeyPath = NSStringFromSelector(@selector(frame));
        trackedViewKeyPaths = @[frameKeyPath];
    });
    return trackedViewKeyPaths;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary<NSString *, id> *)change
                       context:(void *)context {
    [self updateOverlayAndDescriptionForObjectIfNeeded:object];
}

- (void)updateOverlayAndDescriptionForObjectIfNeeded:(id)object {
    NSUInteger indexOfView = [self.viewsAtTapPoint indexOfObject:object];
    if (indexOfView != NSNotFound) {
        UIView *view = self.viewsAtTapPoint[indexOfView];
        NSValue *key = [NSValue valueWithNonretainedObject:view];
        UIView *outline = self.outlineViewsForVisibleViews[key];
        if (outline) {
            outline.frame = [self frameInLocalCoordinatesForView:view];
        }
    }
    if (object == self.selectedView) {
        // 更新选定视图描述，因为我们在此处显示框架值。
        self.explorerToolbar.selectedViewDescription = [FLEXUtility
            descriptionForView:self.selectedView includingFrame:YES
        ];
        CGRect selectedViewOutlineFrame = [self frameInLocalCoordinatesForView:self.selectedView];
        self.selectedViewOverlay.frame = selectedViewOutlineFrame;
    }
}

- (CGRect)frameInLocalCoordinatesForView:(UIView *)view {
    // 转换为窗口坐标，因为视图可能与我们的视图不在同一个窗口中
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    // 从窗口转换为我们视图的坐标空间
    return [self.view convertRect:frameInWindow fromView:nil];
}

- (void)keyboardShown:(NSNotification *)notif {
    CGRect keyboardFrame = [notif.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect toolbarFrame = self.explorerToolbar.frame;
    
    if (CGRectGetMinY(keyboardFrame) < CGRectGetMaxY(toolbarFrame)) {
        toolbarFrame.origin.y = keyboardFrame.origin.y - toolbarFrame.size.height;
        // 再减去一点，以忽略辅助输入视图
        toolbarFrame.origin.y -= 50;
        
        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self updateToolbarPositionWithUnconstrainedFrame:toolbarFrame];
        } completion:nil];
    }
}

#pragma mark - 工具栏按钮

- (void)setupToolbarActions {
    FLEXExplorerToolbar *toolbar = self.explorerToolbar;
    NSDictionary<NSString *, FLEXExplorerToolbarItem *> *actionsToItems = @{
        NSStringFromSelector(@selector(selectButtonTapped:)):        toolbar.selectItem,
        NSStringFromSelector(@selector(hierarchyButtonTapped:)):     toolbar.hierarchyItem,
        NSStringFromSelector(@selector(recentButtonTapped:)):        toolbar.recentItem,
        NSStringFromSelector(@selector(moveButtonTapped:)):          toolbar.moveItem,
        NSStringFromSelector(@selector(globalsButtonTapped:)):       toolbar.globalsItem,
        NSStringFromSelector(@selector(closeButtonTapped:)):         toolbar.closeItem,
    };
    
    [actionsToItems enumerateKeysAndObjectsUsingBlock:^(NSString *sel, FLEXExplorerToolbarItem *item, BOOL *stop) {
        [item addTarget:self action:NSSelectorFromString(sel) forControlEvents:UIControlEventTouchUpInside];
    }];
}

- (void)selectButtonTapped:(FLEXExplorerToolbarItem *)sender {
    [self toggleSelectTool];
}

- (void)hierarchyButtonTapped:(FLEXExplorerToolbarItem *)sender {
    [self toggleViewsTool];
}

- (UIWindow *)statusWindow {
    if (@available(iOS 16, *)) {
        return nil;
    } else {
        if (@available(iOS 13, *)) {
            return nil;
        } else {
            NSString *statusBarString = [NSString stringWithFormat:@"%@arWindow", @"_statusB"];
            return [UIApplication.sharedApplication valueForKey:statusBarString];
        }
    }
}

- (void)recentButtonTapped:(FLEXExplorerToolbarItem *)sender {
    NSAssert(FLEXTabList.sharedList.activeTab, @"必须有活动标签页");
    [self presentViewController:FLEXTabList.sharedList.activeTab animated:YES completion:nil];
}

- (void)moveButtonTapped:(FLEXExplorerToolbarItem *)sender {
    [self toggleMoveTool];
}

- (void)globalsButtonTapped:(FLEXExplorerToolbarItem *)sender {
    [self toggleMenuTool];
}

- (void)closeButtonTapped:(FLEXExplorerToolbarItem *)sender {
    self.currentMode = FLEXExplorerModeDefault;
    [self.delegate explorerViewControllerDidFinish:self];
}

- (void)updateButtonStates {
    FLEXExplorerToolbar *toolbar = self.explorerToolbar;
    
    toolbar.selectItem.selected = self.currentMode == FLEXExplorerModeSelect;
    
    // “移动”仅在选择了对象时启用。
    BOOL hasSelectedObject = self.selectedView != nil;
    toolbar.moveItem.enabled = hasSelectedObject;
    toolbar.moveItem.selected = self.currentMode == FLEXExplorerModeMove;
    
    // “最近”仅在我们有最后一个活动标签页时启用
    if (!self.presentedViewController) {
        toolbar.recentItem.enabled = FLEXTabList.sharedList.activeTab != nil;
    } else {
        toolbar.recentItem.enabled = NO;
    }
}


#pragma mark - 工具栏拖动

- (void)setupToolbarGestures {
    FLEXExplorerToolbar *toolbar = self.explorerToolbar;
    
    // 用于拖动的平移手势。
    [toolbar.dragHandle addGestureRecognizer:[[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarPanGesture:)
    ]];
    
    // 用于提示的点击手势。
    [toolbar.dragHandle addGestureRecognizer:[[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarHintTapGesture:)
    ]];
    
    // 用于显示附加详情的点击手势
    self.detailsTapGR = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarDetailsTapGesture:)
    ];
    [toolbar.selectedViewDescriptionContainer addGestureRecognizer:self.detailsTapGR];
    
    // 用于在某点选择更深/更高层视图的滑动手势
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleChangeViewAtPointGesture:)
    ];
    [toolbar.selectedViewDescriptionContainer addGestureRecognizer:panGesture];
    
    // 用于显示标签页管理器的长按手势
    [toolbar.globalsItem addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarShowTabsGesture:)
    ]];
    
    // 用于显示窗口管理器的长按手势
    [toolbar.selectItem addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarWindowManagerGesture:)
    ]];
    
    // 用于显示视图控制器的长按手势
    [toolbar.hierarchyItem addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarShowViewControllersGesture:)
    ]];
}

- (void)handleToolbarPanGesture:(UIPanGestureRecognizer *)panGR {
    switch (panGR.state) {
        case UIGestureRecognizerStateBegan:
            self.toolbarFrameBeforeDragging = self.explorerToolbar.frame;
            [self updateToolbarPositionWithDragGesture:panGR];
            break;
            
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStateEnded:
            [self updateToolbarPositionWithDragGesture:panGR];
            break;
            
        default:
            break;
    }
}

- (void)updateToolbarPositionWithDragGesture:(UIPanGestureRecognizer *)panGR {
    CGPoint translation = [panGR translationInView:self.view];
    CGRect newToolbarFrame = self.toolbarFrameBeforeDragging;
    newToolbarFrame.origin.y += translation.y;
    
    [self updateToolbarPositionWithUnconstrainedFrame:newToolbarFrame];
}

- (void)updateToolbarPositionWithUnconstrainedFrame:(CGRect)unconstrainedFrame {
    CGRect safeArea = [self viewSafeArea];
    // 我们只约束 Y 轴，因为我们希望工具栏
    // 自己处理 X 轴安全区域布局
    CGFloat minY = CGRectGetMinY(safeArea);
    CGFloat maxY = CGRectGetMaxY(safeArea) - unconstrainedFrame.size.height;
    if (unconstrainedFrame.origin.y < minY) {
        unconstrainedFrame.origin.y = minY;
    } else if (unconstrainedFrame.origin.y > maxY) {
        unconstrainedFrame.origin.y = maxY;
    }

    self.explorerToolbar.frame = unconstrainedFrame;
    NSUserDefaults.standardUserDefaults.flex_toolbarTopMargin = unconstrainedFrame.origin.y;
}

- (void)handleToolbarHintTapGesture:(UITapGestureRecognizer *)tapGR {
    // 使工具栏弹跳以指示它是可拖动的。
    // TODO: 使其更有弹性。
    if (tapGR.state == UIGestureRecognizerStateRecognized) {
        CGRect originalToolbarFrame = self.explorerToolbar.frame;
        const NSTimeInterval kHalfwayDuration = 0.2;
        const CGFloat kVerticalOffset = 30.0;
        [UIView animateWithDuration:kHalfwayDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGRect newToolbarFrame = self.explorerToolbar.frame;
            newToolbarFrame.origin.y += kVerticalOffset;
            self.explorerToolbar.frame = newToolbarFrame;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:kHalfwayDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                self.explorerToolbar.frame = originalToolbarFrame;
            } completion:nil];
        }];
    }
}

- (void)handleToolbarDetailsTapGesture:(UITapGestureRecognizer *)tapGR {
    if (tapGR.state == UIGestureRecognizerStateRecognized && self.selectedView) {
        UIViewController *topStackVC = [FLEXObjectExplorerFactory explorerViewControllerForObject:self.selectedView];
        [self presentViewController:
            [FLEXNavigationController withRootViewController:topStackVC]
        animated:YES completion:nil];
    }
}

- (void)handleToolbarShowTabsGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        // 备份 UIMenuController 项目，因为 dismissViewController: 将尝试替换它们
        self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
        
        // 不使用 FLEXNavigationController，因为标签页查看器本身不是标签页
        [super presentViewController:[[UINavigationController alloc]
            initWithRootViewController:[FLEXTabsViewController new]
        ] animated:YES completion:nil];
    }
}

- (void)handleToolbarWindowManagerGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        // 备份 UIMenuController 项目，因为 dismissViewController: 将尝试替换它们
        self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
        
        [super presentViewController:[FLEXNavigationController
            withRootViewController:[FLEXWindowManagerController new]
        ] animated:YES completion:nil];
    }
}

- (void)handleToolbarShowViewControllersGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan && self.viewsAtTapPoint.count) {
        // 备份 UIMenuController 项目，因为 dismissViewController: 将尝试替换它们
        self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
        
        UIViewController *list = [FLEXViewControllersViewController
            controllersForViews:self.viewsAtTapPoint
        ];
        [self presentViewController:
            [FLEXNavigationController withRootViewController:list
        ] animated:YES completion:nil];
    }
}


#pragma mark - 视图选择

- (void)handleSelectionTap:(UITapGestureRecognizer *)tapGR {
    // 仅当我们处于选择模式时
    if (self.currentMode == FLEXExplorerModeSelect && tapGR.state == UIGestureRecognizerStateRecognized) {
        // 请注意，[tapGR locationInView:nil] 在 iOS 8 中是有问题的，
        // 因此我们必须进行两步转换到窗口坐标。
        // 感谢 @lascorbe 找到这个问题：https://github.com/Flipboard/FLEX/pull/31
        CGPoint tapPointInView = [tapGR locationInView:self.view];
        CGPoint tapPointInWindow = [self.view convertPoint:tapPointInView toView:nil];
        [self updateOutlineViewsForSelectionPoint:tapPointInWindow];
    }
}

- (void)handleChangeViewAtPointGesture:(UIPanGestureRecognizer *)sender {
    NSInteger max = self.viewsAtTapPoint.count - 1;
    NSInteger currentIdx = [self.viewsAtTapPoint indexOfObject:self.selectedView];
    CGFloat locationX = [sender locationInView:self.view].x;
    
    // 跟踪平移手势：每当我们沿 X 轴移动 N 点时，
    // 触发一些触觉反馈并在层级中向上或向下移动。
    // 我们只有在达到阈值时才存储“最后”位置。
    // 我们只有在视图选择更改时才更改视图并触发反馈；
    // 也就是说，只要我们不超出或低于数组。
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            self.selectedViewLastPanX = locationX;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            static CGFloat kNextLevelThreshold = 20.f;
            CGFloat lastX = self.selectedViewLastPanX;
            NSInteger newSelection = currentIdx;
            
            // 向左，向层级下方移动
            if (locationX < lastX && (lastX - locationX) >= kNextLevelThreshold) {
                // 选择一个新的视图索引，最多到最大索引
                newSelection = MIN(max, currentIdx + 1);
                self.selectedViewLastPanX = locationX;
            }
            // 向右，向层级上方移动
            else if (lastX < locationX && (locationX - lastX) >= kNextLevelThreshold) {
                // 选择一个新的视图索引，最少到最小索引
                newSelection = MAX(0, currentIdx - 1);
                self.selectedViewLastPanX = locationX;
            }
            
            if (currentIdx != newSelection) {
                self.selectedView = self.viewsAtTapPoint[newSelection];
                [self actuateSelectionChangedFeedback];
            }
            
            break;
        }
            
        default: break;
    }
}

- (void)actuateSelectionChangedFeedback {
    if (@available(iOS 10.0, *)) {
        [self.selectionFBG selectionChanged];
    }
}

- (void)updateOutlineViewsForSelectionPoint:(CGPoint)selectionPointInWindow {
    [self removeAndClearOutlineViews];
    
    // 包括隐藏视图在“viewsAtTapPoint”数组中，以便我们可以在层级列表中显示它们。
    self.viewsAtTapPoint = [self viewsAtPoint:selectionPointInWindow skipHiddenViews:NO];
    
    // 对于轮廓视图和选定视图，仅使用可见视图。
    // 对隐藏视图进行轮廓化会增加混乱，并使选择行为令人困惑。
    NSArray<UIView *> *visibleViewsAtTapPoint = [self viewsAtPoint:selectionPointInWindow skipHiddenViews:YES];
    NSMutableDictionary<NSValue *, UIView *> *newOutlineViewsForVisibleViews = [NSMutableDictionary new];
    for (UIView *view in visibleViewsAtTapPoint) {
        UIView *outlineView = [self outlineViewForView:view];
        [self.view addSubview:outlineView];
        NSValue *key = [NSValue valueWithNonretainedObject:view];
        [newOutlineViewsForVisibleViews setObject:outlineView forKey:key];
    }
    self.outlineViewsForVisibleViews = newOutlineViewsForVisibleViews;
    self.selectedView = [self viewForSelectionAtPoint:selectionPointInWindow];
    
    // 确保探索工具栏不会落后于新添加的轮廓视图。
    [self.view bringSubviewToFront:self.explorerToolbar];
    
    [self updateButtonStates];
}

- (UIView *)outlineViewForView:(UIView *)view {
    CGRect outlineFrame = [self frameInLocalCoordinatesForView:view];
    UIView *outlineView = [[UIView alloc] initWithFrame:outlineFrame];
    outlineView.backgroundColor = UIColor.clearColor;
    outlineView.layer.borderColor = [FLEXUtility consistentRandomColorForObject:view].CGColor;
    outlineView.layer.borderWidth = 1.0;
    return outlineView;
}

- (void)removeAndClearOutlineViews {
    for (NSValue *key in self.outlineViewsForVisibleViews) {
        UIView *outlineView = self.outlineViewsForVisibleViews[key];
        [outlineView removeFromSuperview];
    }
    self.outlineViewsForVisibleViews = nil;
}

- (NSArray<UIView *> *)viewsAtPoint:(CGPoint)tapPointInWindow skipHiddenViews:(BOOL)skipHidden {
    NSMutableArray<UIView *> *views = [NSMutableArray new];
    for (UIWindow *window in FLEXUtility.allWindows) {
        // 不包括探索者自己的窗口或子视图。
        if (window != self.view.window && [window pointInside:tapPointInWindow withEvent:nil]) {
            [views addObject:window];
            [views addObjectsFromArray:[self
                recursiveSubviewsAtPoint:tapPointInWindow inView:window skipHiddenViews:skipHidden
            ]];
        }
    }
    return views;
}

- (UIView *)viewForSelectionAtPoint:(CGPoint)tapPointInWindow {
    // 使用 FLEXUtility 提供的方法获取 activeScene
    UIWindowScene *scene = FLEXUtility.activeScene;
    UIWindow *windowForSelection = scene.windows.firstObject;
    
    // 遍历所有窗口查找合适的选择目标
    for (UIWindow *window in FLEXUtility.allWindows.reverseObjectEnumerator) {
        if (window != self.view.window) {
            if ([window hitTest:tapPointInWindow withEvent:nil]) {
                windowForSelection = window;
                break;
            }
        }
    }
    
    return [self recursiveSubviewsAtPoint:tapPointInWindow 
                                 inView:windowForSelection 
                        skipHiddenViews:YES].lastObject;
}

- (NSArray<UIView *> *)recursiveSubviewsAtPoint:(CGPoint)pointInView
                                         inView:(UIView *)view
                                skipHiddenViews:(BOOL)skipHidden {
    NSMutableArray<UIView *> *subviewsAtPoint = [NSMutableArray new];
    for (UIView *subview in view.subviews) {
        BOOL isHidden = subview.hidden || subview.alpha < 0.01;
        if (skipHidden && isHidden) {
            continue;
        }
        
        BOOL subviewContainsPoint = CGRectContainsPoint(subview.frame, pointInView);
        if (subviewContainsPoint) {
            [subviewsAtPoint addObject:subview];
        }
        
        // 如果此视图不裁剪到其边界，我们需要检查其子视图，即使它
        // 不包含选择点。它们可能是可见的并包含选择点。
        if (subviewContainsPoint || !subview.clipsToBounds) {
            CGPoint pointInSubview = [view convertPoint:pointInView toView:subview];
            [subviewsAtPoint addObjectsFromArray:[self
                recursiveSubviewsAtPoint:pointInSubview inView:subview skipHiddenViews:skipHidden
            ]];
        }
    }
    return subviewsAtPoint;
}


#pragma mark - 移动选定视图

- (void)handleMovePan:(UIPanGestureRecognizer *)movePanGR {
    switch (movePanGR.state) {
        case UIGestureRecognizerStateBegan:
            self.selectedViewFrameBeforeDragging = self.selectedView.frame;
            [self updateSelectedViewPositionWithDragGesture:movePanGR];
            break;
            
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStateEnded:
            [self updateSelectedViewPositionWithDragGesture:movePanGR];
            break;
            
        default:
            break;
    }
}

- (void)updateSelectedViewPositionWithDragGesture:(UIPanGestureRecognizer *)movePanGR {
    CGPoint translation = [movePanGR translationInView:self.selectedView.superview];
    CGRect newSelectedViewFrame = self.selectedViewFrameBeforeDragging;
    newSelectedViewFrame.origin.x = FLEXFloor(newSelectedViewFrame.origin.x + translation.x);
    newSelectedViewFrame.origin.y = FLEXFloor(newSelectedViewFrame.origin.y + translation.y);
    self.selectedView.frame = newSelectedViewFrame;
}


#pragma mark - 安全区域处理

- (CGRect)viewSafeArea {
    CGRect safeArea = self.view.bounds;
    if (@available(iOS 11.0, *)) {
        safeArea = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    }

    return safeArea;
}

- (void)viewSafeAreaInsetsDidChange {
    if (@available(iOS 11.0, *)) {
        [super viewSafeAreaInsetsDidChange];

        CGRect safeArea = [self viewSafeArea];
        CGSize toolbarSize = [self.explorerToolbar sizeThatFits:CGSizeMake(
            CGRectGetWidth(self.view.bounds), CGRectGetHeight(safeArea)
        )];
        [self updateToolbarPositionWithUnconstrainedFrame:CGRectMake(
            CGRectGetMinX(self.explorerToolbar.frame),
            CGRectGetMinY(self.explorerToolbar.frame),
            toolbarSize.width,
            toolbarSize.height)
        ];
    }
}


#pragma mark - 触摸处理

- (BOOL)shouldReceiveTouchAtWindowPoint:(CGPoint)pointInWindowCoordinates {
    CGPoint pointInLocalCoordinates = [self.view convertPoint:pointInWindowCoordinates fromView:nil];
    
    // 如果我们有一个模态显示，它是否在模态中？
    if (self.presentedViewController) {
        UIView *presentedView = self.presentedViewController.view;
        CGPoint pipvc = [presentedView convertPoint:pointInLocalCoordinates fromView:self.view];
        UIView *hit = [presentedView hitTest:pipvc withEvent:nil];
        if (hit != nil) {
            return YES;
        }
    }
    
    // 始终如果我们处于选择模式
    if (self.currentMode == FLEXExplorerModeSelect) {
        return YES;
    }
    
    // 始终在移动模式中也是
    if (self.currentMode == FLEXExplorerModeMove) {
        return YES;
    }
    
    // 始终如果它在工具栏上
    if (CGRectContainsPoint(self.explorerToolbar.frame, pointInLocalCoordinates)) {
        return YES;
    }
    
    return NO;
}


#pragma mark - FLEXHierarchy 代理

- (void)viewHierarchyDidDismiss:(UIView *)selectedView {
    // 请注意，我们需要等到视图控制器被解雇后才能计算框架
    // 轮廓视图，否则坐标转换不会给出正确的结果。
    [self toggleViewsToolWithCompletion:^{
        // 如果选定视图在点击点数组之外（从“完整层级”中选择），
        // 则清除点击点数组并移除所有轮廓视图。
        if (![self.viewsAtTapPoint containsObject:selectedView]) {
            self.viewsAtTapPoint = nil;
            [self removeAndClearOutlineViews];
        }
        
        // 如果我们现在有一个选定视图并且我们之前没有一个，请进入“选择”模式。
        if (self.currentMode == FLEXExplorerModeDefault && selectedView) {
            self.currentMode = FLEXExplorerModeSelect;
        }
        
        // 选定视图设置器还将适当地更新选定视图覆盖层。
        self.selectedView = selectedView;
    }];
}


#pragma mark - 模态显示和窗口管理

- (void)presentViewController:(UIViewController *)toPresent 
                   animated:(BOOL)animated
                 completion:(void (^)(void))completion {
    // 移除 iOS 13+ 判断,直接使用旧版本代码
    [self.view.window makeKeyWindow];
    [self statusWindow].windowLevel = self.view.window.windowLevel + 1.0;
    
    // 备份并替换 UIMenuController 项目
    // 编辑：不再替换项目，但仍然备份它们
    // 以防我们将来再次开始替换它们
    self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
    
    [self updateButtonStates];
    
    // 显示视图控制器
    [super presentViewController:toPresent animated:animated completion:^{
        [self updateButtonStates];
        
        if (completion) completion();
    }];
}

- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {    
    UIWindow *appWindow = self.window.previousKeyWindow;
    [appWindow makeKeyWindow];
    [appWindow.rootViewController setNeedsStatusBarAppearanceUpdate];
    
    // 恢复之前的 UIMenuController 项目
    // 备份并替换 UIMenuController 项目
    UIMenuController.sharedMenuController.menuItems = self.appMenuItems;
    [UIMenuController.sharedMenuController update];
    self.appMenuItems = nil;
    
    // 恢复状态栏窗口的正常窗口级别。
    // 我们希望它在显示模态时高于 FLEX，
    // 但在探索时低于 FLEX。
    [self statusWindow].windowLevel = UIWindowLevelStatusBar;
    
    [self updateButtonStates];
    
    [super dismissViewControllerAnimated:animated completion:^{
        [self updateButtonStates];
        
        if (completion) completion();
    }];
}

- (BOOL)wantsWindowToBecomeKey {
    return self.window.previousKeyWindow != nil;
}

- (void)toggleToolWithViewControllerProvider:(UINavigationController *(^)(void))future
                                  completion:(void (^)(void))completion {
    if (self.presentedViewController) {
        // 我们不希望显示未来；这是
        // 用于切换相同工具的便利方法
        [self dismissViewControllerAnimated:YES completion:completion];
    } else if (future) {
        [self presentViewController:future() animated:YES completion:completion];
    }
}

- (void)presentTool:(UINavigationController *(^)(void))future
         completion:(void (^)(void))completion {
    if (self.presentedViewController) {
        // 如果工具已经显示，先解雇它
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:future() animated:YES completion:completion];
        }];
    } else if (future) {
        [self presentViewController:future() animated:YES completion:completion];
    }
}

- (FLEXWindow *)window {
    return (id)self.view.window;
}


#pragma mark - 键盘快捷键助手

- (void)toggleSelectTool {
    if (self.currentMode == FLEXExplorerModeSelect) {
        self.currentMode = FLEXExplorerModeDefault;
    } else {
        self.currentMode = FLEXExplorerModeSelect;
    }
}

- (void)toggleMoveTool {
    if (self.currentMode == FLEXExplorerModeMove) {
        self.currentMode = FLEXExplorerModeSelect;
    } else if (self.currentMode == FLEXExplorerModeSelect && self.selectedView) {
        self.currentMode = FLEXExplorerModeMove;
    }
}

- (void)toggleViewsTool {
    [self toggleViewsToolWithCompletion:nil];
}

- (void)toggleViewsToolWithCompletion:(void(^)(void))completion {
    [self toggleToolWithViewControllerProvider:^UINavigationController *{
        if (self.selectedView) {
            return [FLEXHierarchyViewController
                delegate:self
                viewsAtTap:self.viewsAtTapPoint
                selectedView:self.selectedView
            ];
        } else {
            return [FLEXHierarchyViewController delegate:self];
        }
    } completion:completion];
}

- (void)toggleMenuTool {
    [self toggleToolWithViewControllerProvider:^UINavigationController *{
        return [FLEXNavigationController withRootViewController:[FLEXGlobalsViewController new]];
    } completion:nil];
}

- (BOOL)handleDownArrowKeyPressed {
    if (self.currentMode == FLEXExplorerModeMove) {
        CGRect frame = self.selectedView.frame;
        frame.origin.y += 1.0 / UIScreen.mainScreen.scale;
        self.selectedView.frame = frame;
    } else if (self.currentMode == FLEXExplorerModeSelect && self.viewsAtTapPoint.count > 0) {
        NSInteger selectedViewIndex = [self.viewsAtTapPoint indexOfObject:self.selectedView];
        if (selectedViewIndex > 0) {
            self.selectedView = [self.viewsAtTapPoint objectAtIndex:selectedViewIndex - 1];
        }
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)handleUpArrowKeyPressed {
    if (self.currentMode == FLEXExplorerModeMove) {
        CGRect frame = self.selectedView.frame;
        frame.origin.y -= 1.0 / UIScreen.mainScreen.scale;
        self.selectedView.frame = frame;
    } else if (self.currentMode == FLEXExplorerModeSelect && self.viewsAtTapPoint.count > 0) {
        NSInteger selectedViewIndex = [self.viewsAtTapPoint indexOfObject:self.selectedView];
        if (selectedViewIndex < self.viewsAtTapPoint.count - 1) {
            self.selectedView = [self.viewsAtTapPoint objectAtIndex:selectedViewIndex + 1];
        }
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)handleRightArrowKeyPressed {
    if (self.currentMode == FLEXExplorerModeMove) {
        CGRect frame = self.selectedView.frame;
        frame.origin.x += 1.0 / UIScreen.mainScreen.scale;
        self.selectedView.frame = frame;
        return YES;
    }
    
    return NO;
}

- (BOOL)handleLeftArrowKeyPressed {
    if (self.currentMode == FLEXExplorerModeMove) {
        CGRect frame = self.selectedView.frame;
        frame.origin.x -= 1.0 / UIScreen.mainScreen.scale;
        self.selectedView.frame = frame;
        return YES;
    }
    
    return NO;
}

@end
