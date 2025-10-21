//
//  FLEXExplorerViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 4/4/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
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

/// 追踪当前活动的工具/模式
@property (nonatomic) FLEXExplorerMode currentMode;

/// 在移动模式下拖动视图的手势识别器
@property (nonatomic) UIPanGestureRecognizer *movePanGR;

/// 显示所选视图其他详细信息的手势识别器
@property (nonatomic) UITapGestureRecognizer *detailsTapGR;

/// 仅在移动手势进行时有效
@property (nonatomic) CGRect selectedViewFrameBeforeDragging;

/// 仅在工具栏拖动手势进行时有效
@property (nonatomic) CGRect toolbarFrameBeforeDragging;

/// 仅在所选视图的拖动手势进行时有效
@property (nonatomic) CGFloat selectedViewLastPanX;

/// 选择点处层次结构中所有可见视图的边框
/// 键是包含相应视图（非持久）的NSValues
@property (nonatomic) NSDictionary<NSValue *, UIView *> *outlineViewsForVisibleViews;

/// 选择点处的实际视图，最深层的视图在最后
@property (nonatomic) NSArray<UIView *> *viewsAtTapPoint;

/// 我们当前用叠加层突出显示并显示其详细信息的视图
@property (nonatomic) UIView *selectedView;

/// 一个有色透明叠加层，表示视图已被选中
@property (nonatomic) UIView *selectedViewOverlay;

/// 用于在iOS 10+上执行视图选择更改
@property (nonatomic, readonly) UISelectionFeedbackGenerator *selectionFBG API_AVAILABLE(ios(10.0));

/// self.view.window 作为 \c FLEXWindow
@property (nonatomic, readonly) FLEXWindow *window;

/// 我们正在KVO观察的所有视图。帮助我们正确清理
@property (nonatomic) NSMutableSet<UIView *> *observedViews;

/// 用于保存目标应用的UIMenuController项目
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

    // 将工具栏放置在视图顶部的任何栏下方。
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
    
    // 观察键盘以将自身移开
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


#pragma mark - Rotation

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
    // 注释掉此代码，直到找到更好的解决方案
//    if (self.window.isKeyWindow) {
//        [self.window resignKeyWindow];
//    }
    
    UIViewController *viewControllerToAsk = [self viewControllerForRotationAndOrientation];
    UIInterfaceOrientationMask supportedOrientations = FLEXUtility.infoPlistSupportedInterfaceOrientationsMask;
    // 我们通过名称检查其类，因为使用 isKindOfClass 将在运行时定义两次的同一类失败；
    // 这里的目标是避免在我从 tweak dylib 中使用自己检查 FLEX 时递归调用 -supportedInterfaceOrientations
    if (viewControllerToAsk && ![NSStringFromClass([viewControllerToAsk class]) hasPrefix:@"FLEX"]) {
        supportedOrientations = [viewControllerToAsk supportedInterfaceOrientations];
    }
    
    // UIViewController 文档指出此方法不得返回零。
    // 如果我们无法获得支持的接口方向的有效值，则默认为全部支持。
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


#pragma mark - Setter Overrides

- (void)setSelectedView:(UIView *)selectedView {
    if (![_selectedView isEqual:selectedView]) {
        if (![self.viewsAtTapPoint containsObject:_selectedView]) {
            [self stopObservingView:_selectedView];
        }
        
        _selectedView = selectedView;
        
        [self beginObservingView:selectedView];

        // 更新工具栏和选中叠加层
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
            
            // 确保选中叠加层位于所有其他子视图的前面
            // 除了工具栏，它应该始终保持在顶部。
            [self.view bringSubviewToFront:self.selectedViewOverlay];
            [self.view bringSubviewToFront:self.explorerToolbar];
        } else {
            [self.selectedViewOverlay removeFromSuperview];
            self.selectedViewOverlay = nil;
        }
        
        // 一些按钮状态取决于我们是否有选中的视图。
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
                // 隐藏所有轮廓视图以专注于选中的视图，
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


#pragma mark - View Tracking

- (void)beginObservingView:(UIView *)view {
    // 如果我们已经在观察此视图或没有要观察的内容，则退出。
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
        // 更新选中视图描述，因为我们在那里显示框架值。
        self.explorerToolbar.selectedViewDescription = [FLEXUtility
            descriptionForView:self.selectedView includingFrame:YES
        ];
        CGRect selectedViewOutlineFrame = [self frameInLocalCoordinatesForView:self.selectedView];
        self.selectedViewOverlay.frame = selectedViewOutlineFrame;
    }
}

