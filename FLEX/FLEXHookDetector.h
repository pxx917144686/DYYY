//
//  FLEXHookDetector.h
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXHookDetector : NSObject

+ (instancetype)sharedDetector;

// 检查方法是否被Hook
- (BOOL)isMethodHooked:(Method)method ofClass:(Class)cls;

// 获取类的被Hook方法
- (NSArray *)getHookedMethodsForClass:(Class)cls;

// 获取所有被Hook的方法
- (NSDictionary *)getAllHookedMethods;

@end

NS_ASSUME_NONNULL_END