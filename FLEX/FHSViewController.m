// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 1/6/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FHSViewController.h"
#import "FHSSnapshotView.h"
#import "FLEXHierarchyViewController.h" // 确保已导入
#import "FLEXColor.h"
#import "FLEXAlert.h"
#import "FLEXWindow.h"
#import "FLEXResources.h"
#import "NSArray+FLEX.h"
#import "UIBarButtonItem+FLEX.h"

BOOL const kFHSViewControllerExcludeFLEXWindows = YES; // 是否排除 FLEX 窗口

@interface FHSViewController () <FHSSnapshotViewDelegate>
/// 一个仅包含我们希望快照其层次结构的目标视图的数组，
/// 而不是快照中的每个视图。
@property (nonatomic, readonly) NSArray<UIView *> *targetViews;
/// 目标视图对应的 FHSView 对象数组
@property (nonatomic, readonly) NSArray<FHSView *> *views;
/// 生成的视图快照数组
@property (nonatomic          ) NSArray<FHSViewSnapshot *> *snapshots;
/// 显示 3D 快照的视图
@property (nonatomic,         ) FHSSnapshotView *snapshotView;

/// 容纳 snapshotView 的容器视图
@property (nonatomic, readonly) UIView *containerView;
/// 点击位置的视图数组（用于高亮）
@property (nonatomic, readonly) NSArray<UIView *> *viewsAtTap;
/// 强制隐藏头部的视图类集合
@property (nonatomic, readonly) NSMutableSet<Class> *forceHideHeaders;
@end

@implementation FHSViewController
@synthesize views = _views; // 合成 views 属性
@synthesize snapshotView = _snapshotView; // 合成 snapshotView 属性

#pragma mark - 初始化

+ (instancetype)snapshotWindows:(NSArray<UIWindow *> *)windows {
    // 快照一组窗口
    return [[self alloc] initWithViews:windows viewsAtTap:nil selectedView:nil];
}

+ (instancetype)snapshotView:(UIView *)view {
    // 快照单个视图的层次结构
    return [[self alloc] initWithViews:@[view] viewsAtTap:nil selectedView:nil];
}

+ (instancetype)snapshotViewsAtTap:(NSArray<UIView *> *)viewsAtTap selectedView:(UIView *)view {
    // 快照包含点击位置视图的窗口，并高亮点击位置的视图
    NSParameterAssert(viewsAtTap.count); // 确保 viewsAtTap 不为空
    NSParameterAssert(view.window); // 确保选中视图有窗口
    return [[self alloc] initWithViews:@[view.window] viewsAtTap:viewsAtTap selectedView:view];
}

- (id)initWithViews:(NSArray<UIView *> *)views
         viewsAtTap:(NSArray<UIView *> *)viewsAtTap
       selectedView:(UIView *)view {
    NSParameterAssert(views.count); // 确保 views 不为空

    self = [super init];
    if (self) {
        // 初始化强制隐藏头部的类集合（例如 UITableView 的分隔线）
        _forceHideHeaders = [NSMutableSet setWithObject:NSClassFromString(@"_UITableViewCellSeparatorView")];
        _selectedView = view; // 保存选中的视图
        _viewsAtTap = viewsAtTap; // 保存点击位置的视图

        // 如果不是通过点击触发，并且设置了排除 FLEX 窗口，则过滤掉 FLEX 窗口
        if (!viewsAtTap && kFHSViewControllerExcludeFLEXWindows) {
            Class flexwindow = [FLEXWindow class];
            views = [views flex_filtered:^BOOL(UIView *view, NSUInteger idx) {
                return [view class] != flexwindow;
            }];
        }

        _targetViews = views; // 保存目标视图
        // 将目标 UIView 映射为 FHSView 对象
        _views = [views flex_mapped:^id(UIView *view, NSUInteger idx) {
            // 检查父视图是否为 UIScrollView
            BOOL isScrollView = [view.superview isKindOfClass:[UIScrollView class]];
            return [FHSView forView:view isInScrollView:isScrollView];
        }];
    }

    return self;
}

