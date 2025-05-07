// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputObjectView.m
//  Flipboard
//
//  Created by Ryan Olson on 6/15/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXArgumentInputObjectView.h"
#import "FLEXRuntimeUtility.h"

static const CGFloat kSegmentInputMargin = 10; // 分段控件与输入框的边距

// 参数输入对象类型枚举
typedef NS_ENUM(NSUInteger, FLEXArgInputObjectType) {
    FLEXArgInputObjectTypeJSON,    // JSON 类型
    FLEXArgInputObjectTypeAddress  // 地址类型
};

@interface FLEXArgumentInputObjectView ()

@property (nonatomic) UISegmentedControl *objectTypeSegmentControl; // 对象类型分段控件
@property (nonatomic) FLEXArgInputObjectType inputType; // 当前输入类型

@end

@implementation FLEXArgumentInputObjectView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        // 默认使用数字和标点键盘，因为引号、花括号或
        // 方括号很可能是 JSON 的第一个输入字符。
        self.inputTextView.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        self.targetSize = FLEXArgumentInputViewSizeLarge; // 默认大尺寸

        // 初始化分段控件
        self.objectTypeSegmentControl = [[UISegmentedControl alloc] initWithItems:@[@"值", @"地址"]];
        [self.objectTypeSegmentControl addTarget:self action:@selector(didChangeType) forControlEvents:UIControlEventValueChanged];
        self.objectTypeSegmentControl.selectedSegmentIndex = 0; // 默认选中 "值"
        [self addSubview:self.objectTypeSegmentControl];

        // 根据类型和当前值设置首选默认类型
        self.inputType = [[self class] preferredDefaultTypeForObjCType:typeEncoding withCurrentValue:nil];
        self.objectTypeSegmentControl.selectedSegmentIndex = self.inputType;
    }

    return self;
}

- (void)didChangeType {
    self.inputType = self.objectTypeSegmentControl.selectedSegmentIndex; // 更新输入类型

    if (super.inputValue) {
        // 触发文本区域更新，以显示
        // 存储对象的地址，
        // 或显示对象的 JSON 表示
        [self populateTextAreaFromValue:super.inputValue];
    } else {
        // 清空文本区域
        [self populateTextAreaFromValue:nil];
    }
}

- (void)setInputType:(FLEXArgInputObjectType)inputType {
    if (_inputType == inputType) return; // 类型未改变则返回

    _inputType = inputType;

    // 调整输入视图大小
    switch (inputType) {
        case FLEXArgInputObjectTypeJSON:
            self.targetSize = FLEXArgumentInputViewSizeLarge;
            break;
        case FLEXArgInputObjectTypeAddress:
            self.targetSize = FLEXArgumentInputViewSizeSmall;
            break;
    }

    // 更改占位符文本
    switch (inputType) {
        case FLEXArgInputObjectTypeJSON:
            self.inputPlaceholderText =
            @"你可以在这里输入任何有效的 JSON，例如字符串、数字、数组或字典："
            "\n\"这是一个字符串\""
            "\n1234"
            "\n{ \"name\": \"Bob\", \"age\": 47 }"
            "\n["
            "\n   1, 2, 3"
            "\n]";
            break;
        case FLEXArgInputObjectTypeAddress:
            self.inputPlaceholderText = @"0x0000deadb33f"; // 十六进制地址示例
            break;
    }

    [self setNeedsLayout]; // 标记需要重新布局
    [self.superview setNeedsLayout]; // 标记父视图需要重新布局
}

- (void)setInputValue:(id)inputValue {
    super.inputValue = inputValue; // 调用父类实现
    [self populateTextAreaFromValue:inputValue]; // 根据值填充文本区域
}

- (id)inputValue {
    switch (self.inputType) {
        case FLEXArgInputObjectTypeJSON:
            // 从可编辑的 JSON 字符串获取对象值
            return [FLEXRuntimeUtility objectValueFromEditableJSONString:self.inputTextView.text];
        case FLEXArgInputObjectTypeAddress: {
            NSScanner *scanner = [NSScanner scannerWithString:self.inputTextView.text];

            unsigned long long objectPointerValue;
            // 扫描十六进制长整型值
            if ([scanner scanHexLongLong:&objectPointerValue]) {
                return (__bridge id)(void *)objectPointerValue; // 返回桥接后的对象指针
            }

            return nil; // 扫描失败返回 nil
        }
    }
}

