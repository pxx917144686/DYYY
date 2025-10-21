//
//  FLEXTableViewCell.h
//  FLEX
//
//  由 Tanner 创建于 4/17/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import <UIKit/UIKit.h>

@interface FLEXTableViewCell : UITableViewCell

/// 使用这个代替 .textLabel
@property (nonatomic, readonly) UILabel *titleLabel;
/// 使用这个代替 .detailTextLabel
@property (nonatomic, readonly) UILabel *subtitleLabel;

/// 子类可以重写这个方法而不是初始化器，
/// 以执行额外的初始化，而无需大量的样板代码。
/// 记得调用 super！
- (void)postInit;

@end
