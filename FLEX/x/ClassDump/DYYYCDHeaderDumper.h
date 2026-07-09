#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CDDumpProgressBlock)(CGFloat progress, NSString *text);
typedef void (^CDDumpCompletionBlock)(NSURL *_Nullable zipURL, NSError *_Nullable error);

@interface DYYYCDClassInfo : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *superClassName;
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, copy) NSString *imagePath;
@property (nonatomic, assign) NSUInteger instanceSize;
@property (nonatomic, assign) BOOL isMetaClass;
@property (nonatomic, assign) BOOL isKVOClass;
@property (nonatomic, strong) NSArray<NSString *> *protocols;
@property (nonatomic, strong) NSArray<NSDictionary *> *properties;
@property (nonatomic, strong) NSArray<NSDictionary *> *instanceMethods;
@property (nonatomic, strong) NSArray<NSDictionary *> *classMethods;
@property (nonatomic, strong) NSArray<NSDictionary *> *ivars;
@property (nonatomic, strong) NSArray<NSString *> *inheritanceChain;
+ (instancetype)infoForClass:(Class)cls;
@end

@interface DYYYCDHeaderDumper : NSObject

+ (void)dumpHeadersZipWithProgress:(CDDumpProgressBlock)progress
                        completion:(CDDumpCompletionBlock)completion;

+ (nullable NSString *)headerForClassName:(NSString *)className;

+ (nullable Class)classForName:(NSString *)className;

+ (nullable DYYYCDClassInfo *)classInfoForName:(NSString *)className;

+ (NSArray<NSDictionary *> *)allClassNamesByImage;

+ (NSArray<NSString *> *)allClassNames;

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword;

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword prefixMatch:(BOOL)prefixMatch;

+ (NSArray<NSString *> *)recentClassNames;

+ (void)addToRecentClasses:(NSString *)className;

+ (NSArray<NSString *> *)inheritanceChainForClass:(NSString *)className;

+ (nullable NSString *)protocolHeaderForName:(NSString *)protocolName;

+ (NSArray<NSString *> *)allProtocolNames;

@end

NS_ASSUME_NONNULL_END
