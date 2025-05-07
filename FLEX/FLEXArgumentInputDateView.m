// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputDateView.m
//  Flipboard
//
//  由 Daniel Rodriguez Troitino 创建于 2015/2/14。
//  版权所有 (c) 2020 FLEX 团队。保留所有权利。
//

#import "FLEXArgumentInputDateView.h"
#import "FLEXRuntimeUtility.h"

@interface FLEXArgumentInputDateView ()

@property (nonatomic) UIDatePicker *datePicker; // 日期选择器

@end

@implementation FLEXArgumentInputDateView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        self.datePicker = [UIDatePicker new];
        self.datePicker.datePickerMode = UIDatePickerModeDateAndTime; // 设置模式为日期和时间
        // 使用 UTC，因为 NSDate 的描述会打印 UTC 时间
        self.datePicker.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]; // 使用公历
        self.datePicker.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"]; // 设置时区为 UTC
        if (@available(iOS 13.4, *)) {
            self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels; // 使用滚轮样式 (iOS 13.4+)
        }
        [self addSubview:self.datePicker];
    }
    return self;
}

- (void)setInputValue:(id)inputValue {
    if ([inputValue isKindOfClass:[NSDate class]]) {
        // 如果输入值是 NSDate，则设置日期选择器的日期
        self.datePicker.date = inputValue;
    }
}

- (id)inputValue {
    // 返回日期选择器的当前日期
    return self.datePicker.date;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // 设置日期选择器的 frame 为视图边界
    self.datePicker.frame = self.bounds;
}

- (CGSize)sizeThatFits:(CGSize)size {
    // 获取日期选择器适合的尺寸
    CGFloat height = [self.datePicker sizeThatFits:size].height;
    return CGSizeMake(size.width, height);
}

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type); // 确保类型不为空
    // 检查类型是否为 NSDate
    return strcmp(type, FLEXEncodeClass(NSDate)) == 0;
}

@end
