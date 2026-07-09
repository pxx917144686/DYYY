//
//  DYYYFLEXDBQueryRowCell.h
//  FLEX
//
//  Created by Peng Tao on 15/11/24.
//  Copyright © 2015年 f. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DYYYFLEXDBQueryRowCell;

extern NSString * const kFLEXDBQueryRowCellReuse;

@protocol FLEXDBQueryRowCellLayoutSource <NSObject>

- (CGFloat)dbQueryRowCell:(DYYYFLEXDBQueryRowCell *)dbQueryRowCell minXForColumn:(NSUInteger)column;
- (CGFloat)dbQueryRowCell:(DYYYFLEXDBQueryRowCell *)dbQueryRowCell widthForColumn:(NSUInteger)column;

@end

@interface DYYYFLEXDBQueryRowCell : UITableViewCell

/// An array of NSString, NSNumber, or NSData objects
@property (nonatomic) NSArray *data;
@property (nonatomic, weak) id<FLEXDBQueryRowCellLayoutSource> layoutSource;

@end
