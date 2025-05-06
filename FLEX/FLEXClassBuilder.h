//
//  FLEXClassBuilder.h
//  FLEX
//
//  派生自 MirrorKit。
//  创建者：Tanner，日期：7/3/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>
@class FLEXIvarBuilder, FLEXMethodBase, FLEXProperty, FLEXProtocol;


#pragma mark FLEXClassBuilder
@interface FLEXClassBuilder : NSObject

@property (nonatomic, readonly) Class workingClass;

/// 开始构建具有给定名称的类。
///
/// 这个新类将隐式继承自 \c NSObject，并带有 \c 0 个额外字节。
/// 以这种方式创建的类必须在使用前通过 \c -registerClass 进行注册。
+ (instancetype)allocateClass:(NSString *)name;
/// 开始构建具有给定名称和超类的类。
/// @discussion 使用 \c 0 个额外字节调用 \c -allocateClass:superclass:extraBytes:。
/// 以这种方式创建的类必须在使用前通过 \c -registerClass 进行注册。
+ (instancetype)allocateClass:(NSString *)name superclass:(Class)superclass;
/// 开始构建具有给定名称和超类的新类对象。
/// @discussion 将 \c nil 传递给 \e superclass 以创建新的根类。
/// 以这种方式创建的类必须在使用前通过 \c -registerClass 进行注册。
+ (instancetype)allocateClass:(NSString *)name superclass:(Class)superclass extraBytes:(size_t)bytes;
/// 开始构建具有给定名称和 \c 0 个额外字节的新根类对象。
/// @discussion 以这种方式创建的类必须在使用前通过 \c -registerClass 进行注册。
+ (instancetype)allocateRootClass:(NSString *)name;
/// 使用此方法修改现有类。@warning 您不能向现有类添加实例变量。
+ (instancetype)builderForClass:(Class)cls;

/// @return 添加失败的任何方法。
- (NSArray<FLEXMethodBase *> *)addMethods:(NSArray<FLEXMethodBase *> *)methods;
/// @return 添加失败的任何属性。
- (NSArray<FLEXProperty *> *)addProperties:(NSArray<FLEXProperty *> *)properties;
/// @return 添加失败的任何协议。
- (NSArray<FLEXProtocol *> *)addProtocols:(NSArray<FLEXProtocol *> *)protocols;
/// @warning 不支持向现有类添加 Ivar，并且总是会失败。
- (NSArray<FLEXIvarBuilder *> *)addIvars:(NSArray<FLEXIvarBuilder *> *)ivars;

/// 完成新类的构建。
/// @discussion 一旦类被注册，就不能添加实例变量。
/// @note 如果在先前注册的类上调用，则会引发异常。
- (Class)registerClass;
/// 使用 \c objc_lookupClass 来确定工作类是否已注册。
@property (nonatomic, readonly) BOOL isRegistered;

@end


#pragma mark FLEXIvarBuilder // FLEXIvarBuilder 类
@interface FLEXIvarBuilder : NSObject

/// 请考虑使用下面的 \c FLEXIvarBuilderWithNameAndType() 宏。
/// @param name Ivar 的名称，例如 \c \@"_value"。
/// @param size Ivar 的大小。通常为 \c sizeof(type)。对于对象，此值为 \c sizeof(id)。
/// @param alignment Ivar 的对齐方式。通常为 \c log2(sizeof(type))。
/// @param encoding Ivar 的类型编码。对于对象，此值为 \c \@(\@encode(id))，对于其他类型，则为 \c \@(\@encode(type))。
+ (instancetype)name:(NSString *)name size:(size_t)size alignment:(uint8_t)alignment typeEncoding:(NSString *)encoding;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *encoding;
@property (nonatomic, readonly) size_t   size;
@property (nonatomic, readonly) uint8_t  alignment;

@end


#define FLEXIvarBuilderWithNameAndType(nameString, type) [FLEXIvarBuilder \
    name:nameString \
    size:sizeof(type) \
    alignment:log2(sizeof(type)) /* 通常对齐方式是类型的log2大小，但这可能不总是准确或必需的。对于指针类型，通常是sizeof(void*)的log2。对于基本类型，通常是其自身大小的log2。*/ \
    typeEncoding:@(@encode(type)) \
]
