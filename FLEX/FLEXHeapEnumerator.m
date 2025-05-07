//
//  FLEXHeapEnumerator.m
//  Flipboard
//
//  Created by Ryan Olson on 5/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXHeapEnumerator.h"
#import "FLEXObjcInternal.h"
#import "FLEXObjectRef.h"
#import "NSObject+FLEX_Reflection.h"
#import "NSString+FLEX.h"
#import <malloc/malloc.h>
#import <mach/mach.h>
#import <objc/runtime.h>

static CFMutableSetRef registeredClasses;

// 模拟Objective-C对象结构，用于检查内存范围是否为对象
typedef struct {
    Class isa;
} flex_maybe_object_t;

@implementation FLEXHeapSnapshot
+ (instancetype)snapshotWithCounts:(NSDictionary<NSString *, NSNumber *> *)counts
                             sizes:(NSDictionary<NSString *, NSNumber *> *)sizes {
    FLEXHeapSnapshot *snapshot = [FLEXHeapSnapshot new];
    snapshot->_classNames = counts.allKeys;
    snapshot->_instanceCountsForClassNames = counts;
    snapshot->_instanceSizesForClassNames = sizes;
    
    return snapshot;
}
@end

@implementation FLEXHeapEnumerator

static void range_callback(task_t task, void *context, unsigned type, vm_range_t *ranges, unsigned rangeCount) {
    if (!context) {
        return;
    }
    
    for (unsigned int i = 0; i < rangeCount; i++) {
        vm_range_t range = ranges[i];
        flex_maybe_object_t *tryObject = (flex_maybe_object_t *)range.address;
        Class tryClass = NULL;
#ifdef __arm64__
        // 参见 http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html
        extern uint64_t objc_debug_isa_class_mask WEAK_IMPORT_ATTRIBUTE;
        tryClass = (__bridge Class)((void *)((uint64_t)tryObject->isa & objc_debug_isa_class_mask));
#else
        tryClass = tryObject->isa;
#endif
        // 如果类指针与运行时中我们的类指针集合中的一个匹配，那么我们应该有一个对象
        if (CFSetContainsValue(registeredClasses, (__bridge const void *)(tryClass))) {
            (*(flex_object_enumeration_block_t __unsafe_unretained *)context)((__bridge id)tryObject, tryClass);
        }
    }
}

static kern_return_t reader(__unused task_t remote_task, vm_address_t remote_address, __unused vm_size_t size, void **local_memory) {
    *local_memory = (void *)remote_address;
    return KERN_SUCCESS;
}

+ (void)enumerateLiveObjectsUsingBlock:(flex_object_enumeration_block_t)block {
    if (!block) {
        return;
    }
    
    // 每次调用时刷新类列表，以防有新类添加到运行时
    [self updateRegisteredClasses];
    
    // 灵感来源：
    // https://llvm.org/svn/llvm-project/lldb/tags/RELEASE_34/final/examples/darwin/heap_find/heap/heap_find.cpp
    // https://gist.github.com/samdmarshall/17f4e66b5e2e579fd396
    
    vm_address_t *zones = NULL;
    unsigned int zoneCount = 0;
    kern_return_t result = malloc_get_all_zones(TASK_NULL, reader, &zones, &zoneCount);
    
    if (result == KERN_SUCCESS) {
        for (unsigned int i = 0; i < zoneCount; i++) {
            malloc_zone_t *zone = (malloc_zone_t *)zones[i];
            malloc_introspection_t *introspection = zone->introspect;

            // 这可能解释了为什么某些区域函数有时无效；也许不是所有区域都支持它们？
            if (!introspection) {
                continue;
            }

            void (*lock_zone)(malloc_zone_t *zone)   = introspection->force_lock;
            void (*unlock_zone)(malloc_zone_t *zone) = introspection->force_unlock;

            // 回调必须解锁区域，这样我们才能在给定的块内自由分配内存
            flex_object_enumeration_block_t callback = ^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
                unlock_zone(zone);
                block(object, actualClass);
                lock_zone(zone);
            };
            
            BOOL lockZoneValid = FLEXPointerIsReadable(lock_zone);
            BOOL unlockZoneValid =  FLEXPointerIsReadable(unlock_zone);

            // 关于这些函数指针何时以及为何可能为NULL或垃圾的文档很少，
            // 所以我们采用检查NULL以及指针是否可读的方法
            if (introspection->enumerator && lockZoneValid && unlockZoneValid) {
                lock_zone(zone);
                introspection->enumerator(TASK_NULL, (void *)&callback, MALLOC_PTR_IN_USE_RANGE_TYPE, (vm_address_t)zone, reader, &range_callback);
                unlock_zone(zone);
            }
        }
    }
}

+ (void)updateRegisteredClasses {
    if (!registeredClasses) {
        registeredClasses = CFSetCreateMutable(NULL, 0, NULL);
    } else {
        CFSetRemoveAllValues(registeredClasses);
    }
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        CFSetAddValue(registeredClasses, (__bridge const void *)(classes[i]));
    }
    free(classes);
}

