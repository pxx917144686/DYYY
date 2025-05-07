//
//  FLEXTableContentHeaderCell.h
//  FLEX
//
//  Created by Peng Tao on 15/11/26.
//  Copyright © 2015年 f. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSUInteger, FLEXTableColumnHeaderSortType) {
    FLEXTableColumnHeaderSortTypeNone = 0,
    FLEXTableColumnHeaderSortTypeAsc,
    FLEXTableColumnHeaderSortTypeDesc,
};

NS_INLINE FLEXTableColumnHeaderSortType FLEXNextTableColumnHeaderSortType(
    FLEXTableColumnHeaderSortType current) {
    switch (current) {
        case FLEXTableColumnHeaderSortTypeAsc:
            return FLEXTableColumnHeaderSortTypeDesc;
        case FLEXTableColumnHeaderSortTypeNone:
        case FLEXTableColumnHeaderSortTypeDesc:
            return FLEXTableColumnHeaderSortTypeAsc;
    }
    
    return FLEXTableColumnHeaderSortTypeNone;
}

@interface FLEXTableColumnHeader : UIView

@property (nonatomic) NSInteger index;
@property (nonatomic, readonly) UILabel *titleLabel;

@property (nonatomic) FLEXTableColumnHeaderSortType sortType;

@end

