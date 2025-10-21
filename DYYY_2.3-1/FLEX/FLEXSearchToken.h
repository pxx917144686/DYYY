//
//  FLEXSearchToken.h
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett. 保留所有权利。
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, TBWildcardOptions) {
    TBWildcardOptionsNone   = 0,
    TBWildcardOptionsAny    = 1,
    TBWildcardOptionsPrefix = 1 << 1,
    TBWildcardOptionsSuffix = 1 << 2,
};

/// 令牌可能在一端或两端包含通配符，
/// 但目前不能在令牌的中间包含通配符。
@interface FLEXSearchToken : NSObject

+ (instancetype)any;
+ (instancetype)string:(NSString *)string options:(TBWildcardOptions)options;

/// 不会包含通配符（*）符号
@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) TBWildcardOptions options;

/// 与"模糊"相反
@property (nonatomic, readonly) BOOL isAbsolute;
@property (nonatomic, readonly) BOOL isAny;
/// 仍然是 \c isAny，但检查字符串是否为空
@property (nonatomic, readonly) BOOL isEmpty;

@end
