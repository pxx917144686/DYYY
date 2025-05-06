// 遇到问题联系中文翻译作者：pxx917144686
// Copyright (c) 2013, Facebook, Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  * Neither the name Facebook nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#ifndef fishhook_h
#define fishhook_h

#include <stddef.h>
#include <stdint.h>

#if !defined(FISHHOOK_EXPORT)
#define FISHHOOK_VISIBILITY __attribute__((visibility("hidden"))) // 默认隐藏符号
#else
#define FISHHOOK_VISIBILITY __attribute__((visibility("default"))) // 导出符号
#endif

#ifdef __cplusplus
extern "C" {
#endif //__cplusplus

/**
 * 表示从符号名称到其替换的特定预期重绑定的结构体
 */
struct rebinding {
    const char *name;       // 要替换的符号名称
    void *replacement;      // 替换后的函数指针
    void **replaced;        // 指向存储原始函数指针位置的指针
};

/**
 * 对于 rebindings 中的每个重绑定，将对具有指定名称的外部间接符号的引用
 * 重绑定为指向 replacement，适用于调用进程中的每个镜像以及
 * 进程加载的所有未来镜像。如果多次调用 rebind_functions，
 * 要重绑定的符号将添加到现有的重绑定列表中，如果某个符号被多次重绑定，
 * 则后面的重绑定将优先。
 * @return 成功时返回 0
 */
FISHHOOK_VISIBILITY
int flex_rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

/**
 * 如上所述进行重绑定，但仅在指定的镜像中进行。header 应指向 mach-o 头部，
 * slide 应为幻灯片偏移量。其他参数同上。
 * @return 成功时返回 0
 */
FISHHOOK_VISIBILITY
int flex_rebind_symbols_image(void *header,
                              intptr_t slide,
                              struct rebinding rebindings[],
                              size_t rebindings_nel);

#ifdef __cplusplus
}
#endif //__cplusplus

#endif //fishhook_h
