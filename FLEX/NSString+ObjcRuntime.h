// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSString+ObjcRuntime.h
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 7/1/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

@interface NSString (Utilities)

/// 如果接收者是有效的属性字符串，则返回属性字典。
/// 值可以是字符串或 \c YES。值为 false 的布尔属性将不会出现在字典中。
/// 关于如何构造正确的属性字符串，请参阅此链接：
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
///
/// 注意：此方法对于某些类型编码无法正常工作，运行时本身的 property_copyAttributeValue 函数也是如此。Radar：FB7499230
- (NSDictionary *)propertyAttributes;

@end
