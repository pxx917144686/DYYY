//
//  FLEXBookmarkManager.m
//  FLEX
//
//  创建者：Tanner，日期：2/6/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXBookmarkManager.h"

static NSMutableArray *kFLEXBookmarkManagerBookmarks = nil;

@implementation FLEXBookmarkManager

+ (void)initialize {
    if (self == [FLEXBookmarkManager class]) {
        kFLEXBookmarkManagerBookmarks = [NSMutableArray new];
    }
}

+ (NSMutableArray *)bookmarks {
    return kFLEXBookmarkManagerBookmarks;
}

@end