- (void)refreshSnapshotView {
    // 显示加载提示框，阻止交互
    UIAlertController *loading = [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"请稍等").message(@"生成快照中...");
    }];
    [self presentViewController:loading animated:YES completion:^{
        // 生成视图快照模型对象
        self.snapshots = [self.views flex_mapped:^id(FHSView *view, NSUInteger idx) {
            return [FHSViewSnapshot snapshotWithView:view];
        }];
        // 创建新的快照视图
        FHSSnapshotView *newSnapshotView = [FHSSnapshotView delegate:self];

        // 这项工作非常耗时，因此首先在后台线程上执行
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // 设置快照会计算大量的 SCNNode，需要几秒钟时间
            newSnapshotView.snapshots = self.snapshots;

            // 生成完所有模型对象和场景节点后，在主线程上显示视图
            dispatch_async(dispatch_get_main_queue(), ^{
                // 关闭加载提示框
                [loading dismissViewControllerAnimated:YES completion:nil];

                // 设置并显示新的快照视图
                self.snapshotView = newSnapshotView;
            });
        });
    }];
}


#pragma mark - 视图控制器生命周期

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = FLEXColor.primaryBackgroundColor; // 设置背景色
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化导航栏左侧按钮，用于切换 2D/3D 视图
    self.navigationItem.hidesBackButton = YES; // 隐藏默认返回按钮
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.toggle2DIcon // 使用 2D 图标
        target:self.navigationController // 目标为导航控制器
        action:@selector(toggleHierarchyMode) // 调用导航控制器的切换方法
    ];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // 如果快照视图尚未创建，则刷新
    if (!_snapshotView) {
        [self refreshSnapshotView];
    }
}


#pragma mark - 公共方法

- (void)setSelectedView:(UIView *)view {
    _selectedView = view; // 更新选中的视图
    // 更新快照视图中的选中项
    self.snapshotView.selectedView = view ? [self snapshotForView:view] : nil;
}


#pragma mark - 私有方法

#pragma mark 属性

- (FHSSnapshotView *)snapshotView {
    // 仅在视图加载后返回快照视图
    return self.isViewLoaded ? _snapshotView : nil;
}

- (void)setSnapshotView:(FHSSnapshotView *)snapshotView {
    NSParameterAssert(snapshotView); // 确保快照视图不为空

    _snapshotView = snapshotView; // 保存新的快照视图

    // 初始化工具栏项
    self.toolbarItems = @[
        [UIBarButtonItem flex_itemWithCustomView:snapshotView.spacingSlider], // 间距滑块
        UIBarButtonItem.flex_flexibleSpace, // 弹性空间
        [UIBarButtonItem
            flex_itemWithImage:FLEXResources.moreIcon // 更多选项按钮
            target:self action:@selector(didPressOptionsButton:)
        ],
        UIBarButtonItem.flex_flexibleSpace, // 弹性空间
        [UIBarButtonItem flex_itemWithCustomView:snapshotView.depthSlider] // 深度滑块
    ];
    // 调整工具栏项大小
    [self resizeToolbarItems:self.view.frame.size];

    // 如果有点击位置的视图，则使其他视图变暗
    [snapshotView emphasizeViews:self.viewsAtTap];
    // 设置选中的视图（如果有）
    snapshotView.selectedView = [self snapshotForView:self.selectedView];
    // 设置强制隐藏头部的类
    snapshotView.headerExclusions = self.forceHideHeaders.allObjects;
    [snapshotView setNeedsLayout]; // 标记需要重新布局

    // 移除旧的快照视图（如果存在）
    [_snapshotView removeFromSuperview];
    // 将新的快照视图添加到容器视图
    snapshotView.frame = self.containerView.bounds;
    [self.containerView addSubview:snapshotView];
}

- (UIView *)containerView {
    // 返回主视图作为容器视图
    return self.view;
}

#pragma mark 辅助方法

