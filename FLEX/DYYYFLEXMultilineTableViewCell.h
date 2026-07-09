//
//  DYYYFLEXMultilineTableViewCell.h
//  FLEX
//
//  Created by Ryan Olson on 2/13/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXTableViewCell.h"

/// A cell with both labels set to be multi-line capable.
@interface DYYYFLEXMultilineTableViewCell : DYYYFLEXTableViewCell

+ (CGFloat)preferredHeightWithAttributedText:(NSAttributedString *)attributedText
                                    maxWidth:(CGFloat)contentViewWidth
                                       style:(UITableViewStyle)style
                              showsAccessory:(BOOL)showsAccessory;

@end

/// A \c DYYYFLEXMultilineTableViewCell initialized with \c UITableViewCellStyleSubtitle
@interface DYYYFLEXMultilineDetailTableViewCell : DYYYFLEXMultilineTableViewCell

@end
