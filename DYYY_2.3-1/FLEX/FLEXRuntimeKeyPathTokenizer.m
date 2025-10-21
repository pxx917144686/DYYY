//
//  FLEXRuntimeKeyPathTokenizer.m
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett. 保留所有权利。
//

#import "FLEXRuntimeKeyPathTokenizer.h"

#define TBCountOfStringOccurence(target, str) ([target componentsSeparatedByString:str].count - 1)

@implementation FLEXRuntimeKeyPathTokenizer

#pragma mark 初始化

static NSCharacterSet *firstAllowed      = nil;
static NSCharacterSet *identifierAllowed = nil;
static NSCharacterSet *filenameAllowed   = nil;
static NSCharacterSet *keyPathDisallowed = nil;
static NSCharacterSet *methodAllowed     = nil;
+ (void)initialize {
    if (self == [self class]) {
        NSString *_methodFirstAllowed    = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$";
        NSString *_identifierAllowed     = [_methodFirstAllowed stringByAppendingString:@"1234567890"];
        NSString *_methodAllowedSansType = [_identifierAllowed stringByAppendingString:@":"];
        NSString *_filenameNameAllowed   = [_identifierAllowed stringByAppendingString:@"-+?!"];
        firstAllowed      = [NSCharacterSet characterSetWithCharactersInString:_methodFirstAllowed];
        identifierAllowed = [NSCharacterSet characterSetWithCharactersInString:_identifierAllowed];
        filenameAllowed   = [NSCharacterSet characterSetWithCharactersInString:_filenameNameAllowed];
        methodAllowed     = [NSCharacterSet characterSetWithCharactersInString:_methodAllowedSansType];

        NSString *_kpDisallowed = [_identifierAllowed stringByAppendingString:@"-+:\\.*"];
        keyPathDisallowed = [NSCharacterSet characterSetWithCharactersInString:_kpDisallowed].invertedSet;
    }
}

#pragma mark 公共方法

+ (FLEXRuntimeKeyPath *)tokenizeString:(NSString *)userInput {
    if (!userInput.length) {
        return nil;
    }

    NSUInteger tokens = [self tokenCountOfString:userInput];
    if (tokens == 0) {
        return nil;
    }

    if ([userInput containsString:@"**"]) {
        @throw NSInternalInconsistencyException;
    }

    NSNumber *instance = nil;
    NSScanner *scanner = [NSScanner scannerWithString:userInput];
    FLEXSearchToken *bundle    = [self scanToken:scanner allowed:filenameAllowed first:filenameAllowed];
    FLEXSearchToken *cls       = [self scanToken:scanner allowed:identifierAllowed first:firstAllowed];
    FLEXSearchToken *method    = tokens > 2 ? [self scanMethodToken:scanner instance:&instance] : nil;

    return [FLEXRuntimeKeyPath bundle:bundle
                       class:cls
                      method:method
                  isInstance:instance
                      string:userInput];
}

+ (BOOL)allowedInKeyPath:(NSString *)text {
    if (!text.length) {
        return YES;
    }
    
    return [text rangeOfCharacterFromSet:keyPathDisallowed].location == NSNotFound;
}

#pragma mark 私有方法

+ (NSUInteger)tokenCountOfString:(NSString *)userInput {
    NSUInteger escapedCount = TBCountOfStringOccurence(userInput, @"\\.");
    NSUInteger tokenCount  = TBCountOfStringOccurence(userInput, @".") - escapedCount + 1;

    return tokenCount;
}

