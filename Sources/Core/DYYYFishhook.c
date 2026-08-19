// Copyright (c) 2013, Facebook, Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the conditions in DYYYFishhook.h are met.

#include "DYYYFishhook.h"

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach/mach.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#endif

#ifdef __LP64__
typedef struct mach_header_64 dyyy_mach_header_t;
typedef struct segment_command_64 dyyy_segment_command_t;
typedef struct section_64 dyyy_section_t;
typedef struct nlist_64 dyyy_nlist_t;
#define DYYY_LC_SEGMENT LC_SEGMENT_64
#else
typedef struct mach_header dyyy_mach_header_t;
typedef struct segment_command dyyy_segment_command_t;
typedef struct section dyyy_section_t;
typedef struct nlist dyyy_nlist_t;
#define DYYY_LC_SEGMENT LC_SEGMENT
#endif

#ifndef SEG_DATA_CONST
#define SEG_DATA_CONST "__DATA_CONST"
#endif
#ifndef SEG_AUTH
#define SEG_AUTH "__AUTH"
#endif
#ifndef SEG_AUTH_CONST
#define SEG_AUTH_CONST "__AUTH_CONST"
#endif

struct dyyy_rebindings_entry {
    struct dyyy_rebinding *rebindings;
    _Atomic uint64_t *symbol_matches;
    _Atomic uint64_t *successful_writes;
    _Atomic uint64_t *protection_failures;
    size_t count;
    struct dyyy_rebindings_entry *next;
};

static struct dyyy_rebindings_entry *DYYYRebindingsHead;

static int DYYYPrependRebindings(struct dyyy_rebindings_entry **head,
                               struct dyyy_rebinding rebindings[],
                               size_t count) {
    struct dyyy_rebindings_entry *entry = calloc(1, sizeof(*entry));
    if (!entry) return -1;
    entry->rebindings = malloc(sizeof(struct dyyy_rebinding) * count);
    if (!entry->rebindings) {
        free(entry);
        return -1;
    }
    entry->symbol_matches = calloc(count, sizeof(*entry->symbol_matches));
    entry->successful_writes = calloc(count, sizeof(*entry->successful_writes));
    entry->protection_failures = calloc(count, sizeof(*entry->protection_failures));
    if (!entry->symbol_matches || !entry->successful_writes || !entry->protection_failures) {
        free(entry->symbol_matches);
        free(entry->successful_writes);
        free(entry->protection_failures);
        free(entry->rebindings);
        free(entry);
        return -1;
    }
    memcpy(entry->rebindings, rebindings, sizeof(struct dyyy_rebinding) * count);
    entry->count = count;
    entry->next = *head;
    *head = entry;
    return 0;
}

static bool DYYYSegmentContainsBindings(const char *name) {
    return strcmp(name, SEG_DATA) == 0 ||
           strcmp(name, SEG_DATA_CONST) == 0 ||
           strcmp(name, SEG_AUTH) == 0 ||
           strcmp(name, SEG_AUTH_CONST) == 0;
}

