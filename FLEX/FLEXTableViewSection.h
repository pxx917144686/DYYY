// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTableViewSection.h
//  FLEX
//
//  由 Tanner 创建于 1/29/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。

#import <UIKit/UIKit.h>
#import "NSArray+FLEX.h"
@class FLEXTableView;

NS_ASSUME_NONNULL_BEGIN

#pragma mark FLEXTableViewSection

/// 表格视图分区的抽象基类。
///
/// 这里的许多属性或方法默认返回 nil 或某些逻辑等效值。
/// 即便如此，大多数具有默认值的方法都旨在由子类重写。
/// 有些方法根本没有实现，必须由子类实现。
@interface FLEXTableViewSection : NSObject {
    @protected
    /// 默认未使用，如果需要可以使用
    NSString *_title;
    
    @private
    __weak UITableView *_tableView;
    NSInteger _sectionIndex;
}

#pragma mark - 数据

/// 要为自定义分区显示的标题。
/// 子类可以重写或使用 \c _title 实例变量。
@property (nonatomic, readonly, nullable, copy) NSString *title;
/// 此分区中的行数。子类必须重写。
/// 在 \c filterText 更改或调用 \c reloadData 之前，此值不应更改。
@property (nonatomic, readonly) NSInteger numberOfRows;
/// 重用标识符到 \c UITableViewCell (子)类对象的映射。
/// 子类 \e 可以根据需要重写此项，但不是必需的。
/// 有关更多信息，请参见 \c FLEXTableView.h。
/// @return 默认返回 nil。
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, Class> *cellRegistrationMapping;

/// 分区应根据此属性的内容在设置时自行筛选。
/// 如果将其设置为空或空字符串，则不应筛选。
/// 子类应重写或观察此属性并对更改做出反应。
///
/// 通常的做法是为底层模型使用两个数组：
/// 一个用于保存所有行，另一个用于保存未筛选的行。当调用 \c setFilterText:
/// 时，调用 \c super 来存储新值，并相应地重新筛选您的模型。
@property (nonatomic, nullable) NSString *filterText;

/// 为分区提供刷新数据或更改行数的途径。
///
/// 这在重新加载表格视图本身之前调用。如果您的分区从外部数据源提取数据，
/// 那么这里是完全刷新该数据的好地方。
/// 如果您的分区不这样做，那么您可能只需重写
/// \c setFilterText: 来调用 \c super 并调用 \c reloadData 会更简单。
- (void)reloadData;

/// 类似于 \c reloadData，但可选地重新加载与此分区对象关联的表格视图分区（如果存在）。
/// 不要重写。不要在主线程之外调用。
- (void)reloadData:(BOOL)updateTable;

/// 提供一个表格视图和分区索引，以允许分区在某些内容更改时有效地重新加载其自己的表格部分。
/// 表格引用是弱持有的，子类无法访问它或索引。
/// 如果自分区号上次调用以来已更改，请再次调用此方法。
- (void)setTable:(UITableView *)tableView section:(NSInteger)index;

#pragma mark - 行选择

/// 给定的行是否应该可选，例如点击单元格是否应将用户带到新屏幕或触发操作。
/// 子类 \e 可以根据需要重写此项，但不是必需的。
/// @return 默认返回 \c NO
- (BOOL)canSelectRow:(NSInteger)row;

/// 当选择行时要触发的操作“future”，如果行支持通过 \c canSelectRow: 指示的选择。
/// 如果子类不实现 \c viewControllerToPushForRow:，则必须根据其实现 \c canSelectRow: 的方式来实现此方法。
/// @return 如果 \c viewControllerToPushForRow: 未提供视图控制器，则返回 \c nil
/// — 否则它会将该视图控制器推送到 \c host.navigationController
- (nullable void(^)(__kindof UIViewController *host))didSelectRowAction:(NSInteger)row;

/// 当选择行时要显示的视图控制器，如果行支持通过 \c canSelectRow: 指示的选择。
/// 如果子类不实现 \c didSelectRowAction:，则必须根据其实现 \c canSelectRow: 的方式来实现此方法。
/// @return 默认返回 \c nil
- (nullable UIViewController *)viewControllerToPushForRow:(NSInteger)row;

/// 当附件视图的详细信息按钮被按下时调用。
/// @return 默认返回 \c nil。
- (nullable void(^)(__kindof UIViewController *host))didPressInfoButtonAction:(NSInteger)row;

#pragma mark - 单元格配置

/// 为给定行提供重用标识符。子类应重写。
///
/// 自定义重用标识符应在 \c cellRegistrationMapping 中指定。
/// 您可以返回 \c FLEXTableView.h 中的任何标识符，而无需将它们包含在 \c cellRegistrationMapping 中。
/// @return 默认返回 \c kFLEXDefaultCell。
- (NSString *)reuseIdentifierForRow:(NSInteger)row;
/// 为给定行配置单元格。子类必须重写。
- (void)configureCell:(__kindof UITableViewCell *)cell forRow:(NSInteger)row;

#pragma mark - 外部便利

/// 供使用您分区的任何视图控制器使用。不是必需的。
/// @return 可选标题。
- (nullable NSString *)titleForRow:(NSInteger)row;
/// 供使用您分区的任何视图控制器使用。不是必需的。
/// @return 可选副标题。
- (nullable NSString *)subtitleForRow:(NSInteger)row;

#pragma mark - 菜单支持

/// 获取菜单的标题
/// @param row 行号
- (NSString *)menuTitleForRow:(NSInteger)row;

/// 获取菜单项
/// @param row 行号
/// @param sender 发送者视图控制器
- (NSArray<UIMenuElement *> *)menuItemsForRow:(NSInteger)row sender:(UIViewController *)sender API_AVAILABLE(ios(13.0));

@end

NS_ASSUME_NONNULL_END
