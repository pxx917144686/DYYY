// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMutableListSection.h
//  FLEX
//
//  由 Tanner 创建于 3/9/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXCollectionContentSection.h"

typedef void (^FLEXMutableListCellForElement)(__kindof UITableViewCell *cell, id element, NSInteger row);

/// 一个旨在满足具有一个分区的表视图需求的类
/// （或者，一个不应该因为为某个特定表视图创建新分区而导致代码重复的分区）
///
/// 如果要显示不断增长的行列表，甚至要显示静态行列表，请使用此分区。
///
/// 要支持编辑或插入，请在表视图委托类中实现相应的
/// 表视图委托方法，并在更新表视图之前调用 \c mutate: （或 \c setList: ）。
///
/// 默认情况下，不显示分区标题。将其分配给 \c customTitle
///
/// 默认情况下，\c kFLEXDetailCell 是使用的重用标识符。如果需要在单个分区中支持多个重用标识符，
/// 请实现 \c cellForRowAtIndexPath: 方法，自行出队单元格，并在适当的分区对象上调用
/// \c -configureCell:，传入单元格
@interface FLEXMutableListSection<__covariant ObjectType> : FLEXCollectionContentSection

/// 使用空列表初始化一个分区。
+ (instancetype)list:(NSArray<ObjectType> *)list
   cellConfiguration:(FLEXMutableListCellForElement)configurationBlock
       filterMatcher:(BOOL(^)(NSString *filterText, id element))filterBlock;

/// 默认情况下，行不可选择。如果希望行
/// 可选择，请在此处提供选择处理程序。
@property (nonatomic, copy) void (^selectionHandler)(__kindof UIViewController *host, ObjectType element);

/// 表示分区中所有可能行的对象。
@property (nonatomic) NSArray<ObjectType> *list;
/// 表示分区中当前未过滤行的对象。
@property (nonatomic, readonly) NSArray<ObjectType> *filteredList;

/// \c FLEXTableViewSection.h 中相同属性的可读写版本。
///
/// 此属性需要一个条目。如果提供了多个条目，则会引发异常。
/// 如果在单个分区中需要多个重用标识符，则您的视图可能比此类可以处理的更复杂。
@property (nonatomic, readwrite) NSDictionary<NSString *, Class> *cellRegistrationMapping;

/// 调用此方法以更改完整的、未过滤的列表。
/// 这可确保在任何更改后更新 \c filteredList。
- (void)mutate:(void(^)(NSMutableArray *list))block;

@end
