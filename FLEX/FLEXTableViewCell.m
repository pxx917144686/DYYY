//
//  FLEXTableViewCell.m
//  FLEX
//
//  Created by Tanner on 4/17/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewCell.h"
#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "FLEXTableView.h"

@interface UITableView (Internal)
- (BOOL)_canPerformAction:(SEL)action forCell:(UITableViewCell *)cell sender:(id)sender;
- (void)_performAction:(SEL)action forCell:(UITableViewCell *)cell sender:(id)sender;
@end

@interface UITableViewCell (Internal)
@property (nonatomic, readonly) FLEXTableView *_tableView;
@end

@implementation FLEXTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self postInit];
    }

    return self;
}

- (void)postInit {
    UIFont *cellFont = UIFont.flex_defaultTableCellFont;
    self.titleLabel.font = cellFont;
    self.subtitleLabel.font = cellFont;
    self.subtitleLabel.textColor = FLEXColor.deemphasizedTextColor;
    
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    self.titleLabel.numberOfLines = 1;
    self.subtitleLabel.numberOfLines = 1;
}

- (UILabel *)titleLabel {
    return self.textLabel;
}

- (UILabel *)subtitleLabel {
    return self.detailTextLabel;
}

@end
