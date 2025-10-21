//
//  FLEXMemoryAnalyzer.h
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXMemoryAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;

// 获取类的所有实例
- (NSArray *)getAllInstancesOfClass:(Class)cls;

// 获取类的实例数量
- (NSUInteger)getInstanceCountForClass:(Class)cls;

// 内存快照
- (NSDictionary *)getHeapSnapshot;

// 获取所有类的内存使用情况
- (NSDictionary *)getAllClassesMemoryUsage;

@end

NS_ASSUME_NONNULL_END