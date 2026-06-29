//
//  FLEXProtocolBuilder.h
//  FLEX
//
//  派生自 MirrorKit.
//  Created by Tanner on 7/4/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FLEXProperty, FLEXProtocol, Protocol;

@interface FLEXProtocolBuilder : NSObject

/// 开始构建一个具有给定名称的新协议。
/// @discussion 您必须使用
/// \c registerProtocol 方法注册协议才能使用它。
+ (instancetype)allocateProtocol:(NSString *)name;

/// 向协议添加属性。
/// @param property 要添加的属性。
/// @param isRequired 该属性是否是实现协议所必需的。
- (void)addProperty:(FLEXProperty *)property isRequired:(BOOL)isRequired;
/// 向协议添加方法。
/// @param selector 要添加的方法的选择器。
/// @param typeEncoding 要添加的方法的类型编码。
/// @param isRequired 该方法是否是实现协议所必需的。
/// @param isInstanceMethod \c YES 如果方法是实例方法，\c NO 如果是类方法。
- (void)addMethod:(SEL)selector
     typeEncoding:(NSString *)typeEncoding
       isRequired:(BOOL)isRequired
 isInstanceMethod:(BOOL)isInstanceMethod;
/// 使接收协议符合给定的协议。
- (void)addProtocol:(Protocol *)protocol;

/// 注册并返回先前正在构建的接收协议。
- (FLEXProtocol *)registerProtocol;
/// 协议是否仍在构建中或已注册。
@property (nonatomic, readonly) BOOL isRegistered;

@end
