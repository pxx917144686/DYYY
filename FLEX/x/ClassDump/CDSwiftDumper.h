#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CDSwiftDumpProgressBlock)(CGFloat progress, NSString *text);

@interface CDSwiftDumper : NSObject

+ (NSArray<NSString *> *)dumpSwiftInterfacesAtRootDir:(NSString *)rootDir
                                             progress:(CDSwiftDumpProgressBlock _Nullable)progress;

@end

NS_ASSUME_NONNULL_END
