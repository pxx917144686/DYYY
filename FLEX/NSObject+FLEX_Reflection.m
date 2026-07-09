//
//  NSObject+FLEX_Reflection.m
//  FLEX
//
//  衍生自 MirrorKit。
//  由 Tanner 创建于 6/30/15。
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import "NSObject+FLEX_Reflection.h"
#import "DYYYFLEXClassBuilder.h"
#import "DYYYFLEXMirror.h"
#import "DYYYFLEXProperty.h"
#import "DYYYFLEXMethod.h"
#import "DYYYFLEXIvar.h"
#import "DYYYFLEXProtocol.h"
#import "DYYYFLEXPropertyAttributes.h"
#import "NSArray+FLEX.h"
#import "DYYYFLEXUtility.h"


NSString * FLEXTypeEncodingString(const char *returnType, NSUInteger count, ...) {
    if (!returnType) return nil;
    
    NSMutableString *encoding = [NSMutableString new];
    [encoding appendFormat:@"%s%s%s", returnType, @encode(id), @encode(SEL)];
    
    va_list args;
    va_start(args, count);
    char *type = va_arg(args, char *);
    for (NSUInteger i = 0; i < count; i++, type = va_arg(args, char *)) {
        [encoding appendFormat:@"%s", type];
    }
    va_end(args);
    
    return encoding.copy;
}

NSArray<Class> *FLEXGetAllSubclasses(Class cls, BOOL includeSelf) {
    if (!cls) return nil;
    
    Class *buffer = NULL;
    
    int count, size;
    do {
        count  = objc_getClassList(NULL, 0);
        buffer = (Class *)realloc(buffer, count * sizeof(*buffer));
        size   = objc_getClassList(buffer, count);
    } while (size != count);
    
    NSMutableArray *classes = [NSMutableArray new];
    if (includeSelf) {
        [classes addObject:cls];
    }
    
    for (int i = 0; i < count; i++) {
        Class candidate = buffer[i];
        Class superclass = candidate;
        while ((superclass = class_getSuperclass(superclass))) {
            if (superclass == cls) {
                [classes addObject:candidate];
                break;
            }
        }
    }
    
    free(buffer);
    return classes.copy;
}

NSArray<Class> *FLEXGetClassHierarchy(Class cls, BOOL includeSelf) {
    if (!cls) return nil;
    
    NSMutableArray *classes = [NSMutableArray new];
    if (includeSelf) {
        [classes addObject:cls];
    }
    
    while ((cls = [cls superclass])) {
        [classes addObject:cls];
    };

    return classes.copy;
}

NSArray<DYYYFLEXProtocol *> *FLEXGetConformedProtocols(Class cls) {
    if (!cls) return nil;
    
    unsigned int count = 0;
    Protocol *__unsafe_unretained *list = class_copyProtocolList(cls, &count);
    NSArray<Protocol *> *protocols = [NSArray arrayWithObjects:list count:count];
    free(list);
    
    return [protocols flex_mapped:^id(Protocol *pro, NSUInteger idx) {
        return [DYYYFLEXProtocol protocol:pro];
    }];
}

NSArray<DYYYFLEXIvar *> *FLEXGetAllIvars(_Nullable Class cls) {
    if (!cls) return nil;
    
    unsigned int ivcount;
    Ivar *objcivars = class_copyIvarList(cls, &ivcount);
    NSArray *ivars = [NSArray flex_forEachUpTo:ivcount map:^id(NSUInteger i) {
        return [DYYYFLEXIvar ivar:objcivars[i]];
    }];

    free(objcivars);
    return ivars;
}

NSArray<DYYYFLEXProperty *> *FLEXGetAllProperties(_Nullable Class cls) {
    if (!cls) return nil;
    
    unsigned int pcount;
    objc_property_t *objcproperties = class_copyPropertyList(cls, &pcount);
    NSArray *properties = [NSArray flex_forEachUpTo:pcount map:^id(NSUInteger i) {
        return [DYYYFLEXProperty property:objcproperties[i] onClass:cls];
    }];

    free(objcproperties);
    return properties;
}

NSArray<DYYYFLEXMethod *> *FLEXGetAllMethods(_Nullable Class cls, BOOL instance) {
    if (!cls) return nil;

    unsigned int mcount;
    Method *objcmethods = class_copyMethodList(cls, &mcount);
    NSArray *methods = [NSArray flex_forEachUpTo:mcount map:^id(NSUInteger i) {
        return [DYYYFLEXMethod method:objcmethods[i] isInstanceMethod:instance];
    }];
    
    free(objcmethods);
    return methods;
}


#pragma mark NSProxy

