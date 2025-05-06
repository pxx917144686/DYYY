// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputStringView.m
//  Flipboard
//
//  Created by Ryan Olson on 6/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXArgumentInputStringView.h"
#import "FLEXRuntimeUtility.h"

@implementation FLEXArgumentInputStringView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        FLEXTypeEncoding type = typeEncoding[0];
        if (type == FLEXTypeEncodingConst) {
            // 如果在这里崩溃，意味着类型编码字符串无效
            type = typeEncoding[1];
        }

        // 选择器不需要多行文本框
        if (type == FLEXTypeEncodingSelector) {
            self.targetSize = FLEXArgumentInputViewSizeSmall;
        } else {
            self.targetSize = FLEXArgumentInputViewSizeLarge;
        }
    }
    return self;
}

- (void)setInputValue:(id)inputValue {
    if ([inputValue isKindOfClass:[NSString class]]) {
        self.inputTextView.text = inputValue;
    } else if ([inputValue isKindOfClass:[NSValue class]]) {
        NSValue *value = (id)inputValue;
        NSParameterAssert(strlen(value.objCType) == 1); // 确保类型编码长度为 1

        // 来自 NSValue 的 C 字符串或 SEL
        FLEXTypeEncoding type = value.objCType[0];
        if (type == FLEXTypeEncodingConst) {
            // 如果在这里崩溃，意味着类型编码字符串无效
            type = value.objCType[1];
        }

        if (type == FLEXTypeEncodingCString) {
            self.inputTextView.text = @((const char *)value.pointerValue); // C 字符串
        } else if (type == FLEXTypeEncodingSelector) {
            self.inputTextView.text = NSStringFromSelector((SEL)value.pointerValue); // 选择器
        }
    }
}

- (id)inputValue {
    NSString *text = self.inputTextView.text;
    // 将空字符串解释为 nil。我们失去了将空字符串设置为空字符串值的能力，
    // 但我们接受这种权衡，以换取不必为每个字符串输入引号。
    if (!text.length) {
        return nil;
    }

    // 情况：C 字符串和 SEL
    if (self.typeEncoding.length <= 2) {
        FLEXTypeEncoding type = [self.typeEncoding characterAtIndex:0];
        if (type == FLEXTypeEncodingConst) {
            // 如果在这里崩溃，意味着类型编码字符串无效
            type = [self.typeEncoding characterAtIndex:1];
        }

        if (type == FLEXTypeEncodingCString || type == FLEXTypeEncodingSelector) {
            const char *encoding = self.typeEncoding.UTF8String;
            SEL selector = NSSelectorFromString(text);
            return [NSValue valueWithBytes:&selector objCType:encoding]; // 返回包装后的值
        }
    }

    // 情况：NSStrings
    return self.inputTextView.text.copy; // 返回字符串副本
}

// TODO: 支持对字符串使用对象地址，就像在对象参数视图中一样。

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type); // 确保类型不为空
    unsigned long len = strlen(type); // 获取类型编码长度

    BOOL isConst = type[0] == FLEXTypeEncodingConst; // 是否为 const 类型
    NSInteger i = isConst ? 1 : 0; // 偏移量

    BOOL typeIsString = strcmp(type, FLEXEncodeClass(NSString)) == 0; // 类型是否为 NSString
    BOOL typeIsCString = len <= 2 && type[i] == FLEXTypeEncodingCString; // 类型是否为 C 字符串
    BOOL typeIsSEL = len <= 2 && type[i] == FLEXTypeEncodingSelector; // 类型是否为 SEL
    BOOL valueIsString = [value isKindOfClass:[NSString class]]; // 当前值是否为 NSString

    BOOL typeIsPrimitiveString = typeIsSEL || typeIsCString; // 类型是否为基本字符串类型 (C 字符串或 SEL)
    BOOL typeIsSupported = typeIsString || typeIsCString || typeIsSEL; // 类型是否受支持

    BOOL valueIsNSValueWithCorrectType = NO; // 当前值是否为具有正确类型的 NSValue
    if ([value isKindOfClass:[NSValue class]]) {
        NSValue *v = (id)value;
        len = strlen(v.objCType);
        if (len == 1) {
            FLEXTypeEncoding valueType = v.objCType[0]; // 修正：直接获取类型，不需要偏移量 i
            if (valueType == FLEXTypeEncodingCString && typeIsCString) {
                valueIsNSValueWithCorrectType = YES;
            } else if (valueType == FLEXTypeEncodingSelector && typeIsSEL) {
                valueIsNSValueWithCorrectType = YES;
            }
        }
    }

    // 如果没有当前值且类型受支持，则返回 YES
    if (!value && typeIsSupported) {
        return YES;
    }

    // 如果类型是 NSString 且当前值是 NSString，则返回 YES
    if (typeIsString && valueIsString) {
        return YES;
    }

    // 基本字符串类型可以输入为 NSString 或 NSValue
    if (typeIsPrimitiveString && (valueIsString || valueIsNSValueWithCorrectType)) {
        return YES;
    }

    return NO; // 其他情况均不支持
}

@end
