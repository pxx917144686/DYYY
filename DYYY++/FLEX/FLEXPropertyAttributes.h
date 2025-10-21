//
//  FLEXPropertyAttributes.h
//  FLEX
//
//  派生自 MirrorKit.
//  Created by Tanner on 7/5/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark FLEXPropertyAttributes

/// 参见 \e FLEXRuntimeUtilitiy.h 获取有效的字符串标记。
/// 查看此链接了解如何构建正确的属性字符串：
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
@interface FLEXPropertyAttributes : NSObject <NSCopying, NSMutableCopying> {
// 这些对于可变子类的功能是必要的
@protected
    NSUInteger _count;
    NSString *_string, *_backingIvar, *_typeEncoding, *_oldTypeEncoding, *_fullDeclaration;
    NSDictionary *_dictionary;
    objc_property_attribute_t *_list;
    SEL _customGetter, _customSetter;
    BOOL _isReadOnly, _isCopy, _isRetained, _isNonatomic, _isDynamic, _isWeak, _isGarbageCollectable;
}

+ (instancetype)attributesForProperty:(objc_property_t)property;
/// @warning 如果 \e attributes 无效、\c nil 或包含不支持的键，则会引发异常。
+ (instancetype)attributesFromDictionary:(NSDictionary *)attributes;

/// 将属性列表复制到您必须自己调用 \c free() 的缓冲区。
/// 如果您不需要更多地控制列表的生命周期，请使用 \c list。
/// @param attributesCountOut 返回属性数量的参数。
- (objc_property_attribute_t *)copyAttributesList:(nullable unsigned int *)attributesCountOut;

/// 属性特性的数量。
@property (nonatomic, readonly) NSUInteger count;
/// 用于 \c class_replaceProperty 等方法。
@property (nonatomic, readonly) objc_property_attribute_t *list;
/// 属性特性的字符串值。
@property (nonatomic, readonly) NSString *string;
/// 属性特性的人类可读版本。
@property (nonatomic, readonly) NSString *fullDeclaration;
/// 属性特性的字典。
/// 值要么是字符串，要么是 \c YES。布尔属性
/// 如果为假则不会出现在字典中。
@property (nonatomic, readonly) NSDictionary *dictionary;

/// 支持该属性的实例变量的名称。
@property (nonatomic, readonly, nullable) NSString *backingIvar;
/// 属性的类型编码。
@property (nonatomic, readonly, nullable) NSString *typeEncoding;
/// 属性的 \e 旧类型编码。
@property (nonatomic, readonly, nullable) NSString *oldTypeEncoding;
/// 属性的自定义getter（如果有）。
@property (nonatomic, readonly, nullable) SEL customGetter;
/// 属性的自定义setter（如果有）。
@property (nonatomic, readonly, nullable) SEL customSetter;
/// 属性的自定义getter的字符串形式（如果有）。
@property (nonatomic, readonly, nullable) NSString *customGetterString;
/// 属性的自定义setter的字符串形式（如果有）。
@property (nonatomic, readonly, nullable) NSString *customSetterString;

@property (nonatomic, readonly) BOOL isReadOnly;
@property (nonatomic, readonly) BOOL isCopy;
@property (nonatomic, readonly) BOOL isRetained;
@property (nonatomic, readonly) BOOL isNonatomic;
@property (nonatomic, readonly) BOOL isDynamic;
@property (nonatomic, readonly) BOOL isWeak;
@property (nonatomic, readonly) BOOL isGarbageCollectable;

@end


#pragma mark FLEXPropertyAttributes
@interface FLEXMutablePropertyAttributes : FLEXPropertyAttributes

/// 创建并返回一个空的属性特性对象。
+ (instancetype)attributes;

/// 支持该属性的实例变量的名称。
@property (nonatomic, nullable) NSString *backingIvar;
/// 属性的类型编码。
@property (nonatomic, nullable) NSString *typeEncoding;
/// 属性的 \e 旧类型编码。
@property (nonatomic, nullable) NSString *oldTypeEncoding;
/// 属性的自定义getter（如果有）。
@property (nonatomic, nullable) SEL customGetter;
/// 属性的自定义setter（如果有）。
@property (nonatomic, nullable) SEL customSetter;

@property (nonatomic) BOOL isReadOnly;
@property (nonatomic) BOOL isCopy;
@property (nonatomic) BOOL isRetained;
@property (nonatomic) BOOL isNonatomic;
@property (nonatomic) BOOL isDynamic;
@property (nonatomic) BOOL isWeak;
@property (nonatomic) BOOL isGarbageCollectable;

/// 设置 \c typeEncoding 属性的更便捷方法。
/// @discussion 这不适用于结构体和原始指针等复杂类型。
- (void)setTypeEncodingChar:(char)type;

@end

NS_ASSUME_NONNULL_END
