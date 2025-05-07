// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMultilineTableViewCell.h
//  FLEX
//
//  由 Ryan Olson 创建于 2/13/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXTableViewCell.h"

/// 一个标签均设置为能够多行显示的单元格。
@interface FLEXMultilineTableViewCell : FLEXTableViewCell

+ (CGFloat)preferredHeightWithAttributedText:(NSAttributedString *)attributedText
                                    maxWidth:(CGFloat)contentViewWidth
                                       style:(UITableViewStyle)style
                              showsAccessory:(BOOL)showsAccessory;

@end

/// 使用 \c UITableViewCellStyleSubtitle 初始化的 \c FLEXMultilineTableViewCell
@interface FLEXMultilineDetailTableViewCell : FLEXMultilineTableViewCell

@end
