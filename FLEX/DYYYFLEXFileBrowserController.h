//
//  DYYYFLEXFileBrowserController.h
//  Flipboard
//
//  Created by Ryan Olson on 6/9/14.
//  Based on previous work by Evan Doll
//

#import "DYYYFLEXTableViewController.h"
#import "DYYYFLEXGlobalsEntry.h"

@interface DYYYFLEXFileBrowserController : DYYYFLEXTableViewController <DYYYFLEXGlobalsEntry>

+ (instancetype)path:(NSString *)path;
- (id)initWithPath:(NSString *)path;

@end
