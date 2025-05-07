// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputColorView.m
//  Flipboard
//
//  由 Ryan Olson 创建于 2014/6/30。
//  版权所有 (c) 2020 FLEX 团队。保留所有权利。
//

#import "FLEXArgumentInputColorView.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"

@protocol FLEXColorComponentInputViewDelegate;

@interface FLEXColorComponentInputView : UIView

@property (nonatomic) UISlider *slider;
@property (nonatomic) UILabel *valueLabel;

@property (nonatomic, weak) id <FLEXColorComponentInputViewDelegate> delegate;

@end

@protocol FLEXColorComponentInputViewDelegate <NSObject>

- (void)colorComponentInputViewValueDidChange:(FLEXColorComponentInputView *)colorComponentInputView;

@end


@implementation FLEXColorComponentInputView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.slider = [UISlider new];
        [self.slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:self.slider];
        
        self.valueLabel = [UILabel new];
        self.valueLabel.backgroundColor = self.backgroundColor;
        self.valueLabel.font = [UIFont systemFontOfSize:14.0];
        self.valueLabel.textAlignment = NSTextAlignmentRight;
        [self addSubview:self.valueLabel];
        
        [self updateValueLabel];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    self.slider.backgroundColor = backgroundColor;
    self.valueLabel.backgroundColor = backgroundColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    const CGFloat kValueLabelWidth = 50.0; // 值标签宽度
    
    [self.slider sizeToFit]; // 调整滑块大小
    CGFloat sliderWidth = self.bounds.size.width - kValueLabelWidth; // 计算滑块宽度
    self.slider.frame = CGRectMake(0, 0, sliderWidth, self.slider.frame.size.height); // 设置滑块 frame
    
    [self.valueLabel sizeToFit]; // 调整值标签大小
    CGFloat valueLabelOriginX = CGRectGetMaxX(self.slider.frame); // 计算值标签 X 坐标
    // 计算值标签 Y 坐标，使其垂直居中
    CGFloat valueLabelOriginY = FLEXFloor((self.slider.frame.size.height - self.valueLabel.frame.size.height) / 2.0);
    self.valueLabel.frame = CGRectMake(valueLabelOriginX, valueLabelOriginY, kValueLabelWidth, self.valueLabel.frame.size.height); // 设置值标签 frame
}

- (void)sliderChanged:(id)sender {
    // 通知代理值已更改
    [self.delegate colorComponentInputViewValueDidChange:self];
    [self updateValueLabel]; // 更新值标签
}

- (void)updateValueLabel {
    // 更新值标签文本，格式化为三位小数
    self.valueLabel.text = [NSString stringWithFormat:@"%.3f", self.slider.value];
}

- (CGSize)sizeThatFits:(CGSize)size {
    // 返回滑块的高度作为视图的高度
    CGFloat height = [self.slider sizeThatFits:size].height;
    return CGSizeMake(size.width, height);
}

@end

@interface FLEXColorPreviewBox : UIView

@property (nonatomic) UIColor *color;

@property (nonatomic) UIView *colorOverlayView;

@end

@implementation FLEXColorPreviewBox

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = UIColor.blackColor.CGColor;
        self.backgroundColor = [UIColor colorWithPatternImage:[[self class] backgroundPatternImage]];
        
        self.colorOverlayView = [[UIView alloc] initWithFrame:self.bounds];
        self.colorOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.colorOverlayView.backgroundColor = UIColor.clearColor;
        [self addSubview:self.colorOverlayView];
    }
    return self;
}

- (void)setColor:(UIColor *)color {
    self.colorOverlayView.backgroundColor = color;
}

- (UIColor *)color {
    return self.colorOverlayView.backgroundColor;
}

+ (UIImage *)backgroundPatternImage {
    // 创建棋盘格背景图案
    const CGFloat kSquareDimension = 5.0; // 方块尺寸
    CGSize squareSize = CGSizeMake(kSquareDimension, kSquareDimension);
    CGSize imageSize = CGSizeMake(2.0 * kSquareDimension, 2.0 * kSquareDimension); // 图像尺寸为 2x2 方块
    
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, UIScreen.mainScreen.scale); // 开始图像上下文
    
    // 填充白色背景
    [UIColor.whiteColor setFill];
    UIRectFill(CGRectMake(0, 0, imageSize.width, imageSize.height));
    
    // 填充灰色方块，形成棋盘格
    [UIColor.grayColor setFill];
    UIRectFill(CGRectMake(squareSize.width, 0, squareSize.width, squareSize.height));
    UIRectFill(CGRectMake(0, squareSize.height, squareSize.width, squareSize.height));
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); // 获取图像
    UIGraphicsEndImageContext(); // 结束图像上下文
    
    return image;
}

