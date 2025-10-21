//
//  FLEXArgumentInputJSONObjectView.m
//  Flipboard
//
//  由 Ryan Olson 于 6/15/14 创建.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利.
//

#import "FLEXArgumentInputObjectView.h"
#import "FLEXRuntimeUtility.h"

static const CGFloat kSegmentInputMargin = 10;

typedef NS_ENUM(NSUInteger, FLEXArgInputObjectType) {
    FLEXArgInputObjectTypeJSON,
    FLEXArgInputObjectTypeAddress
};

@interface FLEXArgumentInputObjectView ()

@property (nonatomic) UISegmentedControl *objectTypeSegmentControl;
@property (nonatomic) FLEXArgInputObjectType inputType;

@end

@implementation FLEXArgumentInputObjectView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        // 从数字和标点符号键盘开始，因为引号、大括号或
        // 方括号可能是JSON的第一个字符
        self.inputTextView.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        self.targetSize = FLEXArgumentInputViewSizeLarge;

        self.objectTypeSegmentControl = [[UISegmentedControl alloc] initWithItems:@[@"值", @"地址"]];
        [self.objectTypeSegmentControl addTarget:self action:@selector(didChangeType) forControlEvents:UIControlEventValueChanged];
        self.objectTypeSegmentControl.selectedSegmentIndex = 0;
        [self addSubview:self.objectTypeSegmentControl];

        self.inputType = [[self class] preferredDefaultTypeForObjCType:typeEncoding withCurrentValue:nil];
        self.objectTypeSegmentControl.selectedSegmentIndex = self.inputType;
    }

    return self;
}

- (void)didChangeType {
    self.inputType = self.objectTypeSegmentControl.selectedSegmentIndex;

    if (super.inputValue) {
        // 触发文本字段更新以显示
        // 我们得到的存储对象的地址，
        // 或显示对象的JSON表示
        [self populateTextAreaFromValue:super.inputValue];
    } else {
        // 清空文本字段
        [self populateTextAreaFromValue:nil];
    }
}

- (void)setInputType:(FLEXArgInputObjectType)inputType {
    if (_inputType == inputType) return;

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

    // 更改占位符
    switch (inputType) {
        case FLEXArgInputObjectTypeJSON:
            self.inputPlaceholderText =
            @"您可以在此处放置任何有效的JSON，如字符串、数字、数组或字典："
            "\n\"这是一个字符串\""
            "\n1234"
            "\n{ \"name\": \"pxx917144686\", \"age\": 47 }"
            "\n["
            "\n   1, 2, 3"
            "\n]";
            break;
        case FLEXArgInputObjectTypeAddress:
            self.inputPlaceholderText = @"0x0000deadb33f";
            break;
    }

    [self setNeedsLayout];
    [self.superview setNeedsLayout];
}

- (void)setInputValue:(id)inputValue {
    super.inputValue = inputValue;
    [self populateTextAreaFromValue:inputValue];
}

- (id)inputValue {
    switch (self.inputType) {
        case FLEXArgInputObjectTypeJSON:
            return [FLEXRuntimeUtility objectValueFromEditableJSONString:self.inputTextView.text];
        case FLEXArgInputObjectTypeAddress: {
            NSScanner *scanner = [NSScanner scannerWithString:self.inputTextView.text];

            unsigned long long objectPointerValue;
            if ([scanner scanHexLongLong:&objectPointerValue]) {
                return (__bridge id)(void *)objectPointerValue;
            }

            return nil;
        }
    }
}

- (void)populateTextAreaFromValue:(id)value {
    if (!value) {
        self.inputTextView.text = nil;
    } else {
        if (self.inputType == FLEXArgInputObjectTypeJSON) {
            self.inputTextView.text = [FLEXRuntimeUtility editableJSONStringForObject:value];
        } else if (self.inputType == FLEXArgInputObjectTypeAddress) {
            self.inputTextView.text = [NSString stringWithFormat:@"%p", value];
        }
    }

    // 对于程序化更改不会调用代理方法
    [self textViewDidChange:self.inputTextView];
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [super sizeThatFits:size];
    fitSize.height += [self.objectTypeSegmentControl sizeThatFits:size].height + kSegmentInputMargin;

    return fitSize;
}

- (void)layoutSubviews {
    CGFloat segmentHeight = [self.objectTypeSegmentControl sizeThatFits:self.frame.size].height;
    self.objectTypeSegmentControl.frame = CGRectMake(
        0.0,
        // 对于父类而言，我们的分段控件
        // 占据了文本视图的位置，
        // 而我们重写了这个属性以使其不同
        super.topInputFieldVerticalLayoutGuide,
        self.frame.size.width,
        segmentHeight
    );

    [super layoutSubviews];
}

- (CGFloat)topInputFieldVerticalLayoutGuide {
    // 我们的文本视图从分段控件偏移
    CGFloat segmentHeight = [self.objectTypeSegmentControl sizeThatFits:self.frame.size].height;
    return segmentHeight + super.topInputFieldVerticalLayoutGuide + kSegmentInputMargin;
}

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type);
    // 必须是对象类型
    return type[0] == FLEXTypeEncodingObjcObject || type[0] == FLEXTypeEncodingObjcClass;
}

+ (FLEXArgInputObjectType)preferredDefaultTypeForObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type[0] == FLEXTypeEncodingObjcObject || type[0] == FLEXTypeEncodingObjcClass);

    if (value) {
        // 如果有当前值，它必须可序列化为JSON
        // 才能显示JSON编辑器。否则显示地址字段。
        if ([FLEXRuntimeUtility editableJSONStringForObject:value]) {
            return FLEXArgInputObjectTypeJSON;
        } else {
            return FLEXArgInputObjectTypeAddress;
        }
    } else {
        // 否则，看看我们是否有比'id'更多的类型信息。
        // 如果有，确保编码是可序列化为JSON的。
        // 属性和实例变量比方法参数保留更详细的类型编码信息。
        if (strcmp(type, @encode(id)) != 0) {
            BOOL isJSONSerializableType = NO;

            // 从字符串中解析类名，
            // 格式为 `@"ClassName"`
            Class cls = NSClassFromString(({
                NSString *className = nil;
                NSScanner *scan = [NSScanner scannerWithString:@(type)];
                NSCharacterSet *allowed = [NSCharacterSet
                    characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$"
                ];

                // 跳过@"然后扫描名称
                if ([scan scanString:@"@\"" intoString:nil]) {
                    [scan scanCharactersFromSet:allowed intoString:&className];
                }

                className;
            }));

            // 注意：我们不能在这里使用@encode(NSString)，因为它会丢弃
            // 类信息，变成@encode(id)。
            NSArray<Class> *jsonTypes = @[
                [NSString class],
                [NSNumber class],
                [NSArray class],
                [NSDictionary class],
            ];

            // 查找匹配类型
            for (Class jsonClass in jsonTypes) {
                if ([cls isSubclassOfClass:jsonClass]) {
                    isJSONSerializableType = YES;
                    break;
                }
            }

            if (isJSONSerializableType) {
                return FLEXArgInputObjectTypeJSON;
            } else {
                return FLEXArgInputObjectTypeAddress;
            }
        } else {
            return FLEXArgInputObjectTypeAddress;
        }
    }
}

@end
