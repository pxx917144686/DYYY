// 遇到问题联系中文翻译作者：pxx917144686
//
//  UIPasteboard+FLEX.h
//  FLEX
//
//  由 Tanner Bennett 创建于 12/9/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

@interface UIPasteboard (FLEX)

/// 用于复制一个对象，该对象可以是字符串、数据或数字
- (void)flex_copy:(id)unknownType; // 复制对象

@end
