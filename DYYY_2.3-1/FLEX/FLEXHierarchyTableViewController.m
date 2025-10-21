//
//  FLEXHierarchyTableViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-01.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXColor.h"
#import "FLEXHierarchyTableViewController.h"
#import "NSMapTable+FLEX_Subscripting.h"
#import "FLEXUtility.h"
#import "FLEXHierarchyTableViewCell.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXResources.h"
#import "FLEXWindow.h"

typedef NS_ENUM(NSUInteger, FLEXHierarchyScope) {
    FLEXHierarchyScopeFullHierarchy,
    FLEXHierarchyScopeViewsAtTap
};

@interface FLEXHierarchyTableViewController ()

@property (nonatomic) NSArray<UIView *> *allViews;
/// 视图地址到其深度的映射
/// @((uintptr_t)(__bridge void *)view) -> depth
@property (nonatomic) NSMapTable<NSNumber *, NSNumber *> *depthsForViews;
@property (nonatomic) NSArray<UIView *> *viewsAtTap;
@property (nonatomic) NSArray<UIView *> *displayedViews;
@property (nonatomic, readonly) BOOL showScopeBar;

@end

@implementation FLEXHierarchyTableViewController

+ (instancetype)windows:(NSArray<UIWindow *> *)allWindows
             viewsAtTap:(NSArray<UIView *> *)viewsAtTap
           selectedView:(UIView *)selected {
    NSParameterAssert(allWindows.count);

    NSArray *allViews = [self allViewsInHierarchy:allWindows];
    NSMapTable *depths = [self hierarchyDepthsForViews:allViews];
    return [[self alloc] initWithViews:allViews viewsAtTap:viewsAtTap selectedView:selected depths:depths];
}

