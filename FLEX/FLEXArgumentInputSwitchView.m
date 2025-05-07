//
//  FLEXArgumentInputSwitchView.m
//  Flipboard
//
//  创建者：Ryan Olson，日期：6/16/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXArgumentInputSwitchView.h"

@interface FLEXArgumentInputSwitchView ()

@property (nonatomic) UISwitch *inputSwitch;

@end

@implementation FLEXArgumentInputSwitchView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        self.inputSwitch = [UISwitch new];
        [self.inputSwitch addTarget:self action:@selector(switchValueDidChange:) forControlEvents:UIControlEventValueChanged];
        [self.inputSwitch sizeToFit]; // 根据内容调整大小
        [self addSubview:self.inputSwitch];
    }
    return self;
}


#pragma mark Input/Output // 输入/输出

- (void)setInputValue:(id)inputValue {
    BOOL on = NO;
    if ([inputValue isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)inputValue;
        on = [number boolValue];
    } else if ([inputValue isKindOfClass:[NSValue class]]) {
        NSValue *value = (NSValue *)inputValue;
        if (strcmp([value objCType], @encode(BOOL)) == 0) {
            [value getValue:&on];
        }
    }
    self.inputSwitch.on = on;
}

- (id)inputValue {
    BOOL isOn = [self.inputSwitch isOn];
    NSValue *boxedBool = [NSValue value:&isOn withObjCType:@encode(BOOL)];
    return boxedBool;
}

- (void)switchValueDidChange:(id)sender {
    [self.delegate argumentInputViewValueDidChange:self];
}


#pragma mark - Layout and Sizing // 布局和尺寸

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.inputSwitch.frame = CGRectMake(0, self.topInputFieldVerticalLayoutGuide, self.inputSwitch.frame.size.width, self.inputSwitch.frame.size.height);
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [super sizeThatFits:size];
    fitSize.height += self.inputSwitch.frame.size.height;
    return fitSize;
}


#pragma mark - Class Helpers // 类助手方法

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type);
    // 仅限 BOOL 类型。当前值无关紧要。
    return strcmp(type, @encode(BOOL)) == 0;
}

@end
