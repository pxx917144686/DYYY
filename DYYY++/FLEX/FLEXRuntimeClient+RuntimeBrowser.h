#import "FLEXRuntimeClient.h"

@interface FLEXRuntimeClient (RuntimeBrowser)

// 移植 RTBRuntime 的功能
- (NSMutableDictionary *)allClassStubsByName;
- (NSMutableDictionary *)allClassStubsByImagePath;
- (NSMutableArray *)rootClasses;
- (void)readAllRuntimeClasses;
- (NSArray *)sortedClassStubs;
- (void)emptyCachesAndReadAllRuntimeClasses;

// 移植类分析功能
- (NSDictionary *)getDetailedClassInfo:(Class)cls;
- (NSString *)generateHeaderForClass:(Class)cls;
- (NSArray *)getAllInstancesOfClass:(Class)cls;
- (NSUInteger)getInstanceCountForClass:(Class)cls;

@end