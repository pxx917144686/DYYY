//
//  FLEXTableViewController.m
//  FLEX
//
//  由 Tanner 创建于 7/5/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXTableViewController.h"
#import "FLEXExplorerViewController.h"
#import "FLEXBookmarksViewController.h"
#import "FLEXTabsViewController.h"
#import "FLEXScopeCarousel.h"
#import "FLEXTableView.h"
#import "FLEXUtility.h"
#import "FLEXResources.h"
#import "UIBarButtonItem+FLEX.h"
#import <objc/runtime.h>

@interface Block : NSObject
- (void)invoke;
@end

CGFloat const kFLEXDebounceInstant = 0.f;
CGFloat const kFLEXDebounceFast = 0.05;
CGFloat const kFLEXDebounceForAsyncSearch = 0.15;
CGFloat const kFLEXDebounceForExpensiveIO = 0.5;

@interface FLEXTableViewController ()
@property (nonatomic) NSTimer *debounceTimer;
@property (nonatomic) BOOL didInitiallyRevealSearchBar;
@property (nonatomic) UITableViewStyle style;

@property (nonatomic) BOOL hasAppeared;
@property (nonatomic, readonly) UIView *tableHeaderViewContainer;

@property (nonatomic, readonly) BOOL manuallyDeactivateSearchOnDisappear;

@property (nonatomic) UIBarButtonItem *middleToolbarItem;
@property (nonatomic) UIBarButtonItem *middleLeftToolbarItem;
@property (nonatomic) UIBarButtonItem *leftmostToolbarItem;
@end

@implementation FLEXTableViewController
@dynamic tableView;
@synthesize showsShareToolbarItem = _showsShareToolbarItem;
@synthesize tableHeaderViewContainer = _tableHeaderViewContainer;
@synthesize automaticallyShowsSearchBarCancelButton = _automaticallyShowsSearchBarCancelButton;

#pragma mark - 初始化

- (id)init {
    if (@available(iOS 13.0, *)) {
        self = [self initWithStyle:UITableViewStyleInsetGrouped];
    } else {
        self = [self initWithStyle:UITableViewStyleGrouped];
    }
    
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    
    if (self) {
        _searchBarDebounceInterval = kFLEXDebounceFast;
        _showSearchBarInitially = YES;
        _style = style;
        _manuallyDeactivateSearchOnDisappear = (
            NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < 11
        );
        
        // 如果我们实现了这个方法，我们将成为自己的搜索委托
        if ([self respondsToSelector:@selector(updateSearchResults:)]) {
            self.searchDelegate = (id)self;
        }
    }
    
    return self;
}


#pragma mark - 公共方法

- (FLEXWindow *)window {
    return (id)self.view.window;
}

- (void)setShowsSearchBar:(BOOL)showsSearchBar {
    if (_showsSearchBar == showsSearchBar) return;
    _showsSearchBar = showsSearchBar;
    
    if (showsSearchBar) {
        UIViewController *results = self.searchResultsController;
        self.searchController = [[UISearchController alloc] initWithSearchResultsController:results];
        self.searchController.searchBar.placeholder = @"筛选";
        self.searchController.searchResultsUpdater = (id)self;
        self.searchController.delegate = (id)self;
        if (@available(iOS 9.1, *)) {
            self.searchController.obscuresBackgroundDuringPresentation = NO;
        } else {
            self.searchController.dimsBackgroundDuringPresentation = NO;
        }
        self.searchController.hidesNavigationBarDuringPresentation = NO;
        /// iOS 13中不需要；当iOS 13成为最低部署目标时移除此项
        self.searchController.searchBar.delegate = self;

        self.automaticallyShowsSearchBarCancelButton = YES;

        if (@available(iOS 13, *)) {
            self.searchController.automaticallyShowsScopeBar = NO;
        }
        
        [self addSearchController:self.searchController];
    } else {
        // 搜索已显示且刚设置为NO，所以移除它
        [self removeSearchController:self.searchController];
    }
}