@end

@interface FLEXArgumentInputColorView () <FLEXColorComponentInputViewDelegate>

@property (nonatomic) FLEXColorPreviewBox *colorPreviewBox;
@property (nonatomic) UILabel *hexLabel;
@property (nonatomic) FLEXColorComponentInputView *alphaInput;
@property (nonatomic) FLEXColorComponentInputView *redInput;
@property (nonatomic) FLEXColorComponentInputView *greenInput;
@property (nonatomic) FLEXColorComponentInputView *blueInput;

@end

@implementation FLEXArgumentInputColorView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        self.colorPreviewBox = [FLEXColorPreviewBox new];
        [self addSubview:self.colorPreviewBox];
        
        self.hexLabel = [UILabel new];
        self.hexLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
        self.hexLabel.textAlignment = NSTextAlignmentCenter;
        self.hexLabel.font = [UIFont systemFontOfSize:12.0];
        [self addSubview:self.hexLabel];
        
        self.alphaInput = [FLEXColorComponentInputView new];
        self.alphaInput.slider.minimumTrackTintColor = UIColor.blackColor;
        self.alphaInput.delegate = self;
        [self addSubview:self.alphaInput];
        
        self.redInput = [FLEXColorComponentInputView new];
        self.redInput.slider.minimumTrackTintColor = UIColor.redColor;
        self.redInput.delegate = self;
        [self addSubview:self.redInput];
        
        self.greenInput = [FLEXColorComponentInputView new];
        self.greenInput.slider.minimumTrackTintColor = UIColor.greenColor;
        self.greenInput.delegate = self;
        [self addSubview:self.greenInput];
        
        self.blueInput = [FLEXColorComponentInputView new];
        self.blueInput.slider.minimumTrackTintColor = UIColor.blueColor;
        self.blueInput.delegate = self;
        [self addSubview:self.blueInput];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    self.alphaInput.backgroundColor = backgroundColor;
    self.redInput.backgroundColor = backgroundColor;
    self.greenInput.backgroundColor = backgroundColor;
    self.blueInput.backgroundColor = backgroundColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat runningOriginY = 0; // 当前 Y 坐标
    CGSize constrainSize = CGSizeMake(self.bounds.size.width, CGFLOAT_MAX); // 约束尺寸
    
    // 布局颜色预览框
    self.colorPreviewBox.frame = CGRectMake(0, runningOriginY, self.bounds.size.width, [[self class] colorPreviewBoxHeight]);
    runningOriginY = CGRectGetMaxY(self.colorPreviewBox.frame) + [[self class] inputViewVerticalPadding]; // 更新 Y 坐标
    
    [self.hexLabel sizeToFit]; // 调整十六进制标签大小
    const CGFloat kLabelVerticalOutsetAmount = 0.0; // 垂直外扩量
    const CGFloat kLabelHorizontalOutsetAmount = 2.0; // 水平外扩量
    // 计算标签的外扩矩形
    UIEdgeInsets labelOutset = UIEdgeInsetsMake(-kLabelVerticalOutsetAmount, -kLabelHorizontalOutsetAmount, -kLabelVerticalOutsetAmount, -kLabelHorizontalOutsetAmount);
    self.hexLabel.frame = UIEdgeInsetsInsetRect(self.hexLabel.frame, labelOutset); // 应用外扩
    // 计算十六进制标签的位置，使其位于预览框右下角
    CGFloat hexLabelOriginX = self.colorPreviewBox.layer.borderWidth;
    CGFloat hexLabelOriginY = CGRectGetMaxY(self.colorPreviewBox.frame) - self.colorPreviewBox.layer.borderWidth - self.hexLabel.frame.size.height;
    self.hexLabel.frame = CGRectMake(hexLabelOriginX, hexLabelOriginY, self.hexLabel.frame.size.width, self.hexLabel.frame.size.height); // 设置 frame
    
    // 更新标签文本以反映当前值
    [self.alphaInput updateValueLabel];
    [self.redInput updateValueLabel];
    [self.greenInput updateValueLabel];
    [self.blueInput updateValueLabel];

    // 布局颜色分量输入视图
    NSArray<FLEXColorComponentInputView *> *colorComponentInputViews = @[self.alphaInput, self.redInput, self.greenInput, self.blueInput];
    for (FLEXColorComponentInputView *inputView in colorComponentInputViews) {
        CGSize fitSize = [inputView sizeThatFits:constrainSize]; // 计算适合的尺寸
        inputView.frame = CGRectMake(0, runningOriginY, fitSize.width, fitSize.height); // 设置 frame
        runningOriginY = CGRectGetMaxY(inputView.frame) + [[self class] inputViewVerticalPadding]; // 更新 Y 坐标
    }
}

