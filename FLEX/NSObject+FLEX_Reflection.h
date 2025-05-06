//
//  NSObject+FLEX_Reflection.h
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 6/30/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
@class FLEXMirror, FLEXMethod, FLEXIvar, FLEXProperty, FLEXMethodBase, FLEXPropertyAttributes, FLEXProtocol;

NS_ASSUME_NONNULL_BEGIN

/// 返回给定返回类型和参数（如有）编码的类型编码字符串。
/// @discussion 对于一个返回 \c void 并接受一个 \c int 的方法，示例用法如下：
/// @code FLEXTypeEncoding(@encode(void), @encode(int));
/// @param returnType 编码后的返回类型。例如 \c void 将是 \c @encode(void)。
/// @param count 此类型编码字符串中的参数数量。
/// @return 类型编码字符串，如果 \e returnType 为 \c NULL，则返回 \c nil。
NSString * FLEXTypeEncodingString(const char *returnType, NSUInteger count, ...);

NSArray<Class> * _Nullable FLEXGetAllSubclasses(_Nullable Class cls, BOOL includeSelf);
NSArray<Class> * _Nullable FLEXGetClassHierarchy(_Nullable Class cls, BOOL includeSelf);
NSArray<FLEXProtocol *> * _Nullable FLEXGetConformedProtocols(_Nullable Class cls);

NSArray<FLEXIvar *> * _Nullable FLEXGetAllIvars(_Nullable Class cls);
/// @param cls 用于获取实例属性的类对象，
/// 或用于获取类属性的元类对象
NSArray<FLEXProperty *> * _Nullable FLEXGetAllProperties(_Nullable Class cls);
/// @param cls 用于获取实例方法的类对象，
/// 或用于获取类方法的元类对象
/// @param instance 用于标记方法是否为实例方法。
/// 不用于确定是获取实例方法还是类方法。
NSArray<FLEXMethod *> * _Nullable FLEXGetAllMethods(_Nullable Class cls, BOOL instance);
/// @param cls 用于获取所有实例方法和类方法的类对象。
NSArray<FLEXMethod *> * _Nullable FLEXGetAllInstanceAndClassMethods(_Nullable Class cls);



#pragma mark - 反射
@interface NSObject (Reflection)

@property (nonatomic, readonly       ) FLEXMirror *flex_reflection;
@property (nonatomic, readonly, class) FLEXMirror *flex_reflection;

/// 调用 /c FLEXGetAllSubclasses
/// @return 接收类的每个子类，包括接收者本身。
@property (nonatomic, readonly, class) NSArray<Class> *flex_allSubclasses;

/// @return 接收类的元类的 \c Class 对象，如果类为 Nil 或未注册，则为 \c Nil。
@property (nonatomic, readonly, class) Class flex_metaclass;
/// @return 接收类实例的大小（以字节为单位），如果 \e cls 为 \c Nil，则为 \c 0。
@property (nonatomic, readonly, class) size_t flex_instanceSize;

/// 更改对象实例的类。
/// @return 对象 \c class 的先前值，如果对象为 \c nil，则为 \c Nil。
- (Class)flex_setClass:(Class)cls;
/// 设置接收类的超类。“您不应使用此方法”—— Apple。
/// @return 旧的超类。
+ (Class)flex_setSuperclass:(Class)superclass;

/// 调用 \c FLEXGetClassHierarchy()
/// @return 一个沿类层次结构向上的类列表，
/// 从接收者开始，到根类结束。
@property (nonatomic, readonly, class) NSArray<Class> *flex_classHierarchy;

/// 调用 \c FLEXGetConformedProtocols
/// @return 此类本身遵守的协议列表。
@property (nonatomic, readonly, class) NSArray<FLEXProtocol *> *flex_protocols;

@end


#pragma mark - 方法
@interface NSObject (Methods)

/// 特定于接收类的所有实例方法和类方法。
/// @discussion 此方法将仅检索特定于接收类的方法。
/// 要检索父类上的实例变量，只需在 \c [self superclass] 上调用此方法。
/// @return 一个 \c FLEXMethod 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXMethod *> *flex_allMethods;
/// 特定于接收类的所有实例方法。
/// @discussion 此方法将仅检索特定于接收类的方法。
/// 要检索父类上的实例变量，只需在 \c [self superclass] 上调用此方法。
/// @return 一个 \c FLEXMethod 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXMethod *> *flex_allInstanceMethods;
/// 特定于接收类的所有类方法。
/// @discussion 此方法将仅检索特定于接收类的方法。
/// 要检索父类上的实例变量，只需在 \c [self superclass] 上调用此方法。
/// @return 一个 \c FLEXMethod 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXMethod *> *flex_allClassMethods;

