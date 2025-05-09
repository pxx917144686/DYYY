//
//  PTMultiColumnTableView.m
//  PTMultiColumnTableViewDemo
//
//  Created by Peng Tao on 15/11/16.
//  Copyright © 2015年 Peng Tao. All rights reserved.
//

#import "FLEXMultiColumnTableView.h"
#import "FLEXDBQueryRowCell.h"
#import "FLEXTableLeftCell.h"
#import "NSArray+FLEX.h"
#import "FLEXColor.h"

@interface FLEXMultiColumnTableView () <
    UITableViewDataSource, UITableViewDelegate,
    UIScrollViewDelegate, FLEXDBQueryRowCellLayoutSource
>

@property (nonatomic) UIScrollView *contentScrollView;
@property (nonatomic) UIScrollView *headerScrollView;
@property (nonatomic) UITableView  *leftTableView;
@property (nonatomic) UITableView  *contentTableView;
@property (nonatomic) UIView       *leftHeader;

@property (nonatomic) NSArray<UIView *> *headerViews;

/// 如果没有选中列则为 \c NSNotFound
@property (nonatomic) NSInteger sortColumn;
@property (nonatomic) FLEXTableColumnHeaderSortType sortType;

@property (nonatomic, readonly) NSInteger numberOfColumns;
@property (nonatomic, readonly) NSInteger numberOfRows;
@property (nonatomic, readonly) CGFloat topHeaderHeight;
@property (nonatomic, readonly) CGFloat leftHeaderWidth;
@property (nonatomic, readonly) CGFloat columnMargin;

@end

static const CGFloat kColumnMargin = 1;

@implementation FLEXMultiColumnTableView

#pragma mark - 初始化

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
        self.autoresizingMask |= UIViewAutoresizingFlexibleHeight;
        self.autoresizingMask |= UIViewAutoresizingFlexibleTopMargin;
        self.backgroundColor  = FLEXColor.groupedBackgroundColor;
        
        [self loadHeaderScrollView];
        [self loadContentScrollView];
        [self loadLeftView];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat width  = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    CGFloat topheaderHeight = self.topHeaderHeight;
    CGFloat leftHeaderWidth = self.leftHeaderWidth;
    CGFloat topInsets = 0.f;

    if (@available (iOS 11.0, *)) {
        topInsets = self.safeAreaInsets.top;
    }
    
    CGFloat contentWidth = 0.0;
    NSInteger columnsCount = self.numberOfColumns;
    for (int i = 0; i < columnsCount; i++) {
        contentWidth += CGRectGetWidth(self.headerViews[i].bounds);
    }
    
    CGFloat contentHeight = height - topheaderHeight - topInsets;
    
    self.leftHeader.frame = CGRectMake(0, topInsets, self.leftHeaderWidth, self.topHeaderHeight);
    self.leftTableView.frame = CGRectMake(
        0, topheaderHeight + topInsets, leftHeaderWidth, contentHeight
    );
    self.headerScrollView.frame = CGRectMake(
        leftHeaderWidth, topInsets, width - leftHeaderWidth, topheaderHeight
    );
    self.headerScrollView.contentSize = CGSizeMake(
        self.contentTableView.frame.size.width, self.headerScrollView.frame.size.height
    );
    self.contentTableView.frame = CGRectMake(
        0, 0, contentWidth + self.numberOfColumns * self.columnMargin , contentHeight
    );
    self.contentScrollView.frame = CGRectMake(
        leftHeaderWidth, topheaderHeight + topInsets, width - leftHeaderWidth, contentHeight
    );
    self.contentScrollView.contentSize = self.contentTableView.frame.size;
}


#pragma mark - 用户界面

- (void)loadHeaderScrollView {
    UIScrollView *headerScrollView   = [UIScrollView new];
    headerScrollView.delegate        = self;
    headerScrollView.backgroundColor = FLEXColor.secondaryGroupedBackgroundColor;
    self.headerScrollView            = headerScrollView;
    
    [self addSubview:headerScrollView];
}

- (void)loadContentScrollView {
    UIScrollView *scrollView = [UIScrollView new];
    scrollView.bounces       = NO;
    scrollView.delegate      = self;
    
    UITableView *tableView   = [UITableView new];
    tableView.delegate       = self;
    tableView.dataSource     = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [tableView registerClass:[FLEXDBQueryRowCell class]
        forCellReuseIdentifier:kFLEXDBQueryRowCellReuse
    ];
    
    [scrollView addSubview:tableView];
    [self addSubview:scrollView];
    
    self.contentScrollView = scrollView;
    self.contentTableView  = tableView;
}

- (void)loadLeftView {
    UITableView *leftTableView   = [UITableView new];
    leftTableView.delegate       = self;
    leftTableView.dataSource     = self;
    leftTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.leftTableView           = leftTableView;
    [self addSubview:leftTableView];
    
    UIView *leftHeader         = [UIView new];
    leftHeader.backgroundColor = FLEXColor.secondaryBackgroundColor;
    self.leftHeader            = leftHeader;
    [self addSubview:leftHeader];
}


#pragma mark - 数据

- (void)reloadData {
    [self loadHeaderData];
    [self loadLeftViewData];
    [self loadContentData];
}

