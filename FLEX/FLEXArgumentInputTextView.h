//
//  FLEXArgumentInputTextView.h
//  FLEXInjected
//
//  创建者：Ryan Olson，日期：6/15/14.
//
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXArgumentInputView.h"

@interface FLEXArgumentInputTextView : FLEXArgumentInputView <UITextViewDelegate>

// 仅供子类使用

@property (nonatomic, readonly) UITextView *inputTextView;
@property (nonatomic) NSString *inputPlaceholderText;

@end
