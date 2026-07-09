//
//  DYYYFLEXNSStringShortcuts.m
//  FLEX
//
//  Created by Tanner on 3/29/21.
//

#import "DYYYFLEXNSStringShortcuts.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXShortcut.h"

@implementation DYYYFLEXNSStringShortcuts

+ (instancetype)forObject:(NSString *)string {
    NSUInteger length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytesNoCopy:(void *)string.UTF8String length:length freeWhenDone:NO];
    
    return [self forObject:string additionalRows:@[
        [DYYYFLEXActionShortcut title:@"UTF-8 数据" subtitle:^NSString *(id _) {
            return data.description;
        } viewer:^UIViewController *(id _) {
            return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:data];
        } accessoryType:^UITableViewCellAccessoryType(id _) {
            return UITableViewCellAccessoryDisclosureIndicator;
        }]
    ]];
}

@end
