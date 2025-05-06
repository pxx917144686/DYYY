// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputFontsPickerView.m
//  FLEX
//
//  由 啟倫 陳 创建于 2014/7/27。
//  版权所有 (c) 2014年 f。保留所有权利。 // 版权信息可能需要更新
//

#import "FLEXArgumentInputFontsPickerView.h"
#import "FLEXRuntimeUtility.h"

@interface FLEXArgumentInputFontsPickerView ()

@property (nonatomic) NSMutableArray<NSString *> *availableFonts; // 可用字体列表

@end


@implementation FLEXArgumentInputFontsPickerView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        self.targetSize = FLEXArgumentInputViewSizeSmall; // 设置目标尺寸为小
        [self createAvailableFonts]; // 创建可用字体列表
        self.inputTextView.inputView = [self createFontsPicker]; // 设置输入视图为字体选择器
    }
    return self;
}

- (void)setInputValue:(id)inputValue {
    self.inputTextView.text = inputValue; // 设置文本框内容
    // 如果字体不在列表中，则添加到列表开头
    if ([self.availableFonts indexOfObject:inputValue] == NSNotFound) {
        [self.availableFonts insertObject:inputValue atIndex:0];
    }
    // 在选择器中选中对应的行
    [(UIPickerView *)self.inputTextView.inputView selectRow:[self.availableFonts indexOfObject:inputValue] inComponent:0 animated:NO];
}

- (id)inputValue {
    // 返回文本框内容的副本，如果为空则返回 nil
    return self.inputTextView.text.length > 0 ? [self.inputTextView.text copy] : nil;
}

#pragma mark - 私有方法

- (UIPickerView*)createFontsPicker {
    UIPickerView *fontsPicker = [UIPickerView new];
    fontsPicker.dataSource = self; // 设置数据源
    fontsPicker.delegate = self;   // 设置代理
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // 在 iOS 13 中已弃用；从那时起，选择始终显示
    fontsPicker.showsSelectionIndicator = YES;
    #pragma clang diagnostic pop

    return fontsPicker;
}

- (void)createAvailableFonts {
    NSMutableArray<NSString *> *unsortedFontsArray = [NSMutableArray new];
    // 遍历所有字体族和字体名称
    for (NSString *eachFontFamily in UIFont.familyNames) {
        for (NSString *eachFontName in [UIFont fontNamesForFamilyName:eachFontFamily]) {
            [unsortedFontsArray addObject:eachFontName];
        }
    }
    // 对字体名称进行本地化不区分大小写排序
    self.availableFonts = [NSMutableArray arrayWithArray:[unsortedFontsArray sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    // 只有一个组件
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    // 行数为可用字体数量
    return self.availableFonts.count;
}

#pragma mark - UIPickerViewDelegate

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel *fontLabel;
    if (!view) {
        // 如果没有可重用的视图，则创建新的 UILabel
        fontLabel = [UILabel new];
        fontLabel.backgroundColor = UIColor.clearColor;
        fontLabel.textAlignment = NSTextAlignmentCenter;
    } else {
        // 重用视图
        fontLabel = (UILabel*)view;
    }
    // 获取对应行的字体
    UIFont *font = [UIFont fontWithName:self.availableFonts[row] size:15.0];
    // 设置富文本属性
    NSDictionary<NSString *, id> *attributesDictionary = [NSDictionary<NSString *, id> dictionaryWithObject:font forKey:NSFontAttributeName];
    NSAttributedString *attributesString = [[NSAttributedString alloc] initWithString:self.availableFonts[row] attributes:attributesDictionary];
    fontLabel.attributedText = attributesString;
    [fontLabel sizeToFit]; // 调整大小以适应内容
    return fontLabel;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    // 当选中某行时，更新文本框内容
    self.inputTextView.text = self.availableFonts[row];
}

@end