- (CGRect)frameInLocalCoordinatesForView:(UIView *)view {
    // 转换为窗口坐标，因为视图可能位于与我们的视图不同的窗口中
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    // 从窗口转换为我们的视图的坐标空间
    return [self.view convertRect:frameInWindow fromView:nil];
}

- (void)keyboardShown:(NSNotification *)notif {
    CGRect keyboardFrame = [notif.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect toolbarFrame = self.explorerToolbar.frame;
    
    if (CGRectGetMinY(keyboardFrame) < CGRectGetMaxY(toolbarFrame)) {
        toolbarFrame.origin.y = keyboardFrame.origin.y - toolbarFrame.size.height;
        // 再减一点，以忽略附件输入视图
        toolbarFrame.origin.y -= 50;
        
        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self updateToolbarPositionWithUnconstrainedFrame:toolbarFrame];
        } completion:nil];
    }
}

#pragma mark - Toolbar Buttons

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
    if (!@available(iOS 16, *)) {
        NSString *statusBarString = [NSString stringWithFormat:@"%@arWindow", @"_statusB"];
        return [UIApplication.sharedApplication valueForKey:statusBarString];
    }
    
    return nil;
}

- (void)recentButtonTapped:(FLEXExplorerToolbarItem *)sender {
    NSAssert(FLEXTabList.sharedList.activeTab, @"必须有活动标签");
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
    
    // 仅当选择了对象时才启用移动功能
    BOOL hasSelectedObject = self.selectedView != nil;
    toolbar.moveItem.enabled = hasSelectedObject;
    toolbar.moveItem.selected = self.currentMode == FLEXExplorerModeMove;
    
    // 仅当我们有上次活动标签时才启用最近按钮
    if (!self.presentedViewController) {
        toolbar.recentItem.enabled = FLEXTabList.sharedList.activeTab != nil;
    } else {
        toolbar.recentItem.enabled = NO;
    }
}


#pragma mark - Toolbar Dragging

- (void)setupToolbarGestures {
    FLEXExplorerToolbar *toolbar = self.explorerToolbar;
    
    // 拖动的平移手势。
    [toolbar.dragHandle addGestureRecognizer:[[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarPanGesture:)
    ]];
    
    // 提示的点击手势。
    [toolbar.dragHandle addGestureRecognizer:[[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarHintTapGesture:)
    ]];
    
    // 显示其他详细信息的点击手势
    self.detailsTapGR = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarDetailsTapGesture:)
    ];
    [toolbar.selectedViewDescriptionContainer addGestureRecognizer:self.detailsTapGR];
    
    // 选择点处选择更深/更高视图的滑动手势
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleChangeViewAtPointGesture:)
    ];
    [toolbar.selectedViewDescriptionContainer addGestureRecognizer:panGesture];
    
    // 长按手势以显示标签管理器
    [toolbar.globalsItem addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarShowTabsGesture:)
    ]];
    
    // 长按手势以显示窗口管理器
    [toolbar.selectItem addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleToolbarWindowManagerGesture:)
    ]];
    
    // 长按手势以显示点击处的视图控制器
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
    // 我们只约束Y轴，因为我们希望工具栏
    // 自己处理X轴安全区域布局
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
    // 弹跳工具栏以表明它是可拖动的
    // TODO: 使其弹性更强
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
        // 备份UIMenuController项目，因为dismissViewController:将尝试替换它们
        self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
        
        // 不使用FLEXNavigationController，因为标签查看器本身不是标签
        [super presentViewController:[[UINavigationController alloc]
            initWithRootViewController:[FLEXTabsViewController new]
        ] animated:YES completion:nil];
    }
}

- (void)handleToolbarWindowManagerGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        // 备份UIMenuController项目，因为dismissViewController:将尝试替换它们
        self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
        
        [super presentViewController:[FLEXNavigationController
            withRootViewController:[FLEXWindowManagerController new]
        ] animated:YES completion:nil];
    }
}

- (void)handleToolbarShowViewControllersGesture:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan && self.viewsAtTapPoint.count) {
        // 备份UIMenuController项目，因为dismissViewController:将尝试替换它们
        self.appMenuItems = UIMenuController.sharedMenuController.menuItems;
        
        UIViewController *list = [FLEXViewControllersViewController
            controllersForViews:self.viewsAtTapPoint
        ];
        [self presentViewController:
            [FLEXNavigationController withRootViewController:list
        ] animated:YES completion:nil];
    }
}


#pragma mark - View Selection

- (void)handleSelectionTap:(UITapGestureRecognizer *)tapGR {
    // 仅当我们处于选择模式时
    if (self.currentMode == FLEXExplorerModeSelect && tapGR.state == UIGestureRecognizerStateRecognized) {
        // 请注意，[tapGR locationInView:nil] 在 iOS 8 中已损坏，
        // 因此我们必须进行两步转换到窗口坐标。
        // 感谢 @lascorbe 找到这个：https://github.com/Flipboard/FLEX/pull/31
        CGPoint tapPointInView = [tapGR locationInView:self.view];
        CGPoint tapPointInWindow = [self.view convertPoint:tapPointInView toView:nil];
        [self updateOutlineViewsForSelectionPoint:tapPointInWindow];
    }
}

