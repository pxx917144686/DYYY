//
//  PTMultiColumnTableView.h
//  PTMultiColumnTableViewDemo
//
//  Created by Peng Tao on 15/11/16.
//  Copyright © 2015年 Peng Tao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DYYYFLEXTableColumnHeader.h"

@class DYYYFLEXMultiColumnTableView;

@protocol FLEXMultiColumnTableViewDelegate <NSObject>

@required
- (void)multiColumnTableView:(DYYYFLEXMultiColumnTableView *)tableView didSelectRow:(NSInteger)row;
- (void)multiColumnTableView:(DYYYFLEXMultiColumnTableView *)tableView didSelectHeaderForColumn:(NSInteger)column sortType:(FLEXTableColumnHeaderSortType)sortType;

@end

@protocol FLEXMultiColumnTableViewDataSource <NSObject>

@required

- (NSInteger)numberOfColumnsInTableView:(DYYYFLEXMultiColumnTableView *)tableView;
- (NSInteger)numberOfRowsInTableView:(DYYYFLEXMultiColumnTableView *)tableView;
- (NSString *)columnTitle:(NSInteger)column;
- (NSString *)rowTitle:(NSInteger)row;
- (NSArray<NSString *> *)contentForRow:(NSInteger)row;

- (CGFloat)multiColumnTableView:(DYYYFLEXMultiColumnTableView *)tableView minWidthForContentCellInColumn:(NSInteger)column;
- (CGFloat)multiColumnTableView:(DYYYFLEXMultiColumnTableView *)tableView heightForContentCellInRow:(NSInteger)row;
- (CGFloat)heightForTopHeaderInTableView:(DYYYFLEXMultiColumnTableView *)tableView;
- (CGFloat)widthForLeftHeaderInTableView:(DYYYFLEXMultiColumnTableView *)tableView;

@end


@interface DYYYFLEXMultiColumnTableView : UIView

@property (nonatomic, weak) id<FLEXMultiColumnTableViewDataSource> dataSource;
@property (nonatomic, weak) id<FLEXMultiColumnTableViewDelegate> delegate;

- (void)reloadData;

@end
