//
//  FLEXArgumentInputViewFactory.m
//  FLEXInjected
//
//  创建者：Ryan Olson，日期：6/15/14.
//
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXArgumentInputViewFactory.h"
#import "FLEXArgumentInputView.h"
#import "FLEXArgumentInputObjectView.h"
#import "FLEXArgumentInputNumberView.h"
#import "FLEXArgumentInputSwitchView.h"
#import "FLEXArgumentInputStructView.h"
#import "FLEXArgumentInputNotSupportedView.h"
#import "FLEXArgumentInputStringView.h"
#import "FLEXArgumentInputFontView.h"
#import "FLEXArgumentInputColorView.h"
#import "FLEXArgumentInputDateView.h"
#import "FLEXRuntimeUtility.h"

@implementation FLEXArgumentInputViewFactory

+ (FLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding {
    return [self argumentInputViewForTypeEncoding:typeEncoding currentValue:nil];
}

+ (FLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue {
    Class subclass = [self argumentInputViewSubclassForTypeEncoding:typeEncoding currentValue:currentValue];
    if (!subclass) {
        // 如果找不到适合类型编码的子类，则回退到 FLEXArgumentInputNotSupportedView。
        // 不支持的视图显示“nil”并且不允许用户输入。
        subclass = [FLEXArgumentInputNotSupportedView class];
    }
    // 移除字段名称（如果存在）（例如 \"width\"d -> d）
    const NSUInteger fieldNameOffset = [FLEXRuntimeUtility fieldNameOffsetForTypeEncoding:typeEncoding];
    return [[subclass alloc] initWithArgumentTypeEncoding:typeEncoding + fieldNameOffset];
}

+ (Class)argumentInputViewSubclassForTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue {
    // 移除字段名称（如果存在）（例如 \"width\"d -> d）
    const NSUInteger fieldNameOffset = [FLEXRuntimeUtility fieldNameOffsetForTypeEncoding:typeEncoding];
    Class argumentInputViewSubclass = nil;
    NSArray<Class> *inputViewClasses = @[[FLEXArgumentInputColorView class],
                                         [FLEXArgumentInputFontView class],
                                         [FLEXArgumentInputStringView class],
                                         [FLEXArgumentInputStructView class],
                                         [FLEXArgumentInputSwitchView class],
                                         [FLEXArgumentInputDateView class],
                                         [FLEXArgumentInputNumberView class],
                                         [FLEXArgumentInputObjectView class]];

    // 注意，这里的顺序很重要，因为多个子类可能支持相同的类型。
    // 一个例子是数字子类和布尔子类对于类型 @encode(BOOL)。
    // 两者都有效，但我们更倾向于使用布尔子类。
    for (Class inputViewClass in inputViewClasses) {
        if ([inputViewClass supportsObjCType:typeEncoding + fieldNameOffset withCurrentValue:currentValue]) {
            argumentInputViewSubclass = inputViewClass;
            break;
        }
    }

    return argumentInputViewSubclass;
}

+ (BOOL)canEditFieldWithTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue {
    return [self argumentInputViewSubclassForTypeEncoding:typeEncoding currentValue:currentValue] != nil;
}

/// 为自定义结构类型启用显示 ivar 名称
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding {
    [FLEXArgumentInputStructView registerFieldNames:names forTypeEncoding:typeEncoding];
}

@end