- (void)setShowsCarousel:(BOOL)showsCarousel {
    if (_showsCarousel == showsCarousel) return;
    _showsCarousel = showsCarousel;
    
    if (showsCarousel) {
        _carousel = ({ weakify(self)
            
            FLEXScopeCarousel *carousel = [FLEXScopeCarousel new];
            carousel.selectedIndexChangedAction = ^(NSInteger idx) { strongify(self);
                [self.searchDelegate updateSearchResults:self.searchText];
            };

            // UITableView除非重置表头视图，否则不会更新表头大小
            [carousel registerBlockForDynamicTypeChanges:^(FLEXScopeCarousel *_) { strongify(self);
                [self layoutTableHeaderIfNeeded];
            }];

            carousel;
        });
        [self addCarousel:_carousel];
    } else {
        // 轮播已显示且刚设置为NO，所以移除它
        [self removeCarousel:_carousel];
    }
}

- (NSInteger)selectedScope {
    if (self.searchController.searchBar.showsScopeBar) {
        return self.searchController.searchBar.selectedScopeButtonIndex;
    } else if (self.showsCarousel) {
        return self.carousel.selectedIndex;
    } else {
        return 0;
    }
}

- (void)setSelectedScope:(NSInteger)selectedScope {
    if (self.searchController.searchBar.showsScopeBar) {
        self.searchController.searchBar.selectedScopeButtonIndex = selectedScope;
    } else if (self.showsCarousel) {
        self.carousel.selectedIndex = selectedScope;
    }

    [self.searchDelegate updateSearchResults:self.searchText];
}

- (NSString *)searchText {
    return self.searchController.searchBar.text;
}

- (BOOL)automaticallyShowsSearchBarCancelButton {
    if (@available(iOS 13, *)) {
        return self.searchController.automaticallyShowsCancelButton;
    }

    return _automaticallyShowsSearchBarCancelButton;
}

- (void)setAutomaticallyShowsSearchBarCancelButton:(BOOL)value {
    if (@available(iOS 13, *)) {
        self.searchController.automaticallyShowsCancelButton = value;
    }

    _automaticallyShowsSearchBarCancelButton = value;
}

- (void)onBackgroundQueue:(NSArray *(^)(void))backgroundBlock thenOnMainQueue:(void(^)(NSArray *))mainBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *items = backgroundBlock();
        dispatch_async(dispatch_get_main_queue(), ^{
            mainBlock(items);
        });
    });
}

- (void)setsShowsShareToolbarItem:(BOOL)showsShareToolbarItem {
    _showsShareToolbarItem = showsShareToolbarItem;
    if (self.isViewLoaded) {
        [self setupToolbarItems];
    }
}

- (void)disableToolbar {
    self.navigationController.toolbarHidden = YES;
    self.navigationController.hidesBarsOnSwipe = NO;
    self.toolbarItems = nil;
}


#pragma mark - 视图控制器生命周期

