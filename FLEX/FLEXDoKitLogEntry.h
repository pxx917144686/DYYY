#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLEXDoKitLogLevel) {
    FLEXDoKitLogLevelVerbose = 0,
    FLEXDoKitLogLevelDebug = 1,
    FLEXDoKitLogLevelInfo = 2,
    FLEXDoKitLogLevelWarning = 3,
    FLEXDoKitLogLevelError = 4
};

@interface FLEXDoKitLogEntry : NSObject

@property (nonatomic, strong) NSString *message;
@property (nonatomic, assign) FLEXDoKitLogLevel level;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSString *category;

@property (nonatomic, strong) NSString *tag;
@property (nonatomic, strong) NSString *file;
@property (nonatomic, assign) NSUInteger line;

+ (instancetype)entryWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level;

@end

NS_ASSUME_NONNULL_END