//
//  FLEXProtocol.m
//  FLEX
//
//  派生自 MirrorKit.
//  Created by Tanner on 6/30/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXProtocol.h"
#import "FLEXProperty.h"
#import "FLEXRuntimeUtility.h"
#import "NSArray+FLEX.h"
#include <dlfcn.h>

@implementation FLEXProtocol

#pragma mark 初始化器

+ (NSArray *)allProtocols {
    unsigned int prcount;
    Protocol *__unsafe_unretained*protocols = objc_copyProtocolList(&prcount);
    
    NSMutableArray *all = [NSMutableArray new];
    for(NSUInteger i = 0; i < prcount; i++)
        [all addObject:[self protocol:protocols[i]]];
    
    free(protocols);
    return all;
}

+ (instancetype)protocol:(Protocol *)protocol {
    return [[self alloc] initWithProtocol:protocol];
}

- (id)initWithProtocol:(Protocol *)protocol {
    NSParameterAssert(protocol);
    
    self = [super init];
    if (self) {
        _objc_protocol = protocol;
        [self examine];
    }
    
    return self;
}

#pragma mark 其他

- (NSString *)description {
    return self.name;
}

- (NSString *)debugDescription {
    if (@available(iOS 10.0, *)) {
        return [NSString stringWithFormat:@"<%@ name=%@, %lu 必需属性, %lu 可选属性 %lu 必需方法, %lu 可选方法, %lu 协议>",
            NSStringFromClass(self.class), self.name, (unsigned long)self.requiredProperties.count, (unsigned long)self.optionalProperties.count,
            (unsigned long)self.requiredMethods.count, (unsigned long)self.optionalMethods.count, (unsigned long)self.protocols.count];
    } else {
        return [NSString stringWithFormat:@"<%@ name=%@, %lu 属性, %lu 必需方法, %lu 可选方法, %lu 协议>",
            NSStringFromClass(self.class), self.name, (unsigned long)self.properties.count,
            (unsigned long)self.requiredMethods.count, (unsigned long)self.optionalMethods.count, (unsigned long)self.protocols.count];
    }
}

