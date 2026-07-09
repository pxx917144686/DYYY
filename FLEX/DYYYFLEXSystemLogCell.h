//
//  DYYYFLEXSystemLogCell.h
//  FLEX
//
//  Created by Ryan Olson on 1/25/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXTableViewCell.h"

@class DYYYFLEXSystemLogMessage;

extern NSString *const kFLEXSystemLogCellIdentifier;

@interface DYYYFLEXSystemLogCell : DYYYFLEXTableViewCell

@property (nonatomic) DYYYFLEXSystemLogMessage *logMessage;
@property (nonatomic, copy) NSString *highlightedText;

+ (NSString *)displayedTextForLogMessage:(DYYYFLEXSystemLogMessage *)logMessage;
+ (CGFloat)preferredHeightForLogMessage:(DYYYFLEXSystemLogMessage *)logMessage inWidth:(CGFloat)width;

@end
