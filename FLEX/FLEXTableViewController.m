//
//  FLEXTableViewController.m
//  FLEX
//
//  由 Tanner 创建于 7/5/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

// 遇到问题联系中文翻译作者：pxx917144686

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
    self = [self initWithStyle:UITableViewStyleGrouped];
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
        
        // 如果我们实现此方法，我们将成为自己的搜索委托
        if ([self respondsToSelector:@selector(updateSearchResults:)]) {
            self.searchDelegate = (id)self;
        }
    }
    
    return self;
}


#pragma mark - 公开

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
        self.searchController.obscuresBackgroundDuringPresentation = NO;
        self.searchController.hidesNavigationBarDuringPresentation = NO;
        self.searchController.searchBar.delegate = self;

        self.automaticallyShowsSearchBarCancelButton = YES;
        
        [self addSearchController:self.searchController];
    } else {
        // 搜索已显示且刚设置为 NO，因此将其移除
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

            // 除非重置表头视图，否则 UITableView 不会更新表头大小
            [carousel registerBlockForDynamicTypeChanges:^(FLEXScopeCarousel *_) { strongify(self);
                [self layoutTableHeaderIfNeeded];
            }];

            carousel;
        });
        [self addCarousel:_carousel];
    } else {
        // 轮播已显示且刚设置为 NO，因此将其移除
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
    return _automaticallyShowsSearchBarCancelButton;
}

- (void)setAutomaticallyShowsSearchBarCancelButton:(BOOL)value {
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
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.activatesSearchBarAutomatically) {
        [self makeKeyboardAppearNow];
    }

    [self setupToolbarItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.activatesSearchBarAutomatically) {
        // 键盘已出现，现在我们调用此方法，因为我们很快就会显示搜索栏
        [self removeDummyTextField];
        
        // 激活搜索栏
        dispatch_async(dispatch_get_main_queue(), ^{
            // 除非将其包装在此 dispatch_async 调用中，否则此操作无效
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
    // 重置此项，因为我们正在新的父视图控制器下重新出现，需要再次显示它
    self.didInitiallyRevealSearchBar = NO;
}


#pragma mark - 工具栏，公开

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
        // 由于某种原因，这仅对固定间距有效
        // item.width = 60;
    }
    
    // 当不由 FLEXExplorerViewController呈现时，完全禁用选项卡
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
            // 推出最左边的项目
            self.leftmostToolbarItem = self.middleLeftToolbarItem;
            self.middleLeftToolbarItem = self.middleToolbarItem;
            
            // 中间使用分享按钮
            self.middleToolbarItem = self.shareToolbarItem;
        } else {
            // 移除分享按钮，将自定义项目向右移动
            self.middleToolbarItem = self.middleLeftToolbarItem;
            self.middleLeftToolbarItem = self.leftmostToolbarItem;
            self.leftmostToolbarItem = UIBarButtonItem.flex_fixedSpace;
        }
    }
    
    [self setupToolbarItems];
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender {

}


#pragma mark - 私有

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
    self.tableView.tableHeaderView = carousel;
    [self layoutTableHeaderIfNeeded];
}

- (void)removeCarousel:(FLEXScopeCarousel *)carousel {
    [carousel removeFromSuperview];
    
    if (self.showsSearchBar) {
        [self removeSearchController:self.searchController];
        [self addSearchController:self.searchController];
    } else {
        self.tableView.tableHeaderView = nil;
        _tableHeaderViewContainer = nil;
    }
}

- (void)addSearchController:(UISearchController *)controller {
    controller.searchBar.autoresizingMask |= UIViewAutoresizingFlexibleBottomMargin;
    [self.tableHeaderViewContainer addSubview:controller.searchBar];
    CGRect subviewFrame = controller.searchBar.frame;
    CGRect frame = self.tableHeaderViewContainer.frame;
    frame.size.width = MAX(frame.size.width, subviewFrame.size.width);
    frame.size.height = subviewFrame.size.height;
    
    // 如果轮播已存在，则将其下移
    if (self.showsCarousel) {
        self.carousel.frame = FLEXRectSetY(
            self.carousel.frame, subviewFrame.size.height
        );
        frame.size.height += self.carousel.frame.size.height;
    }
    
    self.tableHeaderViewContainer.frame = frame;
    [self layoutTableHeaderIfNeeded];
}

- (void)removeSearchController:(UISearchController *)controller {
    [controller.searchBar removeFromSuperview];
    
    if (self.showsCarousel) {
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

/// 使键盘立即出现。我们用它来使键盘在搜索栏最初设置为出现时更快地出现。
/// 您必须在搜索栏出现之前调用 \c -removeDummyTextField。
- (void)makeKeyboardAppearNow {
    if (!kDummyTextField) {
        kDummyTextField = [UITextField new];
        kDummyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    }
    
    kDummyTextField.inputAccessoryView = self.searchController.searchBar.inputAccessoryView;
    
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = FLEXUtility.activeScene;
        window = scene.windows.firstObject;
    } else {
        window = [[UIApplication sharedApplication].delegate window];
    }
    
    if (window) {
        [window addSubview:kDummyTextField];
    }
}

- (void)removeDummyTextField {
    if (kDummyTextField.superview) {
        [kDummyTextField removeFromSuperview];
    }
}

- (void)textFieldFocusLoop:(NSNotification *)notification {
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                window = windowScene.windows.firstObject;
                if (window) break;
            }
        }
    }
    
    // 降级使用应用程序代理的window
    if (!window) {
        window = [[UIApplication sharedApplication].delegate window];
    }
    
    if (window) {
        [window addSubview:kDummyTextField];
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
    
    // 仅当我们想要并且有非空字符串时才进行去抖动
    // 空字符串事件会立即发送
    if (text.length && self.searchBarDebounceInterval > kFLEXDebounceInstant) {
        [self debounce:updateSearchResults];
    } else {
        updateSearchResults();
    }
}


#pragma mark UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    // 直接显示取消按钮
    if (self.automaticallyShowsSearchBarCancelButton) {
        [searchController.searchBar setShowsCancelButton:YES animated:YES];
    }
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    if (self.automaticallyShowsSearchBarCancelButton) {
        [searchController.searchBar setShowsCancelButton:NO animated:YES];
    }
}


#pragma mark UISearchBarDelegate

/// 在 iOS 13 中不是必需的；当 iOS 13 是部署目标时移除此项
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}


#pragma mark 表格视图

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

@end
