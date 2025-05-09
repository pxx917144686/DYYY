//
//  NSString+FLEX.m
//  FLEX
//
//  由 Tanner 创建于 3/26/17.
//  版权所有 © 2017 Tanner Bennett. 保留所有权利。
//

#import "NSString+FLEX.h"

@interface NSMutableString (Replacement)
- (void)replaceOccurencesOfString:(NSString *)string with:(NSString *)replacement;
- (void)removeLastKeyPathComponent;
@end

@implementation NSMutableString (Replacement)

- (void)replaceOccurencesOfString:(NSString *)string with:(NSString *)replacement {
    [self replaceOccurrencesOfString:string withString:replacement options:0 range:NSMakeRange(0, self.length)];
}

- (void)removeLastKeyPathComponent {
    if (![self containsString:@"."]) {
        [self deleteCharactersInRange:NSMakeRange(0, self.length)];
        return;
    }

    BOOL putEscapesBack = NO;
    if ([self containsString:@"\\."]) {
        [self replaceOccurencesOfString:@"\\." with:@"\\~"];

        // 像 "UIKit\.framework" 这样的情况
        if (![self containsString:@"."]) {
            [self deleteCharactersInRange:NSMakeRange(0, self.length)];
            return;
        }

        putEscapesBack = YES;
    }

    // 像 "Bund" 或 "Bundle.cla" 这样的情况
    if (![self hasSuffix:@"."]) {
        NSUInteger len = self.pathExtension.length;
        [self deleteCharactersInRange:NSMakeRange(self.length-len, len)];
    }

    if (putEscapesBack) {
        [self replaceOccurencesOfString:@"\\~" with:@"\\."];
    }
}

@end

@implementation NSString (FLEXTypeEncoding)

- (NSCharacterSet *)flex_classNameAllowedCharactersSet {
    static NSCharacterSet *classNameAllowedCharactersSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *temp = NSMutableCharacterSet.alphanumericCharacterSet;
        [temp addCharactersInString:@"_"];
        classNameAllowedCharactersSet = temp.copy;
    });
    
    return classNameAllowedCharactersSet;
}

- (BOOL)flex_typeIsConst {
    if (!self.length) return NO;
    return [self characterAtIndex:0] == FLEXTypeEncodingConst;
}

- (FLEXTypeEncoding)flex_firstNonConstType {
    if (!self.length) return FLEXTypeEncodingNull;
    return [self characterAtIndex:(self.flex_typeIsConst ? 1 : 0)];
}

- (FLEXTypeEncoding)flex_pointeeType {
    if (!self.length) return FLEXTypeEncodingNull;
    
    if (self.flex_firstNonConstType == FLEXTypeEncodingPointer) {
        return [self characterAtIndex:(self.flex_typeIsConst ? 2 : 1)];
    }
    
    return FLEXTypeEncodingNull;
}

- (BOOL)flex_typeIsObjectOrClass {
    FLEXTypeEncoding type = self.flex_firstNonConstType;
    return type == FLEXTypeEncodingObjcObject || type == FLEXTypeEncodingObjcClass;
}

- (Class)flex_typeClass {
    if (!self.flex_typeIsObjectOrClass) {
        return nil;
    }
    
    NSScanner *scan = [NSScanner scannerWithString:self];
    // 跳过 const
    [scan scanString:@"r" intoString:nil];
    // 扫描开头的 @"
    if (![scan scanString:@"@\"" intoString:nil]) {
        return nil;
    }
    
    // 扫描类名
    NSString *name = nil;
    if (![scan scanCharactersFromSet:self.flex_classNameAllowedCharactersSet intoString:&name]) {
        return nil;
    }
    // 扫描结尾的引号
    if (![scan scanString:@"\"" intoString:nil]) {
        return nil;
    }
    
    // 返回找到的类
    return NSClassFromString(name);
}

- (BOOL)flex_typeIsNonObjcPointer {
    FLEXTypeEncoding type = self.flex_firstNonConstType;
    return type == FLEXTypeEncodingPointer ||
           type == FLEXTypeEncodingCString ||
           type == FLEXTypeEncodingSelector;
}

@end

@implementation NSString (KeyPaths)

- (NSString *)flex_stringByRemovingLastKeyPathComponent {
    if (![self containsString:@"."]) {
        return @"";
    }

    NSMutableString *mself = self.mutableCopy;
    [mself removeLastKeyPathComponent];
    return mself;
}

- (NSString *)flex_stringByReplacingLastKeyPathComponent:(NSString *)replacement {
    // 替换内容不应该有任何转义的'.'，
    // 所以我们转义所有的'.'
    if ([replacement containsString:@"."]) {
        replacement = [replacement stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    }

    // 像 "Foo" 这样的情况
    if (![self containsString:@"."]) {
        return [replacement stringByAppendingString:@"."];
    }

    NSMutableString *mself = self.mutableCopy;
    [mself removeLastKeyPathComponent];
    [mself appendString:replacement];
    [mself appendString:@"."];
    return mself;
}

@end