- (void)populateTextAreaFromValue:(id)value {
    if (!value) {
        self.inputTextView.text = nil; // 值为空则清空文本
    } else {
        if (self.inputType == FLEXArgInputObjectTypeJSON) {
            // 获取对象的可编辑 JSON 字符串表示
            self.inputTextView.text = [FLEXRuntimeUtility editableJSONStringForObject:value];
        } else if (self.inputType == FLEXArgInputObjectTypeAddress) {
            // 获取对象的地址字符串表示
            self.inputTextView.text = [NSString stringWithFormat:@"%p", value];
        }
    }

    // 编程式更改不会调用委托方法，需要手动调用
    [self textViewDidChange:self.inputTextView];
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [super sizeThatFits:size]; // 获取父类计算的尺寸
    // 加上分段控件的高度和边距
    fitSize.height += [self.objectTypeSegmentControl sizeThatFits:size].height + kSegmentInputMargin;

    return fitSize;
}

- (void)layoutSubviews {
    CGFloat segmentHeight = [self.objectTypeSegmentControl sizeThatFits:self.frame.size].height; // 获取分段控件高度
    self.objectTypeSegmentControl.frame = CGRectMake(
        0.0,
        // 我们的分段控件占据了文本视图的位置，
        // 就父类而言，我们重写此属性以使其不同
        super.topInputFieldVerticalLayoutGuide,
        self.frame.size.width,
        segmentHeight
    );

    [super layoutSubviews]; // 调用父类布局
}

- (CGFloat)topInputFieldVerticalLayoutGuide {
    // 我们的文本视图相对于分段控件有偏移
    CGFloat segmentHeight = [self.objectTypeSegmentControl sizeThatFits:self.frame.size].height;
    // 返回分段控件高度 + 父类顶部参考线 + 边距
    return segmentHeight + super.topInputFieldVerticalLayoutGuide + kSegmentInputMargin;
}

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type); // 确保类型不为空
    // 必须是对象类型或类类型
    return type[0] == FLEXTypeEncodingObjcObject || type[0] == FLEXTypeEncodingObjcClass;
}

+ (FLEXArgInputObjectType)preferredDefaultTypeForObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type[0] == FLEXTypeEncodingObjcObject || type[0] == FLEXTypeEncodingObjcClass); // 确保是对象或类类型

    if (value) {
        // 如果有当前值，它必须可序列化为 JSON
        // 才能显示 JSON 编辑器。否则显示地址字段。
        if ([FLEXRuntimeUtility editableJSONStringForObject:value]) {
            return FLEXArgInputObjectTypeJSON;
        } else {
            return FLEXArgInputObjectTypeAddress;
        }
    } else {
        // 否则，查看我们是否拥有比 'id' 更多的类型信息。
        // 如果有，请确保编码是可序列化为 JSON 的类型。
        // 属性和实例变量比方法参数保留更详细的类型编码信息。
        if (strcmp(type, @encode(id)) != 0) {
            BOOL isJSONSerializableType = NO; // 是否为 JSON 可序列化类型

            // 从字符串中解析类名，
            // 格式为 `@"ClassName"`
            Class cls = NSClassFromString(({
                NSString *className = nil;
                NSScanner *scan = [NSScanner scannerWithString:@(type)];
                // 允许的字符集
                NSCharacterSet *allowed = [NSCharacterSet
                    characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$"
                ];

                // 跳过 @" 然后扫描名称
                if ([scan scanString:@"@\"" intoString:nil]) {
                    [scan scanCharactersFromSet:allowed intoString:&className];
                }

                className;
            }));

            // 注意：我们不能在这里使用 @encode(NSString)，因为那会丢失
            // 类信息，只变成 @encode(id)。
            NSArray<Class> *jsonTypes = @[
                [NSString class],
                [NSNumber class],
                [NSArray class],
                [NSDictionary class],
            ];

            // 查找匹配的类型
            for (Class jsonClass in jsonTypes) {
                if ([cls isSubclassOfClass:jsonClass]) {
                    isJSONSerializableType = YES;
                    break;
                }
            }

            if (isJSONSerializableType) {
                return FLEXArgInputObjectTypeJSON; // 返回 JSON 类型
            } else {
                return FLEXArgInputObjectTypeAddress; // 返回地址类型
            }
        } else {
            return FLEXArgInputObjectTypeAddress; // 如果只有 'id' 类型信息，返回地址类型
        }
    }
}

@end
