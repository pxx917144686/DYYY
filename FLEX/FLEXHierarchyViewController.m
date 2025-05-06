//
//  FLEXHierarchyViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 1/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXHierarchyViewController.h"
#import "FLEXHierarchyTableViewController.h"
#import "FHSViewController.h"
#import "FLEXUtility.h"
#import "FLEXTabList.h"
#import "FLEXResources.h"
#import "UIBarButtonItem+FLEX.h"

typedef NS_ENUM(NSUInteger, FLEXHierarchyViewMode) {
    FLEXHierarchyViewModeTree = 1,
    FLEXHierarchyViewMode3DSnapshot
};

@interface FLEXHierarchyViewController ()
@property (nonatomic, readonly, weak) id<FLEXHierarchyDelegate> hierarchyDelegate;
@property (nonatomic, readonly) FHSViewController *snapshotViewController;
@property (nonatomic, readonly) FLEXHierarchyTableViewController *treeViewController;

@property (nonatomic) FLEXHierarchyViewMode mode;

@property (nonatomic, readwrite) UIView *selectedView;
@end

@implementation FLEXHierarchyViewController

#pragma mark - 初始化

+ (instancetype)delegate:(id<FLEXHierarchyDelegate>)delegate {
    return [self delegate:delegate viewsAtTap:nil selectedView:nil];
}

+ (instancetype)delegate:(id<FLEXHierarchyDelegate>)delegate
              viewsAtTap:(NSArray<UIView *> *)viewsAtTap
            selectedView:(UIView *)selectedView {
    return [[self alloc] initWithDelegate:delegate viewsAtTap:viewsAtTap selectedView:selectedView];
}

- (id)initWithDelegate:(id)delegate viewsAtTap:(NSArray<UIView *> *)viewsAtTap selectedView:(UIView *)view {
    self = [super init];
    if (self) {
        NSArray<UIWindow *> *allWindows = FLEXUtility.allWindows;
        _hierarchyDelegate = delegate;
        _treeViewController = [FLEXHierarchyTableViewController
            windows:allWindows viewsAtTap:viewsAtTap selectedView:view
        ];

        if (viewsAtTap) {
            _snapshotViewController = [FHSViewController snapshotViewsAtTap:viewsAtTap selectedView:view];
        } else {
            _snapshotViewController = [FHSViewController snapshotWindows:allWindows];
        }

        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }

    return self;
}


#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];

    // 3D切换按钮
    self.treeViewController.navigationItem.leftBarButtonItem = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.toggle3DIcon target:self action:@selector(toggleHierarchyMode)
    ];

    // 当树视图行被选中时关闭
    __weak id<FLEXHierarchyDelegate> delegate = self.hierarchyDelegate;
    self.treeViewController.didSelectRowAction = ^(UIView *selectedView) {
        [delegate viewHierarchyDidDismiss:selectedView];
    };

    // 开始时显示树形视图
    _mode = FLEXHierarchyViewModeTree;
    [self pushViewController:self.treeViewController animated:NO];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // 完成按钮：在这里手动添加，因为层次结构界面需要将数据
    // 传回探索视图控制器，以便高亮显示选中的视图
    viewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed)
    ];

    [super pushViewController:viewController animated:animated];
}


#pragma mark - 私有方法

- (void)donePressed {
    // 我们需要在这里手动关闭自己，因为
    // FLEXNavigationController不会自己关闭标签页
    [FLEXTabList.sharedList closeTab:self];
    [self.hierarchyDelegate viewHierarchyDidDismiss:self.selectedView];
}

- (void)toggleHierarchyMode {
    switch (self.mode) {
        case FLEXHierarchyViewModeTree:
            self.mode = FLEXHierarchyViewMode3DSnapshot;
            break;
        case FLEXHierarchyViewMode3DSnapshot:
            self.mode = FLEXHierarchyViewModeTree;
            break;
    }
}

- (void)setMode:(FLEXHierarchyViewMode)mode {
    if (mode != _mode) {
        // 树视图控制器是我们的顶部栈视图控制器，
        // 更改模式只是推入快照视图。将来，
        // 我希望让3D切换按钮透明地在两个视图之间切换，
        // 而不是推入新的视图控制器。
        // 这样视图应该以某种方式共享搜索控制器。
        switch (mode) {
            case FLEXHierarchyViewModeTree:
                [self popViewControllerAnimated:NO];
                self.toolbarHidden = YES;
                self.treeViewController.selectedView = self.selectedView;
                break;
            case FLEXHierarchyViewMode3DSnapshot:
                [self pushViewController:self.snapshotViewController animated:NO];
                self.toolbarHidden = NO;
                self.snapshotViewController.selectedView = self.selectedView;
                break;
        }

        // 最后更改这个，使上面的self.selectedView正常工作
        _mode = mode;
    }
}

- (UIView *)selectedView {
    switch (self.mode) {
        case FLEXHierarchyViewModeTree:
            return self.treeViewController.selectedView;
        case FLEXHierarchyViewMode3DSnapshot:
            return self.snapshotViewController.selectedView;
    }
}

@end
