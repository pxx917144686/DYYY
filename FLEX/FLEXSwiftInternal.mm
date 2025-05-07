//
// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXSwiftInternal.m
//  FLEX
//
//  由 Tanner Bennett 创建于 10/28/21.
//  版权所有 © 2021 Flipboard。保留所有权利。
//

#import "FLEXSwiftInternal.h"
#import <objc/runtime.h>
#include <atomic>

// 类是来自预稳定 Swift ABI 的 Swift 类
#define FAST_IS_SWIFT_LEGACY  (1UL<<0)
// 类是来自稳定 Swift ABI 的 Swift 类
#define FAST_IS_SWIFT_STABLE  (1UL<<1)
// 数据指针
#define FAST_DATA_MASK        0xfffffffcUL

typedef uintptr_t class_data_bits_t;
#if __LP64__
typedef uint32_t mask_t;  // x86_64 和 arm64汇编在16位情况下效率较低
#else
typedef uint16_t mask_t;
#endif

/* dyld_shared_cache_builder 和 obj-C 在这些定义上达成一致 */
struct preopt_cache_entry_t {
    uint32_t sel_offs;
    uint32_t imp_offs;
};

/* dyld_shared_cache_builder 和 obj-C 在这些定义上达成一致 */
struct preopt_cache_t {
    int32_t fallback_class_offset;
    union {
        struct {
            uint16_t shift       :  5;
            uint16_t mask        : 11;
        };
        uint16_t hash_params;
    };
    uint16_t occupied    : 14;
    uint16_t has_inlines :  1;
    uint16_t bit_one     :  1;
    preopt_cache_entry_t entries[];
};

union isa_t {
    uintptr_t bits;
    // 访问类需要自定义 ptrauth 操作
    Class cls;
};

struct cache_t {
    std::atomic<uintptr_t> _bucketsAndMaybeMask;
    union {
        struct {
            std::atomic<mask_t> _maybeMask;
            #if __LP64__
            uint16_t            _flags;
            #endif
            uint16_t            _occupied;
        };
        std::atomic<preopt_cache_t *> _originalPreoptCache;
    };
};

struct objc_object_ {
    union isa_t isa;
};

struct objc_class_ : objc_object_ {
    Class superclass;
    cache_t cache; // 以前是缓存指针和虚函数表
    class_data_bits_t bits;    
};

extern "C" BOOL FLEXIsSwiftObjectOrClass(id objOrClass) {
    Class cls = objOrClass;
    if (!object_isClass(objOrClass)) {
        cls = object_getClass(objOrClass);
    }
    
    class_data_bits_t rodata = ((__bridge objc_class_ *)(cls))->bits;
    
    if (@available(macOS 10.14.4, iOS 12.2, tvOS 12.2, watchOS 5.2, *)) {
        return (rodata & FAST_IS_SWIFT_STABLE) != 0;
    } else {
        return (rodata & FAST_IS_SWIFT_LEGACY) != 0;
    }
}
