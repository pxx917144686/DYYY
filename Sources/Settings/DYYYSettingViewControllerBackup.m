//
//  DYYYSettingViewControllerBackup.m
//  DYYY
//
//  清理缓存、备份/恢复设置、ABTest 配置管理。
//

#import "DYYYSettingViewController.h"
#import "DYYYSettingViewControllerPrivate.h"
#import "DYYYManager.h"
#import "DYYYBottomAlertView.h"
#import "DYYYUtils.h"
#import "DYYYPaths.h"
#import "DYYYABTestHook.h"

@class AWESettingItemModel;

// 添加备份选择器代理
@interface DYYYBackupPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, copy) void (^completionBlock)(NSURL *url);
@end

// 实现备份选择器代理
@implementation DYYYBackupPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        if (self.completionBlock) {
            self.completionBlock(urls.firstObject);
        }
    }
}

@end

// 获取当前ABTest数据
NSDictionary *getCurrentABTestData(void) {
    Class AWEABTestManagerClass = NSClassFromString(@"AWEABTestManager");
    if (!AWEABTestManagerClass) {
        return nil;
    }
    
    id manager = [AWEABTestManagerClass performSelector:@selector(sharedManager)];
    if (!manager) {
        return nil;
    }
    
    SEL abTestDataSelector = NSSelectorFromString(@"abTestData");
    if (![manager respondsToSelector:abTestDataSelector]) {
        return nil;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSDictionary *currentData = [manager performSelector:abTestDataSelector];
    #pragma clang diagnostic pop
    
    return currentData;
}

@implementation DYYYSettingViewController (Backup)

- (void)setupCleanupOptions {
    Class AWESettingItemModelClass = NSClassFromString(@"AWESettingItemModel");
    AWESettingItemModel *cleanCacheItem = [[AWESettingItemModelClass alloc] init];
    cleanCacheItem.identifier = @"DYYYCleanCache";
    cleanCacheItem.title = @"清理缓存";
    cleanCacheItem.detail = @"";
    cleanCacheItem.type = 0;
    cleanCacheItem.svgIconImageName = @"ic_broom_outlined";
    cleanCacheItem.cellType = 26;
    cleanCacheItem.colorStyle = 0;
    cleanCacheItem.isEnable = YES;
    
    // 绑定点击事件
    cleanCacheItem.cellTappedBlock = ^{
        // 处理清理缓存逻辑
        [self handleCleanCache];
    };
}

- (void)handleCleanCache {
    // DYYYBottomAlertView 调用，使用正确的方法名和参数顺序
    [DYYYBottomAlertView showAlertWithTitle:@"清理缓存"
                               message:@"确定要清理缓存吗？\n这将删除临时文件和缓存"
                         cancelButtonText:@"取消"
                         confirmButtonText:@"确定"
                         cancelAction:nil
                         confirmAction:^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSUInteger totalSize = 0;

        // 临时目录
        NSString *tempDir = NSTemporaryDirectory();

        // Library目录下的缓存目录
        NSArray<NSString *> *customDirs = @[@"Caches", @"BDByteCast", @"kitelog"];
        NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;

        NSMutableArray<NSString *> *allPaths = [NSMutableArray arrayWithObject:tempDir];
        for (NSString *sub in customDirs) {
            NSString *fullPath = [libraryDir stringByAppendingPathComponent:sub];
            if ([fileManager fileExistsAtPath:fullPath]) {
                [allPaths addObject:fullPath];
            }
        }

        // 遍历所有目录并清理
        for (NSString *basePath in allPaths) {
            totalSize += [DYYYUtils clearDirectoryContents:basePath];
        }

        float sizeInMB = totalSize / 1024.0 / 1024.0;
        NSString *toastMsg = [NSString stringWithFormat:@"已清理 %.2f MB 的缓存", sizeInMB];
        [DYYYManager showToast:toastMsg];
    }];
}

