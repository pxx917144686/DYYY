#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYUCAppGroupHelper : NSObject

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)accessibleAppGroups;
+ (NSArray<NSString *> *)accessibleAppGroupPaths;

@end

NS_ASSUME_NONNULL_END
