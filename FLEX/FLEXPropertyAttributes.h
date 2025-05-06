//
//  FLEXPropertyAttributes.h
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 7/5/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FLEXPropertyAttributes

/// 有关有效的字符串标记，请参见 \e FLEXRuntimeUtilitiy.h。
/// 有关如何构造正确的属性字符串，请参见此链接：
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
@interface FLEXPropertyAttributes : NSObject <NSCopying, NSMutableCopying> {
    // 这些对于可变子类的功能是必需的
@protected
    NSUInteger _count;
    NSString *_string, *_backingIvar, *_typeEncoding, *_oldTypeEncoding, *_fullDeclaration;
    NSDictionary *_dictionary;
    objc_property_attribute_t *_list;
    SEL _customGetter, _customSetter;
    BOOL _isReadOnly, _isCopy, _isRetained, _isNonatomic, _isDynamic, _isWeak, _isGarbageCollectable;
}

+ (instancetype)attributesForProperty:(objc_property_t)property;
/// @warning 如果 \e attributes 无效、为 \c nil 或包含不支持的键，则引发异常。
+ (instancetype)attributesFromDictionary:(NSDictionary *)attributes;

/// 将属性列表复制到您必须自行 \c free() 的缓冲区中。
/// 如果您不需要对列表的生命周期进行更多控制，请改用 \c list。
/// @param attributesCountOut 属性的数量在此参数中返回。
- (objc_property_attribute_t *)copyAttributesList:(nullable unsigned int *)attributesCountOut;

/// 属性特性的数量。
@property (nonatomic, readonly) NSUInteger count;
/// 用于 \c class_replaceProperty 等。
@property (nonatomic, readonly) objc_property_attribute_t *list;
/// 属性特性的字符串值。
@property (nonatomic, readonly) NSString *string;
/// 属性特性的人类可读版本。
@property (nonatomic, readonly) NSString *fullDeclaration;
/// 属性特性的字典。
/// 值可以是字符串或 \c YES。为 false 的布尔属性
/// 将不会出现在字典中。
@property (nonatomic, readonly) NSDictionary *dictionary;

/// 支持属性的实例变量的名称。
@property (nonatomic, readonly, nullable) NSString *backingIvar;
/// 属性的类型编码。
@property (nonatomic, readonly, nullable) NSString *typeEncoding;
/// 属性的 \e 旧类型编码。
@property (nonatomic, readonly, nullable) NSString *oldTypeEncoding;
/// 属性的自定义 getter（如果有）。
@property (nonatomic, readonly, nullable) SEL customGetter;
/// 属性的自定义 setter（如果有）。
@property (nonatomic, readonly, nullable) SEL customSetter;
/// 属性的自定义 getter（字符串形式，如果有）。
@property (nonatomic, readonly, nullable) NSString *customGetterString;
/// 属性的自定义 setter（字符串形式，如果有）。
@property (nonatomic, readonly, nullable) NSString *customSetterString;

@property (nonatomic, readonly) BOOL isReadOnly;
@property (nonatomic, readonly) BOOL isCopy;
@property (nonatomic, readonly) BOOL isRetained;
@property (nonatomic, readonly) BOOL isNonatomic;
@property (nonatomic, readonly) BOOL isDynamic;
@property (nonatomic, readonly) BOOL isWeak;
@property (nonatomic, readonly) BOOL isGarbageCollectable;

@end


#pragma mark - FLEXPropertyAttributes
@interface FLEXMutablePropertyAttributes : FLEXPropertyAttributes

/// 创建并返回一个空的属性特性对象。
+ (instancetype)attributes;

/// 支持属性的实例变量的名称。
@property (nonatomic, nullable) NSString *backingIvar;
/// 属性的类型编码。
@property (nonatomic, nullable) NSString *typeEncoding;
/// 属性的 \e 旧类型编码。
@property (nonatomic, nullable) NSString *oldTypeEncoding;
/// 属性的自定义 getter（如果有）。
@property (nonatomic, nullable) SEL customGetter;
/// 属性的自定义 setter（如果有）。
@property (nonatomic, nullable) SEL customSetter;

@property (nonatomic) BOOL isReadOnly;
@property (nonatomic) BOOL isCopy;
@property (nonatomic) BOOL isRetained;
@property (nonatomic) BOOL isNonatomic;
@property (nonatomic) BOOL isDynamic;
@property (nonatomic) BOOL isWeak;
@property (nonatomic) BOOL isGarbageCollectable;

/// 设置 \c typeEncoding 属性的一种更便捷的方法。
/// @discussion 这不适用于复杂类型，如结构体和原始指针。
- (void)setTypeEncodingChar:(char)type;

@end

NS_ASSUME_NONNULL_END
