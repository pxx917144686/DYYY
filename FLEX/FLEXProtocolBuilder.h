// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXProtocolBuilder.h
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 7/4/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>
@class FLEXProperty, FLEXProtocol, Protocol;

@interface FLEXProtocolBuilder : NSObject

/// 开始构造一个具有给定名称的新协议。
/// @discussion 您必须在使用之前通过
/// \c registerProtocol 方法注册该协议。
+ (instancetype)allocateProtocol:(NSString *)name;

/// 向协议添加属性。
/// @param property 要添加的属性。
/// @param isRequired 该属性是否是实现协议所必需的。
- (void)addProperty:(FLEXProperty *)property isRequired:(BOOL)isRequired;
/// 向协议添加方法。
/// @param selector 要添加的方法的选择器。
/// @param typeEncoding 要添加的方法的类型编码。
/// @param isRequired 该方法是否是实现协议所必需的。
/// @param isInstanceMethod 如果方法是实例方法，则为 \c YES；如果是类方法，则为 \c NO。
- (void)addMethod:(SEL)selector
     typeEncoding:(NSString *)typeEncoding
       isRequired:(BOOL)isRequired
 isInstanceMethod:(BOOL)isInstanceMethod;
/// 使接收协议遵循给定的协议。
- (void)addProtocol:(Protocol *)protocol;

/// 注册并返回先前正在构造的接收协议。
- (FLEXProtocol *)registerProtocol;
/// 协议是否仍在构造中或已注册。
@property (nonatomic, readonly) BOOL isRegistered;

@end
