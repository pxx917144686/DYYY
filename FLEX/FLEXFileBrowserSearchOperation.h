//
//  FLEXFileBrowserSearchOperation.h
//  FLEX
//
//  Created by 陳啟倫 on 2014/8/4.
//  Copyright (c) 2014年 f. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>

@protocol FLEXFileBrowserSearchOperationDelegate;

@interface FLEXFileBrowserSearchOperation : NSOperation

@property (nonatomic, weak) id<FLEXFileBrowserSearchOperationDelegate> delegate;

- (id)initWithPath:(NSString *)currentPath searchString:(NSString *)searchString;

@end

@protocol FLEXFileBrowserSearchOperationDelegate <NSObject>

- (void)fileBrowserSearchOperationResult:(NSArray<NSString *> *)searchResult size:(uint64_t)size;

@end
