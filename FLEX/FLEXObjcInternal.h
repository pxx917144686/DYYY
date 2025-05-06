// 遇到问题联系中文翻译作者：pxx917144686
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

// 下面的宏直接从 objc-internal.h、objc-private.h、objc-object.h 和 objc-config.h 复制而来，
// 并尽可能少地进行了修改。更改在框注释中注明。
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
// 64 位 Mac - 标记位是 LSB（最低有效位）
#   define OBJC_MSB_TAGGED_POINTERS 0
#else
// 其他所有情况 - 标记位是 MSB（最高有效位）
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
// 最初是 _objc_isTaggedPointer //
//////////////////////////////////////
NS_INLINE BOOL flex_isTaggedPointer(const void *ptr)  {
    #if OBJC_HAVE_TAGGED_POINTERS
        return ((uintptr_t)ptr & _OBJC_TAG_MASK) == _OBJC_TAG_MASK;
    #else
        return NO;
    #endif
}

#define FLEXPointerIsTaggedPointer(obj) flex_isTaggedPointer((__bridge void *)obj)

/// 给定指针是否为有效的可读地址。
BOOL FLEXPointerIsReadable(const void * ptr);

/// @简述 假定内存有效且可读。
/// @讨论 objc-internal.h、objc-private.h 和 objc-config.h
/// https://blog.timac.org/2016/1124/testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
/// https://llvm.org/svn/llvm-project/lldb/trunk/examples/summaries/cocoa/objc_runtime.py
/// https://blog.timac.org/2016/1124/testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
BOOL FLEXPointerIsValidObjcObject(const void * ptr);

#ifdef __cplusplus
}
#endif