/// 检索具有给定名称的类的实例方法。
/// @return 一个初始化的 \c FLEXMethod 对象，如果未找到该方法，则为 \c nil。
+ (FLEXMethod *)flex_methodNamed:(NSString *)name;

/// 检索具有给定名称的类的类方法。
/// @return 一个初始化的 \c FLEXMethod 对象，如果未找到该方法，则为 \c nil。
+ (FLEXMethod *)flex_classMethodNamed:(NSString *)name;

/// 向接收类添加一个具有给定名称和实现的新方法。
/// @discussion 此方法将添加超类实现的覆盖，
/// 但不会替换类中现有的实现。
/// 要更改现有实现，请使用 \c replaceImplementationOfMethod:with:。
///
/// 类型编码以返回类型开始，并按顺序以参数类型结束。
/// \c NSArray 的 \c count 属性 getter 的类型编码如下所示：
/// @code [NSString stringWithFormat:@"%s%s%s%s", @encode(void), @encode(id), @encode(SEL), @encode(NSUInteger)] @endcode
/// 对同一方法使用 \c FLEXTypeEncoding 函数如下所示：
/// @code FLEXTypeEncodingString(@encode(void), 1, @encode(NSUInteger)) @endcode
/// @param typeEncoding 类型编码字符串。考虑使用 \c FLEXTypeEncodingString() 函数。
/// @param instanceMethod NO 表示将方法添加到类本身，YES 表示将其添加为实例方法。
/// @return 如果方法添加成功，则为 YES，否则为 \c NO
/// （例如，该类已包含具有该名称的方法实现）。
+ (BOOL)addMethod:(SEL)selector
     typeEncoding:(NSString *)typeEncoding
   implementation:(IMP)implementaiton
      toInstances:(BOOL)instanceMethod;

/// 替换接收类中方法的实现。
/// @param instanceMethod YES 表示替换实例方法，NO 表示替换类方法。
/// @note 此函数有两种不同的行为方式：
///
/// - 如果方法在接收类中尚不存在，则会像调用
/// \c addMethod:typeEncoding:implementation 一样添加它。
///
/// - 如果方法确实存在，则其 \c IMP 将被替换。
/// @return \e method 的先前 \c IMP。
+ (IMP)replaceImplementationOfMethod:(FLEXMethodBase *)method with:(IMP)implementation useInstance:(BOOL)instanceMethod;
/// 交换给定方法的实现。
/// @discussion 如果给定方法中的一个或两个都不存在于接收类中，
/// 则它们将以其实现被交换的方式添加到类中，就像每个方法都存在一样。
/// 如果每个 \c FLEXSimpleMethod 都包含一个有效的选择器，则此方法不会失败。
/// @param instanceMethod YES 表示对实例方法进行混淆，NO 表示对类方法进行混淆。
+ (void)swizzle:(FLEXMethodBase *)original with:(FLEXMethodBase *)other onInstance:(BOOL)instanceMethod;
/// 交换给定方法的实现。
/// @param instanceMethod YES 表示对实例方法进行混淆，NO 表示对类方法进行混淆。
/// @return 如果成功，则为 \c YES；如果无法从给定字符串中检索选择器，则为 \c NO。
+ (BOOL)swizzleByName:(NSString *)original with:(NSString *)other onInstance:(BOOL)instanceMethod;
/// 交换与给定选择器对应的方法的实现。
+ (void)swizzleBySelector:(SEL)original with:(SEL)other onInstance:(BOOL)instanceMethod;

@end


#pragma mark - 属性 (Properties)
@interface NSObject (Ivars)

/// 特定于接收类的所有实例变量。
/// @discussion 此方法将仅检索特定于接收类的实例变量。
/// 要检索父类上的实例变量，只需调用 \c [[self superclass] allIvars]。
/// @return 一个 \c FLEXIvar 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXIvar *> *flex_allIvars;

/// 检索具有相应名称的实例变量。
/// @return 一个初始化的 \c FLEXIvar 对象，如果未找到 Ivar，则为 \c nil。
+ (FLEXIvar *)flex_ivarNamed:(NSString *)name;

