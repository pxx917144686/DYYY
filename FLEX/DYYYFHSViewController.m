//
//  DYYYFHSViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 1/6/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFHSViewController.h"
#import "DYYYFHSSnapshotView.h"
#import "DYYYFLEXHierarchyViewController.h"
#import "DYYYFLEXColor.h"
#import "DYYYFLEXAlert.h"
#import "DYYYFLEXWindow.h"
#import "DYYYFLEXResources.h"
#import "NSArray+FLEX.h"
#import "UIBarButtonItem+FLEX.h"

BOOL const kFHSViewControllerExcludeFLEXWindows = YES;

@interface DYYYFHSViewController () <FHSSnapshotViewDelegate>
/// An array of only the target views whose hierarchies
/// we wish to snapshot, not every view in the snapshot.
@property (nonatomic, readonly) NSArray<UIView *> *targetViews;
@property (nonatomic, readonly) NSArray<DYYYFHSView *> *views;
@property (nonatomic          ) NSArray<DYYYFHSViewSnapshot *> *snapshots;
@property (nonatomic,         ) DYYYFHSSnapshotView *snapshotView;

@property (nonatomic, readonly) UIView *containerView;
@property (nonatomic, readonly) NSArray<UIView *> *viewsAtTap;
@property (nonatomic, readonly) NSMutableSet<Class> *forceHideHeaders;
@end

@implementation DYYYFHSViewController
@synthesize views = _views;
@synthesize snapshotView = _snapshotView;

#pragma mark - Initialization

+ (instancetype)snapshotWindows:(NSArray<UIWindow *> *)windows {
    return [[self alloc] initWithViews:windows viewsAtTap:nil selectedView:nil];
}

+ (instancetype)snapshotView:(UIView *)view {
    return [[self alloc] initWithViews:@[view] viewsAtTap:nil selectedView:nil];
}

+ (instancetype)snapshotViewsAtTap:(NSArray<UIView *> *)viewsAtTap selectedView:(UIView *)view {
    NSParameterAssert(viewsAtTap.count);
    NSParameterAssert(view.window);
    return [[self alloc] initWithViews:@[view.window] viewsAtTap:viewsAtTap selectedView:view];
}

- (id)initWithViews:(NSArray<UIView *> *)views
         viewsAtTap:(NSArray<UIView *> *)viewsAtTap
       selectedView:(UIView *)view {
    NSParameterAssert(views.count);

    self = [super init];
    if (self) {
        _forceHideHeaders = [NSMutableSet setWithObject:NSClassFromString(@"_UITableViewCellSeparatorView")];
        _selectedView = view;
        _viewsAtTap = viewsAtTap;

        if (!viewsAtTap && kFHSViewControllerExcludeFLEXWindows) {
            Class flexwindow = [DYYYFLEXWindow class];
            views = [views flex_filtered:^BOOL(UIView *view, NSUInteger idx) {
                return [view class] != flexwindow;
            }];
        }

        _targetViews = views;
        _views = [views flex_mapped:^id(UIView *view, NSUInteger idx) {
            BOOL isScrollView = [view.superview isKindOfClass:[UIScrollView class]];
            return [DYYYFHSView forView:view isInScrollView:isScrollView];
        }];
    }

    return self;
}

- (void)refreshSnapshotView {
    // Alert view to block interaction while we load everything
    UIAlertController *loading = [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
        make.title(@"请稍等").message(@"生成快照中...");
    }];
    [self presentViewController:loading animated:YES completion:^{
        self.snapshots = [self.views flex_mapped:^id(DYYYFHSView *view, NSUInteger idx) {
            return [DYYYFHSViewSnapshot snapshotWithView:view];
        }];
        DYYYFHSSnapshotView *newSnapshotView = [DYYYFHSSnapshotView delegate:self];

        // This work is highly intensive so we do it on a background thread first
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Setting the snapshots computes lots of SCNNodes, takes several seconds
            newSnapshotView.snapshots = self.snapshots;

            // After we finish generating all the model objects and scene nodes, display the view
            dispatch_async(dispatch_get_main_queue(), ^{
                // Dismiss alert
                [loading dismissViewControllerAnimated:YES completion:nil];

                self.snapshotView = newSnapshotView;
            });
        });
    }];
}


#pragma mark - View Controller Lifecycle

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Initialize back bar button item for 3D view to look like a button
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem
        flex_itemWithImage:DYYYFLEXResources.toggle2DIcon
        target:self.navigationController
        action:@selector(toggleHierarchyMode)
    ];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!_snapshotView) {
        [self refreshSnapshotView];
    }
}