- (void)loadHeaderData {
    // 移除现有的头部视图（如果有）
    for (UIView *subview in self.headerViews) {
        [subview removeFromSuperview];
    }
    
    __block CGFloat xOffset = 0;
    
    self.headerViews = [NSArray flex_forEachUpTo:self.numberOfColumns map:^id(NSUInteger column) {
        FLEXTableColumnHeader *header = [FLEXTableColumnHeader new];
        header.titleLabel.text = [self columnTitle:column];
        
        CGSize fittingSize = CGSizeMake(CGFLOAT_MAX, self.topHeaderHeight - 1);
        CGFloat width = self.columnMargin + MAX(
            [self minContentWidthForColumn:column],
            [header sizeThatFits:fittingSize].width
        );
        header.frame = CGRectMake(xOffset, 0, width, self.topHeaderHeight - 1);

        if (column == self.sortColumn) {
            header.sortType = self.sortType;
        }
        
        // 头部点击手势
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(contentHeaderTap:)
        ];
        [header addGestureRecognizer:gesture];
        header.userInteractionEnabled = YES;
        
        xOffset += width;
        [self.headerScrollView addSubview:header];
        return header;
    }];
}

- (void)contentHeaderTap:(UIGestureRecognizer *)gesture {
    NSInteger newSortColumn = [self.headerViews indexOfObject:gesture.view];
    FLEXTableColumnHeaderSortType newType = FLEXNextTableColumnHeaderSortType(self.sortType);
    
    // 重置旧的头部视图
    FLEXTableColumnHeader *oldHeader = (id)self.headerViews[self.sortColumn];
    oldHeader.sortType = FLEXTableColumnHeaderSortTypeNone;
    
    // 更新新的头部视图
    FLEXTableColumnHeader *newHeader = (id)self.headerViews[newSortColumn];
    newHeader.sortType = newType;
    
    // 更新自身
    self.sortColumn = newSortColumn;
    self.sortType = newType;

    // 通知代理
    [self.delegate multiColumnTableView:self didSelectHeaderForColumn:newSortColumn sortType:newType];
}

- (void)loadContentData {
    [self.contentTableView reloadData];
}

- (void)loadLeftViewData {
    [self.leftTableView reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 交替背景颜色
    UIColor *backgroundColor = FLEXColor.primaryBackgroundColor;
    if (indexPath.row % 2 != 0) {
        backgroundColor = FLEXColor.secondaryBackgroundColor;
    }
    
    // 左侧表格视图用于行号
    if (tableView == self.leftTableView) {
        FLEXTableLeftCell *cell = [FLEXTableLeftCell cellWithTableView:tableView];
        cell.contentView.backgroundColor = backgroundColor;
        cell.titlelabel.text = [self rowTitle:indexPath.row];
        return cell;
    }
    // 右侧表格视图用于数据
    else {
        FLEXDBQueryRowCell *cell = [tableView
            dequeueReusableCellWithIdentifier:kFLEXDBQueryRowCellReuse forIndexPath:indexPath
        ];
        
        cell.contentView.backgroundColor = backgroundColor;
        cell.data = [self.dataSource contentForRow:indexPath.row];
        cell.layoutSource = self;
        NSAssert(cell.data.count == self.numberOfColumns, @"提供的数据计数不正确");
        return cell;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataSource numberOfRowsInTableView:self];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self.dataSource multiColumnTableView:self heightForContentCellInRow:indexPath.row];
}

// 同步滚动所有滚动视图
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.contentScrollView) {
        self.headerScrollView.contentOffset = scrollView.contentOffset;
    }
    else if (scrollView == self.headerScrollView) {
        self.contentScrollView.contentOffset = scrollView.contentOffset;
    }
    else if (scrollView == self.leftTableView) {
        self.contentTableView.contentOffset = scrollView.contentOffset;
    }
    else if (scrollView == self.contentTableView) {
        self.leftTableView.contentOffset = scrollView.contentOffset;
    }
}


#pragma mark UITableView 代理

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.leftTableView) {
        [self.contentTableView
            selectRowAtIndexPath:indexPath
            animated:NO
            scrollPosition:UITableViewScrollPositionNone
        ];
    }
    else if (tableView == self.contentTableView) {
        [self.delegate multiColumnTableView:self didSelectRow:indexPath.row];
    }
}


#pragma mark FLEXDBQueryRowCellLayoutSource

- (CGFloat)dbQueryRowCell:(FLEXDBQueryRowCell *)dbQueryRowCell minXForColumn:(NSUInteger)column {
    return CGRectGetMinX(self.headerViews[column].frame);
}

- (CGFloat)dbQueryRowCell:(FLEXDBQueryRowCell *)dbQueryRowCell widthForColumn:(NSUInteger)column {
    return CGRectGetWidth(self.headerViews[column].bounds);
}


#pragma mark 数据源访问器

- (NSInteger)numberOfRows {
    return [self.dataSource numberOfRowsInTableView:self];
}

- (NSInteger)numberOfColumns {
    return [self.dataSource numberOfColumnsInTableView:self];
}

- (NSString *)columnTitle:(NSInteger)column {
    return [self.dataSource columnTitle:column];
}

- (NSString *)rowTitle:(NSInteger)row {
    return [self.dataSource rowTitle:row];
}

- (CGFloat)minContentWidthForColumn:(NSInteger)column {
    return [self.dataSource multiColumnTableView:self minWidthForContentCellInColumn:column];
}

- (CGFloat)contentHeightForRow:(NSInteger)row {
    return [self.dataSource multiColumnTableView:self heightForContentCellInRow:row];
}

- (CGFloat)topHeaderHeight {
    return [self.dataSource heightForTopHeaderInTableView:self];
}

- (CGFloat)leftHeaderWidth {
    return [self.dataSource widthForLeftHeaderInTableView:self];
}

- (CGFloat)columnMargin {
    return kColumnMargin;
}

@end
