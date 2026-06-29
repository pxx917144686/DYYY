#import <Foundation/Foundation.h>

@class RTBSearchToken;

@interface RTBRuntimeController : NSObject

+ (instancetype)sharedController;

- (NSArray *)allBundleNames;
- (NSArray *)classesForToken:(RTBSearchToken *)token inBundles:(NSArray *)bundles;

@end