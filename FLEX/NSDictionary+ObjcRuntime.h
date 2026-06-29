//
//  NSDictionary+ObjcRuntime.h
//  FLEX
//
//  衍生自 MirrorKit。
//  由 Tanner 创建于 7/5/15。
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSDictionary (ObjcRuntime)

/// \c kFLEXPropertyAttributeKeyTypeEncoding 是唯一必需的键。
/// 表示布尔值的键应该有 \c YES 值，而不是空字符串。
- (NSString *)propertyAttributesString;

+ (instancetype)attributesDictionaryForProperty:(objc_property_t)property;

@end
