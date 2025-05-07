// 遇到问题联系中文翻译作者：pxx917144686
//
// Source: https://github.com/llvm-mirror/lldb/blob/master/tools/debugserver/source/MacOSX/DarwinLog/ActivityStreamSPI.h
// Minimally modified by Tanner Bennett on 03/03/2019.
//

//===-- ActivityStreamAPI.h -------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for details.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef ActivityStreamSPI_h
#define ActivityStreamSPI_h

#include <Foundation/Foundation.h>

#include <sys/time.h>
// #include <xpc/xpc.h> // XPC 相关，保持原样或根据需要处理

/* 默认情况下，使用 Objective-C 编译器构建时，XPC 对象被声明为 Objective-C 类型。
 * 这使得它们可以参与 ARC、块运行时的 RR 管理以及静态分析器的
 * 泄漏检查，并允许将它们添加到 Cocoa 集合中。
 *
 * 详情请参阅 <os/object.h>。
 */
#if !TARGET_OS_MACCATALYST && !__has_include(<xpc/xpc.h>)
#if OS_OBJECT_USE_OBJC
OS_OBJECT_DECL(xpc_object);
#else
typedef void * xpc_object_t;
#endif
#endif

#define OS_ACTIVITY_MAX_CALLSTACK 32 // 最大调用栈深度

// 枚举

typedef NS_ENUM(uint32_t, os_activity_stream_flag_t) {
    OS_ACTIVITY_STREAM_PROCESS_ONLY = 0x00000001,       // 仅限当前进程
    OS_ACTIVITY_STREAM_SKIP_DECODE = 0x00000002,        // 跳过解码
    OS_ACTIVITY_STREAM_PAYLOAD = 0x00000004,            // 包含有效负载
    OS_ACTIVITY_STREAM_HISTORICAL = 0x00000008,         // 包含历史数据
    OS_ACTIVITY_STREAM_CALLSTACK = 0x00000010,          // 包含调用栈
    OS_ACTIVITY_STREAM_DEBUG = 0x00000020,              // 调试模式
    OS_ACTIVITY_STREAM_BUFFERED = 0x00000040,           // 缓冲模式
    OS_ACTIVITY_STREAM_NO_SENSITIVE = 0x00000080,       // 不包含敏感信息
    OS_ACTIVITY_STREAM_INFO = 0x00000100,               // 包含信息
    OS_ACTIVITY_STREAM_PROMISCUOUS = 0x00000200,        // 混杂模式
    OS_ACTIVITY_STREAM_PRECISE_TIMESTAMPS = 0x00000200  // 精确时间戳 (注意：与 PROMISCUOUS 值相同)
};

typedef NS_ENUM(uint32_t, os_activity_stream_type_t) {
    OS_ACTIVITY_STREAM_TYPE_ACTIVITY_CREATE = 0x0201,     // 活动创建
    OS_ACTIVITY_STREAM_TYPE_ACTIVITY_TRANSITION = 0x0202, // 活动转换
    OS_ACTIVITY_STREAM_TYPE_ACTIVITY_USERACTION = 0x0203, // 用户操作活动

    OS_ACTIVITY_STREAM_TYPE_TRACE_MESSAGE = 0x0300,       // 跟踪消息

    OS_ACTIVITY_STREAM_TYPE_LOG_MESSAGE = 0x0400,         // 日志消息
    OS_ACTIVITY_STREAM_TYPE_LEGACY_LOG_MESSAGE = 0x0480,  // 旧版日志消息

    OS_ACTIVITY_STREAM_TYPE_SIGNPOST_BEGIN = 0x0601,      // 标记点开始
    OS_ACTIVITY_STREAM_TYPE_SIGNPOST_END = 0x0602,        // 标记点结束
    OS_ACTIVITY_STREAM_TYPE_SIGNPOST_EVENT = 0x0603,      // 标记点事件

    OS_ACTIVITY_STREAM_TYPE_STATEDUMP_EVENT = 0x0A00,     // 状态转储事件
};

typedef NS_ENUM(uint32_t, os_activity_stream_event_t) {
    OS_ACTIVITY_STREAM_EVENT_STARTED = 1,         // 流已开始
    OS_ACTIVITY_STREAM_EVENT_STOPPED = 2,         // 流已停止
    OS_ACTIVITY_STREAM_EVENT_FAILED = 3,          // 流失败
    OS_ACTIVITY_STREAM_EVENT_CHUNK_STARTED = 4,   // 数据块开始
    OS_ACTIVITY_STREAM_EVENT_CHUNK_FINISHED = 5,  // 数据块结束
};

// 类型定义

typedef uint64_t os_activity_id_t; // 活动 ID 类型
typedef struct os_activity_stream_s *os_activity_stream_t; // 活动流类型
typedef struct os_activity_stream_entry_s *os_activity_stream_entry_t; // 活动流条目类型

