//
//  FLEXRuntimeUtility.h
//  Flipboard
//
//  由 Ryan Olson 创建于 6/8/14.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import "FLEXRuntimeConstants.h"
@class FLEXObjectRef;

#define PropertyKey(suffix) kFLEXPropertyAttributeKey##suffix : @""
#define PropertyKeyGetter(getter) kFLEXPropertyAttributeKeyCustomGetter : NSStringFromSelector(@selector(getter))
#define PropertyKeySetter(setter) kFLEXPropertyAttributeKeyCustomSetter : NSStringFromSelector(@selector(setter))

/// 参数：最低iOS版本、属性名称、目标类、属性类型和属性列表
#define FLEXRuntimeUtilityTryAddProperty(iOS_atLeast, name, cls, type, ...) ({ \
    if (@available(iOS iOS_atLeast, *)) { \
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:@{ \
            kFLEXPropertyAttributeKeyTypeEncoding : @(type), \
            __VA_ARGS__ \
        }]; \
        [FLEXRuntimeUtility \
            tryAddPropertyWithName:#name \
            attributes:attrs \
            toClass:cls \
        ]; \
    } \
})

/// 参数：最低iOS版本、属性名称、目标类、属性类型和属性列表
#define FLEXRuntimeUtilityTryAddNonatomicProperty(iOS_atLeast, name, cls, type, ...) \
    FLEXRuntimeUtilityTryAddProperty(iOS_atLeast, name, cls, @encode(type), PropertyKey(NonAtomic), __VA_ARGS__);
/// 参数：最低iOS版本、属性名称、目标类、属性类型（类名）和属性列表
#define FLEXRuntimeUtilityTryAddObjectProperty(iOS_atLeast, name, cls, type, ...) \
    FLEXRuntimeUtilityTryAddProperty(iOS_atLeast, name, cls, FLEXEncodeClass(type), PropertyKey(NonAtomic), __VA_ARGS__);

extern NSString * const FLEXRuntimeUtilityErrorDomain;

typedef NS_ENUM(NSInteger, FLEXRuntimeUtilityErrorCode) {
    // 从一个随机值开始，而不是0，以避免与缺少代码混淆
    FLEXRuntimeUtilityErrorCodeDoesNotRecognizeSelector = 0xbabe,
    FLEXRuntimeUtilityErrorCodeInvocationFailed,
    FLEXRuntimeUtilityErrorCodeArgumentTypeMismatch
};

@interface FLEXRuntimeUtility : NSObject

#pragma mark - 通用辅助方法

/// 调用 \c FLEXPointerIsValidObjcObject()
+ (BOOL)pointerIsValidObjcObject:(const void *)pointer;
/// 解包存储在NSValue中的原始对象指针，并将C字符串重新装箱为NSString。
+ (id)potentiallyUnwrapBoxedPointer:(id)returnedObjectOrNil type:(const FLEXTypeEncoding *)returnType;
/// 一些字段在其编码字符串中有名称（例如 \"width\"d）
/// @return 跳过字段名称的偏移量，如果没有名称则为0
+ (NSUInteger)fieldNameOffsetForTypeEncoding:(const FLEXTypeEncoding *)typeEncoding;
/// 给定名称"foo"和类型"int"，这将返回"int foo"，但
/// 给定名称"foo"和类型"T *"，它将返回"T *foo"
+ (NSString *)appendName:(NSString *)name toType:(NSString *)typeEncoding;

/// @return 给定对象或类的类层次结构，
/// 从当前类到最根级的类。
+ (NSArray<Class> *)classHierarchyOfObject:(id)objectOrClass;
/// @return 给定类名的所有子类。
+ (NSArray<FLEXObjectRef *> *)subclassesOfClassWithName:(NSString *)className;

/// 用于在探索器行中简要描述对象
+ (NSString *)summaryForObject:(id)value;
+ (NSString *)safeClassNameForObject:(id)object;
+ (NSString *)safeDescriptionForObject:(id)object;
+ (NSString *)safeDebugDescriptionForObject:(id)object;

+ (BOOL)safeObject:(id)object isKindOfClass:(Class)cls;
+ (BOOL)safeObject:(id)object respondsToSelector:(SEL)sel;

#pragma mark - 属性辅助方法

+ (BOOL)tryAddPropertyWithName:(const char *)name
                    attributes:(NSDictionary<NSString *, NSString *> *)attributePairs
                       toClass:(__unsafe_unretained Class)theClass;
+ (NSArray<NSString *> *)allPropertyAttributeKeys;

#pragma mark - 方法辅助方法

+ (NSArray *)prettyArgumentComponentsForMethod:(Method)method;

#pragma mark - 方法调用/字段编辑

+ (id)performSelector:(SEL)selector onObject:(id)object;
+ (id)performSelector:(SEL)selector
             onObject:(id)object
        withArguments:(NSArray *)arguments
                error:(NSError * __autoreleasing *)error;
+ (id)performSelector:(SEL)selector
             onObject:(id)object
        withArguments:(NSArray *)arguments
      allowForwarding:(BOOL)mightForwardMsgSend
                error:(NSError * __autoreleasing *)error;

+ (NSString *)editableJSONStringForObject:(id)object;
+ (id)objectValueFromEditableJSONString:(NSString *)string;
+ (NSValue *)valueForNumberWithObjCType:(const char *)typeEncoding fromInputString:(NSString *)inputString;
+ (void)enumerateTypesInStructEncoding:(const char *)structEncoding
                            usingBlock:(void (^)(NSString *structName,
                                                 const char *fieldTypeEncoding,
                                                 NSString *prettyTypeEncoding,
                                                 NSUInteger fieldIndex,
                                                 NSUInteger fieldOffset))typeBlock;
+ (NSValue *)valueForPrimitivePointer:(void *)pointer objCType:(const char *)type;

#pragma mark - 元数据辅助方法

+ (NSString *)readableTypeForEncoding:(NSString *)encodingString;

@end
