// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTableViewController.h
//  FLEX
//
//  由 Tanner 创建于 7/5/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>
#import "FLEXTableView.h"
@class FLEXScopeCarousel, FLEXWindow, FLEXTableViewSection;

typedef CGFloat FLEXDebounceInterval;
/// 无延迟，所有事件均已传递
extern CGFloat const kFLEXDebounceInstant;
/// 小延迟，通过避免快速事件使 UI 更流畅
extern CGFloat const kFLEXDebounceFast;
/// 比 Fast 慢，比 ExpensiveIO 快
extern CGFloat const kFLEXDebounceForAsyncSearch;
/// 最不频繁，每秒略多于一次；用于 I/O 或其他昂贵的操作
extern CGFloat const kFLEXDebounceForExpensiveIO;

@protocol FLEXSearchResultsUpdating <NSObject>
/// 处理搜索查询更新事件的方法。
///
/// \c searchBarDebounceInterval 用于降低此方法的调用频率。
/// 当搜索栏成为第一响应者以及所选搜索栏范围索引更改时，也会调用此方法。
- (void)updateSearchResults:(NSString *)newText;
@end

@interface FLEXTableViewController : UITableViewController <
    UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate
>

/// 分组表格视图。在 iOS 13 上有内边距。
///
/// 只需调用 \c initWithStyle:
- (id)init;

/// 子类可以重写以在 \c viewDidLoad: 之前配置控制器：
- (id)initWithStyle:(UITableViewStyle)style;

@property (nonatomic) FLEXTableView *tableView;

/// 如果您的子类符合 \c FLEXSearchResultsUpdating
/// 那么此属性会自动分配给 \c self。
///
/// 设置 \c filterDelegate 也会将此属性设置为该对象。
@property (nonatomic, weak) id<FLEXSearchResultsUpdating> searchDelegate;

/// 默认为 NO。
///
/// 将此设置为 YES 将初始化轮播和视图。
@property (nonatomic) BOOL showsCarousel;
/// 一个水平滚动的列表，其功能类似于搜索栏的范围栏。
/// 当您可能有超过 4 个范围选项时，您会希望使用此功能。
@property (nonatomic) FLEXScopeCarousel *carousel;

/// 默认为 NO。
///
/// 将此设置为 YES 将初始化 searchController 和视图。
@property (nonatomic) BOOL showsSearchBar;
/// 默认为 NO。
///
/// 将此设置为 YES 将使搜索栏在视图出现时显示。
/// 否则，iOS 仅在您向上滚动时显示搜索栏。
@property (nonatomic) BOOL showSearchBarInitially;
/// 默认为 NO。
///
/// 将此设置为 YES 将使搜索栏在视图出现时激活。
@property (nonatomic) BOOL activatesSearchBarAutomatically;

/// 除非 showsSearchBar 设置为 YES，否则为 nil。
///
/// self 用作默认的搜索结果更新程序和委托。
/// 默认情况下，搜索栏不会使背景变暗或隐藏导航栏。
/// 在 iOS 11 及更高版本上，搜索栏将显示在标题下方的导航栏中。
@property (nonatomic) UISearchController *searchController;
/// 用于初始化搜索控制器。默认为 nil。
@property (nonatomic) UIViewController *searchResultsController;
/// 默认为“Fast”
///
/// 确定搜索栏结果将被“去抖动”的频率。
/// 空查询事件总是立即发送。当用户在此时间间隔内未更改查询时，将发送查询事件。
@property (nonatomic) FLEXDebounceInterval searchBarDebounceInterval;
/// 搜索栏在滚动时是否停留在视图顶部。
///
/// 调用 self.navigationItem.hidesSearchBarWhenScrolling。
/// 不要直接更改 self.navigationItem.hidesSearchBarWhenScrolling，
/// 否则它将不会被遵守。请改用此属性。
/// 默认为 NO。
@property (nonatomic) BOOL pinSearchBar;
/// 默认情况下，当搜索变为活动状态时，我们将显示搜索栏的取消按钮，
/// 并在搜索被关闭时隐藏它。
///
/// 不要手动设置 searchController 的 searchBar 上的 showsCancelButton 属性。
/// 在打开 showsSearchBar 后设置此属性。
///
/// 在 iOS 13 之前不起作用，可以在任何版本上安全调用。
@property (nonatomic) BOOL automaticallyShowsSearchBarCancelButton;

/// 如果使用范围栏，则为 self.searchController.searchBar.selectedScopeButtonIndex。
/// 否则，这是轮播的选定索引，如果两者都不使用，则为 NSNotFound。
@property (nonatomic) NSInteger selectedScope;
/// self.searchController.searchBar.text
@property (nonatomic, readonly, copy) NSString *searchText;

/// 一个完全可选的委托，用于转发搜索结果更新程序调用。
/// 如果设置了委托，则不会在此视图控制器上调用 updateSearchResults:。
@property (nonatomic, weak) id<FLEXSearchResultsUpdating> searchResultsUpdater;

/// self.view.window 作为 \c FLEXWindow
@property (nonatomic, readonly) FLEXWindow *window;

/// 便于在后台进行一些异步的处理器密集型搜索，
/// 然后在主队列上更新 UI。
- (void)onBackgroundQueue:(NSArray *(^)(void))backgroundBlock thenOnMainQueue:(void(^)(NSArray *))mainBlock;

/// 按从右到左的顺序向工具栏添加最多 3 个附加项。
///
/// 也就是说，给定数组中的第一项将是任何现有工具栏项后面的最右侧项。
/// 默认情况下，会显示书签和选项卡的按钮。
///
/// 如果您希望对按钮的排列方式或显示的按钮有更多控制，
/// 您可以直接访问预先存在的工具栏项的属性，并通过重写下面的
/// \c setupToolbarItems 方法手动设置 \c self.toolbarItems。
- (void)addToolbarItems:(NSArray<UIBarButtonItem *> *)items;

/// 子类可以重写。您不应直接调用此方法。
- (void)setupToolbarItems;

@property (nonatomic, readonly) UIBarButtonItem *shareToolbarItem;
@property (nonatomic, readonly) UIBarButtonItem *bookmarksToolbarItem;
@property (nonatomic, readonly) UIBarButtonItem *openTabsToolbarItem;

/// 是否在工具栏中间显示“共享”图标。默认为 NO。
///
/// 在添加自定义工具栏项后打开此选项将挤掉最左侧的工具栏项，并将其余项向左移动。
@property (nonatomic) BOOL showsShareToolbarItem;
/// 当按下共享按钮时调用。
/// 默认实现不执行任何操作。子类可以重写。
- (void)shareButtonPressed:(UIBarButtonItem *)sender;

/// 子类可以调用此方法以选择退出所有与工具栏相关的行为。
/// 如果要禁用显示工具栏的手势，则必须这样做。
- (void)disableToolbar;

@end
