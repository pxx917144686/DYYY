//
//  DYYYFLEXGlobalsEntry.m
//  FLEX
//
//  Created by Javier Soto on 7/26/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXGlobalsEntry.h"

@implementation DYYYFLEXGlobalsEntry

+ (instancetype)entryWithEntry:(Class<DYYYFLEXGlobalsEntry>)cls row:(FLEXGlobalsRow)row {
    BOOL providesVCs = [cls respondsToSelector:@selector(globalsEntryViewController:)];
    BOOL providesActions = [cls respondsToSelector:@selector(globalsEntryRowAction:)];
    NSParameterAssert(cls);
    NSParameterAssert(providesVCs || providesActions);

    DYYYFLEXGlobalsEntry *entry = [self new];
    entry->_entryNameFuture = ^{ return [cls globalsEntryTitle:row]; };

    if (providesVCs) {
        id action = providesActions ? [cls globalsEntryRowAction:row] : nil;
        if (action) {
            entry->_rowAction = action;
        } else {
            entry->_viewControllerFuture = ^{ return [cls globalsEntryViewController:row]; };
        }
    } else {
        entry->_rowAction = [cls globalsEntryRowAction:row];
    }

    return entry;
}

+ (instancetype)entryWithNameFuture:(FLEXGlobalsEntryNameFuture)nameFuture
               viewControllerFuture:(FLEXGlobalsEntryViewControllerFuture)viewControllerFuture {
    NSParameterAssert(nameFuture);
    NSParameterAssert(viewControllerFuture);

    DYYYFLEXGlobalsEntry *entry = [self new];
    entry->_entryNameFuture = [nameFuture copy];
    entry->_viewControllerFuture = [viewControllerFuture copy];

    return entry;
}

+ (instancetype)entryWithNameFuture:(FLEXGlobalsEntryNameFuture)nameFuture
                             action:(FLEXGlobalsEntryRowAction)rowSelectedAction {
    NSParameterAssert(nameFuture);
    NSParameterAssert(rowSelectedAction);

    DYYYFLEXGlobalsEntry *entry = [self new];
    entry->_entryNameFuture = [nameFuture copy];
    entry->_rowAction = [rowSelectedAction copy];

    return entry;
}

@end

@interface DYYYFLEXGlobalsEntry (Debugging)
@property (nonatomic, readonly) NSString *name;
@end

@implementation DYYYFLEXGlobalsEntry (Debugging)

- (NSString *)name {
    return self.entryNameFuture();
}

@end

#pragma mark - flex_concreteGlobalsEntry

@implementation NSObject (DYYYFLEXGlobalsEntry)

+ (DYYYFLEXGlobalsEntry *)flex_concreteGlobalsEntry:(FLEXGlobalsRow)row {
    if ([self conformsToProtocol:@protocol(DYYYFLEXGlobalsEntry)]) {
        return [DYYYFLEXGlobalsEntry entryWithEntry:self row:row];
    }

    return nil;
}

@end