#pragma mark - Public

- (void)setSelectedView:(UIView *)view {
    _selectedView = view;
    self.snapshotView.selectedView = view ? [self snapshotForView:view] : nil;
}


#pragma mark - Private

#pragma mark Properties

- (DYYYFHSSnapshotView *)snapshotView {
    return self.isViewLoaded ? _snapshotView : nil;
}

- (void)setSnapshotView:(DYYYFHSSnapshotView *)snapshotView {
    NSParameterAssert(snapshotView);

    _snapshotView = snapshotView;

    // Initialize our toolbar items
    self.toolbarItems = @[
        [UIBarButtonItem flex_itemWithCustomView:snapshotView.spacingSlider],
        UIBarButtonItem.flex_flexibleSpace,
        [UIBarButtonItem
            flex_itemWithImage:DYYYFLEXResources.moreIcon
            target:self action:@selector(didPressOptionsButton:)
        ],
        UIBarButtonItem.flex_flexibleSpace,
        [UIBarButtonItem flex_itemWithCustomView:snapshotView.depthSlider]
    ];
    [self resizeToolbarItems:self.view.frame.size];

    // If we have views-at-tap, dim the other views
    [snapshotView emphasizeViews:self.viewsAtTap];
    // Set the selected view, if any
    snapshotView.selectedView = [self snapshotForView:self.selectedView];
    snapshotView.headerExclusions = self.forceHideHeaders.allObjects;
    [snapshotView setNeedsLayout];

    // Remove old snapshot, if any, and add the new one
    [_snapshotView removeFromSuperview];
    snapshotView.frame = self.containerView.bounds;
    [self.containerView addSubview:snapshotView];
}

- (UIView *)containerView {
    return self.view;
}

#pragma mark Helper

- (DYYYFHSViewSnapshot *)snapshotForView:(UIView *)view {
    if (!view || !self.snapshots.count) return nil;

    for (DYYYFHSViewSnapshot *snapshot in self.snapshots) {
        DYYYFHSViewSnapshot *found = [snapshot snapshotForView:view];
        if (found) {
            return found;
        }
    }

    // Error: we have snapshots but the view we requested is not in one
    @throw NSInternalInconsistencyException;
    return nil;
}

#pragma mark Events

- (void)didPressOptionsButton:(UIBarButtonItem *)sender {
    [DYYYFLEXAlert makeSheet:^(DYYYFLEXAlert *make) {
        if (self.selectedView) {
            make.button(@"隐藏选定的视图").handler(^(NSArray<NSString *> *strings) {
                [self.snapshotView hideView:[self snapshotForView:self.selectedView]];
            });
            make.button(@"隐藏像这样视图的标题").handler(^(NSArray<NSString *> *strings) {
                Class cls = [self.selectedView class];
                if (![self.forceHideHeaders containsObject:cls]) {
                    [self.forceHideHeaders addObject:[self.selectedView class]];
                    self.snapshotView.headerExclusions = self.forceHideHeaders.allObjects;
                }
            });
        }
        make.title(@"选项");
        make.button(@"切换标题").handler(^(NSArray<NSString *> *strings) {
            [self.snapshotView toggleShowHeaders];
        });
        make.button(@"切换大纲").handler(^(NSArray<NSString *> *strings) {
            [self.snapshotView toggleShowBorders];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self source:sender];
}

- (void)resizeToolbarItems:(CGSize)viewSize {
    CGFloat sliderHeights = self.snapshotView.spacingSlider.bounds.size.height;
    CGFloat sliderWidths = viewSize.width / 3.f;
    CGRect frame = CGRectMake(0, 0, sliderWidths, sliderHeights);
    self.snapshotView.spacingSlider.frame = frame;
    self.snapshotView.depthSlider.frame = frame;

    [self.navigationController.toolbar setNeedsLayout];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self resizeToolbarItems:self.view.frame.size];
    } completion:nil];
}

#pragma mark FHSSnapshotViewDelegate

- (void)didDeselectView:(DYYYFHSViewSnapshot *)snapshot {
    // Our setter would also call the setter for the snapshot view,
    // which we don't need to do here since it is already selected
    _selectedView = nil;
}

- (void)didLongPressView:(DYYYFHSViewSnapshot *)snapshot {

}

- (void)didSelectView:(DYYYFHSViewSnapshot *)snapshot {
    // Our setter would also call the setter for the snapshot view,
    // which we don't need to do here since it is already selected
    _selectedView = snapshot.view.view;
}

@end
