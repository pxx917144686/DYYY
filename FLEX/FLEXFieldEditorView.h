//
//  FLEXFieldEditorView.h
//  Flipboard
//
//  创建者：Ryan Olson，日期：5/16/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@class FLEXArgumentInputView;

@interface FLEXFieldEditorView : UIView

@property (nonatomic, copy) NSString *targetDescription;
@property (nonatomic, copy) NSString *fieldDescription;

@property (nonatomic, copy) NSArray<FLEXArgumentInputView *> *argumentInputViews;

@end
