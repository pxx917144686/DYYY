//
//  FLEXArgumentInputNotSupportedView.m
//  Flipboard
//
//  由 Ryan Olson 于 6/18/14 创建.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利.
//

#import "FLEXArgumentInputNotSupportedView.h"
#import "FLEXColor.h"

@implementation FLEXArgumentInputNotSupportedView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        self.inputTextView.userInteractionEnabled = NO;
        self.inputTextView.backgroundColor = [FLEXColor secondaryGroupedBackgroundColorWithAlpha:0.5];
        self.inputPlaceholderText = @"nil  (类型不支持)";
        self.targetSize = FLEXArgumentInputViewSizeSmall;
    }
    return self;
}

@end
