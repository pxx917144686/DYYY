// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeKeyPathTokenizer.m
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett。保留所有权利。
//

#import "FLEXRuntimeKeyPathTokenizer.h"

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

#pragma mark 公开方法

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
    // 计算转义句点的数量
    NSUInteger escapedCount = [[userInput componentsSeparatedByString:@"\\."] count] - 1;
    // 用占位符替换转义句点
    userInput = [userInput stringByReplacingOccurrencesOfString:@"\\." withString:@"FLEXPeriodPlaceholder"];
    // 按未转义句点分割
    NSUInteger tokenCount = [[userInput componentsSeparatedByString:@"."] count] - escapedCount;

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

    // 标记不能以 '.' 开头
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
        // 在此块中，我们尚未扫描任何内容，除了可能的前导 '\' 或 '\.'
        if (!didScanFirstAllowed) {
            if ([scanner scanCharactersFromSet:first intoString:&tmp]) {
                [token appendString:tmp];
                didScanFirstAllowed = YES;
            } else if ([scanner scanString:@"\\" intoString:nil]) {
                if (options == TBWildcardOptionsPrefix && [scanner scanString:@"." intoString:nil]) {
                    [token appendString:@"."];
                } else if (scanner.isAtEnd && options == TBWildcardOptionsPrefix) {
                    // 仅当以 '*' 为前缀时才允许独立的 '\'
                    return FLEXSearchToken.any;
                } else {
                    // 标记以数字、句点或其他不允许的字符开头，
                    // 或者标记是独立的 '\' 且没有 '*' 前缀
                    @throw NSInternalInconsistencyException;
                }
            } else {
                // 标记以数字、句点或其他不允许的字符开头
                @throw NSInternalInconsistencyException;
            }
        } else if ([scanner scanCharactersFromSet:allowedChars intoString:&tmp]) {
            [token appendString:tmp];
        }
        // 扫描 '\.' 或尾随的 '\'
        else if ([scanner scanString:@"\\" intoString:nil]) {
            if ([scanner scanString:@"." intoString:nil]) {
                [token appendString:@"."];
            } else if (scanner.isAtEnd) {
                // 如果在末尾，忽略后面没有句点的反斜杠
                return [FLEXSearchToken string:token options:options | TBWildcardOptionsSuffix];
            } else {
                // 只有句点可以跟在反斜杠后面
                @throw NSInternalInconsistencyException;
            }
        }
        // 扫描 '*.'
        else if ([scanner scanString:@"*." intoString:nil]) {
            options |= TBWildcardOptionsSuffix;
            stop = YES;
            didScanDelimiter = YES;
        }
        // 扫描后面没有 . 的 '*'
        else if ([scanner scanString:@"*" intoString:nil]) {
            if (!scanner.isAtEnd) {
                // 无效标记，通配符在标记中间
                @throw NSInternalInconsistencyException;
            }
        } else if ([scanner scanCharactersFromSet:disallowed intoString:nil]) {
            // 无效标记，包含无效字符
            @throw NSInternalInconsistencyException;
        }
    }

    // 我们是否扫描到了尾随的、未转义的 '.'？
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
        // 方法不能以 '.' 结尾，除非是 '\.'
        @throw NSInternalInconsistencyException;
    }
    
    if ([scanner scanString:@"-" intoString:nil]) {
        *instance = @YES;
    } else if ([scanner scanString:@"+" intoString:nil]) {
        *instance = @NO;
    } else {
        if ([scanner scanString:@"*" intoString:nil]) {
            // 只是检查一下……它必须以这三个字符之一开头！
            scanner.scanLocation--;
        } else {
            @throw NSInternalInconsistencyException;
        }
    }

    // 不允许 -*foo
    if (*instance && [scanner scanString:@"*" intoString:nil]) {
        @throw NSInternalInconsistencyException;
    }

    if (scanner.isAtEnd) {
        return [FLEXSearchToken string:@"" options:TBWildcardOptionsSuffix];
    }

    return [self scanToken:scanner allowed:methodAllowed first:firstAllowed];
}

@end
