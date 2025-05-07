// 遇到问题联系中文翻译作者：pxx917144686
//
//  PTMultiColumnTableView.h
//  PTMultiColumnTableViewDemo
//
//  由 Peng Tao 创建于 15/11/16.
//  版权所有 © 2015年 Peng Tao。保留所有权利。
//

#import <UIKit/UIKit.h>
#import "FLEXTableColumnHeader.h"

@class FLEXMultiColumnTableView;

@protocol FLEXMultiColumnTableViewDelegate <NSObject>

@required
- (void)multiColumnTableView:(FLEXMultiColumnTableView *)tableView didSelectRow:(NSInteger)row;
- (void)multiColumnTableView:(FLEXMultiColumnTableView *)tableView didSelectHeaderForColumn:(NSInteger)column sortType:(FLEXTableColumnHeaderSortType)sortType;

@end

@protocol FLEXMultiColumnTableViewDataSource <NSObject>

@required

- (NSInteger)numberOfColumnsInTableView:(FLEXMultiColumnTableView *)tableView;
- (NSInteger)numberOfRowsInTableView:(FLEXMultiColumnTableView *)tableView;
- (NSString *)columnTitle:(NSInteger)column;
- (NSString *)rowTitle:(NSInteger)row;
- (NSArray<NSString *> *)contentForRow:(NSInteger)row;

- (CGFloat)multiColumnTableView:(FLEXMultiColumnTableView *)tableView minWidthForContentCellInColumn:(NSInteger)column;
- (CGFloat)multiColumnTableView:(FLEXMultiColumnTableView *)tableView heightForContentCellInRow:(NSInteger)row;
- (CGFloat)heightForTopHeaderInTableView:(FLEXMultiColumnTableView *)tableView;
- (CGFloat)widthForLeftHeaderInTableView:(FLEXMultiColumnTableView *)tableView;

@end


@interface FLEXMultiColumnTableView : UIView

@property (nonatomic, weak) id<FLEXMultiColumnTableViewDataSource> dataSource;
@property (nonatomic, weak) id<FLEXMultiColumnTableViewDelegate> delegate;

- (void)reloadData;

@end
