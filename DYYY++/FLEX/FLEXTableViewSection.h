//
//  FLEXTableViewSection.h
//  FLEX
//
//  由 Tanner 创建于 1/29/20.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import <UIKit/UIKit.h>
#import "NSArray+FLEX.h"
@class FLEXTableView;

NS_ASSUME_NONNULL_BEGIN

#pragma mark FLEXTableViewSection

/// 表视图区段的抽象基类。
///
/// 这里的许多属性或方法默认返回 nil 或某些逻辑等效项。
/// 即便如此，大多数带有默认值的方法都旨在被子类重写。
/// 有些方法根本没有实现，必须由子类实现。
@interface FLEXTableViewSection : NSObject {
    @protected
    /// 默认未使用，根据需要使用
    NSString *_title;
    
    @private
    __weak UITableView *_tableView;
    NSInteger _sectionIndex;
}

#pragma mark - 数据

/// 为自定义区段显示的标题。
/// 子类可以重写或使用 \c _title 实例变量。
@property (nonatomic, readonly, nullable, copy) NSString *title;
/// 本区段中的行数。子类必须重写。
/// 这不应该改变，直到 \c filterText 改变或调用 \c reloadData。
@property (nonatomic, readonly) NSInteger numberOfRows;
/// 重用标识符到 \c UITableViewCell（子）类对象的映射。
/// 子类\e 可以根据需要重写此项，但不是必需的。
/// 有关更多信息，请参见 \c FLEXTableView.h。
/// @return 默认为 nil。
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, Class> *cellRegistrationMapping;

/// 区段应该根据此属性的内容进行自我过滤。
/// 如果设置为 nil 或空字符串，则不应过滤。
/// 子类应重写或观察此属性并对更改做出反应。
///
/// 使用两个数组作为底层模型是常见做法：
/// 一个用于保存所有行，一个用于保存未过滤的行。当 \c setFilterText:
/// 被调用时，调用 \c super 来存储新值，并相应地重新过滤您的模型。
@property (nonatomic, nullable) NSString *filterText;

/// 为区段提供刷新数据或更改行数的途径。
///
/// 这在重新加载表视图本身之前被调用。如果您的区段从外部数据源拉取数据，
/// 这是完全刷新该数据的好地方。
/// 如果您的区段不这样做，那么仅仅重写
/// \c setFilterText: 来调用 \c super 并调用 \c reloadData 可能会更简单。
- (void)reloadData;

/// 类似于 \c reloadData，但可选择重新加载与此区段对象关联的表视图区段（如果有）。
/// 不要重写。不要在主线程之外调用。
- (void)reloadData:(BOOL)updateTable;

/// 提供表视图和区段索引，以允许当某些内容更改时，区段能够高效地重新加载表中的自己的区段。
/// 表引用被弱引用，子类无法访问它或索引。如果自上次调用此方法以来区段编号已更改，
/// 请再次调用此方法。
- (void)setTable:(UITableView *)tableView section:(NSInteger)index;

#pragma mark - 行选择

/// 给定行是否应该是可选择的，例如点击单元格是否应该
/// 将用户带到新屏幕或触发操作。
/// 子类 \e 可以根据需要重写此项，但不是必需的。
/// @return 默认为 \c NO
- (BOOL)canSelectRow:(NSInteger)row;

/// 当行被选中时要触发的动作"未来"，如果行
/// 支持被选中，如 \c canSelectRow: 所示。子类
/// 必须根据他们如何实现 \c canSelectRow: 来实现这一点
/// 如果他们没有实现 \c viewControllerToPushForRow:
/// @return 如果 \c viewControllerToPushForRow: 没有提供视图控制器，则返回 \c nil
/// 否则，它将该视图控制器推到 \c host.navigationController 上
- (nullable void(^)(__kindof UIViewController *host))didSelectRowAction:(NSInteger)row;

/// 行被选中时要显示的视图控制器，如果行
/// 支持被选中，如 \c canSelectRow: 所示。子类
/// 必须根据他们如何实现 \c canSelectRow: 来实现这一点
/// 如果他们没有实现 \c didSelectRowAction:
/// @return 默认为 \c nil
- (nullable UIViewController *)viewControllerToPushForRow:(NSInteger)row;

/// 当附加视图的详情按钮被按下时调用。
/// @return 默认为 \c nil。
- (nullable void(^)(__kindof UIViewController *host))didPressInfoButtonAction:(NSInteger)row;

#pragma mark - 上下文菜单

/// 默认情况下，这是行的标题。
/// @return 上下文菜单的标题（如果有）。
- (nullable NSString *)menuTitleForRow:(NSInteger)row API_AVAILABLE(ios(13.0));
/// 受保护，不打算公开使用。\c menuTitleForRow:
/// 已经包含从此方法返回的值。
/// 
/// 默认情况下，这返回 \c @""。子类可以重写以
/// 提供上下文菜单目标的详细描述。
- (NSString *)menuSubtitleForRow:(NSInteger)row API_AVAILABLE(ios(13.0));
/// 上下文菜单项（如果有）。子类可以重写。
/// 默认情况下，只包括 \c copyMenuItemsForRow: 的项目。
- (nullable NSArray<UIMenuElement *> *)menuItemsForRow:(NSInteger)row sender:(UIViewController *)sender API_AVAILABLE(ios(13.0));
/// 子类可以重写以返回可复制项目的列表。
///
/// 列表中的每两个元素组成一个键值对，其中键
/// 应该是将要复制内容的描述，值应该是
/// 要复制的字符串。返回空字符串作为值显示禁用的操作。
- (nullable NSArray<NSString *> *)copyMenuItemsForRow:(NSInteger)row API_AVAILABLE(ios(13.0));

#pragma mark - 单元格配置

/// 为给定行提供重用标识符。子类应该重写。
///
/// 自定义重用标识符应在 \c cellRegistrationMapping 中指定。
/// 您可以返回 \c FLEXTableView.h 中的任何标识符
/// 而无需将它们包含在 \c cellRegistrationMapping 中。
/// @return 默认为 \c kFLEXDefaultCell。
- (NSString *)reuseIdentifierForRow:(NSInteger)row;
/// 为给定行配置单元格。子类必须重写。
- (void)configureCell:(__kindof UITableViewCell *)cell forRow:(NSInteger)row;

#pragma mark - 外部便利方法

/// 供使用您的区段的任何视图控制器使用。非必需。
/// @return 可选标题。
- (nullable NSString *)titleForRow:(NSInteger)row;
/// 供使用您的区段的任何视图控制器使用。非必需。
/// @return 可选副标题。
- (nullable NSString *)subtitleForRow:(NSInteger)row;

@end

NS_ASSUME_NONNULL_END