+ (NSArray<FLEXObjectRef *> *)instancesOfClassWithName:(NSString *)className retained:(BOOL)retain {
    const char *classNameCString = className.UTF8String;
    NSMutableArray *instances = [NSMutableArray new];
    [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        if (strcmp(classNameCString, class_getName(actualClass)) == 0) {
            // 注意：某些类的对象在调用retain时会崩溃。
            // 用户应避免点击这些类的实例列表。
            // 例如：OS_dispatch_queue_specific_queue
            // 将来，我们可以为已知有问题的类提供某种警告。
            if (malloc_size((__bridge const void *)(object)) > 0) {
                [instances addObject:object];
            }
        }
    }];

    NSArray<FLEXObjectRef *> *references = [FLEXObjectRef referencingAll:instances retained:retain];
    return references;
}

+ (NSArray<FLEXObjectRef *> *)objectsWithReferencesToObject:(id)object retained:(BOOL)retain {
    NSMutableArray<FLEXObjectRef *> *instances = [NSMutableArray new];
    [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id tryObject, __unsafe_unretained Class actualClass) {
        // 跳过已知无效的对象
        if (!FLEXPointerIsValidObjcObject((__bridge void *)tryObject)) {
            return;
        }
        
        // 获取对象上的所有实例变量。从类开始，沿着继承链向上移动。
        // 一旦找到匹配项，记录它并继续处理下一个对象。
        // 没有理由在同一个对象中找到多个匹配项。
        Class tryClass = actualClass;
        while (tryClass) {
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList(tryClass, &ivarCount);

            for (unsigned int ivarIndex = 0; ivarIndex < ivarCount; ivarIndex++) {
                Ivar ivar = ivars[ivarIndex];
                NSString *typeEncoding = @(ivar_getTypeEncoding(ivar) ?: "");

                if (typeEncoding.flex_typeIsObjectOrClass) {
                    ptrdiff_t offset = ivar_getOffset(ivar);
                    uintptr_t *fieldPointer = (__bridge void *)tryObject + offset;

                    if (*fieldPointer == (uintptr_t)(__bridge void *)object) {
                        NSString *ivarName = @(ivar_getName(ivar) ?: "???");
                        id ref = [FLEXObjectRef referencing:tryObject ivar:ivarName retained:retain];
                        [instances addObject:ref];
                        return;
                    }
                }
            }

            free(ivars);
            tryClass = class_getSuperclass(tryClass);
        }
    }];

    return instances;
}

+ (FLEXHeapSnapshot *)generateHeapSnapshot {
    // 设置一个CFMutableDictionary，使用类指针作为键，NSUInteger作为值。
    // 我们通过审慎的类型转换，稍微滥用了CFMutableDictionary来获取原始键，但它能完成工作。
    // 字典初始化时为每个类设置计数为0，这样在枚举期间就不必扩展。
    // 虽然使用类名字符串键到NSNumber计数的NSMutableDictionary可能更整洁，
    // 但我们选择CF/原始类型方法，因为它让我们可以枚举堆中的对象而不在枚举期间分配任何内存。
    // 在堆上为每个对象创建一个NSString/NSNumber的替代方案会严重污染活动对象的计数。
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    CFMutableDictionaryRef mutableCountsForClasses = CFDictionaryCreateMutable(NULL, classCount, NULL, NULL);
    for (unsigned int i = 0; i < classCount; i++) {
        CFDictionarySetValue(mutableCountsForClasses, (__bridge const void *)classes[i], (const void *)0);
    }
    
    // 枚举堆上的所有对象，为每个类构建实例计数
    [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class cls) {
        NSUInteger instanceCount = (NSUInteger)CFDictionaryGetValue(
            mutableCountsForClasses, (__bridge const void *)cls
        );
        instanceCount++;
        CFDictionarySetValue(
            mutableCountsForClasses, (__bridge const void *)cls, (const void *)instanceCount
        );
    }];
    
    // 将我们的CF原始字典转换为更友好的类名字符串到实例计数的映射
    NSMutableDictionary<NSString *, NSNumber *> *countsForClassNames = [NSMutableDictionary new];
    NSMutableDictionary<NSString *, NSNumber *> *sizesForClassNames = [NSMutableDictionary new];
    for (unsigned int i = 0; i < classCount; i++) {
        Class class = classes[i];
        NSUInteger instanceCount = (NSUInteger)CFDictionaryGetValue(mutableCountsForClasses, (__bridge const void *)(class));
        NSString *className = @(class_getName(class));
        
        if (instanceCount > 0) {
            countsForClassNames[className] = @(instanceCount);
            sizesForClassNames[className] = @(class_getInstanceSize(class));
        }
    }
    free(classes);
    
    return [FLEXHeapSnapshot snapshotWithCounts:countsForClassNames sizes:sizesForClassNames];
}

@end
