//
//  DYYYFLEXTableViewCell.m
//  FLEX
//
//  Created by Tanner on 4/17/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXTableViewCell.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXColor.h"
#import "DYYYFLEXTableView.h"

@interface UITableView (Internal)
// Exists at least since iOS 5
- (BOOL)_canPerformAction:(SEL)action forCell:(UITableViewCell *)cell sender:(id)sender;
- (void)_performAction:(SEL)action forCell:(UITableViewCell *)cell sender:(id)sender;
@end

@interface UITableViewCell (Internal)
// Exists at least since iOS 5
@property (nonatomic, readonly) DYYYFLEXTableView *_tableView;
@end

@implementation DYYYFLEXTableViewCell

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
    self.subtitleLabel.textColor = DYYYFLEXColor.deemphasizedTextColor;
    
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
