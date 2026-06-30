//
//  FLEXBookmarkManager.m
//  FLEX
//
//  Created by Tanner on 2/6/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXBookmarkManager.h"

static NSMutableArray *kFLEXBookmarkManagerBookmarks = nil;
static id _kFLEXBookmarkManagerLock = nil;

@implementation FLEXBookmarkManager

+ (void)initialize {
    if (self == [FLEXBookmarkManager class]) {
        kFLEXBookmarkManagerBookmarks = [NSMutableArray new];
        _kFLEXBookmarkManagerLock = [NSObject new];
    }
}

+ (NSMutableArray *)bookmarks {
    @synchronized(_kFLEXBookmarkManagerLock) {
        return kFLEXBookmarkManagerBookmarks;
    }
}

+ (void)addBookmark:(id)bookmark {
    @synchronized(_kFLEXBookmarkManagerLock) {
        [kFLEXBookmarkManagerBookmarks addObject:bookmark];
    }
}

+ (void)removeBookmarkAtIndex:(NSUInteger)index {
    @synchronized(_kFLEXBookmarkManagerLock) {
        [kFLEXBookmarkManagerBookmarks removeObjectAtIndex:index];
    }
}

+ (void)removeBookmarksAtIndexes:(NSIndexSet *)indexes {
    @synchronized(_kFLEXBookmarkManagerLock) {
        [kFLEXBookmarkManagerBookmarks removeObjectsAtIndexes:indexes];
    }
}

+ (void)removeAllBookmarks {
    @synchronized(_kFLEXBookmarkManagerLock) {
        [kFLEXBookmarkManagerBookmarks removeAllObjects];
    }
}

+ (NSUInteger)bookmarkCount {
    @synchronized(_kFLEXBookmarkManagerLock) {
        return kFLEXBookmarkManagerBookmarks.count;
    }
}

+ (id)bookmarkAtIndex:(NSUInteger)index {
    @synchronized(_kFLEXBookmarkManagerLock) {
        return kFLEXBookmarkManagerBookmarks[index];
    }
}

+ (NSArray *)allBookmarks {
    @synchronized(_kFLEXBookmarkManagerLock) {
        return [kFLEXBookmarkManagerBookmarks copy];
    }
}

@end
