//
//  DYYYFLEXTableLeftCell.m
//  FLEX
//
//  Created by Peng Tao on 15/11/24.
//  Copyright © 2015年 f. All rights reserved.
//

#import "DYYYFLEXTableLeftCell.h"

@implementation DYYYFLEXTableLeftCell

+ (instancetype)cellWithTableView:(UITableView *)tableView {
    static NSString *identifier = @"DYYYFLEXTableLeftCell";
    DYYYFLEXTableLeftCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (!cell) {
        cell = [[DYYYFLEXTableLeftCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
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
