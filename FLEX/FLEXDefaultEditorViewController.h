//
//  FLEXDefaultEditorViewController.h
//  Flipboard
//
//  创建者：Ryan Olson，日期：5/23/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXFieldEditorViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDefaultEditorViewController : FLEXVariableEditorViewController

+ (instancetype)target:(NSUserDefaults *)defaults key:(NSString *)key commitHandler:(void(^_Nullable)(void))onCommit;

+ (BOOL)canEditDefaultWithValue:(nullable id)currentValue;

@end

NS_ASSUME_NONNULL_END