/// @return 内存中接收对象中给定 ivar 的地址，
/// 如果找不到，则为 \c NULL。
- (void *)flex_getIvarAddress:(FLEXIvar *)ivar;
/// @return 内存中接收对象中给定 ivar 的地址，
/// 如果找不到，则为 \c NULL。
- (void *)flex_getIvarAddressByName:(NSString *)name;
/// @discussion 如果您手头已经有一个 \c Ivar，则此方法比创建 \c FLEXIvar 并调用
/// \c -getIvarAddress: 更快
/// @return 内存中接收对象中给定 ivar 的地址，
/// 如果找不到，则为 \c NULL。
- (void *)flex_getObjcIvarAddress:(Ivar)ivar;

/// 设置接收对象上给定实例变量的值。
/// @discussion 仅当目标实例变量是对象时使用。
- (void)flex_setIvar:(FLEXIvar *)ivar object:(id)value;
/// 设置接收对象上给定实例变量的值。
/// @discussion 仅当目标实例变量是对象时使用。
/// @return 如果成功，则为 \c YES；如果找不到实例变量，则为 \c NO。
- (BOOL)flex_setIvarByName:(NSString *)name object:(id)value;
/// @discussion 仅当目标实例变量是对象时使用。
/// 如果您手头已经有一个 \c Ivar，则此方法比创建 \c FLEXIvar 并调用
/// \c -setIvar: 更快。
- (void)flex_setObjcIvar:(Ivar)ivar object:(id)value;

/// 将接收对象上给定实例变量的值设置为
/// \e value 处数据的 \e size 字节数。
/// @discussion 如果可以，请使用其他方法之一。
- (void)flex_setIvar:(FLEXIvar *)ivar value:(void *)value size:(size_t)size;
/// 将接收对象上给定实例变量的值设置为
/// \e value 处数据的 \e size 字节数。
/// @discussion 如果可以，请使用其他方法之一
/// @return 如果成功，则为 \c YES；如果找不到实例变量，则为 \c NO。
- (BOOL)flex_setIvarByName:(NSString *)name value:(void *)value size:(size_t)size;
/// 将接收对象上给定实例变量的值设置为
/// \e value 处数据的 \e size 字节数。
/// @discussion 如果您手头已经有一个 \c Ivar，则此方法比创建 \c FLEXIvar 并调用
/// \c -setIvar:value:size 更快。
- (void)flex_setObjcIvar:(Ivar)ivar value:(void *)value size:(size_t)size;

@end

#pragma mark - 属性 (Properties)
@interface NSObject (Properties)

/// 特定于接收类的所有实例和类属性。
/// @discussion 此方法将仅检索特定于接收类的属性。
/// 要检索父类上的实例变量，只需在 \c [self superclass] 上调用此方法。
/// @return 一个 \c FLEXProperty 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXProperty *> *flex_allProperties;
/// 特定于接收类的所有实例属性。
/// @discussion 此方法将仅检索特定于接收类的属性。
/// 要检索父类上的实例变量，只需在 \c [self superclass] 上调用此方法。
/// @return 一个 \c FLEXProperty 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXProperty *> *flex_allInstanceProperties;
/// 特定于接收类的所有类属性。
/// @discussion 此方法将仅检索特定于接收类的属性。
/// 要检索父类上的实例变量，只需在 \c [self superclass] 上调用此方法。
/// @return 一个 \c FLEXProperty 对象数组。
@property (nonatomic, readonly, class) NSArray<FLEXProperty *> *flex_allClassProperties;

/// 检索具有给定名称的类的属性。
/// @return 一个初始化的 \c FLEXProperty 对象，如果未找到该属性，则为 \c nil。
+ (FLEXProperty *)flex_propertyNamed:(NSString *)name;
/// @return 一个初始化的 \c FLEXProperty 对象，如果未找到该属性，则为 \c nil。
+ (FLEXProperty *)flex_classPropertyNamed:(NSString *)name;

/// 替换接收类上的给定属性。
+ (void)flex_replaceProperty:(FLEXProperty *)property;
/// 替换接收类上的给定属性。用于更改属性的特性。
+ (void)flex_replaceProperty:(NSString *)name attributes:(FLEXPropertyAttributes *)attributes;

@end

NS_ASSUME_NONNULL_END
