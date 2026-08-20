#ifndef DYYY_CUSTOM_INPUT_VIEW_H
#define DYYY_CUSTOM_INPUT_VIEW_H

#import <UIKit/UIKit.h>

#ifndef DYYYCustomInputView_DEFINED
#define DYYYCustomInputView_DEFINED

NS_ASSUME_NONNULL_BEGIN

// 自定义文本输入视图
@interface DYYYCustomInputView : UIView <UITextFieldDelegate>
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *inputTextField;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy, nullable) void (^onConfirm)(NSString *text);
@property (nonatomic, copy, nullable) void (^onCancel)(void);
@property (nonatomic, assign) CGRect originalFrame; 
@property (nonatomic, copy, nullable) NSString *defaultText;
@property (nonatomic, copy, nullable) NSString *placeholderText;

- (instancetype)initWithTitle:(NSString *)title defaultText:(nullable NSString *)defaultText;
- (instancetype)initWithTitle:(NSString *)title defaultText:(nullable NSString *)defaultText placeholder:(nullable NSString *)placeholder;
- (instancetype)initWithTitle:(NSString *)title;
- (void)show;
- (void)showWithConfirmBlock:(void (^)(NSString *text))confirmBlock cancelBlock:(nullable void (^)(void))cancelBlock;
- (void)dismiss;
@end

NS_ASSUME_NONNULL_END

#endif // DYYYCustomInputView_DEFINED
#endif // DYYY_CUSTOM_INPUT_VIEW_H
