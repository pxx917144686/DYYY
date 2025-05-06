//
//  FLEXFileBrowserController.h
//  Flipboard
//
//  Created by Ryan Olson on 6/9/14.
//  Based on previous work by Evan Doll
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewController.h"
#import "FLEXGlobalsEntry.h"

@interface FLEXFileBrowserController : FLEXTableViewController <FLEXGlobalsEntry>

+ (instancetype)path:(NSString *)path;
- (id)initWithPath:(NSString *)path;

@end