- (void)setInputValue:(id)inputValue {
    if ([inputValue isKindOfClass:[UIColor class]]) {
        // 如果是 UIColor，直接更新
        [self updateWithColor:inputValue];
    } else if ([inputValue isKindOfClass:[NSValue class]]) {
        const char *type = [inputValue objCType];
        if (strcmp(type, @encode(CGColorRef)) == 0) {
            // 如果是 CGColorRef，转换为 UIColor 后更新
            CGColorRef colorRef;
            [inputValue getValue:&colorRef];
            UIColor *color = [[UIColor alloc] initWithCGColor:colorRef];
            [self updateWithColor:color];
        }
    } else {
        // 默认使用透明色
        [self updateWithColor:UIColor.clearColor];
    }
}

- (id)inputValue {
    // 根据滑块值创建 UIColor 对象
    return [UIColor colorWithRed:self.redInput.slider.value green:self.greenInput.slider.value blue:self.blueInput.slider.value alpha:self.alphaInput.slider.value];
}

- (void)colorComponentInputViewValueDidChange:(FLEXColorComponentInputView *)colorComponentInputView {
    // 当颜色分量改变时，更新颜色预览
    [self updateColorPreview];
}

- (void)updateWithColor:(UIColor *)color {
    CGFloat red, green, blue, white, alpha;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        // 获取 RGBA 分量并更新滑块和标签
        self.alphaInput.slider.value = alpha;
        [self.alphaInput updateValueLabel];
        self.redInput.slider.value = red;
        [self.redInput updateValueLabel];
        self.greenInput.slider.value = green;
        [self.greenInput updateValueLabel];
        self.blueInput.slider.value = blue;
        [self.blueInput updateValueLabel];
    } else if ([color getWhite:&white alpha:&alpha]) {
        // 处理灰度颜色，将灰度值赋给 RGB 分量
        self.alphaInput.slider.value = alpha;
        [self.alphaInput updateValueLabel];
        self.redInput.slider.value = white;
        [self.redInput updateValueLabel];
        self.greenInput.slider.value = white;
        [self.greenInput updateValueLabel];
        self.blueInput.slider.value = white;
        [self.blueInput updateValueLabel];
    }
    [self updateColorPreview]; // 更新颜色预览
}

- (void)updateColorPreview {
    self.colorPreviewBox.color = self.inputValue; // 更新预览框颜色
    // 计算 RGB 字节值
    unsigned char redByte = self.redInput.slider.value * 255;
    unsigned char greenByte = self.greenInput.slider.value * 255;
    unsigned char blueByte = self.blueInput.slider.value * 255;
    // 更新十六进制标签文本
    self.hexLabel.text = [NSString stringWithFormat:@"#%02X%02X%02X", redByte, greenByte, blueByte];
    [self setNeedsLayout]; // 标记需要重新布局
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat height = 0;
    // 累加预览框和各分量输入视图的高度及间距
    height += [[self class] colorPreviewBoxHeight];
    height += [[self class] inputViewVerticalPadding];
    height += [self.alphaInput sizeThatFits:size].height;
    height += [[self class] inputViewVerticalPadding];
    height += [self.redInput sizeThatFits:size].height;
    height += [[self class] inputViewVerticalPadding];
    height += [self.greenInput sizeThatFits:size].height;
    height += [[self class] inputViewVerticalPadding];
    height += [self.blueInput sizeThatFits:size].height;
    return CGSizeMake(size.width, height); // 返回计算的总高度
}

+ (CGFloat)inputViewVerticalPadding {
    // 输入视图之间的垂直间距
    return 10.0;
}

+ (CGFloat)colorPreviewBoxHeight {
    // 颜色预览框的高度
    return 40.0;
}

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type); // 确保类型不为空

    // 我们不关心 currentValue 是否是颜色；我们将默认为 +clearColor
    // 检查类型是否为 CGColorRef 或 UIColor
    return (strcmp(type, @encode(CGColorRef)) == 0) || (strcmp(type, FLEXEncodeClass(UIColor)) == 0);
}

@end
