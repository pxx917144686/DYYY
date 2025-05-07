//
//  FLEXDBQueryRowCell.h
//  FLEX
//
//  创建者：Peng Tao，日期：15/11/24.
//  版权所有 © 2015年 f。保留所有权利。
//

// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@class FLEXDBQueryRowCell;

extern NSString * const kFLEXDBQueryRowCellReuse;

@protocol FLEXDBQueryRowCellLayoutSource <NSObject>

- (CGFloat)dbQueryRowCell:(FLEXDBQueryRowCell *)dbQueryRowCell minXForColumn:(NSUInteger)column;
- (CGFloat)dbQueryRowCell:(FLEXDBQueryRowCell *)dbQueryRowCell widthForColumn:(NSUInteger)column;

@end

@interface FLEXDBQueryRowCell : UITableViewCell

/// NSString、NSNumber 或 NSData 对象的数组
@property (nonatomic) NSArray *data;
@property (nonatomic, weak) id<FLEXDBQueryRowCellLayoutSource> layoutSource;

@end
