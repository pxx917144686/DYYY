//
//  FLEXNSDataShortcuts.m
//  FLEX
//
//  Created by Tanner on 3/29/21.
//

#import "FLEXNSDataShortcuts.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXShortcut.h"

@implementation FLEXNSDataShortcuts

+ (instancetype)forObject:(NSData *)data {
    NSString *string = [self stringForData:data];
    
    return [self forObject:data additionalRows:@[
        [FLEXActionShortcut title:@"UTF-8 字符串" subtitle:^(NSData *object) {
            return string.length ? string : (string ?
                @"数据不是UTF8字符串" : @"空字符串"
            );
        } viewer:^UIViewController *(id object) {
            return [FLEXObjectExplorerFactory explorerViewControllerForObject:string];
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
