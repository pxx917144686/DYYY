// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputNumberView.m
//  Flipboard
//
//  Created by Ryan Olson on 6/15/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXArgumentInputNumberView.h"
#import "FLEXRuntimeUtility.h"

@implementation FLEXArgumentInputNumberView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        // 设置键盘类型为数字和标点
        self.inputTextView.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        self.targetSize = FLEXArgumentInputViewSizeSmall; // 设置目标尺寸为小
    }
    
    return self;
}

- (void)setInputValue:(id)inputValue {
    // 如果输入值响应 stringValue 方法，则设置为文本框内容
    if ([inputValue respondsToSelector:@selector(stringValue)]) {
        self.inputTextView.text = [inputValue stringValue];
    }
}

- (id)inputValue {
    // 从输入字符串获取对应 Objective-C 类型的数值
    return [FLEXRuntimeUtility valueForNumberWithObjCType:self.typeEncoding.UTF8String fromInputString:self.inputTextView.text];
}

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type); // 确保类型不为空
    
    static NSArray<NSString *> *supportedTypes = nil; // 支持的类型数组
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 初始化支持的类型列表
        supportedTypes = @[
            @FLEXEncodeClass(NSNumber),
            @FLEXEncodeClass(NSDecimalNumber),
            @(@encode(char)),
            @(@encode(int)),
            @(@encode(short)),
            @(@encode(long)),
            @(@encode(long long)),
            @(@encode(unsigned char)),
            @(@encode(unsigned int)),
            @(@encode(unsigned short)),
            @(@encode(unsigned long)),
            @(@encode(unsigned long long)),
            @(@encode(float)),
            @(@encode(double)),
            // @(@encode(_Bool)) or @(@encode(bool)) is handled by FLEXArgumentInputSwitchView
            @(@encode(long double)) // long double 可能无法正常工作
        ];
    });
    
    // 检查类型是否存在且在支持的类型列表中
    return type && [supportedTypes containsObject:@(type)];
}

@end
