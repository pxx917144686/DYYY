//
//  FLEXFilteringTableViewController.h
//  FLEX
//
//  Created by Tanner on 3/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewController.h"

#pragma mark - FLEXTableViewFiltering
@protocol FLEXTableViewFiltering <FLEXSearchResultsUpdating>

/// 可见的、"已过滤"部分的数组。例如，
/// 如果你在 \c allSections 中有3个部分，而用户搜索
/// 的内容只匹配一个部分中的行，那么
/// 该属性将只包含那个匹配的部分。
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *sections;
/// 所有可能部分的数组。空的部分将被移除
/// 并且结果数组存储在 \c section 属性中。设置
/// 此属性应立即将 \c sections 设置为 \c nonemptySections
///
/// 不要手动初始化此属性，它将会
/// 使用 \c makeSections 的结果为你初始化。
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *allSections;

/// 此计算属性应过滤 \c allSections 以分配给 \c sections
@property (nonatomic, readonly, copy) NSArray<FLEXTableViewSection *> *nonemptySections;

/// 这应该能够重新初始化 \c allSections
- (NSArray<FLEXTableViewSection *> *)makeSections;

@end


#pragma mark - FLEXFilteringTableViewController
/// 一个表视图，使用由特殊代理提供的
/// \c FLEXTableViewSection 对象数组实现 \c UITableView* 方法。
@interface FLEXFilteringTableViewController : FLEXTableViewController <FLEXTableViewFiltering>

/// 存储当前搜索查询。
@property (nonatomic, copy) NSString *filterText;

/// 此属性默认设置为 \c self。
///
/// 此属性用于自动处理表视图的几乎所有数据源
/// 和代理方法，包括当用户搜索时的行和部分过滤，
/// 3D Touch上下文菜单，行选择等。
///
/// 设置此属性也会将 \c searchDelegate 设置为该对象。
@property (nonatomic, weak) id<FLEXTableViewFiltering> filterDelegate;

/// 默认为 \c NO。如果启用，所有过滤将通过调用
/// \c onBackgroundQueue:thenOnMainQueue: 完成，并在主队列上更新UI。
@property (nonatomic) BOOL filterInBackground;

/// 默认为 \c NO。如果启用，将为每个部分提供一个 • 作为索引标题。
@property (nonatomic) BOOL wantsSectionIndexTitles;

/// 重新计算非空部分并重新加载表视图。
///
/// 子类可能会重写以执行额外的重新加载逻辑，
/// 如在需要时调用 \c -reloadSections。确保在任何
/// 会影响表视图外观的逻辑之后调用 \c super，
/// 因为表视图最后被重新加载。
///
/// 在此类实现的 \c updateSearchResults: 末尾调用
- (void)reloadData;

/// 调用此方法以在 \c self.filterDelegate.allSections
/// 中的每个部分上调用 \c -reloadData。
- (void)reloadSections;

#pragma mark FLEXTableViewFiltering

@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *sections;
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *allSections;

/// 如果使用 \c self 作为 \c filterDelegate（这是默认设置），
/// 子类可以重写以在特定条件下隐藏特定部分。
///
/// 例如，对象浏览器在搜索时会隐藏描述部分。
@property (nonatomic, readonly, copy) NSArray<FLEXTableViewSection *> *nonemptySections;

/// 如果使用 \c self 作为 \c filterDelegate（这是默认设置），
/// 子类应重写以提供表视图的部分。
- (NSArray<FLEXTableViewSection *> *)makeSections;

@end
