#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CDHeaderDumper.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^UCClassDumpToolProgressBlock)(CGFloat progress, NSString *text);
typedef void (^UCClassDumpToolCompletionBlock)(NSURL * _Nullable zipURL, NSError * _Nullable error);

@interface UCClassDumpTool : NSObject

+ (void)dumpHeadersZipWithProgress:(UCClassDumpToolProgressBlock)progress
                        completion:(UCClassDumpToolCompletionBlock)completion;

+ (nullable NSString *)headerForClassName:(NSString *)className;

+ (nullable CDClassInfo *)classInfoForName:(NSString *)className;

+ (NSArray<NSString *> *)allClassNames;

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword;

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword prefixMatch:(BOOL)prefixMatch;

+ (NSArray<NSDictionary *> *)classNamesByImage;

+ (NSArray<NSString *> *)recentClassNames;

+ (void)addToRecentClasses:(NSString *)className;

+ (NSArray<NSString *> *)inheritanceChainForClass:(NSString *)className;

+ (nullable NSString *)protocolHeaderForName:(NSString *)protocolName;

+ (NSArray<NSString *> *)allProtocolNames;

@end

NS_ASSUME_NONNULL_END
