#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXHookDetector.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#import <malloc/malloc.h>

@implementation FLEXRuntimeClient (RuntimeBrowser)

- (NSMutableDictionary *)allClassStubsByName {
    static NSMutableDictionary *_allClassStubsByName = nil;
    if (!_allClassStubsByName) {
        _allClassStubsByName = [NSMutableDictionary dictionary];
        [self readAllRuntimeClasses];
    }
    return _allClassStubsByName;
}

- (NSMutableDictionary *)allClassStubsByImagePath {
    static NSMutableDictionary *_allClassStubsByImagePath = nil;
    if (!_allClassStubsByImagePath) {
        _allClassStubsByImagePath = [NSMutableDictionary dictionary];
        [self readAllRuntimeClasses];
    }
    return _allClassStubsByImagePath;
}

- (NSMutableArray *)rootClasses {
    static NSMutableArray *_rootClasses = nil;
    if (!_rootClasses) {
        _rootClasses = [NSMutableArray array];
        [self readAllRuntimeClasses];
    }
    return _rootClasses;
}

- (void)readAllRuntimeClasses {
    // 实现类读取逻辑
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    NSMutableDictionary *classByName = [self allClassStubsByName];
    NSMutableDictionary *classByPath = [self allClassStubsByImagePath];
    NSMutableArray *roots = [self rootClasses];
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        
        if (className) {
            classByName[className] = className;
            
            // 获取类所在的镜像路径
            const char *imageName = class_getImageName(cls);
            if (imageName) {
                NSString *imagePath = @(imageName);
                NSMutableArray *classesInImage = classByPath[imagePath];
                if (!classesInImage) {
                    classesInImage = [NSMutableArray array];
                    classByPath[imagePath] = classesInImage;
                }
                [classesInImage addObject:className];
            }
            
            // 检查是否为根类
            if (!class_getSuperclass(cls)) {
                if (![roots containsObject:className]) {
                    [roots addObject:className];
                }
            }
        }
    }
    
    free(classes);
}

// 修复malloc枚举函数调用
static void range_recorder(unsigned int task, void *context, unsigned int type, vm_range_t *ranges, unsigned int count) {
    NSMutableArray *instances = (__bridge NSMutableArray *)context;
    Class targetClass = objc_getAssociatedObject(instances, @selector(targetClass));
    
    for (unsigned int j = 0; j < count; j++) {
        vm_range_t range = ranges[j];
        void *ptr = (void *)range.address;
        
        @try {
            if (ptr && malloc_size(ptr) > 0) {
                id obj = (__bridge id)ptr;
                if ([obj isKindOfClass:targetClass]) {
                    [instances addObject:obj];
                }
            }
        } @catch (NSException *exception) {
            // 忽略无效对象
        }
    }
}

