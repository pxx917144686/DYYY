//
//  FLEXTabList.h
//  FLEX
//
//  由 Tanner 创建于 2/1/20.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXTabList : NSObject

@property (nonatomic, readonly, class) FLEXTabList *sharedList;

@property (nonatomic, readonly, nullable) UINavigationController *activeTab;
@property (nonatomic, readonly) NSArray<UINavigationController *> *openTabs;
/// 每个标签最后活跃时的快照。
@property (nonatomic, readonly) NSArray<UIImage *> *openTabSnapshots;
/// 如果没有标签存在，则为 \c NSNotFound。
/// 设置此属性会将活动标签更改为已打开标签中的一个。
@property (nonatomic) NSInteger activeTabIndex;

/// 添加新标签并将新标签设置为活动标签。
- (void)addTab:(UINavigationController *)newTab;
/// 关闭给定的标签。如果此标签是活动标签，
/// 则在此之前最近的标签成为活动标签。
- (void)closeTab:(UINavigationController *)tab;
/// 关闭给定索引处的标签。如果此标签是活动标签，
/// 则在此之前最近的标签成为活动标签。
- (void)closeTabAtIndex:(NSInteger)idx;
/// 关闭给定索引处的所有标签。如果包含活动标签，
/// 则最近仍打开的标签成为活动标签。
- (void)closeTabsAtIndexes:(NSIndexSet *)indexes;
/// 关闭活动标签的快捷方式。
- (void)closeActiveTab;
/// 关闭\e所有标签的快捷方式。
- (void)closeAllTabs;

- (void)updateSnapshotForActiveTab;

@end

NS_ASSUME_NONNULL_END