- (void)handleChangeViewAtPointGesture:(UIPanGestureRecognizer *)sender {
    NSInteger max = self.viewsAtTapPoint.count - 1;
    NSInteger currentIdx = [self.viewsAtTapPoint indexOfObject:self.selectedView];
    CGFloat locationX = [sender locationInView:self.view].x;
    
    // 跟踪平移手势：每当我们沿着X轴移动N点时，
    // 触发一些触觉反馈并沿层次结构向上或向下移动。
    // 只有当我们达到阈值时，我们才会存储“最后”位置。
    // 只有当视图选择发生变化时，我们才会更改视图并触发反馈；
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
            
            // 向左，向下层次结构
            if (locationX < lastX && (lastX - locationX) >= kNextLevelThreshold) {
                // 选择一个新的视图索引，直到最大索引
                newSelection = MIN(max, currentIdx + 1);
                self.selectedViewLastPanX = locationX;
            }
            // 向右，向上层次结构
            else if (lastX < locationX && (locationX - lastX) >= kNextLevelThreshold) {
                // 选择一个新的视图索引，直到最小索引
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
    
    // 包括隐藏视图在“viewsAtTapPoint”数组中，以便我们可以在层次结构列表中显示它们。
    self.viewsAtTapPoint = [self viewsAtPoint:selectionPointInWindow skipHiddenViews:NO];
    
    // 对于轮廓视图和选中的视图，仅使用可见视图。
    // 对隐藏视图进行轮廓化会增加混乱并使选择行为令人困惑。
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
    // 在会处理触摸的窗口中选择，但不只使用hitTest:withEvent:的结果
    // 因此我们仍然可以选择已禁用交互的视图
    // 如果没有窗口想要触摸，则默认为应用程序的关键窗口
    UIWindow *windowForSelection = UIApplication.sharedApplication.keyWindow;
    for (UIWindow *window in FLEXUtility.allWindows.reverseObjectEnumerator) {
        // 忽略探索者自己的窗口。
        if (window != self.view.window) {
            if ([window hitTest:tapPointInWindow withEvent:nil]) {
                windowForSelection = window;
                break;
            }
        }
    }
    
    // 选择点击点处最深的可见视图。这通常对应于用户想要选择的内容。
    return [self recursiveSubviewsAtPoint:tapPointInWindow inView:windowForSelection skipHiddenViews:YES].lastObject;
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
        
        // 如果此视图不剪裁到其边界，我们需要检查其子视图，即使它
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


#pragma mark - Selected View Moving

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


#pragma mark - Safe Area Handling

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


#pragma mark - Touch Handling

- (BOOL)shouldReceiveTouchAtWindowPoint:(CGPoint)pointInWindowCoordinates {
    CGPoint pointInLocalCoordinates = [self.view convertPoint:pointInWindowCoordinates fromView:nil];
    
    // 如果我们有一个模态呈现，它是否在模态中？
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
    
    // 移动模式也始终如此
    if (self.currentMode == FLEXExplorerModeMove) {
        return YES;
    }
    
    // 始终如果它在工具栏上
    if (CGRectContainsPoint(self.explorerToolbar.frame, pointInLocalCoordinates)) {
        return YES;
    }
    
    return NO;
}


#pragma mark - FLEXHierarchyDelegate

- (void)viewHierarchyDidDismiss:(UIView *)selectedView {
    // 请注意，我们需要等到视图控制器被解雇后才能计算框架
    // 轮廓视图，否则坐标转换不会给出正确的结果。
    [self toggleViewsToolWithCompletion:^{
        // 如果选中的视图在点击点数组之外（从“完整层次结构”中选择），
        // 然后清除点击点数组并删除所有轮廓视图。
        if (![self.viewsAtTapPoint containsObject:selectedView]) {
            self.viewsAtTapPoint = nil;
            [self removeAndClearOutlineViews];
        }
        
        // 如果我们现在有一个选中的视图并且我们之前没有一个，请转到“选择”模式。
        if (self.currentMode == FLEXExplorerModeDefault && selectedView) {
            self.currentMode = FLEXExplorerModeSelect;
        }
        
        // 选中视图设置器还将适当地更新选中视图叠加层。
        self.selectedView = selectedView;
    }];
}


#pragma mark - Modal Presentation and Window Management

- (void)presentViewController:(UIViewController *)toPresent
                               animated:(BOOL)animated
                             completion:(void (^)(void))completion {
    // 使我们的窗口成为关键窗口以正确处理输入。
    [self.view.window makeKeyWindow];

    // 将状态栏移到FLEX顶部，以便我们可以获得滚动到顶部的行为。
    if (!@available(iOS 13, *)) {
        [self statusWindow].windowLevel = self.view.window.windowLevel + 1.0;
    }
    
    // 备份并替换UIMenuController项目
    // 编辑：不再替换项目，但仍然备份它们
    // 如果我们将来再次开始替换它们
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
    
    // 恢复以前的UIMenuController项目
    // 备份并替换UIMenuController项目
    UIMenuController.sharedMenuController.menuItems = self.appMenuItems;
    [UIMenuController.sharedMenuController update];
    self.appMenuItems = nil;
    
    // 恢复状态栏窗口的正常窗口级别。
    // 在呈现模态时，我们希望它在FLEX之上，以便滚动到顶部
    // 但在其他情况下在FLEX之下以便探索。
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
        // 我们不希望呈现未来；这是
        // 用于切换相同工具的便捷方法
        [self dismissViewControllerAnimated:YES completion:completion];
    } else if (future) {
        [self presentViewController:future() animated:YES completion:completion];
    }
}

- (void)presentTool:(UINavigationController *(^)(void))future
         completion:(void (^)(void))completion {
    if (self.presentedViewController) {
        // 如果工具已经呈现，先解雇它
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


#pragma mark - Keyboard Shortcut Helpers

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
