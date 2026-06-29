#import "FLEXMemoryAnalyzer+RuntimeBrowser.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXRuntimeClient.h"
#import <mach/mach.h>
#import <malloc/malloc.h>
#import <objc/runtime.h>

@implementation FLEXMemoryAnalyzer (RuntimeBrowser)

- (NSDictionary *)getDetailedHeapSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    
    // 获取内存使用统计
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    snapshot[@"residentSize"] = @(info.resident_size);
    snapshot[@"virtualSize"] = @(info.virtual_size);
    
    snapshot[@"memoryZones"] = [self getDetailedMemoryZoneInfo];
    
    // 获取类实例分布
    snapshot[@"instanceDistribution"] = [self getClassInstanceDistribution];
    
    // 检测可能的内存泄漏
    snapshot[@"potentialLeaks"] = [self findMemoryLeaks];
    
    // 获取 malloc 统计信息
    malloc_statistics_t stats;
    malloc_zone_statistics(NULL, &stats);
    
    snapshot[@"mallocStats"] = @{
        @"blocksInUse": @(stats.blocks_in_use),
        @"sizeInUse": @(stats.size_in_use),
        @"maxSizeInUse": @(stats.max_size_in_use),
        @"sizeAllocated": @(stats.size_allocated)
    };
    
    return snapshot;
}

- (NSArray *)getDetailedMemoryZoneInfo {
    NSMutableArray *zones = [NSMutableArray array];
    
    vm_address_t *zone_addresses = NULL;
    unsigned int zone_count = 0;
    
    kern_return_t kr = malloc_get_all_zones(mach_task_self(), NULL, &zone_addresses, &zone_count);
    
    if (kr == KERN_SUCCESS) {
        for (unsigned int i = 0; i < zone_count; i++) {
            malloc_zone_t *zone = (malloc_zone_t *)zone_addresses[i];
            if (zone && zone->zone_name) {
                malloc_statistics_t stats;
                malloc_zone_statistics(zone, &stats);
                
                [zones addObject:@{
                    @"name": @(zone->zone_name),
                    @"blocksInUse": @(stats.blocks_in_use),
                    @"sizeInUse": @(stats.size_in_use),
                    @"sizeAllocated": @(stats.size_allocated)
                }];
            }
        }
    }
    
    return zones;
}

- (NSDictionary *)getClassInstanceDistribution {
    NSMutableDictionary *distribution = [NSMutableDictionary dictionary];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        
        // 获取实例数量（简化版本）
        NSUInteger instanceCount = [self getInstanceCountForClass:cls];
        if (instanceCount > 0) {
            distribution[className] = @{
                @"count": @(instanceCount),
                @"instanceSize": @(class_getInstanceSize(cls))
            };
        }
    }
    
    free(classes);
    return distribution;
}

- (NSArray *)findMemoryLeaks {
    // 简化的内存泄漏检测逻辑
    NSMutableArray *potentialLeaks = [NSMutableArray array];
    
    // 这里可以实现更复杂的泄漏检测算法
    // 目前返回空数组作为占位符
    
    return potentialLeaks;
}

@end