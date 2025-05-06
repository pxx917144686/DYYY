// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputFontView.m
//  Flipboard
//
//  由 Ryan Olson 创建于 2014/6/28。
//  版权所有 (c) 2020 FLEX 团队。保留所有权利。
//

#import "FLEXArgumentInputFontView.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXArgumentInputFontsPickerView.h"

@interface FLEXArgumentInputFontView ()

@property (nonatomic) FLEXArgumentInputView *fontNameInput;
@property (nonatomic) FLEXArgumentInputView *pointSizeInput;

@end

@implementation FLEXArgumentInputFontView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        // 初始化字体名称输入视图
        self.fontNameInput = [[FLEXArgumentInputFontsPickerView alloc] initWithArgumentTypeEncoding:FLEXEncodeClass(NSString)];
        self.fontNameInput.targetSize = FLEXArgumentInputViewSizeSmall;
        self.fontNameInput.title = @"字体名称:";
        [self addSubview:self.fontNameInput];
        
        // 初始化字号输入视图
        self.pointSizeInput = [FLEXArgumentInputViewFactory argumentInputViewForTypeEncoding:@encode(CGFloat)];
        self.pointSizeInput.targetSize = FLEXArgumentInputViewSizeSmall;
        self.pointSizeInput.title = @"点大小:";
        [self addSubview:self.pointSizeInput];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    self.fontNameInput.backgroundColor = backgroundColor;
    self.pointSizeInput.backgroundColor = backgroundColor;
}

- (void)setInputValue:(id)inputValue {
    if ([inputValue isKindOfClass:[UIFont class]]) {
        // 设置字体名称和大小
        UIFont *font = (UIFont *)inputValue;
        self.fontNameInput.inputValue = font.fontName;
        self.pointSizeInput.inputValue = @(font.pointSize);
    }
}

- (id)inputValue {
    CGFloat pointSize = 0;
    if ([self.pointSizeInput.inputValue isKindOfClass:[NSValue class]]) {
        // 获取点大小
        NSValue *pointSizeValue = (NSValue *)self.pointSizeInput.inputValue;
        if (strcmp([pointSizeValue objCType], @encode(CGFloat)) == 0) {
            [pointSizeValue getValue:&pointSize];
        }
    }
    // 根据字体名称和大小创建 UIFont 对象
    return [UIFont fontWithName:self.fontNameInput.inputValue size:pointSize];
}

- (BOOL)inputViewIsFirstResponder {
    // 检查任一子输入视图是否为第一响应者
    return [self.fontNameInput inputViewIsFirstResponder] || [self.pointSizeInput inputViewIsFirstResponder];
}


#pragma mark - 布局和尺寸调整

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat runningOriginY = self.topInputFieldVerticalLayoutGuide; // 获取顶部布局参考线
    
    // 布局字体名称输入视图
    CGSize fontNameFitSize = [self.fontNameInput sizeThatFits:self.bounds.size];
    self.fontNameInput.frame = CGRectMake(0, runningOriginY, fontNameFitSize.width, fontNameFitSize.height);
    runningOriginY = CGRectGetMaxY(self.fontNameInput.frame) + [[self class] verticalPaddingBetweenFields]; // 更新 Y 坐标
    
    // 布局字号输入视图
    CGSize pointSizeFitSize = [self.pointSizeInput sizeThatFits:self.bounds.size];
    self.pointSizeInput.frame = CGRectMake(0, runningOriginY, pointSizeFitSize.width, pointSizeFitSize.height);
}

+ (CGFloat)verticalPaddingBetweenFields {
    // 字段之间的垂直填充
    return 10.0;
}

- (CGSize)sizeThatFits:(CGSize)size {
    // 计算适合的尺寸
    CGSize fitSize = [super sizeThatFits:size]; // 获取父类计算的尺寸
    
    CGSize constrainSize = CGSizeMake(size.width, CGFLOAT_MAX); // 约束尺寸
    
    CGFloat height = fitSize.height; // 初始高度
    // 累加子视图高度和间距
    height += [self.fontNameInput sizeThatFits:constrainSize].height;
    height += [[self class] verticalPaddingBetweenFields];
    height += [self.pointSizeInput sizeThatFits:constrainSize].height;
    
    return CGSizeMake(fitSize.width, height); // 返回最终计算的尺寸
}


#pragma mark - 类方法

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    // 检查是否支持给定的 Objective-C 类型 (UIFont)
    NSParameterAssert(type); // 确保类型不为空
    return strcmp(type, FLEXEncodeClass(UIFont)) == 0;
}

@end
