// filepath: NSObject+FLEX_Reflection.m
// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSObject+FLEX_Reflection.m
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 6/30/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "NSObject+FLEX_Reflection.h"
#import "FLEXClassBuilder.h"
#import "FLEXMirror.h"
#import "FLEXProperty.h"
#import "FLEXMethod.h"
#import "FLEXIvar.h"
#import "FLEXProtocol.h"
#import "FLEXPropertyAttributes.h"
#import "NSArray+FLEX.h"
#import "FLEXUtility.h"


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

NSArray<FLEXProtocol *> *FLEXGetConformedProtocols(Class cls) {
    if (!cls) return nil;
    
    unsigned int count = 0;
    Protocol *__unsafe_unretained *list = class_copyProtocolList(cls, &count);
    NSArray<Protocol *> *protocols = [NSArray arrayWithObjects:list count:count];
    free(list);
    
    return [protocols flex_mapped:^id(Protocol *pro, NSUInteger idx) {
        return [FLEXProtocol protocol:pro];
    }];
}

NSArray<FLEXIvar *> *FLEXGetAllIvars(_Nullable Class cls) {
    if (!cls) return nil;
    
    unsigned int ivcount;
    Ivar *objcivars = class_copyIvarList(cls, &ivcount);
    NSArray *ivars = [NSArray flex_forEachUpTo:ivcount map:^id(NSUInteger i) {
        return [FLEXIvar ivar:objcivars[i]];
    }];

    free(objcivars);
    return ivars;
}

NSArray<FLEXProperty *> *FLEXGetAllProperties(_Nullable Class cls) {
    if (!cls) return nil;
    
    unsigned int pcount;
    objc_property_t *objcproperties = class_copyPropertyList(cls, &pcount);
    NSArray *properties = [NSArray flex_forEachUpTo:pcount map:^id(NSUInteger i) {
        return [FLEXProperty property:objcproperties[i] onClass:cls];
    }];

    free(objcproperties);
    return properties;
}

NSArray<FLEXMethod *> *FLEXGetAllMethods(_Nullable Class cls, BOOL instance) {
    if (!cls) return nil;

    unsigned int mcount;
    Method *objcmethods = class_copyMethodList(cls, &mcount);
    NSArray *methods = [NSArray flex_forEachUpTo:mcount map:^id(NSUInteger i) {
        return [FLEXMethod method:objcmethods[i] isInstanceMethod:instance];
    }];
    
    free(objcmethods);
    return methods;
}


#pragma mark - NSProxy

@interface NSProxy (AnyObjectAdditions) @end
@implementation NSProxy (AnyObjectAdditions)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    // 我们需要获取此文件中的所有方法并将它们添加到 NSProxy。
    // 为此，我们需要类本身及其元类。
    // 编辑：同时也将它们添加到 Swift._SwiftObject
    Class NSProxyClass = [NSProxy class];
    Class NSProxy_meta = object_getClass(NSProxyClass);
    Class SwiftObjectClass = (
        NSClassFromString(@"SwiftObject") ?: NSClassFromString(@"Swift._SwiftObject")
    );
    
    // 从 NSObject 复制所有 "flex_" 方法
    id filterFunc = ^BOOL(FLEXMethod *method, NSUInteger idx) {
        return [method.name hasPrefix:@"flex_"];
    };
    NSArray *instanceMethods = [NSObject.flex_allInstanceMethods flex_filtered:filterFunc];
    NSArray *classMethods = [NSObject.flex_allClassMethods flex_filtered:filterFunc];
    
    FLEXClassBuilder *proxy     = [FLEXClassBuilder builderForClass:NSProxyClass];
    FLEXClassBuilder *proxyMeta = [FLEXClassBuilder builderForClass:NSProxy_meta];
    [proxy addMethods:instanceMethods];
    [proxyMeta addMethods:classMethods];
    
    if (SwiftObjectClass) {
        Class SwiftObject_meta = object_getClass(SwiftObjectClass);
        FLEXClassBuilder *swiftObject = [FLEXClassBuilder builderForClass:SwiftObjectClass];
        FLEXClassBuilder *swiftObjectMeta = [FLEXClassBuilder builderForClass:SwiftObject_meta];
        [swiftObject addMethods:instanceMethods];
        [swiftObjectMeta addMethods:classMethods];
        
        // 这样我们就可以将 Swift 对象放入字典中...
        [swiftObjectMeta addMethods:@[
            [NSObject flex_classMethodNamed:@"copyWithZone:"]]
        ];
    }
}

@end

#pragma mark - 反射

@implementation NSObject (Reflection)

