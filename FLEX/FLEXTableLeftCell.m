// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTableLeftCell.m
//  FLEX
//
//  由 Peng Tao 创建于 15/11/24.
//  版权所有 © 2015年 f。保留所有权利。

#import "FLEXTableLeftCell.h"

@implementation FLEXTableLeftCell

+ (instancetype)cellWithTableView:(UITableView *)tableView {
    static NSString *identifier = @"FLEXTableLeftCell";
    FLEXTableLeftCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (!cell) {
        cell = [[FLEXTableLeftCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        UILabel *textLabel               = [UILabel new];
        textLabel.textAlignment          = NSTextAlignmentCenter;
        textLabel.font                   = [UIFont systemFontOfSize:13.0];
        [cell.contentView addSubview:textLabel];
        cell.titlelabel = textLabel;
    }
    
    return cell;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.titlelabel.frame = self.contentView.frame;
}
@end
