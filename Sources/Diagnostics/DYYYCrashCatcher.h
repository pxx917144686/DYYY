#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * DYYY++ 崩溃日志自动抓取
 * 捕获未捕获 ObjC 异常与致命信号，写入 Documents/DYYY/CrashLogs/。
 */
@interface DYYYCrashCatcher : NSObject

+ (void)install;

// 当前已保存的崩溃日志文件路径列表（按时间升序）
+ (NSArray<NSString *> *)savedLogFilePaths;

@end

NS_ASSUME_NONNULL_END
