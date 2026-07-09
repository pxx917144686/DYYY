#import <Foundation/Foundation.h>

@interface DYYYRTBSearchToken : NSObject

@property (nonatomic, strong) NSString *string;

+ (instancetype)any;
+ (instancetype)tokenWithString:(NSString *)string;

- (BOOL)matchesString:(NSString *)string;

@end