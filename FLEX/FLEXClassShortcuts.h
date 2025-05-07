//
//  FLEXClassShortcuts.h
//  FLEX
//
//  创建者：Tanner Bennett，日期：11/22/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXShortcutsSection.h"

/// 为类对象提供便捷的快捷方式。
/// 这是所有类对象的默认部分。
@interface FLEXClassShortcuts : FLEXShortcutsSection

+ (instancetype)forObject:(Class)cls;

@end
