//
//  FLEXBookmarkManager.h
//  FLEX
//
//  Created by Tanner on 2/6/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXBookmarkManager : NSObject

@property (nonatomic, readonly, class) NSMutableArray *bookmarks;

+ (void)addBookmark:(id)bookmark;
+ (void)removeBookmarkAtIndex:(NSUInteger)index;
+ (void)removeBookmarksAtIndexes:(NSIndexSet *)indexes;
+ (void)removeAllBookmarks;
+ (NSUInteger)bookmarkCount;
+ (id)bookmarkAtIndex:(NSUInteger)index;
+ (NSArray *)allBookmarks;

@end

NS_ASSUME_NONNULL_END