+ (FLEXMirror *)flex_reflection {
    return [FLEXMirror reflect:self];
}

- (FLEXMirror *)flex_reflection {
    return [FLEXMirror reflect:self];
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

+ (NSArray<FLEXProtocol *> *)flex_protocols {
    return FLEXGetConformedProtocols(self);
}

@end


#pragma mark - 方法

@implementation NSObject (Methods)

+ (NSArray<FLEXMethod *> *)flex_allMethods {
    NSMutableArray *instanceMethods = self.flex_allInstanceMethods.mutableCopy;
    [instanceMethods addObjectsFromArray:self.flex_allClassMethods];
    return instanceMethods;
}

+ (NSArray<FLEXMethod *> *)flex_allInstanceMethods {
    return FLEXGetAllMethods(self, YES);
}

+ (NSArray<FLEXMethod *> *)flex_allClassMethods {
    return FLEXGetAllMethods(self.flex_metaclass, NO) ?: @[];
}

+ (FLEXMethod *)flex_methodNamed:(NSString *)name {
    Method m = class_getInstanceMethod([self class], NSSelectorFromString(name));
    if (m == NULL) {
        return nil;
    }

    return [FLEXMethod method:m isInstanceMethod:YES];
}

+ (FLEXMethod *)flex_classMethodNamed:(NSString *)name {
    Method m = class_getClassMethod([self class], NSSelectorFromString(name));
    if (m == NULL) {
        return nil;
    }

    return [FLEXMethod method:m isInstanceMethod:NO];
}

+ (BOOL)addMethod:(SEL)selector
     typeEncoding:(NSString *)typeEncoding
   implementation:(IMP)implementaiton
      toInstances:(BOOL)instance {
    return class_addMethod(instance ? self.class : self.flex_metaclass, selector, implementaiton, typeEncoding.UTF8String);
}

+ (IMP)replaceImplementationOfMethod:(FLEXMethodBase *)method with:(IMP)implementation useInstance:(BOOL)instance {
    return class_replaceMethod(instance ? self.class : self.flex_metaclass, method.selector, implementation, method.typeEncoding.UTF8String);
}

+ (void)swizzle:(FLEXMethodBase *)original with:(FLEXMethodBase *)other onInstance:(BOOL)instance {
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


#pragma mark - 实例变量

@implementation NSObject (Ivars)

+ (NSArray<FLEXIvar *> *)flex_allIvars {
    return FLEXGetAllIvars(self);
}

+ (FLEXIvar *)flex_ivarNamed:(NSString *)name {
    Ivar i = class_getInstanceVariable([self class], name.UTF8String);
    if (i == NULL) {
        return nil;
    }

    return [FLEXIvar ivar:i];
}

#pragma mark 获取地址
- (void *)flex_getIvarAddress:(FLEXIvar *)ivar {
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
- (void)flex_setIvar:(FLEXIvar *)ivar object:(id)value {
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
- (void)flex_setIvar:(FLEXIvar *)ivar value:(void *)value size:(size_t)size {
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


#pragma mark - 属性

@implementation NSObject (Properties)

+ (NSArray<FLEXProperty *> *)flex_allProperties {
    NSMutableArray *instanceProperties = self.flex_allInstanceProperties.mutableCopy;
    [instanceProperties addObjectsFromArray:self.flex_allClassProperties];
    return instanceProperties;
}

+ (NSArray<FLEXProperty *> *)flex_allInstanceProperties {
    return FLEXGetAllProperties(self);
}

+ (NSArray<FLEXProperty *> *)flex_allClassProperties {
    return FLEXGetAllProperties(self.flex_metaclass) ?: @[];
}

+ (FLEXProperty *)flex_propertyNamed:(NSString *)name {
    objc_property_t p = class_getProperty([self class], name.UTF8String);
    if (p == NULL) {
        return nil;
    }

    return [FLEXProperty property:p onClass:self];
}

+ (FLEXProperty *)flex_classPropertyNamed:(NSString *)name {
    objc_property_t p = class_getProperty(object_getClass(self), name.UTF8String);
    if (p == NULL) {
        return nil;
    }

    return [FLEXProperty property:p onClass:object_getClass(self)];
}

+ (void)flex_replaceProperty:(FLEXProperty *)property {
    [self flex_replaceProperty:property.name attributes:property.attributes];
}

+ (void)flex_replaceProperty:(NSString *)name attributes:(FLEXPropertyAttributes *)attributes {
    unsigned int count;
    objc_property_attribute_t *objc_attributes = [attributes copyAttributesList:&count];
    class_replaceProperty([self class], name.UTF8String, objc_attributes, count);
    free(objc_attributes);
}

@end


