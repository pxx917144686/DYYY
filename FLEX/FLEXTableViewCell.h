// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTableViewCell.h
//  FLEX
//
//  由 Tanner 创建于 4/17/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

@interface FLEXTableViewCell : UITableViewCell

/// 请使用此属性替代 .textLabel
@property (nonatomic, readonly) UILabel *titleLabel;
/// 请使用此属性替代 .detailTextLabel
@property (nonatomic, readonly) UILabel *subtitleLabel;

/// 子类可以重写此方法而不是初始化方法，
/// 以执行额外的初始化，而无需大量样板代码。
/// 记住调用 super！
- (void)postInit;

@end
