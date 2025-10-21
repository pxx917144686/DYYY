//
//  Cocoa+FLEXShortcuts.m
//  Pods
//
//  Created by Tanner on 2/24/21.
//  
//

#import "Cocoa+FLEXShortcuts.h"

@implementation UIAlertAction (FLEXShortcuts)
- (NSString *)flex_styleName {
    switch (self.style) {
        case UIAlertActionStyleDefault:
            return @"默认风格";
        case UIAlertActionStyleCancel:
            return @"取消风格";
        case UIAlertActionStyleDestructive:
            return @"警告风格";
            
        default:
            return [NSString stringWithFormat:@"未知 (%@)", @(self.style)];
    }
}
@end
