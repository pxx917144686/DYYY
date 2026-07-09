//
//  DYYYFLEXManager+Private.h
//  PebbleApp
//
//  Created by Javier Soto on 7/26/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXManager.h"
#import "DYYYFLEXWindow.h"

@class DYYYFLEXGlobalsEntry, DYYYFLEXExplorerViewController;

@interface DYYYFLEXManager (Private)

@property (nonatomic, readonly) DYYYFLEXWindow *explorerWindow;
@property (nonatomic, readonly) DYYYFLEXExplorerViewController *explorerViewController;

/// An array of DYYYFLEXGlobalsEntry objects that have been registered by the user.
@property (nonatomic, readonly) NSMutableArray<DYYYFLEXGlobalsEntry *> *userGlobalEntries;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, FLEXCustomContentViewerFuture> *customContentTypeViewers;

@end
