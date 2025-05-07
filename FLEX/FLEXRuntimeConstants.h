// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeConstants.h
//  FLEX
//
//  由 Tanner 创建于 3/11/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define FLEXEncodeClass(class) ("@\"" #class "\"")
#define FLEXEncodeObject(obj) (obj ? [NSString stringWithFormat:@"@\"%@\"", [obj class]].UTF8String : @encode(id))

// 参数 0 和 1 始终是 self 和 _cmd
extern const unsigned int kFLEXNumberOfImplicitArgs;

// 参见 https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6
extern NSString *const kFLEXPropertyAttributeKeyTypeEncoding;
extern NSString *const kFLEXPropertyAttributeKeyBackingIvarName;
extern NSString *const kFLEXPropertyAttributeKeyReadOnly;
extern NSString *const kFLEXPropertyAttributeKeyCopy;
extern NSString *const kFLEXPropertyAttributeKeyRetain;
extern NSString *const kFLEXPropertyAttributeKeyNonAtomic;
extern NSString *const kFLEXPropertyAttributeKeyCustomGetter;
extern NSString *const kFLEXPropertyAttributeKeyCustomSetter;
extern NSString *const kFLEXPropertyAttributeKeyDynamic;
extern NSString *const kFLEXPropertyAttributeKeyWeak;
extern NSString *const kFLEXPropertyAttributeKeyGarbageCollectable;
extern NSString *const kFLEXPropertyAttributeKeyOldStyleTypeEncoding;

typedef NS_ENUM(NSUInteger, FLEXPropertyAttribute) {
    FLEXPropertyAttributeTypeEncoding       = 'T',
    FLEXPropertyAttributeBackingIvarName    = 'V',
    FLEXPropertyAttributeCopy               = 'C',
    FLEXPropertyAttributeCustomGetter       = 'G',
    FLEXPropertyAttributeCustomSetter       = 'S',
    FLEXPropertyAttributeDynamic            = 'D',
    FLEXPropertyAttributeGarbageCollectible = 'P',
    FLEXPropertyAttributeNonAtomic          = 'N',
    FLEXPropertyAttributeOldTypeEncoding    = 't',
    FLEXPropertyAttributeReadOnly           = 'R',
    FLEXPropertyAttributeRetain             = '&',
    FLEXPropertyAttributeWeak               = 'W'
}; //NS_SWIFT_NAME(FLEX.PropertyAttribute); // FLEX属性特性

typedef NS_ENUM(char, FLEXTypeEncoding) {
    FLEXTypeEncodingNull             = '\0',
    FLEXTypeEncodingUnknown          = '?',
    FLEXTypeEncodingChar             = 'c',
    FLEXTypeEncodingInt              = 'i',
    FLEXTypeEncodingShort            = 's',
    FLEXTypeEncodingLong             = 'l',
    FLEXTypeEncodingLongLong         = 'q',
    FLEXTypeEncodingUnsignedChar     = 'C',
    FLEXTypeEncodingUnsignedInt      = 'I',
    FLEXTypeEncodingUnsignedShort    = 'S',
    FLEXTypeEncodingUnsignedLong     = 'L',
    FLEXTypeEncodingUnsignedLongLong = 'Q',
    FLEXTypeEncodingFloat            = 'f',
    FLEXTypeEncodingDouble           = 'd',
    FLEXTypeEncodingLongDouble       = 'D',
    FLEXTypeEncodingCBool            = 'B',
    FLEXTypeEncodingVoid             = 'v',
    FLEXTypeEncodingCString          = '*',
    FLEXTypeEncodingObjcObject       = '@',
    FLEXTypeEncodingObjcClass        = '#',
    FLEXTypeEncodingSelector         = ':',
    FLEXTypeEncodingArrayBegin       = '[',
    FLEXTypeEncodingArrayEnd         = ']',
    FLEXTypeEncodingStructBegin      = '{',
    FLEXTypeEncodingStructEnd        = '}',
    FLEXTypeEncodingUnionBegin       = '(',
    FLEXTypeEncodingUnionEnd         = ')',
    FLEXTypeEncodingQuote            = '\"',
    FLEXTypeEncodingBitField         = 'b',
    FLEXTypeEncodingPointer          = '^',
    FLEXTypeEncodingConst            = 'r'
}; //NS_SWIFT_NAME(FLEX.TypeEncoding); // FLEX类型编码
