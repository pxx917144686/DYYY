// Copyright (c) 2013, Facebook, Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name Facebook nor the names of its contributors may be used to
//   endorse or promote products derived from this software without permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DAMAGES ARISING FROM USE.

#ifndef DYYYFishhook_h
#define DYYYFishhook_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct dyyy_rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

struct dyyy_rebinding_status {
    uint64_t symbol_matches;
    uint64_t successful_writes;
    uint64_t protection_failures;
};

int dyyy_rebind_symbols(struct dyyy_rebinding rebindings[], size_t count);

/// 返回当前已加载镜像及后续镜像中的实际匹配/写入计数。
int dyyy_rebinding_status_for_name(const char *name, struct dyyy_rebinding_status *status);

#ifdef __cplusplus
}
#endif

#endif /* DYYYFishhook_h */
