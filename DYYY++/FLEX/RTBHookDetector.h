#import <Foundation/Foundation.h>

@interface RTBHookDetector : NSObject

+ (instancetype)sharedDetector;

// 完整的Hook检测功能
- (NSDictionary *)getAllHookedMethods;
- (NSDictionary *)getAllSwizzledMethods;
- (NSArray *)getHookedMethodsForClass:(Class)cls;
- (BOOL)isMethodHooked:(SEL)selector inClass:(Class)cls;
- (NSArray *)getKnownHookingFrameworks;

@end