- (instancetype)initWithViews:(NSArray<UIView *> *)allViews
                   viewsAtTap:(NSArray<UIView *> *)viewsAtTap
                 selectedView:(UIView *)selectedView
                       depths:(NSMapTable<NSNumber *, NSNumber *> *)depthsForViews {
    NSParameterAssert(allViews);
    NSParameterAssert(depthsForViews.count == allViews.count);

    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.allViews = allViews;
        self.depthsForViews = depthsForViews;
        self.viewsAtTap = viewsAtTap;
        self.selectedView = selectedView;
        
        self.title = @"查看层次结构树";
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 在不同场景之间保持选中状态
    self.clearsSelectionOnViewWillAppear = NO;
    
    // 为单元格提供更多空间
    self.tableView.rowHeight = 50.0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    // 分割线缩进会与持久单元格选择冲突
    [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    
    self.showsSearchBar = YES;
    self.showSearchBarInitially = YES;
    // 在此屏幕上使用固定搜索栏会导致
    // 下一个推入的视图控制器出现奇怪的视觉效果。
    //
    // self.pinSearchBar = YES;
    self.searchBarDebounceInterval = kFLEXDebounceInstant;
    self.automaticallyShowsSearchBarCancelButton = NO;
    if (self.showScopeBar) {
        self.searchController.searchBar.showsScopeBar = YES;
        self.searchController.searchBar.scopeButtonTitles = @[@"完整层次结构", @"当前选中视图"];
        self.selectedScope = FLEXHierarchyScopeViewsAtTap;
    }
    
    [self updateDisplayedViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self disableToolbar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self trySelectCellForSelectedView];
}


#pragma mark - 层次结构辅助方法

+ (NSArray<UIView *> *)allViewsInHierarchy:(NSArray<UIWindow *> *)windows {
    return [windows flex_flatmapped:^id(UIWindow *window, NSUInteger idx) {
        if (![window isKindOfClass:[FLEXWindow class]]) {
            return [self viewWithRecursiveSubviews:window];
        }

        return nil;
    }];
}

+ (NSArray<UIView *> *)viewWithRecursiveSubviews:(UIView *)view {
    NSMutableArray<UIView *> *subviews = [NSMutableArray arrayWithObject:view];
    for (UIView *subview in view.subviews) {
        [subviews addObjectsFromArray:[self viewWithRecursiveSubviews:subview]];
    }

    return subviews;
}

+ (NSMapTable<UIView *, NSNumber *> *)hierarchyDepthsForViews:(NSArray<UIView *> *)views {
    NSMapTable<UIView *, NSNumber *> *depths = [NSMapTable strongToStrongObjectsMapTable];
    for (UIView *view in views) {
        NSInteger depth = 0;
        UIView *tryView = view;
        while (tryView.superview) {
            tryView = tryView.superview;
            depth++;
        }
        depths[@((uintptr_t)(__bridge void *)view)] = @(depth);
    }

    return depths;
}


#pragma mark 选择和过滤辅助方法

- (void)trySelectCellForSelectedView {
    NSUInteger selectedViewIndex = [self.displayedViews indexOfObject:self.selectedView];
    if (selectedViewIndex != NSNotFound) {
        UITableViewScrollPosition scrollPosition = UITableViewScrollPositionMiddle;
        NSIndexPath *selectedViewIndexPath = [NSIndexPath indexPathForRow:selectedViewIndex inSection:0];
        [self.tableView selectRowAtIndexPath:selectedViewIndexPath animated:YES scrollPosition:scrollPosition];
    }
}

- (void)updateDisplayedViews {
    NSArray<UIView *> *candidateViews = nil;
    if (self.showScopeBar) {
        if (self.selectedScope == FLEXHierarchyScopeViewsAtTap) {
            candidateViews = self.viewsAtTap;
        } else if (self.selectedScope == FLEXHierarchyScopeFullHierarchy) {
            candidateViews = self.allViews;
        }
    } else {
        candidateViews = self.allViews;
    }
    
    if (self.searchText.length) {
        self.displayedViews = [candidateViews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *candidateView, NSDictionary<NSString *, id> *bindings) {
            NSString *title = [FLEXUtility descriptionForView:candidateView includingFrame:NO];
            NSString *candidateViewPointerAddress = [NSString stringWithFormat:@"%p", candidateView];
            BOOL matchedViewPointerAddress = [candidateViewPointerAddress rangeOfString:self.searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL matchedViewTitle = [title rangeOfString:self.searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
            return matchedViewPointerAddress || matchedViewTitle;
        }]];
    } else {
        self.displayedViews = candidateViews;
    }
    
    [self.tableView reloadData];
}

- (void)setSelectedView:(UIView *)selectedView {
    _selectedView = selectedView;
    if (self.isViewLoaded) {
        [self trySelectCellForSelectedView];
    }
}


#pragma mark - 搜索栏 / 范围栏

- (BOOL)showScopeBar {
    return self.viewsAtTap.count > 0;
}

- (void)updateSearchResults:(NSString *)newText {
    [self updateDisplayedViews];
    
    // 如果搜索栏文本字段处于活动状态，请不要滚动到选中项，因为我们可能
    // 想继续输入。否则，滚动让选中的单元格可见。
    if (!self.searchController.searchBar.isFirstResponder) {
        [self trySelectCellForSelectedView];
    }
}


#pragma mark - 表视图数据源

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayedViews.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    FLEXHierarchyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[FLEXHierarchyTableViewCell alloc] initWithReuseIdentifier:CellIdentifier];
    }
    
    UIView *view = self.displayedViews[indexPath.row];

    cell.textLabel.text = [FLEXUtility descriptionForView:view includingFrame:NO];
    cell.detailTextLabel.text = [FLEXUtility detailDescriptionForView:view];
    cell.randomColorTag = [FLEXUtility consistentRandomColorForObject:view];
    cell.viewDepth = self.depthsForViews[@((uintptr_t)(__bridge void *)view)].integerValue;
    cell.indicatedViewColor = view.backgroundColor;

    if (view.isHidden || view.alpha < 0.01) {
        cell.textLabel.textColor = FLEXColor.deemphasizedTextColor;
        cell.detailTextLabel.textColor = FLEXColor.deemphasizedTextColor;
    } else {
        cell.textLabel.textColor = FLEXColor.primaryTextColor;
        cell.detailTextLabel.textColor = FLEXColor.primaryTextColor;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    _selectedView = self.displayedViews[indexPath.row]; // Don't scroll, avoid setter
    if (self.didSelectRowAction) {
        self.didSelectRowAction(_selectedView);
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    UIView *drillInView = self.displayedViews[indexPath.row];
    FLEXObjectExplorerViewController *viewExplorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:drillInView];
    [self.navigationController pushViewController:viewExplorer animated:YES];
}

@end