@interface NSProxy (AnyObjectAdditions) @end
@implementation NSProxy (AnyObjectAdditions)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    // 我们需要获取此文件中的所有方法并将它们添加到 NSProxy。
    // 为此，我们需要类本身及其元类。
    // 编辑：也将它们添加到 Swift._SwiftObject
    Class NSProxyClass = [NSProxy class];
    Class NSProxy_meta = object_getClass(NSProxyClass);
    Class SwiftObjectClass = (
        NSClassFromString(@"SwiftObject") ?: NSClassFromString(@"Swift._SwiftObject")
    );
    
    // 从 NSObject 复制所有 "flex_" 开头的方法
    id filterFunc = ^BOOL(DYYYFLEXMethod *method, NSUInteger idx) {
        return [method.name hasPrefix:@"flex_"];
    };
    NSArray *instanceMethods = [NSObject.flex_allInstanceMethods flex_filtered:filterFunc];
    NSArray *classMethods = [NSObject.flex_allClassMethods flex_filtered:filterFunc];
    
    DYYYFLEXClassBuilder *proxy     = [DYYYFLEXClassBuilder builderForClass:NSProxyClass];
    DYYYFLEXClassBuilder *proxyMeta = [DYYYFLEXClassBuilder builderForClass:NSProxy_meta];
    [proxy addMethods:instanceMethods];
    [proxyMeta addMethods:classMethods];
    
    if (SwiftObjectClass) {
        Class SwiftObject_meta = object_getClass(SwiftObjectClass);
        DYYYFLEXClassBuilder *swiftObject = [DYYYFLEXClassBuilder builderForClass:SwiftObjectClass];
        DYYYFLEXClassBuilder *swiftObjectMeta = [DYYYFLEXClassBuilder builderForClass:SwiftObject_meta];
        [swiftObject addMethods:instanceMethods];
        [swiftObjectMeta addMethods:classMethods];
        
        // 这样我们就可以将 Swift 对象放入字典中...
        [swiftObjectMeta addMethods:@[
            [NSObject flex_classMethodNamed:@"copyWithZone:"]]
        ];
    }
}

@end

#pragma mark 反射

@implementation NSObject (Reflection)

+ (DYYYFLEXMirror *)flex_reflection {
    return [DYYYFLEXMirror reflect:self];
}

- (DYYYFLEXMirror *)flex_reflection {
    return [DYYYFLEXMirror reflect:self];
}

/// 代码借鉴自 Mike Ash 的 MAObjCRuntime
+ (NSArray *)flex_allSubclasses {
    return FLEXGetAllSubclasses(self, YES);
}

- (Class)flex_setClass:(Class)cls {
    return object_setClass(self, cls);
}

+ (Class)flex_metaclass {
    return objc_getMetaClass(NSStringFromClass(self.class).UTF8String);
}

+ (size_t)flex_instanceSize {
    return class_getInstanceSize(self.class);
}

+ (Class)flex_setSuperclass:(Class)superclass {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return class_setSuperclass(self, superclass);
    #pragma clang diagnostic pop
}

+ (NSArray<Class> *)flex_classHierarchy {
    return FLEXGetClassHierarchy(self, YES);
}

+ (NSArray<DYYYFLEXProtocol *> *)flex_protocols {
    return FLEXGetConformedProtocols(self);
}

@end


#pragma mark 方法

@implementation NSObject (Methods)

+ (NSArray<DYYYFLEXMethod *> *)flex_allMethods {
    NSMutableArray *instanceMethods = self.flex_allInstanceMethods.mutableCopy;
    [instanceMethods addObjectsFromArray:self.flex_allClassMethods];
    return instanceMethods;
}

+ (NSArray<DYYYFLEXMethod *> *)flex_allInstanceMethods {
    return FLEXGetAllMethods(self, YES);
}

+ (NSArray<DYYYFLEXMethod *> *)flex_allClassMethods {
    return FLEXGetAllMethods(self.flex_metaclass, NO) ?: @[];
}

+ (DYYYFLEXMethod *)flex_methodNamed:(NSString *)name {
    Method m = class_getInstanceMethod([self class], NSSelectorFromString(name));
    if (m == NULL) {
        return nil;
    }

    return [DYYYFLEXMethod method:m isInstanceMethod:YES];
}

+ (DYYYFLEXMethod *)flex_classMethodNamed:(NSString *)name {
    Method m = class_getClassMethod([self class], NSSelectorFromString(name));
    if (m == NULL) {
        return nil;
    }

    return [DYYYFLEXMethod method:m isInstanceMethod:NO];
}

+ (BOOL)addMethod:(SEL)selector
     typeEncoding:(NSString *)typeEncoding
   implementation:(IMP)implementaiton
      toInstances:(BOOL)instance {
    return class_addMethod(instance ? self.class : self.flex_metaclass, selector, implementaiton, typeEncoding.UTF8String);
}

+ (IMP)replaceImplementationOfMethod:(DYYYFLEXMethodBase *)method with:(IMP)implementation useInstance:(BOOL)instance {
    return class_replaceMethod(instance ? self.class : self.flex_metaclass, method.selector, implementation, method.typeEncoding.UTF8String);
}

+ (void)swizzle:(DYYYFLEXMethodBase *)original with:(DYYYFLEXMethodBase *)other onInstance:(BOOL)instance {
    [self swizzleBySelector:original.selector with:other.selector onInstance:instance];
}

