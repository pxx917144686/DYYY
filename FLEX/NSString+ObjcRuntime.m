// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSString+ObjcRuntime.m
//  FLEX
//
//  源自 MirrorKit。
//  由 Tanner 创建于 7/1/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "NSString+ObjcRuntime.h"
#import "FLEXRuntimeUtility.h"

@implementation NSString (Utilities)

- (NSString *)stringbyDeletingCharacterAtIndex:(NSUInteger)idx {
    NSMutableString *string = self.mutableCopy;
    [string replaceCharactersInRange:NSMakeRange(idx, 1) withString:@""];
    return string;
}

/// 关于如何构造正确的属性字符串，请参阅此链接：
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
- (NSDictionary *)propertyAttributes {
    if (!self.length) return nil;
    
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    
    NSArray *components = [self componentsSeparatedByString:@","];
    for (NSString *attribute in components) {
        FLEXPropertyAttribute c = (FLEXPropertyAttribute)[attribute characterAtIndex:0];
        switch (c) {
            case FLEXPropertyAttributeTypeEncoding:
                // 注意：此处的类型编码并非总是正确。Radar：FB7499230
                attributes[kFLEXPropertyAttributeKeyTypeEncoding] = [attribute stringbyDeletingCharacterAtIndex:0];
                break;
            case FLEXPropertyAttributeBackingIvarName:
                attributes[kFLEXPropertyAttributeKeyBackingIvarName] = [attribute stringbyDeletingCharacterAtIndex:0];
                break;
            case FLEXPropertyAttributeCopy:
                attributes[kFLEXPropertyAttributeKeyCopy] = @YES;
                break;
            case FLEXPropertyAttributeCustomGetter:
                attributes[kFLEXPropertyAttributeKeyCustomGetter] = [attribute stringbyDeletingCharacterAtIndex:0];
                break;
            case FLEXPropertyAttributeCustomSetter:
                attributes[kFLEXPropertyAttributeKeyCustomSetter] = [attribute stringbyDeletingCharacterAtIndex:0];
                break;
            case FLEXPropertyAttributeDynamic:
                attributes[kFLEXPropertyAttributeKeyDynamic] = @YES;
                break;
            case FLEXPropertyAttributeGarbageCollectible:
                attributes[kFLEXPropertyAttributeKeyGarbageCollectable] = @YES;
                break;
            case FLEXPropertyAttributeNonAtomic:
                attributes[kFLEXPropertyAttributeKeyNonAtomic] = @YES;
                break;
            case FLEXPropertyAttributeOldTypeEncoding:
                attributes[kFLEXPropertyAttributeKeyOldStyleTypeEncoding] = [attribute stringbyDeletingCharacterAtIndex:0];
                break;
            case FLEXPropertyAttributeReadOnly:
                attributes[kFLEXPropertyAttributeKeyReadOnly] = @YES;
                break;
            case FLEXPropertyAttributeRetain:
                attributes[kFLEXPropertyAttributeKeyRetain] = @YES;
                break;
            case FLEXPropertyAttributeWeak:
                attributes[kFLEXPropertyAttributeKeyWeak] = @YES;
                break;
        }
    }

    return attributes;
}

@end
