// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMirror.h
//  FLEX
//
//  派生自 MirrorKit。
//  由 Tanner 创建于 6/29/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
@class FLEXMethod, FLEXProperty, FLEXIvar, FLEXProtocol;

NS_ASSUME_NONNULL_BEGIN

#pragma mark FLEXMirror 协议
NS_SWIFT_NAME(FLEXMirrorProtocol)
@protocol FLEXMirror <NSObject>

/// Swift 初始化程序
/// @throws 如果传入元类对象。
- (instancetype)initWithSubject:(id)objectOrClass NS_SWIFT_NAME(init(reflecting:));

/// 用于创建此 \c FLEXMirror 的底层对象或 \c Class。
@property (nonatomic, readonly) id   value;
/// \c value 是类还是类实例。
@property (nonatomic, readonly) BOOL isClass;
/// \c value 属性的 \c Class 的名称。
@property (nonatomic, readonly) NSString *className;

@property (nonatomic, readonly) NSArray<FLEXProperty *> *properties;
@property (nonatomic, readonly) NSArray<FLEXProperty *> *classProperties;
@property (nonatomic, readonly) NSArray<FLEXIvar *>     *ivars;
@property (nonatomic, readonly) NSArray<FLEXMethod *>   *methods;
@property (nonatomic, readonly) NSArray<FLEXMethod *>   *classMethods;
@property (nonatomic, readonly) NSArray<FLEXProtocol *> *protocols;

/// 超类镜像使用传入值对应的类进行初始化。
/// 如果传入类的实例，则使用其超类创建此镜像。
/// 如果传入一个类，则使用该类的超类。
///
/// @注意 此属性应为计算属性，而非缓存属性。
@property (nonatomic, readonly, nullable) id<FLEXMirror> superMirror NS_SWIFT_NAME(superMirror);

@end

#pragma mark FLEXMirror 类
@interface FLEXMirror : NSObject <FLEXMirror>

/// 反射对象的实例或 \c Class。
/// @讨论 \c FLEXMirror 将立即收集所有有用的信息。如果您的代码仅使用少量信息，
/// 或者如果您的代码需要更快地运行，请考虑使用提供的 \c NSObject 类别。
///
/// 无论您反射的是实例还是类对象，\c methods 和 \c properties
/// 都将填充实例方法和属性，而 \c classMethods 和 \c classProperties
/// 将填充类方法和属性。
///
/// @param objectOrClass 对象的实例或 \c Class 对象。
/// @throws 如果传入元类对象。
/// @return \c FLEXMirror 的实例。
+ (instancetype)reflect:(id)objectOrClass;

@property (nonatomic, readonly) id   value;
@property (nonatomic, readonly) BOOL isClass;
@property (nonatomic, readonly) NSString *className;

@property (nonatomic, readonly) NSArray<FLEXProperty *> *properties;
@property (nonatomic, readonly) NSArray<FLEXProperty *> *classProperties;
@property (nonatomic, readonly) NSArray<FLEXIvar *>     *ivars;
@property (nonatomic, readonly) NSArray<FLEXMethod *>   *methods;
@property (nonatomic, readonly) NSArray<FLEXMethod *>   *classMethods;
@property (nonatomic, readonly) NSArray<FLEXProtocol *> *protocols;

@property (nonatomic, readonly, nullable) FLEXMirror *superMirror NS_SWIFT_NAME(superMirror);

@end


@interface FLEXMirror (ExtendedMirror)

/// @return具有给定名称的实例方法，如果不存在则为 \c nil。
- (nullable FLEXMethod *)methodNamed:(nullable NSString *)name;
/// @return具有给定名称的类方法，如果不存在则为 \c nil。
- (nullable FLEXMethod *)classMethodNamed:(nullable NSString *)name;
/// @return具有给定名称的实例属性，如果不存在则为 \c nil。
- (nullable FLEXProperty *)propertyNamed:(nullable NSString *)name;
/// @return具有给定名称的类属性，如果不存在则为 \c nil。
- (nullable FLEXProperty *)classPropertyNamed:(nullable NSString *)name;
/// @return具有给定名称的实例变量，如果不存在则为 \c nil。
- (nullable FLEXIvar *)ivarNamed:(nullable NSString *)name;
/// @return具有给定名称的协议，如果不存在则为 \c nil。
- (nullable FLEXProtocol *)protocolNamed:(nullable NSString *)name;

@end

NS_ASSUME_NONNULL_END
