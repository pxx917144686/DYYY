//
//  DYYYFLEXNSDataShortcuts.m
//  FLEX
//
//  Created by Tanner on 3/29/21.
//

#import "DYYYFLEXNSDataShortcuts.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXShortcut.h"

@implementation DYYYFLEXNSDataShortcuts

+ (instancetype)forObject:(NSData *)data {
    NSString *string = [self stringForData:data];
    
    return [self forObject:data additionalRows:@[
        [DYYYFLEXActionShortcut title:@"UTF-8 字符串" subtitle:^(NSData *object) {
            return string.length ? string : (string ?
                @"数据不是UTF8字符串" : @"空字符串"
            );
        } viewer:^UIViewController *(id object) {
            return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:string];
        } accessoryType:^UITableViewCellAccessoryType(NSData *object) {
            if (string.length) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
            
            return UITableViewCellAccessoryNone;
        }]
    ]];
}

+ (NSString *)stringForData:(NSData *)data {
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@interface NSData (Overrides) @end
@implementation NSData (Overrides)

// 这通常会导致崩溃
- (NSUInteger)length {
    return 0;
}

@end
