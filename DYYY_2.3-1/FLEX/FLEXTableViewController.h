//
//  FLEXTableViewController.h
//  FLEX
//
//  Created by Tanner on 7/5/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FLEXTableView.h"
@class FLEXScopeCarousel, FLEXWindow, FLEXTableViewSection;

typedef CGFloat FLEXDebounceInterval;
/// No delay, all events delivered
extern CGFloat const kFLEXDebounceInstant;
/// Small delay which makes UI seem smoother by avoiding rapid events
extern CGFloat const kFLEXDebounceFast;
/// Slower than Fast, faster than ExpensiveIO
extern CGFloat const kFLEXDebounceForAsyncSearch;
/// The least frequent, at just over once per second; for I/O or other expensive operations
extern CGFloat const kFLEXDebounceForExpensiveIO;

@protocol FLEXSearchResultsUpdating <NSObject>
/// A method to handle search query update events.
///
/// \c searchBarDebounceInterval is used to reduce the frequency at which this
/// method is called. This method is also called when the search bar becomes
/// the first responder, and when the selected search bar scope index changes.
- (void)updateSearchResults:(NSString *)newText;
@end

@interface FLEXTableViewController : UITableViewController <
    UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate
>

/// A grouped table view. Inset on iOS 13.
///
/// Simply calls into \c initWithStyle:
- (id)init;

/// Subclasses may override to configure the controller before \c viewDidLoad:
- (id)initWithStyle:(UITableViewStyle)style;

@property (nonatomic) FLEXTableView *tableView;

/// If your subclass conforms to \c FLEXSearchResultsUpdating
/// then this property is assigned to \c self automatically.
///
/// Setting \c filterDelegate will also set this property to that object.
@property (nonatomic, weak) id<FLEXSearchResultsUpdating> searchDelegate;

/// Defaults to NO.
///
/// Setting this to YES will initialize the carousel and the view.
@property (nonatomic) BOOL showsCarousel;
/// A horizontally scrolling list with functionality similar to
/// that of a search bar's scope bar. You'd want to use this when
/// you have potentially more than 4 scope options.
@property (nonatomic) FLEXScopeCarousel *carousel;

/// Defaults to NO.
///
/// Setting this to YES will initialize searchController and the view.
@property (nonatomic) BOOL showsSearchBar;
/// Defaults to NO.
///
/// Setting this to YES will make the search bar appear whenever the view appears.
/// Otherwise, iOS will only show the search bar when you scroll up.
@property (nonatomic) BOOL showSearchBarInitially;
/// Defaults to NO.
///
/// Setting this to YES will make the search bar activate whenever the view appears.
@property (nonatomic) BOOL activatesSearchBarAutomatically;

/// nil unless showsSearchBar is set to YES.
///
/// self is used as the default search results updater and delegate.
/// The search bar will not dim the background or hide the navigation bar by default.
/// On iOS 11 and up, the search bar will appear in the navigation bar below the title.
@property (nonatomic) UISearchController *searchController;
/// Used to initialize the search controller. Defaults to nil.
@property (nonatomic) UIViewController *searchResultsController;
/// Defaults to "Fast"
///
/// Determines how often search bar results will be "debounced."
/// Empty query events are always sent instantly. Query events will
/// be sent when the user has not changed the query for this interval.
@property (nonatomic) FLEXDebounceInterval searchBarDebounceInterval;
/// Whether the search bar stays at the top of the view while scrolling.
///
/// Calls into self.navigationItem.hidesSearchBarWhenScrolling.
/// Do not change self.navigationItem.hidesSearchBarWhenScrolling directly,
/// or it will not be respsected. Use this instead.
/// Defaults to NO.
@property (nonatomic) BOOL pinSearchBar;
/// By default, we will show the search bar's cancel button when
/// search becomes active and hide it when search is dismissed.
///
/// Do not set the showsCancelButton property on the searchController's
/// searchBar manually. Set this property after turning on showsSearchBar.
///
/// Does nothing pre-iOS 13, safe to call on any version.
@property (nonatomic) BOOL automaticallyShowsSearchBarCancelButton;

/// If using the scope bar, self.searchController.searchBar.selectedScopeButtonIndex.
/// Otherwise, this is the selected index of the carousel, or NSNotFound if using neither.
@property (nonatomic) NSInteger selectedScope;
/// self.searchController.searchBar.text
@property (nonatomic, readonly, copy) NSString *searchText;

/// A totally optional delegate to forward search results updater calls to.
/// If a delegate is set, updateSearchResults: is not called on this view controller.
@property (nonatomic, weak) id<FLEXSearchResultsUpdating> searchResultsUpdater;

/// self.view.window as a \c FLEXWindow
@property (nonatomic, readonly) FLEXWindow *window;

/// Convenient for doing some async processor-intensive searching
/// in the background before updating the UI back on the main queue.
- (void)onBackgroundQueue:(NSArray *(^)(void))backgroundBlock thenOnMainQueue:(void(^)(NSArray *))mainBlock;

/// 以从右到左的顺序最多向工具栏添加3个额外项目。
///
/// 也就是说，给定数组中的第一个项目将是位于任何现有工具栏项目后面的最右边项目。
/// 默认情况下，会显示书签和标签的按钮。
///
/// 如果您希望对按钮的排列方式或显示哪些按钮有更多的控制权，
/// 您可以直接访问预先存在的工具栏项目的属性，并通过重写下面的
/// \c setupToolbarItems 方法手动设置 \c self.toolbarItems。
- (void)addToolbarItems:(NSArray<UIBarButtonItem *> *)items;

/// 子类可以重写。您通常不需要直接调用此方法。
- (void)setupToolbarItems;

@property (nonatomic, readonly) UIBarButtonItem *shareToolbarItem;
@property (nonatomic, readonly) UIBarButtonItem *bookmarksToolbarItem;
@property (nonatomic, readonly) UIBarButtonItem *openTabsToolbarItem;

/// 是否在工具栏中间显示"分享"图标。默认为 NO。
///
/// 在添加自定义工具栏项目后打开此项将推出最左边的
/// 工具栏项目并将其他项目向左移动。
@property (nonatomic) BOOL showsShareToolbarItem;
/// 当分享按钮被按下时调用。
/// 默认实现什么都不做。子类可以重写。
- (void)shareButtonPressed:(UIBarButtonItem *)sender;

/// 子类可以调用此方法以选择退出所有与工具栏相关的行为。
/// 如果您想禁用显示工具栏的手势，这是必要的。
- (void)disableToolbar;

@end
