//
//  NSDictionary+ObjcRuntime.m
//  FLEX
//
//  衍生自 MirrorKit。
//  由 Tanner 创建于 7/5/15。
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "NSDictionary+ObjcRuntime.h"
#import "FLEXRuntimeUtility.h"

@implementation NSDictionary (ObjcRuntime)

/// 查看此链接了解如何构造正确的属性字符串：
/// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
- (NSString *)propertyAttributesString {
    if (!self[kFLEXPropertyAttributeKeyTypeEncoding]) return nil;
    
    NSMutableString *attributes = [NSMutableString new];
    [attributes appendFormat:@"T%@,", self[kFLEXPropertyAttributeKeyTypeEncoding]];
    
    for (NSString *attribute in self.allKeys) {
        FLEXPropertyAttribute c = (FLEXPropertyAttribute)[attribute characterAtIndex:0];
        switch (c) {
            case FLEXPropertyAttributeTypeEncoding:
                break;
            case FLEXPropertyAttributeBackingIvarName:
                [attributes appendFormat:@"%@%@,",
                    kFLEXPropertyAttributeKeyBackingIvarName,
                    self[kFLEXPropertyAttributeKeyBackingIvarName]
                ];
                break;
            case FLEXPropertyAttributeCopy:
                if ([self[kFLEXPropertyAttributeKeyCopy] boolValue])
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyCopy];
                break;
            case FLEXPropertyAttributeCustomGetter:
                [attributes appendFormat:@"%@%@,",
                    kFLEXPropertyAttributeKeyCustomGetter,
                    self[kFLEXPropertyAttributeKeyCustomGetter]
                ];
                break;
            case FLEXPropertyAttributeCustomSetter:
                [attributes appendFormat:@"%@%@,",
                    kFLEXPropertyAttributeKeyCustomSetter,
                    self[kFLEXPropertyAttributeKeyCustomSetter]
                ];
                break;
            case FLEXPropertyAttributeDynamic:
                if ([self[kFLEXPropertyAttributeKeyDynamic] boolValue])
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyDynamic];
                break;
            case FLEXPropertyAttributeGarbageCollectible:
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyGarbageCollectable];
                break;
            case FLEXPropertyAttributeNonAtomic:
                if ([self[kFLEXPropertyAttributeKeyNonAtomic] boolValue])
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyNonAtomic];
                break;
            case FLEXPropertyAttributeOldTypeEncoding:
                [attributes appendFormat:@"%@%@,",
                    kFLEXPropertyAttributeKeyOldStyleTypeEncoding,
                    self[kFLEXPropertyAttributeKeyOldStyleTypeEncoding]
                ];
                break;
            case FLEXPropertyAttributeReadOnly:
                if ([self[kFLEXPropertyAttributeKeyReadOnly] boolValue])
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyReadOnly];
                break;
            case FLEXPropertyAttributeRetain:
                if ([self[kFLEXPropertyAttributeKeyRetain] boolValue])
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyRetain];
                break;
            case FLEXPropertyAttributeWeak:
                if ([self[kFLEXPropertyAttributeKeyWeak] boolValue])
                [attributes appendFormat:@"%@,", kFLEXPropertyAttributeKeyWeak];
                break;
            default:
                return nil;
                break;
        }
    }
    
    [attributes deleteCharactersInRange:NSMakeRange(attributes.length-1, 1)];
    return attributes.copy;
}

+ (instancetype)attributesDictionaryForProperty:(objc_property_t)property {
    NSMutableDictionary *attrs = [NSMutableDictionary new];

    for (NSString *key in FLEXRuntimeUtility.allPropertyAttributeKeys) {
        char *value = property_copyAttributeValue(property, key.UTF8String);
        if (value) {
            attrs[key] = [[NSString alloc]
                initWithBytesNoCopy:value
                length:strlen(value)
                encoding:NSUTF8StringEncoding
                freeWhenDone:YES
            ];
        }
    }

    return attrs.copy;
}

@end
