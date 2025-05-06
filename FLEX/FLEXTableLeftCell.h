//
//  FLEXTableLeftCell.h
//  FLEX
//
//  Created by Peng Tao on 15/11/24.
//  Copyright © 2015年 f. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@interface FLEXTableLeftCell : UITableViewCell

@property (nonatomic) UILabel *titlelabel;

+ (instancetype)cellWithTableView:(UITableView *)tableView;

@end
