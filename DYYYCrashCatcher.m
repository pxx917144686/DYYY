#import "DYYYCrashCatcher.h"
#import "DYYYPaths.h"
#import <UIKit/UIKit.h>
#import <signal.h>
#import <execinfo.h>
#import <unistd.h>
#import <fcntl.h>
#import <time.h>
#import <sys/stat.h>
#import <string.h>

#define DYYY_MAX_CRASH_LOGS 3

// 崩溃日志目录的 C 路径缓存（constructor 阶段准备，signal handler 内只做 C 级操作）
static char gDYYYCrashDirPath[PATH_MAX] = {0};
// 防递归：崩溃处理中再次崩溃直接走默认流程
static volatile sig_atomic_t gDYYYCrashHandling = 0;
// 链式保存的旧处理器，写完日志后交还抖音/其他 SDK 处理
static NSUncaughtExceptionHandler *gDYYYPreviousExceptionHandler = NULL;
static void (*gDYYYOldSignalHandlers[NSIG])(int);

static NSString *DYYYCrashLogDirectory(void) {
    NSString *dir = [DYYYPaths logsDir]; // 调试类统一平铺 Logs/
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

// 启动时清理旧日志，仅保留最近 DYYY_MAX_CRASH_LOGS 份
static void DYYYCleanupOldCrashLogs(void) {
    NSString *dir = DYYYCrashLogDirectory();
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    if (files.count <= DYYY_MAX_CRASH_LOGS) return;

    NSArray<NSString *> *sorted = [files sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b];
    }];
    NSUInteger removeCount = sorted.count - DYYY_MAX_CRASH_LOGS;
    for (NSUInteger i = 0; i < removeCount; i++) {
        [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:sorted[i]] error:nil];
    }
}

static const char *DYYYSignalName(int sig) {
    switch (sig) {
        case SIGABRT: return "SIGABRT";
        case SIGSEGV: return "SIGSEGV";
        case SIGBUS:  return "SIGBUS";
        case SIGILL:  return "SIGILL";
        case SIGFPE:  return "SIGFPE";
        case SIGTRAP: return "SIGTRAP";
        default:      return "UNKNOWN_SIGNAL";
    }
}

// 信号处理器：仅 C 级操作（open/write/backtrace_symbols_fd），避免在崩溃现场使用 ObjC
static void DYYYSignalHandler(int sig) {
    if (gDYYYCrashHandling) {
        signal(sig, SIG_DFL);
        raise(sig);
        return;
    }
    gDYYYCrashHandling = 1;

    if (gDYYYCrashDirPath[0] != 0) {
        time_t now = time(NULL);
        char nameBuf[PATH_MAX];
        snprintf(nameBuf, sizeof(nameBuf), "%s/Crash_%ld.txt", gDYYYCrashDirPath, (long)now);

        int fd = open(nameBuf, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd >= 0) {
            char header[256];
            int len = snprintf(header, sizeof(header),
                               "===== DYYY++ 崩溃日志 =====\n时间戳: %ld\n类型: 致命信号\n信号: %d (%s)\n\n调用栈:\n",
                               (long)now, sig, DYYYSignalName(sig));
            if (len > 0) write(fd, header, (size_t)len);

            void *frames[64];
            int frameCount = backtrace(frames, 64);
            // 直接写 fd，避免内存分配
            backtrace_symbols_fd(frames, frameCount, fd);
            close(fd);
        }
    }

    // 交还旧处理器或走默认崩溃流程
    void (*old)(int) = gDYYYOldSignalHandlers[sig];
    if (old && old != SIG_DFL && old != DYYYSignalHandler) {
        old(sig);
    } else {
        signal(sig, SIG_DFL);
        raise(sig);
    }
}

// 未捕获 ObjC 异常处理器：ObjC 环境可用，写详细日志后链式调用旧处理器
static void DYYYUncaughtExceptionHandler(NSException *exception) {
    if (gDYYYCrashHandling) return;
    gDYYYCrashHandling = 1;

    @try {
        NSString *dir = DYYYCrashLogDirectory();
        long long ts = (long long)[[NSDate date] timeIntervalSince1970];
        NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"Crash_%lld.txt", ts]];
        NSString *stack = [[exception callStackSymbols] componentsJoinedByString:@"\n"] ?: @"(无调用栈)";
        NSString *content = [NSString stringWithFormat:
            @"===== DYYY++ 崩溃日志 =====\n时间: %@ (unix %lld)\n类型: 未捕获 ObjC 异常\n异常名: %@\n原因: %@\n\n调用栈:\n%@\n",
            [NSDate date], ts, exception.name ?: @"(未知)", exception.reason ?: @"(无原因)", stack];
        [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } @catch (NSException *e) {
        // 崩溃现场写日志失败则放弃，绝不二次崩溃
    }

    if (gDYYYPreviousExceptionHandler) {
        gDYYYPreviousExceptionHandler(exception);
    }
}

@implementation DYYYCrashCatcher

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 准备目录 + 缓存 C 路径 + 清理旧日志
        NSString *dir = DYYYCrashLogDirectory();
        if (dir.fileSystemRepresentation) {
            strlcpy(gDYYYCrashDirPath, dir.fileSystemRepresentation, sizeof(gDYYYCrashDirPath));
        }
        DYYYCleanupOldCrashLogs();

        // 链式保存旧异常处理器
        gDYYYPreviousExceptionHandler = NSGetUncaughtExceptionHandler();
        NSSetUncaughtExceptionHandler(&DYYYUncaughtExceptionHandler);

        // 安装信号处理器（保存旧处理器链）
        int signals[] = { SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP };
        for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) {
            int sig = signals[i];
            void (*old)(int) = signal(sig, DYYYSignalHandler);
            if (old != SIG_ERR && old != SIG_IGN) {
                gDYYYOldSignalHandlers[sig] = old;
            }
        }

        NSLog(@"[DYYY] 崩溃日志抓取已安装, 目录: %@", dir);
    });
}

+ (NSArray<NSString *> *)savedLogFilePaths {
    NSString *dir = DYYYCrashLogDirectory();
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSArray<NSString *> *sorted = [files sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b];
    }];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSString *name in sorted) {
        [paths addObject:[dir stringByAppendingPathComponent:name]];
    }
    return paths;
}

@end

// 尽早安装（constructor 阶段，早于 Logos %ctor 的用户态初始化顺序不可保证，
// 但本安装与 DYYYFloatClearButton 的 SIGSEGV SIG_IGN 冲突已移除，故互不覆盖）
__attribute__((constructor)) static void DYYYCrashCatcherAutoInstall(void) {
    @autoreleasepool {
        [DYYYCrashCatcher install];
    }
}