- (FHSViewSnapshot *)snapshotForView:(UIView *)view {
    if (!view || !self.snapshots.count) return nil; // 如果视图或快照为空，返回 nil

    // 遍历根快照查找对应的快照对象
    for (FHSViewSnapshot *snapshot in self.snapshots) {
        FHSViewSnapshot *found = [snapshot snapshotForView:view];
        if (found) {
            return found; // 找到则返回
        }
    }

    // 错误：有快照但未找到请求的视图
    @throw NSInternalInconsistencyException; // 抛出内部不一致异常
    return nil;
}

#pragma mark 事件

- (void)didPressOptionsButton:(UIBarButtonItem *)sender {
    // 显示选项动作表
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        if (self.selectedView) {
            // 如果有选中的视图，添加相关选项
            make.button(@"隐藏选定视图").handler(^(NSArray<NSString *> *strings) {
                // 隐藏选中的视图
                [self.snapshotView hideView:[self snapshotForView:self.selectedView]];
            });
            make.button(@"隐藏像这样视图的标题").handler(^(NSArray<NSString *> *strings) {
                // 将选中视图的类添加到强制隐藏列表
                Class cls = [self.selectedView class];
                if (![self.forceHideHeaders containsObject:cls]) {
                    [self.forceHideHeaders addObject:[self.selectedView class]];
                    // 更新快照视图的排除列表
                    self.snapshotView.headerExclusions = self.forceHideHeaders.allObjects;
                }
            });
        }
        make.title(@"选项"); // 设置标题
        // 添加通用选项
        make.button(@"切换标题").handler(^(NSArray<NSString *> *strings) {
            [self.snapshotView toggleShowHeaders]; // 切换标题显示
        });
        make.button(@"切换轮廓").handler(^(NSArray<NSString *> *strings) {
            [self.snapshotView toggleShowBorders]; // 切换边框显示
        });
        make.button(@"取消").cancelStyle(); // 取消按钮
    } showFrom:self source:sender]; // 从按钮处显示
}

- (void)resizeToolbarItems:(CGSize)viewSize {
    // 调整工具栏中滑块的宽度
    CGFloat sliderHeights = self.snapshotView.spacingSlider.bounds.size.height;
    CGFloat sliderWidths = viewSize.width / 3.f; // 宽度设为视图宽度的三分之一
    CGRect frame = CGRectMake(0, 0, sliderWidths, sliderHeights);
    self.snapshotView.spacingSlider.frame = frame;
    self.snapshotView.depthSlider.frame = frame;

    // 标记工具栏需要重新布局
    [self.navigationController.toolbar setNeedsLayout];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // 在视图尺寸过渡期间调整工具栏项大小
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self resizeToolbarItems:size];
    } completion:nil];
}


#pragma mark - FHSSnapshotViewDelegate

- (void)didSelectView:(FHSViewSnapshot *)view {
    // 代理方法：当快照视图中选中一个视图时调用
    _selectedView = view.view.view; // 更新选中的 UIView
    // 通知导航控制器（可能是 FLEXHierarchyViewController）更新选中状态
    // 使用 performSelector 尝试调用 didSelectView:
    SEL selector = NSSelectorFromString(@"didSelectView:");
    if ([self.navigationController respondsToSelector:selector]) {
        // 忽略 performSelector 可能引起的内存泄漏警告
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.navigationController performSelector:selector withObject:self.selectedView];
        #pragma clang diagnostic pop
    }
}

- (void)didDeselectView:(FHSViewSnapshot *)view {
    // 代理方法：当快照视图中取消选中一个视图时调用
    _selectedView = nil; // 清除选中的 UIView
    // 通知导航控制器（可能是 FLEXHierarchyViewController）更新选中状态
    // 使用 performSelector 尝试调用 didSelectView:
    SEL selector = NSSelectorFromString(@"didSelectView:");
    if ([self.navigationController respondsToSelector:selector]) {
        // 忽略 performSelector 可能引起的内存泄漏警告
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.navigationController performSelector:selector withObject:nil];
        #pragma clang diagnostic pop
    }
}

@end