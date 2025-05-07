// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTabList.h
//  FLEX
//
//  由 Tanner 创建于 2/1/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXTabList : NSObject

@property (nonatomic, readonly, class) FLEXTabList *sharedList;

@property (nonatomic, readonly, nullable) UINavigationController *activeTab;
@property (nonatomic, readonly) NSArray<UINavigationController *> *openTabs;
/// 每个选项卡上次活动时的快照。
@property (nonatomic, readonly) NSArray<UIImage *> *openTabSnapshots;
/// 如果没有选项卡，则为 \c NSNotFound。
/// 设置此属性会将活动选项卡更改为已打开的选项卡之一。
@property (nonatomic) NSInteger activeTabIndex;

/// 添加一个新选项卡并将新选项卡设置为活动选项卡。
- (void)addTab:(UINavigationController *)newTab;
/// 关闭给定的选项卡。如果此选项卡是活动选项卡，
/// 则之前的最新选项卡将成为活动选项卡。
- (void)closeTab:(UINavigationController *)tab;
/// 关闭给定索引处的选项卡。如果此选项卡是活动选项卡，
/// 则之前的最新选项卡将成为活动选项卡。
- (void)closeTabAtIndex:(NSInteger)idx;
/// 关闭给定索引处的所有选项卡。如果包含活动选项卡，
/// 则最新的仍处于打开状态的选项卡将成为活动选项卡。
- (void)closeTabsAtIndexes:(NSIndexSet *)indexes;
/// 关闭活动选项卡的快捷方式。
- (void)closeActiveTab;
/// 关闭\e所有选项卡的快捷方式。
- (void)closeAllTabs;

- (void)updateSnapshotForActiveTab;

@end

NS_ASSUME_NONNULL_END
