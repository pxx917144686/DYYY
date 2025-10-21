//
//  FLEXObjcInternal.h
//  FLEX
//
//  Created by Tanner Bennett on 11/1/18.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// 下面的宏直接来源于以下文件，基本上保持原样：
// objc-internal.h, objc-private.h, objc-object.h, 和 objc-config.h
// 尽可能少地进行修改。更改内容在方框注释中注明。
// https://opensource.apple.com/source/objc4/objc4-723/
// https://opensource.apple.com/source/objc4/objc4-723/runtime/objc-internal.h.auto.html
// https://opensource.apple.com/source/objc4/objc4-723/runtime/objc-object.h.auto.html

/////////////////////
// objc-internal.h //
/////////////////////

#if __LP64__
#define OBJC_HAVE_TAGGED_POINTERS 1
#endif

#if OBJC_HAVE_TAGGED_POINTERS

#if TARGET_OS_OSX && __x86_64__
// 64位 Mac - 标记位是LSB
#   define OBJC_MSB_TAGGED_POINTERS 0
#else
// 其他情况 - 标记位是MSB
#   define OBJC_MSB_TAGGED_POINTERS 1
#endif

#if OBJC_MSB_TAGGED_POINTERS
#   define _OBJC_TAG_MASK (1UL<<63)
#   define _OBJC_TAG_EXT_MASK (0xfUL<<60)
#else
#   define _OBJC_TAG_MASK 1UL
#   define _OBJC_TAG_EXT_MASK 0xfUL
#endif

#endif // OBJC_HAVE_TAGGED_POINTERS

//////////////////////////////////////
// 原为 _objc_isTaggedPointer //
//////////////////////////////////////
NS_INLINE BOOL flex_isTaggedPointer(const void *ptr)  {
    #if OBJC_HAVE_TAGGED_POINTERS
        return ((uintptr_t)ptr & _OBJC_TAG_MASK) == _OBJC_TAG_MASK;
    #else
        return NO;
    #endif
}

#define FLEXPointerIsTaggedPointer(obj) flex_isTaggedPointer((__bridge void *)obj)

/// 判断给定的指针是否是有效的、可读的地址。
BOOL FLEXPointerIsReadable(const void * ptr);

/// @brief 假设内存是有效且可读的。
/// @discussion objc-internal.h, objc-private.h, 和 objc-config.h
/// https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
/// https://llvm.org/svn/llvm-project/lldb/trunk/examples/summaries/cocoa/objc_runtime.py
/// https://blog.timac.org/2016/1124/testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
BOOL FLEXPointerIsValidObjcObject(const void * ptr);

#ifdef __cplusplus
}
#endif
