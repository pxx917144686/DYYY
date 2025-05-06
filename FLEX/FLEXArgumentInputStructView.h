// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputStructView.h
//  Flipboard
//
//  Created by Ryan Olson on 6/16/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXArgumentInputView.h"

@interface FLEXArgumentInputStructView : FLEXArgumentInputView

/// 为自定义结构体类型启用显示实例变量名称
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding;

@end
