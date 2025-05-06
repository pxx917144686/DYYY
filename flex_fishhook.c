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

#include "flex_fishhook.h"

#include <dlfcn.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#ifdef __LP64__
// 64 位架构定义
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
// 32 位架构定义
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#ifndef SEG_DATA_CONST
#define SEG_DATA_CONST  "__DATA_CONST" // 定义常量数据段名称
#endif

// 重绑定条目结构体，用于构建链表
struct rebindings_entry {
    struct rebinding *rebindings; // 重绑定数组
    size_t rebindings_nel;        // 重绑定数量
    struct rebindings_entry *next; // 指向下一个条目的指针
};

static struct rebindings_entry *_flex_rebindings_head; // 重绑定链表头指针

/// 将新的重绑定添加到链表头部
/// @return 成功时返回 0
static int flex_prepend_rebindings(struct rebindings_entry **rebindings_head,
                              struct rebinding rebindings[],
                              size_t nel) {
    // 分配新的链表节点内存
    struct rebindings_entry *new_entry = (struct rebindings_entry *) malloc(sizeof(struct rebindings_entry));
    if (!new_entry) {
        return -1; // 内存分配失败
    }
    
    // 分配存储重绑定数组的内存
    new_entry->rebindings = (struct rebinding *) malloc(sizeof(struct rebinding) * nel);
    if (!new_entry->rebindings) {
        free(new_entry);
        return -1; // 内存分配失败
    }
    
    // 复制重绑定数据
    memcpy(new_entry->rebindings, rebindings, sizeof(struct rebinding) * nel);
    new_entry->rebindings_nel = nel;
    // 将新节点插入链表头部
    new_entry->next = *rebindings_head;
    *rebindings_head = new_entry;
    
    return 0; // 成功
}

// 获取指定内存区域的保护属性
static vm_prot_t flex_get_protection(void *sectionStart) {
    mach_port_t task = mach_task_self(); // 获取当前任务端口
    vm_size_t size = 0;
    vm_address_t address = (vm_address_t)sectionStart;
    memory_object_name_t object;
#if __LP64__
    // 64 位获取内存区域信息
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    vm_region_basic_info_data_64_t info;
    kern_return_t info_ret = vm_region_64(
        task, &address, &size, VM_REGION_BASIC_INFO_64,
        (vm_region_info_64_t)&info, &count, &object
    );
#else
    // 32 位获取内存区域信息
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT;
    vm_region_basic_info_data_t info;
    kern_return_t info_ret = vm_region(
        task, &address, &size, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &count, &object
    );
#endif
    if (info_ret == KERN_SUCCESS) {
        return info.protection; // 返回保护属性
    } else {
        return VM_PROT_READ; // 失败时默认返回只读
    }
}

// 对指定的 section 执行重绑定操作
static void flex_perform_rebinding_with_section(struct rebindings_entry *rebindings,
                                                section_t *section,
                                                intptr_t slide,
                                                nlist_t *symtab,
                                                char *strtab,
                                                uint32_t *indirect_symtab) {
    // 检查是否为 __DATA_CONST 段
    const bool isDataConst = strcmp(section->segname, SEG_DATA_CONST) == 0;
    // 获取间接符号表索引数组
    uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
    // 获取间接符号绑定地址（指针数组）
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);
    vm_prot_t oldProtection = VM_PROT_READ; // 默认旧保护属性为只读
    
    if (isDataConst) {
        // 如果是 __DATA_CONST 段，获取当前保护属性并修改为可读写
        oldProtection = flex_get_protection(indirect_symbol_bindings);
        mprotect(indirect_symbol_bindings, section->size, PROT_READ | PROT_WRITE);
    }
    
    // 遍历 section 中的每个符号绑定
    for (uint i = 0; i < section->size / sizeof(void *); i++) {
        uint32_t symtab_index = indirect_symbol_indices[i]; // 获取符号表索引
        
        // 跳过绝对符号和局部符号
        if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL ||
            symtab_index == (INDIRECT_SYMBOL_LOCAL   | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        
        // 获取符号名称
        uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        // 检查符号名称是否至少有两个字符（通常以下划线开头）
        bool symbol_name_longer_than_1 = symbol_name[0] && symbol_name[1];
        struct rebindings_entry *cur = rebindings; // 当前重绑定条目
        
        // 遍历重绑定链表
        while (cur) {
            // 遍历当前条目中的重绑定数组
            for (uint j = 0; j < cur->rebindings_nel; j++) {
                // 如果符号名称匹配（忽略第一个下划线）
                if (symbol_name_longer_than_1 &&
                  strcmp(&symbol_name[1], cur->rebindings[j].name) == 0) {
                    
                    // 如果需要保存原始实现，并且当前绑定不是替换实现
                    if (cur->rebindings[j].replaced != NULL &&
                      indirect_symbol_bindings[i] != cur->rebindings[j].replacement) {
                        
                        // 保存原始实现
                        *(cur->rebindings[j].replaced) = indirect_symbol_bindings[i];
                    }
                    
                    // 执行重绑定，将绑定指向替换实现
                    indirect_symbol_bindings[i] = cur->rebindings[j].replacement;
                    goto symbol_loop; // 处理完当前符号，跳到下一个符号
                }
            }
            
            cur = cur->next; // 移动到下一个重绑定条目
        }
        
    symbol_loop:; // 符号循环标签
    }
    
    if (isDataConst) {
        // 如果是 __DATA_CONST 段，恢复原始保护属性
        int protection = 0;
        if (oldProtection & VM_PROT_READ) {
            protection |= PROT_READ;
        }
        if (oldProtection & VM_PROT_WRITE) {
            protection |= PROT_WRITE;
        }
        if (oldProtection & VM_PROT_EXECUTE) {
            protection |= PROT_EXEC;
        }
        
        mprotect(indirect_symbol_bindings, section->size, protection);
    }
}

