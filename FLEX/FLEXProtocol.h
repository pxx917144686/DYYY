// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXProtocol.h
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 6/30/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXRuntimeConstants.h"
@class FLEXProperty, FLEXMethodDescription;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FLEXProtocol
@interface FLEXProtocol : NSObject

/// 运行时注册的每个协议。
+ (NSArray<FLEXProtocol *> *)allProtocols;
+ (instancetype)protocol:(Protocol *)protocol;

/// 底层的协议数据结构。
@property (nonatomic, readonly) Protocol *objc_protocol;

/// 协议的名称。
@property (nonatomic, readonly) NSString *name;
/// 协议的必需方法（如果有）。这包括属性的 getter 和 setter。
@property (nonatomic, readonly) NSArray<FLEXMethodDescription *> *requiredMethods;
/// 协议的可选方法（如果有）。这包括属性的 getter 和 setter。
@property (nonatomic, readonly) NSArray<FLEXMethodDescription *> *optionalMethods;
/// 此协议遵循的所有协议（如果有）。
@property (nonatomic, readonly) NSArray<FLEXProtocol *> *protocols;
/// 包含此协议定义的镜像的完整路径，
/// 如果此协议可能是在运行时定义的，则为 \c nil。
@property (nonatomic, readonly, nullable) NSString *imagePath;

/// 协议中的属性（如果有）。在 iOS 10+ 上为 \c nil
@property (nonatomic, readonly, nullable) NSArray<FLEXProperty *> *properties API_DEPRECATED("请使用下面更具体的访问器", ios(2.0, 10.0));

/// 协议中的必需属性（如果有）。
@property (nonatomic, readonly) NSArray<FLEXProperty *> *requiredProperties API_AVAILABLE(ios(10.0));
/// 协议中的可选属性（如果有）。
@property (nonatomic, readonly) NSArray<FLEXProperty *> *optionalProperties API_AVAILABLE(ios(10.0));

/// 供内部使用
@property (nonatomic) id tag;

/// 不要与 \c -conformsToProtocol: 混淆，后者指的是当前的
/// \c FLEXProtocol 实例，而不是底层的 \c Protocol 对象。
- (BOOL)conformsTo:(Protocol *)protocol;

@end


#pragma mark - 方法描述
@interface FLEXMethodDescription : NSObject

+ (instancetype)description:(struct objc_method_description)description;
+ (instancetype)description:(struct objc_method_description)description instance:(BOOL)isInstance;

/// 底层的方法描述数据结构。
@property (nonatomic, readonly) struct objc_method_description objc_description;
/// 方法的选择器。
@property (nonatomic, readonly) SEL selector;
/// 方法的类型编码。
@property (nonatomic, readonly) NSString *typeEncoding;
/// 方法的返回类型。
@property (nonatomic, readonly) FLEXTypeEncoding returnType;
/// 如果这是实例方法，则为 \c YES；如果是类方法，则为 \c NO；如果未指定，则为 \c nil
@property (nonatomic, readonly) NSNumber *instance;
@end

NS_ASSUME_NONNULL_END
