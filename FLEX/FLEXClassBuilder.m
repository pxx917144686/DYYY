//
//  FLEXClassBuilder.m
//  FLEX
//
//  源自 MirrorKit.
//  由 Tanner 于 7/3/15 创建.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利.
//

#import "FLEXClassBuilder.h"
#import "FLEXProperty.h"
#import "FLEXMethodBase.h"
#import "FLEXProtocol.h"
#import <objc/runtime.h>


#pragma mark FLEXClassBuilder

@interface FLEXClassBuilder ()
@property (nonatomic) NSString *name;
@end

@implementation FLEXClassBuilder

- (id)init {
    [NSException
        raise:NSInternalInconsistencyException
        format:@"不应使用 -init 创建类实例"
    ];
    return nil;
}

#pragma mark 初始化器
+ (instancetype)allocateClass:(NSString *)name {
    return [self allocateClass:name superclass:NSObject.class];
}

+ (instancetype)allocateClass:(NSString *)name superclass:(Class)superclass {
    return [self allocateClass:name superclass:superclass extraBytes:0];
}

+ (instancetype)allocateClass:(NSString *)name superclass:(Class)superclass extraBytes:(size_t)bytes {
    NSParameterAssert(name);
    return [[self alloc] initWithClass:objc_allocateClassPair(superclass, name.UTF8String, bytes)];
}

+ (instancetype)allocateRootClass:(NSString *)name {
    NSParameterAssert(name);
    return [[self alloc] initWithClass:objc_allocateClassPair(Nil, name.UTF8String, 0)];
}

+ (instancetype)builderForClass:(Class)cls {
    return [[self alloc] initWithClass:cls];
}

- (id)initWithClass:(Class)cls {
    NSParameterAssert(cls);
    
    self = [super init];
    if (self) {
        _workingClass = cls;
        _name = NSStringFromClass(_workingClass);
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ 名称=%@, 已注册=%d>",
            NSStringFromClass(self.class), self.name, self.isRegistered];
}

#pragma mark 构建
- (NSArray *)addMethods:(NSArray *)methods {
    NSParameterAssert(methods.count);
    
    NSMutableArray *failed = [NSMutableArray new];
    for (FLEXMethodBase *m in methods) {
        if (!class_addMethod(self.workingClass, m.selector, m.implementation, m.typeEncoding.UTF8String)) {
            [failed addObject:m];
        }
    }
    
    return failed;
}

- (NSArray *)addProperties:(NSArray *)properties {
    NSParameterAssert(properties.count);
    
    NSMutableArray *failed = [NSMutableArray new];
    for (FLEXProperty *p in properties) {
        unsigned int pcount;
        objc_property_attribute_t *attributes = [p copyAttributesList:&pcount];
        if (!class_addProperty(self.workingClass, p.name.UTF8String, attributes, pcount)) {
            [failed addObject:p];
        }
        free(attributes);
    }
    
    return failed;
}

- (NSArray *)addProtocols:(NSArray *)protocols {
    NSParameterAssert(protocols.count);
    
    NSMutableArray *failed = [NSMutableArray new];
    for (FLEXProtocol *p in protocols) {
        if (!class_addProtocol(self.workingClass, p.objc_protocol)) {
            [failed addObject:p];
        }
    }
    
    return failed;
}

- (NSArray *)addIvars:(NSArray *)ivars {
    NSParameterAssert(ivars.count);
    
    NSMutableArray *failed = [NSMutableArray new];
    for (FLEXIvarBuilder *ivar in ivars) {
        if (!class_addIvar(self.workingClass, ivar.name.UTF8String, ivar.size, ivar.alignment, ivar.encoding.UTF8String)) {
            [failed addObject:ivar];
        }
    }
    
    return failed;
}

- (Class)registerClass {
    if (self.isRegistered) {
        [NSException raise:NSInternalInconsistencyException format:@"类已经注册"];
    }
    
    objc_registerClassPair(self.workingClass);
    return self.workingClass;
}

- (BOOL)isRegistered {
    return objc_lookUpClass(self.name.UTF8String) != nil;
}

@end


#pragma mark FLEXIvarBuilder

@implementation FLEXIvarBuilder

+ (instancetype)name:(NSString *)name size:(size_t)size alignment:(uint8_t)alignment typeEncoding:(NSString *)encoding {
    return [[self alloc] initWithName:name size:size alignment:alignment typeEncoding:encoding];
}

- (id)initWithName:(NSString *)name size:(size_t)size alignment:(uint8_t)alignment typeEncoding:(NSString *)encoding {
    NSParameterAssert(name); NSParameterAssert(encoding);
    NSParameterAssert(size > 0); NSParameterAssert(alignment > 0);
    
    self = [super init];
    if (self) {
        _name      = name;
        _encoding  = encoding;
        _size      = size;
        _alignment = alignment;
    }
    
    return self;
}

@end