#define OS_ACTIVITY_STREAM_COMMON()                                          \
uint64_t trace_id;                                                           \
uint64_t timestamp;                                                          \
uint64_t thread;                                                             \
const uint8_t *image_uuid;                                                   \
const char *image_path;                                                      \
struct timeval tv_gmt;                                                       \
struct timezone tz;                                                          \
uint32_t offset // 公共字段宏定义

typedef struct os_activity_stream_common_s {
    OS_ACTIVITY_STREAM_COMMON();
} * os_activity_stream_common_t; // 公共流结构体

struct os_activity_create_s { // 活动创建结构体
    OS_ACTIVITY_STREAM_COMMON();
    const char *name;
    os_activity_id_t creator_aid;
    uint64_t unique_pid;
};

struct os_activity_transition_s { // 活动转换结构体
    OS_ACTIVITY_STREAM_COMMON();
    os_activity_id_t transition_id;
};

typedef struct os_log_message_s { // 日志消息结构体
    OS_ACTIVITY_STREAM_COMMON();
    const char *format;
    const uint8_t *buffer;
    size_t buffer_sz;
    const uint8_t *privdata;
    size_t privdata_sz;
    const char *subsystem;
    const char *category;
    uint32_t oversize_id;
    uint8_t ttl;
    bool persisted;
} * os_log_message_t;

typedef struct os_trace_message_v2_s { // 跟踪消息 V2 结构体
    OS_ACTIVITY_STREAM_COMMON();
    const char *format;
    const void *buffer;
    size_t bufferLen;
    xpc_object_t __unsafe_unretained payload;
} * os_trace_message_v2_t;

typedef struct os_activity_useraction_s { // 用户操作活动结构体
    OS_ACTIVITY_STREAM_COMMON();
    const char *action;
    bool persisted;
} * os_activity_useraction_t;

typedef struct os_signpost_s { // 标记点结构体
    OS_ACTIVITY_STREAM_COMMON();
    const char *format;
    const uint8_t *buffer;
    size_t buffer_sz;
    const uint8_t *privdata;
    size_t privdata_sz;
    const char *subsystem;
    const char *category;
    uint64_t duration_nsec;
    uint32_t callstack_depth;
    uint64_t callstack[OS_ACTIVITY_MAX_CALLSTACK];
} * os_signpost_t;

typedef struct os_activity_statedump_s { // 状态转储结构体
    OS_ACTIVITY_STREAM_COMMON();
    char *message;
    size_t message_size;
    char image_path_buffer[PATH_MAX]; // 假设 PATH_MAX 已定义
} * os_activity_statedump_t;

struct os_activity_stream_entry_s { // 活动流条目结构体
    os_activity_stream_type_t type;

    // 关于流式传输数据的进程信息
    pid_t pid;
    uint64_t proc_id;
    const uint8_t *proc_imageuuid;
    const char *proc_imagepath;

    // 与此流式事件关联的活动
    os_activity_id_t activity_id;
    os_activity_id_t parent_id;

    union { // 根据类型联合不同的结构体
        struct os_activity_stream_common_s common;
        struct os_activity_create_s activity_create;
        struct os_activity_transition_s activity_transition;
        struct os_log_message_s log_message;
        struct os_trace_message_v2_s trace_message;
        struct os_activity_useraction_s useraction;
        struct os_signpost_s signpost;
        struct os_activity_statedump_s statedump;
    };
};

// 块 (Blocks)

typedef bool (^os_activity_stream_block_t)(os_activity_stream_entry_t entry,
                                           int error); // 活动流处理块类型

typedef void (^os_activity_stream_event_block_t)(
                                                 os_activity_stream_t stream, os_activity_stream_event_t event); // 活动流事件处理块类型

// SPI 入口点原型

typedef os_activity_stream_t (*os_activity_stream_for_pid_t)(
                                                             pid_t pid, os_activity_stream_flag_t flags,
                                                             os_activity_stream_block_t stream_block); // 获取指定 PID 活动流的函数指针类型

typedef void (*os_activity_stream_resume_t)(os_activity_stream_t stream); // 恢复活动流的函数指针类型

typedef void (*os_activity_stream_cancel_t)(os_activity_stream_t stream); // 取消活动流的函数指针类型

typedef char *(*os_log_copy_formatted_message_t)(os_log_message_t log_message); // 复制格式化日志消息的函数指针类型

typedef void (*os_activity_stream_set_event_handler_t)(
                                                       os_activity_stream_t stream, os_activity_stream_event_block_t block); // 设置活动流事件处理程序的函数指针类型

#endif /* ActivityStreamSPI_h */
