#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * DYYY++ 文件路径集中管理
 * 所有插件产生的缓存/文件统一归入 Documents/DYYY/ 分类目录。
 */
@interface DYYYPaths : NSObject

+ (NSString *)dyyyRootDir;    // Documents/DYYY
+ (NSString *)iconsDir;       // DYYY/Icons（用户自定义图标/头像）
+ (NSString *)abTestDir;      // DYYY/ABTest（ABTest 配置 json）
+ (NSString *)backupDir;      // DYYY/Backup（设置备份 json）
+ (NSString *)tempDir;        // DYYY/Temp（临时文件，用完即删）
+ (NSString *)logsDir;        // DYYY/Logs（调试类平铺：崩溃日志 + 逆向助手数据库）

@end

NS_ASSUME_NONNULL_END
