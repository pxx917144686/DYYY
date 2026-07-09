#import <Foundation/Foundation.h>

@class DYYYRTBSearchToken;

@interface DYYYRTBRuntimeController : NSObject

+ (instancetype)sharedController;

- (NSArray *)allBundleNames;
- (NSArray *)classesForToken:(DYYYRTBSearchToken *)token inBundles:(NSArray *)bundles;

@end