+ (BOOL)swizzleByName:(NSString *)original with:(NSString *)other onInstance:(BOOL)instance {
    SEL originalMethod = NSSelectorFromString(original);
    SEL newMethod      = NSSelectorFromString(other);
    if (originalMethod == 0 || newMethod == 0) {
        return NO;
    }

    [self swizzleBySelector:originalMethod with:newMethod onInstance:instance];
    return YES;
}

+ (void)swizzleBySelector:(SEL)original with:(SEL)other onInstance:(BOOL)instance {
    Class cls = instance ? self.class : self.flex_metaclass;
    Method originalMethod = class_getInstanceMethod(cls, original);
    Method newMethod = class_getInstanceMethod(cls, other);
    if (class_addMethod(cls, original, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(cls, other, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

@end


#pragma mark 实例变量

@implementation NSObject (Ivars)

+ (NSArray<DYYYFLEXIvar *> *)flex_allIvars {
    return FLEXGetAllIvars(self);
}

+ (DYYYFLEXIvar *)flex_ivarNamed:(NSString *)name {
    Ivar i = class_getInstanceVariable([self class], name.UTF8String);
    if (i == NULL) {
        return nil;
    }

    return [DYYYFLEXIvar ivar:i];
}

#pragma mark 获取地址
- (void *)flex_getIvarAddress:(DYYYFLEXIvar *)ivar {
    return (uint8_t *)(__bridge void *)self + ivar.offset;
}

- (void *)flex_getObjcIvarAddress:(Ivar)ivar {
    return (uint8_t *)(__bridge void *)self + ivar_getOffset(ivar);
}

- (void *)flex_getIvarAddressByName:(NSString *)name {
    Ivar ivar = class_getInstanceVariable(self.class, name.UTF8String);
    if (!ivar) return 0;
    
    return (uint8_t *)(__bridge void *)self + ivar_getOffset(ivar);
}

#pragma mark 设置实例变量对象
- (void)flex_setIvar:(DYYYFLEXIvar *)ivar object:(id)value {
    object_setIvar(self, ivar.objc_ivar, value);
}

- (BOOL)flex_setIvarByName:(NSString *)name object:(id)value {
    Ivar ivar = class_getInstanceVariable(self.class, name.UTF8String);
    if (!ivar) return NO;
    
    object_setIvar(self, ivar, value);
    return YES;
}

- (void)flex_setObjcIvar:(Ivar)ivar object:(id)value {
    object_setIvar(self, ivar, value);
}

#pragma mark 设置实例变量值
- (void)flex_setIvar:(DYYYFLEXIvar *)ivar value:(void *)value size:(size_t)size {
    void *address = [self flex_getIvarAddress:ivar];
    memcpy(address, value, size);
}

- (BOOL)flex_setIvarByName:(NSString *)name value:(void *)value size:(size_t)size {
    Ivar ivar = class_getInstanceVariable(self.class, name.UTF8String);
    if (!ivar) return NO;
    
    [self flex_setObjcIvar:ivar value:value size:size];
    return YES;
}

- (void)flex_setObjcIvar:(Ivar)ivar value:(void *)value size:(size_t)size {
    void *address = [self flex_getObjcIvarAddress:ivar];
    memcpy(address, value, size);
}

@end


#pragma mark 属性

@implementation NSObject (Properties)

+ (NSArray<DYYYFLEXProperty *> *)flex_allProperties {
    NSMutableArray *instanceProperties = self.flex_allInstanceProperties.mutableCopy;
    [instanceProperties addObjectsFromArray:self.flex_allClassProperties];
    return instanceProperties;
}

+ (NSArray<DYYYFLEXProperty *> *)flex_allInstanceProperties {
    return FLEXGetAllProperties(self);
}

+ (NSArray<DYYYFLEXProperty *> *)flex_allClassProperties {
    return FLEXGetAllProperties(self.flex_metaclass) ?: @[];
}

+ (DYYYFLEXProperty *)flex_propertyNamed:(NSString *)name {
    objc_property_t p = class_getProperty([self class], name.UTF8String);
    if (p == NULL) {
        return nil;
    }

    return [DYYYFLEXProperty property:p onClass:self];
}

+ (DYYYFLEXProperty *)flex_classPropertyNamed:(NSString *)name {
    objc_property_t p = class_getProperty(object_getClass(self), name.UTF8String);
    if (p == NULL) {
        return nil;
    }

    return [DYYYFLEXProperty property:p onClass:object_getClass(self)];
}

+ (void)flex_replaceProperty:(DYYYFLEXProperty *)property {
    [self flex_replaceProperty:property.name attributes:property.attributes];
}

+ (void)flex_replaceProperty:(NSString *)name attributes:(DYYYFLEXPropertyAttributes *)attributes {
    unsigned int count;
    objc_property_attribute_t *objc_attributes = [attributes copyAttributesList:&count];
    class_replaceProperty([self class], name.UTF8String, objc_attributes, count);
    free(objc_attributes);
}

@end