+ (FLEXSearchToken *)scanToken:(NSScanner *)scanner allowed:(NSCharacterSet *)allowedChars first:(NSCharacterSet *)first {
    if (scanner.isAtEnd) {
        if ([scanner.string hasSuffix:@"."] && ![scanner.string hasSuffix:@"\\."]) {
            return [FLEXSearchToken string:nil options:TBWildcardOptionsAny];
        }
        return nil;
    }

    TBWildcardOptions options = TBWildcardOptionsNone;
    NSMutableString *token = [NSMutableString new];

    // 令牌不能以'.'开头
    if ([scanner scanString:@"." intoString:nil]) {
        @throw NSInternalInconsistencyException;
    }

    if ([scanner scanString:@"*." intoString:nil]) {
        return [FLEXSearchToken string:nil options:TBWildcardOptionsAny];
    } else if ([scanner scanString:@"*" intoString:nil]) {
        if (scanner.isAtEnd) {
            return FLEXSearchToken.any;
        }
        
        options |= TBWildcardOptionsPrefix;
    }

    NSString *tmp = nil;
    BOOL stop = NO, didScanDelimiter = NO, didScanFirstAllowed = NO;
    NSCharacterSet *disallowed = allowedChars.invertedSet;
    while (!stop && ![scanner scanString:@"." intoString:&tmp] && !scanner.isAtEnd) {
        // 扫描单词字符
        // 在这个块中，我们还没有扫描任何内容，除了可能的前导'\'或'\.'
        if (!didScanFirstAllowed) {
            if ([scanner scanCharactersFromSet:first intoString:&tmp]) {
                [token appendString:tmp];
                didScanFirstAllowed = YES;
            } else if ([scanner scanString:@"\\" intoString:nil]) {
                if (options == TBWildcardOptionsPrefix && [scanner scanString:@"." intoString:nil]) {
                    [token appendString:@"."];
                } else if (scanner.isAtEnd && options == TBWildcardOptionsPrefix) {
                    // 只有在前缀为'*'时才允许独立的'\'
                    return FLEXSearchToken.any;
                } else {
                    // 令牌以数字、句点或其他不允许的内容开头，
                    // 或者令牌是没有'*'前缀的独立'\'
                    @throw NSInternalInconsistencyException;
                }
            } else {
                // 令牌以数字、句点或其他不允许的内容开头
                @throw NSInternalInconsistencyException;
            }
        } else if ([scanner scanCharactersFromSet:allowedChars intoString:&tmp]) {
            [token appendString:tmp];
        }
        // 扫描'\.'或尾随'\'
        else if ([scanner scanString:@"\\" intoString:nil]) {
            if ([scanner scanString:@"." intoString:nil]) {
                [token appendString:@"."];
            } else if (scanner.isAtEnd) {
                // 如果在末尾，忽略不后跟句点的正斜杠
                return [FLEXSearchToken string:token options:options | TBWildcardOptionsSuffix];
            } else {
                // 只有句点可以跟在正斜杠后面
                @throw NSInternalInconsistencyException;
            }
        }
        // 扫描'*.'
        else if ([scanner scanString:@"*." intoString:nil]) {
            options |= TBWildcardOptionsSuffix;
            stop = YES;
            didScanDelimiter = YES;
        }
        // 扫描不后跟.的'*'
        else if ([scanner scanString:@"*" intoString:nil]) {
            if (!scanner.isAtEnd) {
                // 无效令牌，令牌中间有通配符
                @throw NSInternalInconsistencyException;
            }
        } else if ([scanner scanCharactersFromSet:disallowed intoString:nil]) {
            // 无效令牌，无效字符
            @throw NSInternalInconsistencyException;
        }
    }

    // 我们是否扫描了一个尾随的、未转义的'.'？
    if ([tmp isEqualToString:@"."]) {
        didScanDelimiter = YES;
    }

    if (!didScanDelimiter) {
        options |= TBWildcardOptionsSuffix;
    }

    return [FLEXSearchToken string:token options:options];
}

+ (FLEXSearchToken *)scanMethodToken:(NSScanner *)scanner instance:(NSNumber **)instance {
    if (scanner.isAtEnd) {
        if ([scanner.string hasSuffix:@"."]) {
            return [FLEXSearchToken string:nil options:TBWildcardOptionsAny];
        }
        return nil;
    }

    if ([scanner.string hasSuffix:@"."] && ![scanner.string hasSuffix:@"\\."]) {
        // 方法不能以'.'结尾，除了'\.'
        @throw NSInternalInconsistencyException;
    }
    
    if ([scanner scanString:@"-" intoString:nil]) {
        *instance = @YES;
    } else if ([scanner scanString:@"+" intoString:nil]) {
        *instance = @NO;
    } else {
        if ([scanner scanString:@"*" intoString:nil]) {
            // 只是检查...它必须以这三个之一开头！
            scanner.scanLocation--;
        } else {
            @throw NSInternalInconsistencyException;
        }
    }

    // -*foo 不允许
    if (*instance && [scanner scanString:@"*" intoString:nil]) {
        @throw NSInternalInconsistencyException;
    }

    if (scanner.isAtEnd) {
        return [FLEXSearchToken string:@"" options:TBWildcardOptionsSuffix];
    }

    return [self scanToken:scanner allowed:methodAllowed first:firstAllowed];
}

@end
