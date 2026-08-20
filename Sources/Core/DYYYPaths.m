#import "DYYYPaths.h"
#import <sys/stat.h>

@implementation DYYYPaths

+ (NSString *)documentsDir {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

+ (NSString *)dyyyRootDir {
    return [[self documentsDir] stringByAppendingPathComponent:@"DYYY"];
}

+ (NSString *)iconsDir {
    return [[self dyyyRootDir] stringByAppendingPathComponent:@"Icons"];
}

+ (NSString *)abTestDir {
    return [[self dyyyRootDir] stringByAppendingPathComponent:@"ABTest"];
}

+ (NSString *)backupDir {
    return [[self dyyyRootDir] stringByAppendingPathComponent:@"Backup"];
}

+ (NSString *)tempDir {
    return [[self dyyyRootDir] stringByAppendingPathComponent:@"Temp"];
}

+ (NSString *)logsDir {
    return [[self dyyyRootDir] stringByAppendingPathComponent:@"Logs"];
}

#pragma mark - 旧文件一次性迁移（幂等 move，失败留原地由读取侧回退）

static void DYYYMigrateFile(NSString *oldPath, NSString *newPath) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:oldPath] && ![fm fileExistsAtPath:newPath]) {
        [fm moveItemAtPath:oldPath toPath:newPath error:nil];
    }
}

// 目录内全部文件迁移（成功后删除空旧目录）
static void DYYYMigrateDirectoryContents(NSString *oldDir, NSString *newDir) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:oldDir error:nil];
    for (NSString *name in files) {
        DYYYMigrateFile([oldDir stringByAppendingPathComponent:name],
                        [newDir stringByAppendingPathComponent:name]);
    }
    // 空目录清理
    NSArray<NSString *> *remaining = [fm contentsOfDirectoryAtPath:oldDir error:nil];
    if (remaining.count == 0) {
        [fm removeItemAtPath:oldDir error:nil];
    }
}

static void DYYYMigrateLegacyFiles(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in @[[DYYYPaths dyyyRootDir], [DYYYPaths iconsDir], [DYYYPaths abTestDir],
                            [DYYYPaths backupDir], [DYYYPaths tempDir], [DYYYPaths logsDir]]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSString *doc = [DYYYPaths documentsDir];
    NSString *root = [DYYYPaths dyyyRootDir];
    NSString *logs = [DYYYPaths logsDir];

    // 逆向助手数据库：Documents 根 → Logs/（平铺）
    DYYYMigrateFile([doc stringByAppendingPathComponent:@"iosnixiangzhushoutest.sqlite"],
                    [logs stringByAppendingPathComponent:@"iosnixiangzhushoutest.sqlite"]);

    // 崩溃日志：旧 CrashLogs/ 目录 → Logs/（平铺）
    DYYYMigrateDirectoryContents([root stringByAppendingPathComponent:@"CrashLogs"], logs);

    // 图标/头像：DYYY 根 → Icons/
    for (NSString *name in @[@"like_before.png", @"like_after.png", @"comment.png",
                             @"unfavorite.png", @"favorite.png", @"share.png",
                             @"qingping.png", @"custom_album_image.png"]) {
        DYYYMigrateFile([root stringByAppendingPathComponent:name],
                        [[DYYYPaths iconsDir] stringByAppendingPathComponent:name]);
    }

    // ABTest 配置：DYYY 根 → ABTest/
    for (NSString *name in @[@"abtest_data_fixed.json", @"abtest_config.json"]) {
        DYYYMigrateFile([root stringByAppendingPathComponent:name],
                        [[DYYYPaths abTestDir] stringByAppendingPathComponent:name]);
    }

    // 设置备份：DYYY 根 DYYY_Backup_*.json → Backup/
    NSArray<NSString *> *rootFiles = [fm contentsOfDirectoryAtPath:root error:nil];
    for (NSString *name in rootFiles) {
        if ([name hasPrefix:@"DYYY_Backup_"] && [name.pathExtension isEqualToString:@"json"]) {
            DYYYMigrateFile([root stringByAppendingPathComponent:name],
                            [[DYYYPaths backupDir] stringByAppendingPathComponent:name]);
        }
    }
}

__attribute__((constructor)) static void DYYYPathsMigrateOnLaunch(void) {
    @autoreleasepool {
        [DYYYPaths runLegacyMigrationIfNeeded];
    }
}

+ (void)runLegacyMigrationIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DYYYMigrateLegacyFiles();
    });
}

@end
