//
//  FLEXNavigationController.m
//  FLEX
//
//  由 Tanner 创建于 1/30/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXNavigationController.h"
#import "FLEXExplorerViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXTabList.h"

@interface UINavigationController (Private) <UIGestureRecognizerDelegate>
- (void)_gestureRecognizedInteractiveHide:(UIGestureRecognizer *)sender;
@end
@interface UIPanGestureRecognizer (Private)
- (void)_setDelegate:(id)delegate;
@end

@interface FLEXNavigationController ()
@property (nonatomic, readonly) BOOL toolbarWasHidden;
@property (nonatomic) BOOL waitingToAddTab;
@property (nonatomic, readonly) BOOL canShowToolbar;
@property (nonatomic) BOOL didSetupPendingDismissButtons;
@property (nonatomic) UISwipeGestureRecognizer *navigationBarSwipeGesture;
@end

@implementation FLEXNavigationController

+ (instancetype)withRootViewController:(UIViewController *)rootVC {
    FLEXNavigationController *nav = [[self alloc] initWithRootViewController:rootVC];
    return nav;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.waitingToAddTab = YES;
    
    // 如果隐藏，则添加手势以显示工具栏
    UITapGestureRecognizer *navbarTapGesture = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleNavigationBarTap:)
    ];
    
    // 不要取消触摸以解决 iOS 13 之前版本上的错误
    navbarTapGesture.cancelsTouchesInView = NO;
    [self.navigationBar addGestureRecognizer:navbarTapGesture];
    
    // 如果不是以表单样式呈现，则添加手势以关闭
    if (@available(iOS 13, *)) {
        switch (self.modalPresentationStyle) {
            case UIModalPresentationAutomatic:
            case UIModalPresentationPageSheet:
            case UIModalPresentationFormSheet:
                break;
                
            default:
                [self addNavigationBarSwipeGesture];
                break;
        }
    } else {
        [self addNavigationBarSwipeGesture];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presenter = self.sheetPresentationController;
        presenter.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent,
        ];
        presenter.prefersScrollingExpandsWhenScrolledToEdge = NO;
        presenter.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        presenter.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    }
    
    if (self.beingPresented && !self.didSetupPendingDismissButtons) {
        for (UIViewController *vc in self.viewControllers) {
            [self addNavigationBarItemsToViewController:vc.navigationItem];
        }
        
        self.didSetupPendingDismissButtons = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 仅当我们正确呈现时才添加新选项卡
    if (self.waitingToAddTab) {
        if ([self.presentingViewController isKindOfClass:[FLEXExplorerViewController class]]) {
            // 新的导航控制器总是将自己添加为新选项卡，
            // 选项卡由 FLEXExplorerViewController 关闭
            [FLEXTabList.sharedList addTab:self];
            self.waitingToAddTab = NO;
        }
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [super pushViewController:viewController animated:animated];
    [self addNavigationBarItemsToViewController:viewController.navigationItem];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    // 解决 UIActivityViewController 出于某种原因尝试关闭我们的问题
    if (![self.viewControllers.lastObject.presentedViewController isKindOfClass:UIActivityViewController.self]) {
        [super dismissViewControllerAnimated:flag completion:completion];
    }
}

- (void)dismissAnimated {
    // 仅当按下完成按钮时才关闭选项卡；这
    // 允许您通过向下拖动以关闭来保持选项卡打开
    if ([self.presentingViewController isKindOfClass:[FLEXExplorerViewController class]]) {
        [FLEXTabList.sharedList closeTab:self];        
    }
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)canShowToolbar {
    return self.topViewController.toolbarItems.count > 0;
}

- (void)addNavigationBarItemsToViewController:(UINavigationItem *)navigationItem {
    if (!self.presentingViewController) {
        return;
    }
    
    // 检查完成项是否已存在
    for (UIBarButtonItem *item in navigationItem.rightBarButtonItems) {
        if (item.style == UIBarButtonItemStyleDone) {
            return;
        }
    }
    
    // 如果根视图控制器没有“完成”按钮，则为其提供一个
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(dismissAnimated)
    ];
    
    // 如果已存在其他按钮，则将该按钮前置
    NSArray *existingItems = navigationItem.rightBarButtonItems;
    if (existingItems.count) {
        navigationItem.rightBarButtonItems = [@[done] arrayByAddingObjectsFromArray:existingItems];
    } else {
        navigationItem.rightBarButtonItem = done;
    }
    
    // 防止我们在 -viewWillAppear: 中再次对相同的视图控制器调用此方法
    self.didSetupPendingDismissButtons = YES;
}

- (void)addNavigationBarSwipeGesture {
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleNavigationBarSwipe:)
    ];
    swipe.direction = UISwipeGestureRecognizerDirectionDown;
    swipe.delegate = self;
    self.navigationBarSwipeGesture = swipe;
    [self.navigationBar addGestureRecognizer:swipe];
}

- (void)handleNavigationBarSwipe:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}
     
- (void)handleNavigationBarTap:(UIGestureRecognizer *)sender {
    // 如果我们只是点击一个按钮，则不显示工具栏
    CGPoint location = [sender locationInView:self.navigationBar];
    UIView *hitView = [self.navigationBar hitTest:location withEvent:nil];
    if ([hitView isKindOfClass:[UIControl class]]) {
        return;
    }

    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (self.toolbarHidden && self.canShowToolbar) {
            [self setToolbarHidden:NO animated:YES];
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g1 shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)g2 {
    if (g1 == self.navigationBarSwipeGesture && g2 == self.barHideOnSwipeGestureRecognizer) {
        return YES;
    }
    
    return NO;
}

- (void)_gestureRecognizedInteractiveHide:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        BOOL show = self.canShowToolbar;
        CGFloat yTranslation = [sender translationInView:self.view].y;
        CGFloat yVelocity = [sender velocityInView:self.view].y;
        if (yVelocity > 2000) {
            [self setToolbarHidden:YES animated:YES];
        } else if (show && yTranslation > 20 && yVelocity > 250) {
            [self setToolbarHidden:NO animated:YES];
        } else if (yTranslation < -20) {
            [self setToolbarHidden:YES animated:YES];
        }
    }
}

@end

@implementation UINavigationController (FLEXObjectExploring)

- (void)pushExplorerForObject:(id)object {
    [self pushExplorerForObject:object animated:YES];
}

- (void)pushExplorerForObject:(id)object animated:(BOOL)animated {
    UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:object];
    if (explorer) {
        [self pushViewController:explorer animated:animated];
    }
}

@end