// 对指定的镜像（image）执行重绑定
static void flex_rebind_symbols_for_image(struct rebindings_entry *rebindings,
                                          const struct mach_header *header,
                                          intptr_t slide) {
    Dl_info info;
    // 获取镜像信息，如果失败则返回
    if (dladdr(header, &info) == 0) {
        return;
    }
    
    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL; // LINKEDIT 段命令
    struct symtab_command* symtab_cmd = NULL;    // 符号表命令
    struct dysymtab_command* dysymtab_cmd = NULL; // 动态符号表命令
    
    // 遍历 Mach-O 头部的加载命令
    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            // 查找 LINKEDIT 段
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            // 查找符号表命令
            symtab_cmd = (struct symtab_command*)cur_seg_cmd;
        } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
            // 查找动态符号表命令
            dysymtab_cmd = (struct dysymtab_command*)cur_seg_cmd;
        }
    }
    
    // 如果缺少必要的命令或没有间接符号，则返回
    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment ||
        !dysymtab_cmd->nindirectsyms) {
        return;
    }
    
    // 计算符号表和字符串表的基地址
    // linkedit_base = slide + vmaddr_linkedit - fileoff_linkedit
    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    // 符号表地址 = linkedit_base + symoff
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    // 字符串表地址 = linkedit_base + stroff
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    
    // 获取间接符号表地址（uint32_t 索引数组）
    // indirect_symtab = linkedit_base + indirectsymoff
    uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);
    
    // 再次遍历加载命令，查找 DATA 和 DATA_CONST 段
    cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            // 只处理 DATA 和 DATA_CONST 段
            if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0 &&
                strcmp(cur_seg_cmd->segname, SEG_DATA_CONST) != 0) {
                continue;
            }
            
            // 遍历段中的每个 section
            for (uint j = 0; j < cur_seg_cmd->nsects; j++) {
                section_t *sect = (section_t *)(cur + sizeof(segment_command_t)) + j;
                
                // 处理惰性符号指针 section (S_LAZY_SYMBOL_POINTERS)
                if ((sect->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS) {
                    flex_perform_rebinding_with_section(
                        rebindings, sect, slide, symtab, strtab, indirect_symtab
                    );
                }
                // 处理非惰性符号指针 section (S_NON_LAZY_SYMBOL_POINTERS)
                if ((sect->flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {
                    flex_perform_rebinding_with_section(
                        rebindings, sect, slide, symtab, strtab, indirect_symtab
                    );
                }
            }
        }
    }
}

// dyld 添加镜像时的回调函数
static void _flex_rebind_symbols_for_image(const struct mach_header *header,
                                           intptr_t slide) {
    // 调用实际的重绑定函数
    flex_rebind_symbols_for_image(_flex_rebindings_head, header, slide);
}

// 对指定的单个镜像执行重绑定
int flex_rebind_symbols_image(void *header,
                              intptr_t slide,
                              struct rebinding rebindings[],
                              size_t rebindings_nel) {
    struct rebindings_entry *rebindings_head = NULL;
    
    // 创建临时的重绑定链表头
    int retval = flex_prepend_rebindings(&rebindings_head, rebindings, rebindings_nel);
    // 对该镜像执行重绑定
    flex_rebind_symbols_for_image(rebindings_head, (const struct mach_header *) header, slide);
    
    // 释放临时链表节点内存
    if (rebindings_head) {
        free(rebindings_head->rebindings);
    }
    
    free(rebindings_head);
    return retval; // 返回结果
}

/// 对当前进程中的所有镜像以及未来加载的镜像执行重绑定
/// @return 成功时返回 0
int flex_rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel) {
    // 将新的重绑定添加到全局链表头部
    int retval = flex_prepend_rebindings(&_flex_rebindings_head, rebindings, rebindings_nel);
    if (retval < 0) {
        return retval; // 添加失败
    }
    
    // 如果这是第一次调用（链表中只有一个节点），则注册 dyld 添加镜像的回调函数
    // （该回调也会对已存在的镜像调用一次）
    // 否则，仅对当前已存在的镜像执行重绑定
    if (!_flex_rebindings_head->next) {
        _dyld_register_func_for_add_image(_flex_rebind_symbols_for_image);
    } else {
        // 遍历当前所有已加载的镜像
        uint32_t c = _dyld_image_count();
        for (uint32_t i = 0; i < c; i++) {
            // 对每个镜像执行重绑定
            _flex_rebind_symbols_for_image(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
        }
    }
    
    return retval; // 返回结果
}