- (void)setupBackupFunctions {
    // 确保表格已经加载
    if (!self.tableView) return;
    
    // 找到备份设置项并添加点击事件（按可见行遍历，兼容子分组折叠）
    for (NSInteger section = 0; section < self.settingSections.count; section++) {
        NSArray<DYYYSettingItem *> *items = [self visibleItemsForSection:section];
        for (NSInteger row = 0; row < items.count; row++) {
            DYYYSettingItem *item = items[row];
            
            if ([item.key isEqualToString:@"DYYYBackupSettings"]) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                
                if (cell) {
                    // 移除现有的开关
                    if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                        [cell.accessoryView removeFromSuperview];
                    }
                    
                    // 创建新的按钮
                    UIButton *backupButton = [UIButton buttonWithType:UIButtonTypeSystem];
                    [backupButton setTitle:@"备份" forState:UIControlStateNormal];
                    backupButton.frame = CGRectMake(0, 0, 60, 30);
                    backupButton.layer.cornerRadius = 8;
                    backupButton.backgroundColor = [UIColor systemBlueColor];
                    [backupButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    [backupButton addTarget:self action:@selector(backupSettings) forControlEvents:UIControlEventTouchUpInside];
                    cell.accessoryView = backupButton;
                }
            }
            else if ([item.key isEqualToString:@"DYYYRestoreSettings"]) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                
                if (cell) {
                    // 移除现有的开关
                    if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                        [cell.accessoryView removeFromSuperview];
                    }
                    
                    // 创建新的按钮
                    UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
                    [restoreButton setTitle:@"恢复" forState:UIControlStateNormal];
                    restoreButton.frame = CGRectMake(0, 0, 60, 30);
                    restoreButton.layer.cornerRadius = 8;
                    restoreButton.backgroundColor = [UIColor systemBlueColor];
                    [restoreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    [restoreButton addTarget:self action:@selector(restoreSettings) forControlEvents:UIControlEventTouchUpInside];
                    cell.accessoryView = restoreButton;
                }
            }
        }
    }
}

- (void)backupSettings {
    // 获取所有以DYYY开头的NSUserDefaults键值
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    NSMutableDictionary *dyyySettings = [NSMutableDictionary dictionary];

    for (NSString *key in allDefaults.allKeys) {
        if ([key hasPrefix:@"DYYY"]) {
            dyyySettings[key] = [defaults objectForKey:key];
        }
    }

    // 备份图标文件
    NSString *iconsFolderPath = [DYYYPaths iconsDir];

    NSArray *iconFileNames = @[ @"like_before.png", @"like_after.png", @"comment.png", @"unfavorite.png", @"favorite.png", @"share.png", @"qingping.png" ];

    NSMutableDictionary *iconBase64Dict = [NSMutableDictionary dictionary];

    for (NSString *iconFileName in iconFileNames) {
        NSString *iconPath = [iconsFolderPath stringByAppendingPathComponent:iconFileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
            // 读取图片数据并转换为Base64
            NSData *imageData = [NSData dataWithContentsOfFile:iconPath];
            if (imageData) {
                NSString *base64String = [imageData base64EncodedStringWithOptions:0];
                iconBase64Dict[iconFileName] = base64String;
            }
        }
    }

    // 将图标Base64数据添加到备份设置中
    if (iconBase64Dict.count > 0) {
        dyyySettings[@"DYYYIconsBase64"] = iconBase64Dict;
    }

    // 转换为JSON数据
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dyyySettings options:NSJSONWritingPrettyPrinted error:&error];

    if (error) {
        [DYYYManager showToast:@"备份失败：无法序列化设置数据"];
        return;
    }

    // 确保目录存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *backupDir = [DYYYPaths backupDir];
    NSError *directoryError = nil;
    if (![fileManager fileExistsAtPath:backupDir]) {
        [fileManager createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:&directoryError];
    }
    if (directoryError) {
        [DYYYManager showToast:[NSString stringWithFormat:@"备份失败：无法创建备份目录 %@", directoryError.localizedDescription]];
        return;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *backupFileName = [NSString stringWithFormat:@"DYYY_Backup_%@.json", timestamp];
    NSString *backupFilePath = [backupDir stringByAppendingPathComponent:backupFileName];

    BOOL success = [jsonData writeToFile:backupFilePath atomically:YES];

    if (!success) {
        [DYYYManager showToast:@"备份失败：无法写入备份文件"];
        return;
    }

    [DYYYManager showToast:[NSString stringWithFormat:@"备份成功：%@", backupFileName]];
}