- (NSArray *)getAllInstancesOfClass:(Class)cls {
    NSMutableArray *instances = [NSMutableArray array];
    
    // 将目标类关联到结果数组，供回调函数使用
    objc_setAssociatedObject(instances, @selector(targetClass), cls, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 使用 malloc 枚举所有对象
    vm_address_t *zones = NULL;
    unsigned int zoneCount = 0;
    
    kern_return_t kr = malloc_get_all_zones(mach_task_self(), NULL, &zones, &zoneCount);
    
    if (kr == KERN_SUCCESS) {
        for (unsigned int i = 0; i < zoneCount; i++) {
            malloc_zone_t *zone = (malloc_zone_t *)zones[i];
            if (zone && zone->introspect && zone->introspect->enumerator) {
                @try {
                    // 使用函数指针而不是block
                    zone->introspect->enumerator(mach_task_self(), (__bridge void *)instances, MALLOC_PTR_IN_USE_RANGE_TYPE, (vm_address_t)zone, NULL, range_recorder);
                } @catch (NSException *exception) {
                    // 忽略枚举错误
                }
            }
        }
    }
    
    // 清理关联对象
    objc_setAssociatedObject(instances, @selector(targetClass), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return instances;
}

- (BOOL)isValidObjcObject:(void *)ptr {
    if (!ptr) return NO;
    
    @try {
        id obj = (__bridge id)ptr;
        return [obj class] != nil;
    } @catch (NSException *exception) {
        return NO;
    }
}

- (NSUInteger)getInstanceCountForClass:(Class)cls {
    return [[self getAllInstancesOfClass:cls] count];
}

- (NSArray *)sortedClassStubs {
    NSArray *allClassNames = [[self allClassStubsByName] allKeys];
    return [allClassNames sortedArrayUsingSelector:@selector(compare:)];
}

- (void)emptyCachesAndReadAllRuntimeClasses {
    // 清空缓存
    objc_setAssociatedObject(self, @selector(allClassStubsByName), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, @selector(allClassStubsByImagePath), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, @selector(rootClasses), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 重新读取
    [self readAllRuntimeClasses];
}

#pragma mark - 添加缺失的方法实现

- (NSDictionary *)getDetailedClassInfo:(Class)cls {
    if (!cls) return @{};
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    // 基本信息
    info[@"className"] = NSStringFromClass(cls);
    info[@"superclass"] = class_getSuperclass(cls) ? NSStringFromClass(class_getSuperclass(cls)) : @"(none)";
    info[@"instanceSize"] = @(class_getInstanceSize(cls));
    info[@"isMetaClass"] = @(class_isMetaClass(cls));
    
    // 镜像信息
    const char *imageName = class_getImageName(cls);
    if (imageName) {
        info[@"imageName"] = @(imageName);
        info[@"shortImageName"] = [self shortNameForImageName:@(imageName)];
    }
    
    // 方法统计
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    info[@"instanceMethodCount"] = @(methodCount);
    free(methods);
    
    Method *classMethods = class_copyMethodList(object_getClass(cls), &methodCount);
    info[@"classMethodCount"] = @(methodCount);
    free(classMethods);
    
    // 属性统计
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    info[@"propertyCount"] = @(propertyCount);
    free(properties);
    
    // 实例变量统计
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    info[@"ivarCount"] = @(ivarCount);
    free(ivars);
    
    // 协议统计
    unsigned int protocolCount = 0;
    Protocol *__unsafe_unretained *protocols = class_copyProtocolList(cls, &protocolCount);
    info[@"protocolCount"] = @(protocolCount);
    free(protocols);
    
    // 实例数量
    info[@"instanceCount"] = @([self getInstanceCountForClass:cls]);
    
    return info;
}

- (NSString *)generateHeaderForClass:(Class)cls {
    if (!cls) return @"";
    
    NSMutableString *header = [NSMutableString string];
    
    // 类声明
    Class superclass = class_getSuperclass(cls);
    NSString *superclassName = superclass ? NSStringFromClass(superclass) : @"NSObject";
    
    [header appendFormat:@"@interface %@ : %@\n\n", NSStringFromClass(cls), superclassName];
    
    // 实例变量
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    
    if (ivarCount > 0) {
        [header appendString:@"// Instance Variables\n{\n"];
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *ivarName = ivar_getName(ivar);
            const char *ivarType = ivar_getTypeEncoding(ivar);
            
            [header appendFormat:@"    %s %s;\n", ivarType, ivarName];
        }
        [header appendString:@"}\n\n"];
    }
    free(ivars);
    
    // 属性
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    
    if (propertyCount > 0) {
        [header appendString:@"// Properties\n"];
        for (unsigned int i = 0; i < propertyCount; i++) {
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            const char *propertyAttributes = property_getAttributes(property);
            
            [header appendFormat:@"@property %s %s;\n", propertyAttributes, propertyName];
        }
        [header appendString:@"\n"];
    }
    free(properties);
    
    // 实例方法
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    if (methodCount > 0) {
        [header appendString:@"// Instance Methods\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            const char *typeEncoding = method_getTypeEncoding(method);
            
            [header appendFormat:@"- (%s)%s;\n", typeEncoding, sel_getName(selector)];
        }
        [header appendString:@"\n"];
    }
    free(methods);
    
    // 类方法
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    if (methodCount > 0) {
        [header appendString:@"// Class Methods\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            const char *typeEncoding = method_getTypeEncoding(method);
            
            [header appendFormat:@"+ (%s)%s;\n", typeEncoding, sel_getName(selector)];
        }
        [header appendString:@"\n"];
    }
    free(methods);
    
    [header appendString:@"@end"];
    
    return header;
}

#pragma mark - 其他实用方法

- (NSArray *)dokit_getAllClassesWithPrefix:(NSString *)prefix {
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        
        if (!prefix || [className hasPrefix:prefix]) {
            [result addObject:className];
        }
    }
    
    free(classes);
    return [result sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)dokit_getMethodsForClass:(Class)cls includeHooked:(BOOL)includeHooked {
    if (!cls) return @[];
    
    NSMutableArray *methods = [NSMutableArray array];
    
    // 实例方法
    unsigned int methodCount = 0;
    Method *instanceMethods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = instanceMethods[i];
        SEL selector = method_getName(method);
        const char *typeEncoding = method_getTypeEncoding(method);
        IMP implementation = method_getImplementation(method);
        
        NSMutableDictionary *methodInfo = [NSMutableDictionary dictionary];
        methodInfo[@"selector"] = NSStringFromSelector(selector);
        methodInfo[@"encoding"] = @(typeEncoding);
        methodInfo[@"isInstanceMethod"] = @YES;
        methodInfo[@"implementation"] = [NSString stringWithFormat:@"%p", implementation];
        
        if (includeHooked) {
            // 使用 FLEXHookDetector 来检测Hook
            FLEXHookDetector *detector = [FLEXHookDetector sharedDetector];
            BOOL isHooked = [detector isMethodHooked:method ofClass:cls];
            methodInfo[@"isHooked"] = @(isHooked);
        }
        
        [methods addObject:methodInfo];
    }
    free(instanceMethods);
    
    // 类方法
    Class metaClass = object_getClass(cls);
    Method *classMethods = class_copyMethodList(metaClass, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = classMethods[i];
        SEL selector = method_getName(method);
        const char *typeEncoding = method_getTypeEncoding(method);
        IMP implementation = method_getImplementation(method);
        
        NSMutableDictionary *methodInfo = [NSMutableDictionary dictionary];
        methodInfo[@"selector"] = NSStringFromSelector(selector);
        methodInfo[@"encoding"] = @(typeEncoding);
        methodInfo[@"isInstanceMethod"] = @NO;
        methodInfo[@"implementation"] = [NSString stringWithFormat:@"%p", implementation];
        
        if (includeHooked) {
            // 使用 FLEXHookDetector 来检测Hook
            FLEXHookDetector *detector = [FLEXHookDetector sharedDetector];
            BOOL isHooked = [detector isMethodHooked:method ofClass:metaClass];
            methodInfo[@"isHooked"] = @(isHooked);
        }
        
        [methods addObject:methodInfo];
    }
    free(classMethods);
    
    return methods;
}

- (NSDictionary *)dokit_getClassHierarchyTree {
    NSMutableDictionary *tree = [NSMutableDictionary dictionary];
    
    // 获取所有根类
    NSArray *rootClasses = [self rootClasses];
    
    for (NSString *rootClassName in rootClasses) {
        Class rootClass = NSClassFromString(rootClassName);
        if (rootClass) {
            tree[rootClassName] = [self buildClassTreeForClass:rootClass];
        }
    }
    
    return tree;
}

- (NSDictionary *)buildClassTreeForClass:(Class)cls {
    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    
    node[@"className"] = NSStringFromClass(cls);
    node[@"instanceSize"] = @(class_getInstanceSize(cls));
    node[@"methodCount"] = @([[self dokit_getMethodsForClass:cls includeHooked:NO] count]);
    
    // 获取直接子类
    NSMutableArray *subclasses = [NSMutableArray array];
    
    unsigned int classCount = 0;
    Class *allClasses = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class currentClass = allClasses[i];
        if (class_getSuperclass(currentClass) == cls) {
            [subclasses addObject:[self buildClassTreeForClass:currentClass]];
        }
    }
    
    free(allClasses);
    
    if (subclasses.count > 0) {
        node[@"subclasses"] = subclasses;
    }
    
    return node;
}