static void DYYYPerformRebinding(struct dyyy_rebindings_entry *entries,
                               dyyy_section_t *section,
                               intptr_t slide,
                               dyyy_nlist_t *symbolTable,
                               uint32_t symbolCount,
                               char *stringTable,
                               uint32_t stringTableSize,
                               uint32_t *indirectTable,
                               uint32_t indirectCount) {
    if (section->reserved1 >= indirectCount) return;
    uint32_t *indices = indirectTable + section->reserved1;
    void **bindings = (void **)((uintptr_t)slide + section->addr);
    size_t bindingCount = (size_t)(section->size / sizeof(void *));
    size_t availableIndices = indirectCount - section->reserved1;
    if (bindingCount > availableIndices) bindingCount = availableIndices;

    for (size_t i = 0; i < bindingCount; i++) {
        uint32_t symbolIndex = indices[i];
        if (symbolIndex == INDIRECT_SYMBOL_ABS || symbolIndex == INDIRECT_SYMBOL_LOCAL ||
            symbolIndex == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) continue;
        if (symbolIndex >= symbolCount) continue;

        uint32_t stringOffset = symbolTable[symbolIndex].n_un.n_strx;
        if (stringOffset >= stringTableSize) continue;
        char *symbolName = stringTable + stringOffset;
        if (!symbolName[0] || !symbolName[1]) continue;

        for (struct dyyy_rebindings_entry *entry = entries; entry; entry = entry->next) {
            for (size_t j = 0; j < entry->count; j++) {
                struct dyyy_rebinding *rebinding = &entry->rebindings[j];
                if (strcmp(symbolName + 1, rebinding->name) != 0) continue;
                atomic_fetch_add_explicit(&entry->symbol_matches[j], 1, memory_order_relaxed);

                if (rebinding->replaced && bindings[i] != rebinding->replacement) {
                    *rebinding->replaced = bindings[i];
                }

                kern_return_t protection = vm_protect(mach_task_self(),
                                                       (vm_address_t)bindings,
                                                       (vm_size_t)section->size,
                                                       false,
                                                       VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                if (protection == KERN_SUCCESS) {
                    void *replacement = rebinding->replacement;
#if __has_feature(ptrauth_calls)
                    if (strcmp(section->sectname, "__auth_got") == 0) {
                        replacement = ptrauth_strip(replacement, ptrauth_key_process_independent_code);
                        replacement = ptrauth_sign_unauthenticated(
                            replacement, ptrauth_key_process_independent_code, &bindings[i]);
                    }
#endif
                    bindings[i] = replacement;
                    atomic_fetch_add_explicit(&entry->successful_writes[j], 1, memory_order_relaxed);
                } else {
                    atomic_fetch_add_explicit(&entry->protection_failures[j], 1, memory_order_relaxed);
                }
                goto next_binding;
            }
        }
next_binding:;
    }
}

static void DYYYRebindImage(struct dyyy_rebindings_entry *entries,
                          const struct mach_header *header,
                          intptr_t slide) {
    if (!header || !entries) return;
    Dl_info imageInfo;
    if (dladdr(header, &imageInfo) == 0) return;

    dyyy_segment_command_t *linkedit = NULL;
    struct symtab_command *symtab = NULL;
    struct dysymtab_command *dysymtab = NULL;
    uintptr_t cursor = (uintptr_t)header + sizeof(dyyy_mach_header_t);

    for (uint32_t i = 0; i < header->ncmds; i++) {
        struct load_command *command = (struct load_command *)cursor;
        if (command->cmd == DYYY_LC_SEGMENT) {
            dyyy_segment_command_t *segment = (dyyy_segment_command_t *)command;
            if (strcmp(segment->segname, SEG_LINKEDIT) == 0) linkedit = segment;
        } else if (command->cmd == LC_SYMTAB) {
            symtab = (struct symtab_command *)command;
        } else if (command->cmd == LC_DYSYMTAB) {
            dysymtab = (struct dysymtab_command *)command;
        }
        cursor += command->cmdsize;
    }

    if (!linkedit || !symtab || !dysymtab || dysymtab->nindirectsyms == 0) return;

    uintptr_t linkeditBase = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    dyyy_nlist_t *symbolTable = (dyyy_nlist_t *)(linkeditBase + symtab->symoff);
    char *stringTable = (char *)(linkeditBase + symtab->stroff);
    uint32_t *indirectTable = (uint32_t *)(linkeditBase + dysymtab->indirectsymoff);

    cursor = (uintptr_t)header + sizeof(dyyy_mach_header_t);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        struct load_command *command = (struct load_command *)cursor;
        if (command->cmd == DYYY_LC_SEGMENT) {
            dyyy_segment_command_t *segment = (dyyy_segment_command_t *)command;
            if (DYYYSegmentContainsBindings(segment->segname)) {
                dyyy_section_t *sections = (dyyy_section_t *)(cursor + sizeof(dyyy_segment_command_t));
                for (uint32_t j = 0; j < segment->nsects; j++) {
                    uint32_t type = sections[j].flags & SECTION_TYPE;
                    if (type == S_LAZY_SYMBOL_POINTERS || type == S_NON_LAZY_SYMBOL_POINTERS) {
                        DYYYPerformRebinding(entries, &sections[j], slide,
                                           symbolTable, symtab->nsyms,
                                           stringTable, symtab->strsize,
                                           indirectTable, dysymtab->nindirectsyms);
                    }
                }
            }
        }
        cursor += command->cmdsize;
    }
}

static void DYYYRebindAddedImage(const struct mach_header *header, intptr_t slide) {
    DYYYRebindImage(DYYYRebindingsHead, header, slide);
}

int dyyy_rebind_symbols(struct dyyy_rebinding rebindings[], size_t count) {
    if (!rebindings || count == 0) return -1;
    int result = DYYYPrependRebindings(&DYYYRebindingsHead, rebindings, count);
    if (result != 0) return result;

    if (!DYYYRebindingsHead->next) {
        _dyld_register_func_for_add_image(DYYYRebindAddedImage);
    } else {
        uint32_t imageCount = _dyld_image_count();
        for (uint32_t i = 0; i < imageCount; i++) {
            DYYYRebindAddedImage(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
        }
    }
    return 0;
}

int dyyy_rebinding_status_for_name(const char *name, struct dyyy_rebinding_status *status) {
    if (!name || !status) return -1;
    memset(status, 0, sizeof(*status));
    bool found = false;
    for (struct dyyy_rebindings_entry *entry = DYYYRebindingsHead; entry; entry = entry->next) {
        for (size_t i = 0; i < entry->count; i++) {
            if (strcmp(entry->rebindings[i].name, name) != 0) continue;
            found = true;
            status->symbol_matches += atomic_load_explicit(&entry->symbol_matches[i], memory_order_relaxed);
            status->successful_writes += atomic_load_explicit(&entry->successful_writes[i], memory_order_relaxed);
            status->protection_failures += atomic_load_explicit(&entry->protection_failures[i], memory_order_relaxed);
        }
    }
    return found ? 0 : -1;
}
