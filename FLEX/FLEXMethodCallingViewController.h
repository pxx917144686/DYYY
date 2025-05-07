// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMethodCallingViewController.h
//  Flipboard
//
//  由 Ryan Olson 创建于 5/23/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXVariableEditorViewController.h"
#import "FLEXMethod.h"

@interface FLEXMethodCallingViewController : FLEXVariableEditorViewController

+ (instancetype)target:(id)target method:(FLEXMethod *)method;

@end