- (NSUInteger)dokit_getInstanceCountForClass:(Class)cls {
    return [[self dokit_getAllInstancesOfClass:cls] count];
}

- (NSArray *)dokit_getAllInstancesOfClass:(Class)cls {
    return [self getAllInstancesOfClass:cls];
}

// 修复第二个枚举函数调用
static void range_recorder_heap(unsigned int task, void *context, unsigned int type, vm_range_t *ranges, unsigned int count) {
    NSMutableArray *results = (__bridge NSMutableArray *)context;
    Class targetClass = objc_getAssociatedObject(results, @selector(targetClass));
    
    for (unsigned int j = 0; j < count; j++) {
        vm_range_t range = ranges[j];
        void *ptr = (void *)range.address;
        
        @try {
            if (ptr && malloc_size(ptr) > 0) {
                id obj = (__bridge id)ptr;
                if ([obj isKindOfClass:targetClass]) {
                    [results addObject:obj];
                }
            }
        } @catch (NSException *exception) {
            // 忽略无效对象
        }
    }
}

- (void)enumerateObjectsInZone:(malloc_zone_t *)zone forClass:(Class)targetClass results:(NSMutableArray *)results {
    objc_setAssociatedObject(results, @selector(targetClass), targetClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    @try {
        // 使用函数指针而不是block
        zone->introspect->enumerator(mach_task_self(), (__bridge void *)results, MALLOC_PTR_IN_USE_RANGE_TYPE, (vm_address_t)zone, NULL, range_recorder_heap);
    } @catch (NSException *exception) {
        // 忽略枚举错误
    }
    
    objc_setAssociatedObject(results, @selector(targetClass), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)flex_getHeapSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    
    // 基础内存信息
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    snapshot[@"residentSize"] = @(info.resident_size);
    snapshot[@"virtualSize"] = @(info.virtual_size);
    snapshot[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    // 类实例统计
    NSMutableDictionary *classStats = [NSMutableDictionary dictionary];
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        NSUInteger instanceCount = [self getInstanceCountForClass:cls];
        
        if (instanceCount > 0) {
            classStats[className] = @{
                @"count": @(instanceCount),
                @"size": @(class_getInstanceSize(cls))
            };
        }
    }
    
    free(classes);
    snapshot[@"classStatistics"] = classStats;
    
    return snapshot;
}

@end