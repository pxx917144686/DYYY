// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntime+Compare.m
//  FLEX
//
//  由 Tanner Bennett 创建于 8/28/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXRuntime+Compare.h"

@implementation FLEXProperty (Compare)

- (NSComparisonResult)compare:(FLEXProperty *)other {
    NSComparisonResult r = [self.name caseInsensitiveCompare:other.name];
    if (r == NSOrderedSame) {
        // TODO: 确保空图像名称排在图像名称之前
        return [self.imageName ?: @"" compare:other.imageName];
    }

    return r;
}

@end

@implementation FLEXIvar (Compare)

- (NSComparisonResult)compare:(FLEXIvar *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

@end

@implementation FLEXMethodBase (Compare)

- (NSComparisonResult)compare:(FLEXMethodBase *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

@end

@implementation FLEXProtocol (Compare)

- (NSComparisonResult)compare:(FLEXProtocol *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

@end
