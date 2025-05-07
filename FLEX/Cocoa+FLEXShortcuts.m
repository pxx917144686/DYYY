// 遇到问题联系中文翻译作者：pxx917144686
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
            return @"默认样式";
        case UIAlertActionStyleCancel:
            return @"取消样式";
        case UIAlertActionStyleDestructive:
            return @"破坏性样式";
            
        default:
            return [NSString stringWithFormat:@"未知 (%@)", @(self.style)];
    }
}
@end
