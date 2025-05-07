// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXSingleRowSection.h
//  FLEX
//
//  由 Tanner Bennett 创建于 9/25/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXTableViewSection.h"

NS_ASSUME_NONNULL_BEGIN

/// 提供特定单行的分区。
///
/// 您可以选择提供一个视图控制器，以便在选择该行时推送，
/// 或者提供一个在选择该行时执行的操作。
/// 首先使用哪一个取决于表格视图数据源。
@interface FLEXSingleRowSection : FLEXTableViewSection

/// @param reuseIdentifier 如果为 nil，则使用 kFLEXDefaultCell。
+ (instancetype)title:(nullable NSString *)sectionTitle
                reuse:(nullable NSString *)reuseIdentifier
                 cell:(void(^)(__kindof UITableViewCell *cell))cellConfiguration;

@property (nullable, nonatomic) UIViewController *pushOnSelection;
@property (nullable, nonatomic) void (^selectionAction)(UIViewController *host);
/// 用于确定单行是否应显示自身。
@property (nonatomic) BOOL (^filterMatcher)(NSString *filterText);

@end

NS_ASSUME_NONNULL_END
