//
//  UITextField+Range.m
//  FLEX
//
//  Created by Tanner on 6/13/17.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "UITextField+Range.h"

@implementation UITextField (Range)

- (NSRange)flex_selectedRange {
    UITextRange *r = self.selectedTextRange;
    if (r) {
        NSInteger loc = [self offsetFromPosition:self.beginningOfDocument toPosition:r.start];
        NSInteger len = [self offsetFromPosition:r.start toPosition:r.end];
        return NSMakeRange(loc, len);
    }

    return NSMakeRange(NSNotFound, 0);
}

@end
