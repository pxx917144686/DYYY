//
//  NSString+ObjcRuntime.h
//  FLEX
//
//  衍生自 MirrorKit。
//  由 Tanner 创建于 7/1/15。
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

@interface NSString (Utilities)

/// 如果接收者是有效的属性属性字符串，则返回属性属性的字典。
/// 值要么是字符串，要么是 \c YES。为 false 的布尔属性将不会
/// 出现在字典中。参见此链接了解如何构造正确的属性字符串：
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
///
/// 注意：此方法对某些类型编码不能正常工作，运行时本身的
/// property_copyAttributeValue 函数也是如此。
- (NSDictionary *)propertyAttributes;

@end
