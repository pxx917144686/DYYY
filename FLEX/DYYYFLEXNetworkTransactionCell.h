//
//  DYYYFLEXNetworkTransactionCell.h
//  Flipboard
//
//  Created by Ryan Olson on 2/8/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DYYYFLEXNetworkTransaction;

@interface DYYYFLEXNetworkTransactionCell : UITableViewCell

@property (nonatomic) DYYYFLEXNetworkTransaction *transaction;

@property (nonatomic, readonly, class) NSString *reuseID;
@property (nonatomic, readonly, class) CGFloat preferredCellHeight;

@end
