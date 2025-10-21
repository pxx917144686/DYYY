//
//  FLEXObjectRef.h
//  FLEX
//
//  Created by Tanner Bennett on 7/24/18.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLEXObjectRef : NSObject

/// 引用一个对象，不影响其生命周期，也不产生引用计数操作。
+ (instancetype)unretained:(__unsafe_unretained id)object;
+ (instancetype)unretained:(__unsafe_unretained id)object ivar:(NSString *)ivarName;

/// 引用一个对象并控制其生命周期。
+ (instancetype)retained:(id)object;
+ (instancetype)retained:(id)object ivar:(NSString *)ivarName;

/// 引用一个对象并有条件地选择是否保留它。
+ (instancetype)referencing:(__unsafe_unretained id)object retained:(BOOL)retain;
+ (instancetype)referencing:(__unsafe_unretained id)object ivar:(NSString *)ivarName retained:(BOOL)retain;

+ (NSArray<FLEXObjectRef *> *)referencingAll:(NSArray *)objects retained:(BOOL)retain;
/// 类没有摘要，引用只是类名。
+ (NSArray<FLEXObjectRef *> *)referencingClasses:(NSArray<Class> *)classes;

/// 例如，"NSString 0x1d4085d0"或"NSLayoutConstraint _object"
@property (nonatomic, readonly) NSString *reference;
/// 对于实例，这是-[FLEXRuntimeUtility summaryForObject:]的结果
/// 对于类，没有摘要。
@property (nonatomic, readonly) NSString *summary;
@property (nonatomic, readonly, unsafe_unretained) id object;

/// 如果引用的对象尚未被保留，则保留它
- (void)retainObject;
/// 如果引用的对象已经被保留，则释放它
- (void)releaseObject;

@end