- (void)examine {
    _name = @(protocol_getName(self.objc_protocol));
    
    // 镜像路径
    Dl_info exeInfo;
    if (dladdr((__bridge const void *)(_objc_protocol), &exeInfo)) {
        _imagePath = exeInfo.dli_fname ? @(exeInfo.dli_fname) : nil;
    }
    
    // 遵循协议和方法 //
    
    unsigned int pccount, mdrcount, mdocount;
    struct objc_method_description *objcrMethods, *objcoMethods;
    Protocol *protocol = _objc_protocol;
    Protocol * __unsafe_unretained *protocols = protocol_copyProtocolList(protocol, &pccount);
    
    // 协议
    _protocols = [NSArray flex_forEachUpTo:pccount map:^id(NSUInteger i) {
        return [FLEXProtocol protocol:protocols[i]];
    }];
    free(protocols);
    
    // 必需的实例方法
    objcrMethods = protocol_copyMethodDescriptionList(protocol, YES, YES, &mdrcount);
    NSArray *rMethods = [NSArray flex_forEachUpTo:mdrcount map:^id(NSUInteger i) {
        return [FLEXMethodDescription description:objcrMethods[i] instance:YES];
    }];
    free(objcrMethods);
    
    // 必需的类方法 
    objcrMethods = protocol_copyMethodDescriptionList(protocol, YES, NO, &mdrcount);
    _requiredMethods = [[NSArray flex_forEachUpTo:mdrcount map:^id(NSUInteger i) {
        return [FLEXMethodDescription description:objcrMethods[i] instance:NO];
    }] arrayByAddingObjectsFromArray:rMethods];
    free(objcrMethods);
    
    // 可选的实例方法
    objcoMethods = protocol_copyMethodDescriptionList(protocol, NO, YES, &mdocount);
    NSArray *oMethods = [NSArray flex_forEachUpTo:mdocount map:^id(NSUInteger i) {
        return [FLEXMethodDescription description:objcoMethods[i] instance:YES];
    }];
    free(objcoMethods);
    
    // 可选的类方法
    objcoMethods = protocol_copyMethodDescriptionList(protocol, NO, NO, &mdocount);
    _optionalMethods = [[NSArray flex_forEachUpTo:mdocount map:^id(NSUInteger i) {
        return [FLEXMethodDescription description:objcoMethods[i] instance:NO];
    }] arrayByAddingObjectsFromArray:oMethods];
    free(objcoMethods);
    
    // 属性处理比较麻烦，因为直到iOS 10才修复了API //
    
    if (@available(iOS 10.0, *)) {
        unsigned int prrcount, procount;
        Class instance = [NSObject class], meta = objc_getMetaClass("NSObject");
        
        // 必需的类和实例属性 //
        
        // 先处理实例属性
        objc_property_t *rProps = protocol_copyPropertyList2(protocol, &prrcount, YES, YES);
        NSArray *rProperties = [NSArray flex_forEachUpTo:prrcount map:^id(NSUInteger i) {
            return [FLEXProperty property:rProps[i] onClass:instance];
        }];
        free(rProps);
        
        // 然后处理类属性
        rProps = protocol_copyPropertyList2(protocol, &prrcount, NO, YES);
        _requiredProperties = [[NSArray flex_forEachUpTo:prrcount map:^id(NSUInteger i) {
            return [FLEXProperty property:rProps[i] onClass:instance];
        }] arrayByAddingObjectsFromArray:rProperties];
        free(rProps);
        
        // 可选的类和实例属性 //
        
        // 先处理实例属性
        objc_property_t *oProps = protocol_copyPropertyList2(protocol, &procount, YES, YES);
        NSArray *oProperties = [NSArray flex_forEachUpTo:prrcount map:^id(NSUInteger i) {
            return [FLEXProperty property:oProps[i] onClass:meta];
        }];
        free(oProps);
        
        // 然后处理类属性
        oProps = protocol_copyPropertyList2(protocol, &procount, NO, YES);
        _optionalProperties = [[NSArray flex_forEachUpTo:procount map:^id(NSUInteger i) {
            return [FLEXProperty property:oProps[i] onClass:meta];
        }] arrayByAddingObjectsFromArray:oProperties];
        free(oProps);
        
    } else {
        unsigned int prcount;
        objc_property_t *objcproperties = protocol_copyPropertyList(protocol, &prcount);
        _properties = [NSArray flex_forEachUpTo:prcount map:^id(NSUInteger i) {
            return [FLEXProperty property:objcproperties[i]];
        }];
        
        _requiredProperties = @[];
        _optionalProperties = @[];
        
        free(objcproperties);
    }
}

- (BOOL)conformsTo:(Protocol *)protocol {
    return protocol_conformsToProtocol(self.objc_protocol, protocol);
}

@end

#pragma mark FLEXMethodDescription

@implementation FLEXMethodDescription

- (id)init {
    [NSException
        raise:NSInternalInconsistencyException
        format:@"不应该使用-init创建类实例"
    ];
    return nil;
}

+ (instancetype)description:(struct objc_method_description)description {
    return [[self alloc] initWithDescription:description instance:nil];
}

+ (instancetype)description:(struct objc_method_description)description instance:(BOOL)isInstance {
    return [[self alloc] initWithDescription:description instance:@(isInstance)];
}

- (id)initWithDescription:(struct objc_method_description)md instance:(NSNumber *)instance {
    NSParameterAssert(md.name != NULL);
    
    self = [super init];
    if (self) {
        _objc_description = md;
        _selector         = md.name;
        _typeEncoding     = @(md.types);
        _returnType       = (FLEXTypeEncoding)[self.typeEncoding characterAtIndex:0];
        _instance         = instance;
    }
    
    return self;
}

- (NSString *)description {
    return NSStringFromSelector(self.selector);
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@ name=%@, type=%@>",
            NSStringFromClass(self.class), NSStringFromSelector(self.selector), self.typeEncoding];
}

@end