- (void)restoreSettings {
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json", @"public.text"] inMode:UIDocumentPickerModeImport];
    documentPicker.allowsMultipleSelection = NO;

    NSString *backupDir = [DYYYPaths backupDir];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:backupDir]) {
        [fileManager createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (@available(iOS 13.0, *)) {
        documentPicker.directoryURL = [NSURL fileURLWithPath:backupDir isDirectory:YES];
    }

    // 强引用代理对象
    self.restorePickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
    self.restorePickerDelegate.completionBlock = ^(NSURL *url) {
        if (!url) {
            [DYYYManager showToast:@"未选择备份文件"];
            return;
        }
        
        NSData *jsonData = [NSData dataWithContentsOfURL:url];
        if (!jsonData) {
            [DYYYManager showToast:@"无法读取备份文件"];
            return;
        }

        NSError *jsonError;
        NSDictionary *dyyySettings = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
        if (jsonError || ![dyyySettings isKindOfClass:[NSDictionary class]]) {
            [DYYYManager showToast:@"备份文件格式错误"];
            return;
        }

        // 恢复图标文件
        NSDictionary *iconBase64Dict = dyyySettings[@"DYYYIconsBase64"];
        if (iconBase64Dict && [iconBase64Dict isKindOfClass:[NSDictionary class]]) {
            NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *dyyyFolderPath = [DYYYPaths iconsDir];

            // 确保DYYY文件夹存在
            if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
            }

            // 从Base64还原图标文件
            for (NSString *iconFileName in iconBase64Dict) {
                NSString *base64String = iconBase64Dict[iconFileName];
                if ([base64String isKindOfClass:[NSString class]]) {
                    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
                    if (imageData) {
                        NSString *iconPath = [dyyyFolderPath stringByAppendingPathComponent:iconFileName];
                        [imageData writeToFile:iconPath atomically:YES];
                    }
                }
            }

            NSMutableDictionary *cleanSettings = [dyyySettings mutableCopy];
            [cleanSettings removeObjectForKey:@"DYYYIconsBase64"];
            dyyySettings = cleanSettings;
        }

        // 恢复设置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in dyyySettings) {
            [defaults setObject:dyyySettings[key] forKey:key];
        }
        [defaults synchronize];

        // 在主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYManager showToast:@"设置已恢复，请重启应用以应用所有更改"];
            
            // 刷新设置界面
            [self.tableView reloadData];
        });
    };

    documentPicker.delegate = self.restorePickerDelegate;

    // iPad上的展示方式
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        documentPicker.popoverPresentationController.sourceView = self.view;
        documentPicker.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                           self.view.bounds.size.height / 2, 
                                                                           0, 0);
    }

    // 安全地呈现视图控制器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:documentPicker animated:YES completion:nil];
    });
}

#pragma mark - ABTest 配置

// 添加图标按钮点击处理方法
- (void)saveCurrentABTestData {
    NSDictionary *currentData = getCurrentABTestData();
    if (!currentData) {
        [DYYYManager showToast:@"获取ABTest数据失败"];
        return;
    }
    
    // 保存到文档目录
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [DYYYPaths abTestDir];
    NSString *configPath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_config.json"];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:currentData options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error) {
        [DYYYManager showToast:@"序列化数据失败"];
        return;
    }
    
    // 确保目录存在
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    if ([jsonData writeToFile:configPath atomically:YES]) {
        [DYYYManager showToast:@"ABTest配置已保存"];
    } else {
        [DYYYManager showToast:@"保存失败"];
    }
}

- (void)loadABTestConfigFile {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self.restorePickerDelegate;
    picker.allowsMultipleSelection = NO;
    
    self.restorePickerDelegate.completionBlock = ^(NSURL *url) {
        [self processABTestConfigFile:url];
    };
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)processABTestConfigFile:(NSURL *)url {
    NSError *error;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    
    if (error) {
        [DYYYManager showToast:@"读取文件失败"];
        return;
    }
    
    NSDictionary *configData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error) {
        [DYYYManager showToast:@"解析JSON失败"];
        return;
    }
    
    // 应用ABTest配置
    Class AWEABTestManagerClass = NSClassFromString(@"AWEABTestManager");
    if (AWEABTestManagerClass) {
        id manager = [AWEABTestManagerClass performSelector:@selector(sharedManager)];
        if ([manager respondsToSelector:@selector(setAbTestData:)]) {
            [manager performSelector:@selector(setAbTestData:) withObject:configData];
            [DYYYManager showToast:@"ABTest配置已应用"];
        }
    }
}

- (void)deleteABTestConfigFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *dyyyFolderPath = [DYYYPaths abTestDir];
    NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:jsonFilePath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:jsonFilePath error:&error];
        
        if (!error) {
            gFileExists = NO;
            gFixedABTestData = nil;
            gDataLoaded = NO;
            [DYYYManager showToast:@"ABTest配置文件已删除"];
        } else {
            [DYYYManager showToast:[NSString stringWithFormat:@"删除配置文件失败: %@", error.localizedDescription]];
        }
    } else {
        [DYYYManager showToast:@"没有找到ABTest配置文件"];
    }
}

@end
