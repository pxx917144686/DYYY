//
//  FLEXGlobalsViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-03.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXFilteringTableViewController.h"
@protocol FLEXGlobalsTableViewControllerDelegate;

typedef NS_ENUM(NSUInteger, FLEXGlobalsSectionKind) {
    FLEXGlobalsSectionProcessAndEvents = 0,
    FLEXGlobalsSectionAppShortcuts,
    FLEXGlobalsSectionMisc,
    FLEXGlobalsSectionCount
};

@interface FLEXGlobalsViewController : FLEXFilteringTableViewController

@end
