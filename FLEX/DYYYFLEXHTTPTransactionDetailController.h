//
//  DYYYFLEXHTTPTransactionDetailController.h
//  Flipboard
//
//  Created by Ryan Olson on 2/10/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DYYYFLEXHTTPTransaction;

@interface DYYYFLEXHTTPTransactionDetailController : UITableViewController

+ (instancetype)withTransaction:(DYYYFLEXHTTPTransaction *)transaction;

@end
