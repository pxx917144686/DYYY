//
//  DYYYFLEXGlobalsViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-03.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXFilteringTableViewController.h"
@protocol FLEXGlobalsTableViewControllerDelegate;

typedef NS_ENUM(NSUInteger, FLEXGlobalsSectionKind) {
    FLEXGlobalsSectionProcessAndEvents = 0,
    FLEXGlobalsSectionAppShortcuts,
    FLEXGlobalsSectionMisc,
    FLEXGlobalsSectionCount
};

@interface DYYYFLEXGlobalsViewController : DYYYFLEXFilteringTableViewController

@end
