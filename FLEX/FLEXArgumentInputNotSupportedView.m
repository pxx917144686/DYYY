// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputNotSupportedView.m
//  Flipboard
//
//  创建者：Ryan Olson，创建日期：2014年6月18日
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。

#import "FLEXArgumentInputNotSupportedView.h"
#import "FLEXColor.h"

@implementation FLEXArgumentInputNotSupportedView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        self.inputTextView.userInteractionEnabled = NO; // 禁用用户交互
        // 设置背景色为半透明的次要分组背景色
        self.inputTextView.backgroundColor = [FLEXColor secondaryGroupedBackgroundColorWithAlpha:0.5];
        self.inputPlaceholderText = @"nil (不支持的类型)"; // 设置占位符文本
        self.targetSize = FLEXArgumentInputViewSizeSmall; // 设置目标尺寸为小
    }
    return self;
}

// 不支持任何类型，因此 inputValue 始终为 nil
// - (id)inputValue { return nil; }

// 不支持任何类型，因此 setInputValue: 是空操作
// - (void)setInputValue:(id)inputValue { }

// 不支持任何类型，因此总是返回 NO
// + (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value { return NO; }

@end
