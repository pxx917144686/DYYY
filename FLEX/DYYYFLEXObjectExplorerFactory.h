//
//  DYYYFLEXObjectExplorerFactory.h
//  Flipboard
//
//  Created by Ryan Olson on 5/15/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXGlobalsEntry.h"

#ifndef _FLEXObjectExplorerViewController_h
#import "DYYYFLEXObjectExplorerViewController.h"
#else
@class DYYYFLEXObjectExplorerViewController;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface DYYYFLEXObjectExplorerFactory : NSObject <DYYYFLEXGlobalsEntry>

+ (nullable DYYYFLEXObjectExplorerViewController *)explorerViewControllerForObject:(nullable id)object;

/// Register a specific explorer view controller class to be used when exploring
/// an object of a specific class. Calls will overwrite existing registrations.
/// Sections must be initialized using \c forObject: like
+ (void)registerExplorerSection:(Class)sectionClass forClass:(Class)objectClass;

@end

NS_ASSUME_NONNULL_END
