// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTableView.h
//  FLEX
//
//  由 Tanner 创建于 4/17/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark 重用标识符

typedef NSString * FLEXTableViewCellReuseIdentifier;

/// 使用 \c UITableViewCellStyleDefault 初始化的常规 \c FLEXTableViewCell
extern FLEXTableViewCellReuseIdentifier const kFLEXDefaultCell;
/// 使用 \c UITableViewCellStyleSubtitle 初始化的 \c FLEXSubtitleTableViewCell
extern FLEXTableViewCellReuseIdentifier const kFLEXDetailCell;
/// 使用 \c UITableViewCellStyleDefault 初始化的 \c FLEXMultilineTableViewCell
extern FLEXTableViewCellReuseIdentifier const kFLEXMultilineCell;
/// 使用 \c UITableViewCellStyleSubtitle 初始化的 \c FLEXMultilineTableViewCell
extern FLEXTableViewCellReuseIdentifier const kFLEXMultilineDetailCell;
/// 使用 \c UITableViewCellStyleValue1 初始化的 \c FLEXTableViewCell
extern FLEXTableViewCellReuseIdentifier const kFLEXKeyValueCell;
/// 一个 \c FLEXSubtitleTableViewCell，其两个标签均使用等宽字体
extern FLEXTableViewCellReuseIdentifier const kFLEXCodeFontCell;

#pragma mark - FLEXTableView
@interface FLEXTableView : UITableView

+ (instancetype)flexDefaultTableView;
+ (instancetype)groupedTableView;
+ (instancetype)plainTableView;
+ (instancetype)style:(UITableViewStyle)style;

/// 您无需为上述任何默认重用标识符（标记为 \c FLEXTableViewCellReuseIdentifier 类型）注册类，
/// 除非您希望为这些重用标识符中的任何一个提供自定义单元格。默认情况下，分别使用
/// \c FLEXTableViewCell、\c FLEXSubtitleTableViewCell 和 \c FLEXMultilineTableViewCell。
///
/// @param registrationMapping 重用标识符到 \c UITableViewCell (子)类对象的映射。
- (void)registerCells:(NSDictionary<NSString *, Class> *)registrationMapping;

@end

NS_ASSUME_NONNULL_END