- (void)loadView {
    self.view = [FLEXTableView style:self.style];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.tableView.estimatedRowHeight = 10;
    
    _shareToolbarItem = FLEXBarButtonItemSystem(Action, self, @selector(shareButtonPressed:));
    _bookmarksToolbarItem = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.bookmarksIcon target:self action:@selector(showBookmarks)
    ];
    _openTabsToolbarItem = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.openTabsIcon target:self action:@selector(showTabSwitcher)
    ];
    
    self.leftmostToolbarItem = UIBarButtonItem.flex_fixedSpace;
    self.middleLeftToolbarItem = UIBarButtonItem.flex_fixedSpace;
    self.middleToolbarItem = UIBarButtonItem.flex_fixedSpace;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    
    // 工具栏
    self.navigationController.toolbarHidden = self.toolbarItems.count > 0;
    self.navigationController.hidesBarsOnSwipe = YES;

    // 在iOS 13上，无论如何根视图控制器都会显示其搜索栏。
    // 关闭此选项可以避免导航栏在我们切换navigationItem.hidesSearchBarWhenScrolling
    // 开关时产生的一些奇怪闪烁。闪烁仍会在后续视图控制器上发生，
    // 但至少我们可以避免它出现在根视图控制器上
    if (@available(iOS 13, *)) {
        if (self.navigationController.viewControllers.firstObject == self) {
            _showSearchBarInitially = NO;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (@available(iOS 11.0, *)) {
        // 回退时，使搜索栏重新出现而不是隐藏
        if ((self.pinSearchBar || self.showSearchBarInitially) && !self.didInitiallyRevealSearchBar) {
            self.navigationItem.hidesSearchBarWhenScrolling = NO;
        }
    }
    
    // 使键盘看起来出现得更快
    if (self.activatesSearchBarAutomatically) {
        [self makeKeyboardAppearNow];
    }

    [self setupToolbarItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // 允许滚动收起搜索栏，但仅当我们不想固定它时
    if (@available(iOS 11.0, *)) {
        if (self.showSearchBarInitially && !self.pinSearchBar && !self.didInitiallyRevealSearchBar) {
            // 所有这些繁琐操作都是为了解决iOS 13至13.2中的一个错误
            // 快速切换navigationItem.hidesSearchBarWhenScrolling使搜索栏
            // 初始出现会导致搜索栏出现错误，变成透明并随着滚动浮动在屏幕上
            [UIView animateWithDuration:0.2 animations:^{
                self.navigationItem.hidesSearchBarWhenScrolling = YES;
                [self.navigationController.view setNeedsLayout];
                [self.navigationController.view layoutIfNeeded];
            }];
        }
    }
    
    if (self.activatesSearchBarAutomatically) {
        // 键盘已出现，现在我们调用这个因为我们即将呈现搜索栏
        [self removeDummyTextField];
        
        // 激活搜索栏
        dispatch_async(dispatch_get_main_queue(), ^{
            // 除非包装在这个dispatch_async调用中，否则这不起作用
            [self.searchController.searchBar becomeFirstResponder];
        });
    }

    // 我们只想在视图控制器首次出现时显示搜索栏。
    self.didInitiallyRevealSearchBar = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.manuallyDeactivateSearchOnDisappear && self.searchController.isActive) {
        self.searchController.active = NO;
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    [super didMoveToParentViewController:parent];
    // 重置此项，因为我们正在新的父视图控制器下重新出现，
    // 需要再次显示它
    self.didInitiallyRevealSearchBar = NO;
}


#pragma mark - 工具栏，公共方法

- (void)setupToolbarItems {
    if (!self.isViewLoaded) {
        return;
    }
    
    self.toolbarItems = @[
        self.leftmostToolbarItem,
        UIBarButtonItem.flex_flexibleSpace,
        self.middleLeftToolbarItem,
        UIBarButtonItem.flex_flexibleSpace,
        self.middleToolbarItem,
        UIBarButtonItem.flex_flexibleSpace,
        self.bookmarksToolbarItem,
        UIBarButtonItem.flex_flexibleSpace,
        self.openTabsToolbarItem,
    ];
    
    for (UIBarButtonItem *item in self.toolbarItems) {
        [item _setWidth:60];
        // 这对除固定空间外的任何项都不起作用
        // item.width = 60;
    }
    
    // 当不是由FLEXExplorerViewController呈现时完全禁用标签
    UIViewController *presenter = self.navigationController.presentingViewController;
    if (![presenter isKindOfClass:[FLEXExplorerViewController class]]) {
        self.openTabsToolbarItem.enabled = NO;
    }
}

- (void)addToolbarItems:(NSArray<UIBarButtonItem *> *)items {
    if (self.showsShareToolbarItem) {
        // 分享按钮在中间，跳过中间按钮
        if (items.count > 0) {
            self.middleLeftToolbarItem = items[0];
        }
        if (items.count > 1) {
            self.leftmostToolbarItem = items[1];
        }
    } else {
        // 从右到左添加按钮
        if (items.count > 0) {
            self.middleToolbarItem = items[0];
        }
        if (items.count > 1) {
            self.middleLeftToolbarItem = items[1];
        }
        if (items.count > 2) {
            self.leftmostToolbarItem = items[2];
        }
    }
    
    [self setupToolbarItems];
}

- (void)setShowsShareToolbarItem:(BOOL)showShare {
    if (_showsShareToolbarItem != showShare) {
        _showsShareToolbarItem = showShare;
        
        if (showShare) {
            // 推出最左边的项
            self.leftmostToolbarItem = self.middleLeftToolbarItem;
            self.middleLeftToolbarItem = self.middleToolbarItem;
            
            // 在中间使用分享
            self.middleToolbarItem = self.shareToolbarItem;
        } else {
            // 移除分享，将自定义项向右移动
            self.middleToolbarItem = self.middleLeftToolbarItem;
            self.middleLeftToolbarItem = self.leftmostToolbarItem;
            self.leftmostToolbarItem = UIBarButtonItem.flex_fixedSpace;
        }
    }
    
    [self setupToolbarItems];
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender {

}


#pragma mark - 私有方法

- (void)debounce:(void(^)(void))block {
    [self.debounceTimer invalidate];
    
    self.debounceTimer = [NSTimer
        scheduledTimerWithTimeInterval:self.searchBarDebounceInterval
        target:block
        selector:@selector(invoke)
        userInfo:nil
        repeats:NO
    ];
}

- (void)layoutTableHeaderIfNeeded {
    if (self.showsCarousel) {
        self.carousel.frame = FLEXRectSetHeight(
            self.carousel.frame, self.carousel.intrinsicContentSize.height
        );
    }
    
    self.tableView.tableHeaderView = self.tableView.tableHeaderView;
}

- (void)addCarousel:(FLEXScopeCarousel *)carousel {
    if (@available(iOS 11.0, *)) {
        self.tableView.tableHeaderView = carousel;
    } else {
        carousel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        
        CGRect frame = self.tableHeaderViewContainer.frame;
        CGRect subviewFrame = carousel.frame;
        subviewFrame.origin.y = 0;
        
        // 如果搜索栏已经存在，将轮播放在搜索栏下方
        if (self.showsSearchBar) {
            carousel.frame = subviewFrame = FLEXRectSetY(
                subviewFrame, self.searchController.searchBar.frame.size.height
            );
            frame.size.height += carousel.intrinsicContentSize.height;
        } else {
            frame.size.height = carousel.intrinsicContentSize.height;
        }
        
        self.tableHeaderViewContainer.frame = frame;
        [self.tableHeaderViewContainer addSubview:carousel];
    }
    
    [self layoutTableHeaderIfNeeded];
}

- (void)removeCarousel:(FLEXScopeCarousel *)carousel {
    [carousel removeFromSuperview];
    
    if (@available(iOS 11.0, *)) {
        self.tableView.tableHeaderView = nil;
    } else {
        if (self.showsSearchBar) {
            [self removeSearchController:self.searchController];
            [self addSearchController:self.searchController];
        } else {
            self.tableView.tableHeaderView = nil;
            _tableHeaderViewContainer = nil;
        }
    }
}

- (void)addSearchController:(UISearchController *)controller {
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = controller;
    } else {
        controller.searchBar.autoresizingMask |= UIViewAutoresizingFlexibleBottomMargin;
        [self.tableHeaderViewContainer addSubview:controller.searchBar];
        CGRect subviewFrame = controller.searchBar.frame;
        CGRect frame = self.tableHeaderViewContainer.frame;
        frame.size.width = MAX(frame.size.width, subviewFrame.size.width);
        frame.size.height = subviewFrame.size.height;
        
        // 如果轮播已经存在，将其往下移动
        if (self.showsCarousel) {
            self.carousel.frame = FLEXRectSetY(
                self.carousel.frame, subviewFrame.size.height
            );
            frame.size.height += self.carousel.frame.size.height;
        }
        
        self.tableHeaderViewContainer.frame = frame;
        [self layoutTableHeaderIfNeeded];
    }
}

- (void)removeSearchController:(UISearchController *)controller {
    [controller.searchBar removeFromSuperview];
    
    if (self.showsCarousel) {
        // self.carousel.frame = FLEXRectRemake(CGPointZero, self.carousel.frame.size);
        [self removeCarousel:self.carousel];
        [self addCarousel:self.carousel];
    } else {
        self.tableView.tableHeaderView = nil;
        _tableHeaderViewContainer = nil;
    }
}

- (UIView *)tableHeaderViewContainer {
    if (!_tableHeaderViewContainer) {
        _tableHeaderViewContainer = [UIView new];
        self.tableView.tableHeaderView = self.tableHeaderViewContainer;
    }
    
    return _tableHeaderViewContainer;
}

- (void)showBookmarks {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[FLEXBookmarksViewController new]
    ];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showTabSwitcher {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:[FLEXTabsViewController new]
    ];
    [self presentViewController:nav animated:YES completion:nil];
}


#pragma mark - 搜索栏

#pragma mark 更快的键盘

static UITextField *kDummyTextField = nil;

/// 使键盘立即出现。我们使用这个来使键盘在搜索栏初始显示时更快地出现。
/// 在搜索栏出现之前，您必须调用 \c -removeDummyTextField。
- (void)makeKeyboardAppearNow {
    if (!kDummyTextField) {
        kDummyTextField = [UITextField new];
        kDummyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    }
    
    kDummyTextField.inputAccessoryView = self.searchController.searchBar.inputAccessoryView;
    [UIApplication.sharedApplication.keyWindow addSubview:kDummyTextField];
    [kDummyTextField becomeFirstResponder];
}

- (void)removeDummyTextField {
    if (kDummyTextField.superview) {
        [kDummyTextField removeFromSuperview];
    }
}

#pragma mark UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self.debounceTimer invalidate];
    NSString *text = searchController.searchBar.text;
    
    void (^updateSearchResults)(void) = ^{
        if (self.searchResultsUpdater) {
            [self.searchResultsUpdater updateSearchResults:text];
        } else {
            [self.searchDelegate updateSearchResults:text];
        }
    };
    
    // 只有当我们需要时，并且有非空字符串时才延迟处理
    // 空字符串事件立即发送
    if (text.length && self.searchBarDebounceInterval > kFLEXDebounceInstant) {
        [self debounce:updateSearchResults];
    } else {
        updateSearchResults();
    }
}


#pragma mark UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    // 手动显示iOS 13以下版本的取消按钮
    if (!@available(iOS 13, *) && self.automaticallyShowsSearchBarCancelButton) {
        [searchController.searchBar setShowsCancelButton:YES animated:YES];
    }
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    // 手动隐藏iOS 13以下版本的取消按钮
    if (!@available(iOS 13, *) && self.automaticallyShowsSearchBarCancelButton) {
        [searchController.searchBar setShowsCancelButton:NO animated:YES];
    }
}


#pragma mark UISearchBarDelegate

/// iOS 13中不需要；当iOS 13成为部署目标时移除此项
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}


#pragma mark 表视图

/// 在第一个部分没有标题在圆角表视图样式下看起来很奇怪
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (@available(iOS 13, *)) {
        if (self.style == UITableViewStyleInsetGrouped) {
            return @" ";
        }
    }

    return nil; // 对于普通/分组样式
}

@end
