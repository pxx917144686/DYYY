//
//  FLEXArgumentInputView.h
//  Flipboard
//
//  创建者：Ryan Olson，日期：5/30/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, FLEXArgumentInputViewSize) {
    /// 2 行，中等大小
    FLEXArgumentInputViewSizeDefault = 0,
    /// 一行
    FLEXArgumentInputViewSizeSmall,
    /// 多行
    FLEXArgumentInputViewSizeLarge
};

@protocol FLEXArgumentInputViewDelegate;

@interface FLEXArgumentInputView : UIView

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding;

/// 字段的名称。可选（可以为 nil）。
@property (nonatomic, copy) NSString *title;

/// 要使用初始值填充字段，请设置此属性。
/// 要检索用户输入的值，请访问此属性。
/// 原始类型和结构体应该/将会被包装在 NSValue 容器中。
/// 具体子类应覆盖此属性的 setter 和 getter。
/// 子类可以调用 super.inputValue 来访问该值的后备存储。
@property (nonatomic) id inputValue;

/// 将此值设置为 large 会使某些参数输入视图增大其输入字段的大小。
/// 如果屏幕上只有一个输入视图（即用于属性和实例变量编辑），则有助于增加空间利用率。
@property (nonatomic) FLEXArgumentInputViewSize targetSize;

/// 输入视图的用户可以获取用户输入增量更改的委托回调。
@property (nonatomic, weak) id <FLEXArgumentInputViewDelegate> delegate;

// 子类可以覆盖

/// 如果输入视图有一个或多个文本视图，则当其中一个获得焦点时返回 YES。
@property (nonatomic, readonly) BOOL inputViewIsFirstResponder;

///供子类指示它们可以处理编辑给定类型和值的字段。
/// FLEXArgumentInputViewFactory 使用它来创建适当的输入视图。
+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value;

// 仅供子类使用

@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) NSString *typeEncoding;
@property (nonatomic, readonly) CGFloat topInputFieldVerticalLayoutGuide;

@end

@protocol FLEXArgumentInputViewDelegate <NSObject>

- (void)argumentInputViewValueDidChange:(FLEXArgumentInputView *)argumentInputView;

@end
