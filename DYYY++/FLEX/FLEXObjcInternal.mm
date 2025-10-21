//
//  FLEXObjcInternal.mm
//  FLEX
//
//  Created by Tanner Bennett on 11/1/18.
//

/*
 * Copyright (c) 2005-2007 Apple Inc.  All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * 此文件包含原始代码和/或原始代码的修改版本，
 * 如 Apple 公共源码许可证版本 2.0（“许可证”）中定义的。
 * 您不能在不符合许可证的情况下使用此文件。
 * 请访问 http://www.opensource.apple.com/apsl/ 获取许可证并阅读后再使用此文件。
 *
 * 根据许可证分发的原始代码和所有软件均以“按原样”方式提供，
 * 不提供任何形式的保证，无论是明示还是暗示，
 * APPLE 特此否认所有此类保证，包括但不限于对适销性、
 * 适合特定用途、安静享受或非侵权的任何保证。
 * 有关权利和限制的具体语言，请参阅许可证。
 *
 * @APPLE_LICENSE_HEADER_END@
 */

#import "FLEXObjcInternal.h"
#import <objc/runtime.h>
// 用于 malloc_size
#import <malloc/malloc.h>
// 用于 vm_region_64
#include <mach/mach.h>

#if __arm64e__
#include <ptrauth.h>
#endif

#define ALWAYS_INLINE inline __attribute__((always_inline))
#define NEVER_INLINE inline __attribute__((noinline))

// 下面的宏直接从以下文件复制而来：
// objc-internal.h, objc-private.h, objc-object.h, 和 objc-config.h，
// 尽可能少地进行修改。更改内容在方框注释中注明。
// https://opensource.apple.com/source/objc4/objc4-723/
// https://opensource.apple.com/source/objc4/objc4-723/runtime/objc-internal.h.auto.html
// https://opensource.apple.com/source/objc4/objc4-723/runtime/objc-object.h.auto.html

/////////////////////
// objc-internal.h //
/////////////////////

#if OBJC_HAVE_TAGGED_POINTERS

///////////////////
// objc-object.h //
///////////////////

////////////////////////////////////////////////
// 原名 objc_object::isExtTaggedPointer //
////////////////////////////////////////////////
NS_INLINE BOOL flex_isExtTaggedPointer(const void *ptr)  {
    return ((uintptr_t)ptr & _OBJC_TAG_EXT_MASK) == _OBJC_TAG_EXT_MASK;
}

#endif // OBJC_HAVE_TAGGED_POINTERS

/////////////////////////////////////
// FLEXObjectInternal              //
// 此点之后没有 Apple 代码 //
/////////////////////////////////////

extern "C" {

BOOL FLEXPointerIsReadable(const void *inPtr) {
    kern_return_t error = KERN_SUCCESS;

    vm_size_t vmsize;
#if __arm64e__
    // 在 arm64e 上，我们需要从指针中剥离 PAC，使地址可读
    vm_address_t address = (vm_address_t)ptrauth_strip(inPtr, ptrauth_key_function_pointer);
#else
    vm_address_t address = (vm_address_t)inPtr;
#endif
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object;

    error = vm_region_64(
        mach_task_self(),
        &address,
        &vmsize,
        VM_REGION_BASIC_INFO,
        (vm_region_info_t)&info,
        &info_count,
        &object
    );

    if (error != KERN_SUCCESS) {
        // vm_region/vm_region_64 返回了一个错误
        return NO;
    } else if (!(BOOL)(info.protection & VM_PROT_READ)) {
        return NO;
    }

#if __arm64e__
    address = (vm_address_t)ptrauth_strip(inPtr, ptrauth_key_function_pointer);
#else
    address = (vm_address_t)inPtr;
#endif
    
    // 读取内存
    vm_size_t size = 0;
    char buf[sizeof(uintptr_t)];
    error = vm_read_overwrite(mach_task_self(), address, sizeof(uintptr_t), (vm_address_t)buf, &size);
    if (error != KERN_SUCCESS) {
        // vm_read_overwrite 返回了一个错误
        return NO;
    }

    return YES;
}

/// 接受可能可读或不可读的地址。
/// https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
BOOL FLEXPointerIsValidObjcObject(const void *ptr) {
    uintptr_t pointer = (uintptr_t)ptr;

    if (!ptr) {
        return NO;
    }

#if OBJC_HAVE_TAGGED_POINTERS
    // 标记指针设置了 0x1，其他有效指针没有
    // objc-internal.h -> _objc_isTaggedPointer()
    if (flex_isTaggedPointer(ptr) || flex_isExtTaggedPointer(ptr)) {
        return YES;
    }
#endif

    // 检查指针对齐
    if ((pointer % sizeof(uintptr_t)) != 0) {
        return NO;
    }

    // 来自 LLDB：
    // class_t 中的指针只设置了 0 到 46 位，
    // 所以如果任何指针的 47 到 63 位为高，我们知道这不是有效的 isa
    // https://llvm.org/svn/llvm-project/lldb/trunk/examples/summaries/cocoa/objc_runtime.py
    if ((pointer & 0xFFFF800000000000) != 0) {
        return NO;
    }

    // 确保解引用此地址不会崩溃
    if (!FLEXPointerIsReadable(ptr)) {
        return NO;
    }

    // http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html
    // 我们检查返回的类是否可读，因为 object_getClass
    // 在给定非nil指针指向非对象时，可能会返回垃圾值
    Class cls = object_getClass((__bridge id)ptr);
    if (!cls || !FLEXPointerIsReadable((__bridge void *)cls)) {
        return NO;
    }
    
    // 仅仅因为这个指针可读并不意味着其 ISA 偏移处的内容也可读。
    // 我们需要对它的 ISA 进行相同的检查。
    // 即使这也不完美，因为一旦我们调用 object_isClass，我们将
    // 解引用元类的成员，它可能是否可读。目前没有办法
    // 在这里进行检查，而且我还没有硬编码一个解决方案。
    Class metaclass = object_getClass(cls);
    if (!metaclass || !FLEXPointerIsReadable((__bridge void *)metaclass)) {
        return NO;
    }
    
    // 我们获得的类指针在运行时看起来是类吗？
    if (!object_isClass(cls)) {
        return NO;
    }
    
    // 分配大小是否至少与预期的实例大小一样大？
    ssize_t instanceSize = class_getInstanceSize(cls);
    if (malloc_size(ptr) < instanceSize) {
        return NO;
    }

    return YES;
}


} // End extern "C"
