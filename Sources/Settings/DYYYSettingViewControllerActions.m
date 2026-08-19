#import "DYYYSettingViewControllerActions.h"
#import "DYYYSettingItem.h"
#import "DYYYSettingUIComponents.h"
#import "DYYYManager.h"
#import "DYYYBottomAlertView.h"
#import "DYYYUtils.h"
#import "DYYYFloatSpeedButton.h"
#import "DYYYSwitchManager.h"
#import "DYYYABTestHook.h"
#import "DYYYSelfTest.h"
#import "DYYYPaths.h"
#import "DYYYFilterSettingsView.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <math.h>

@interface UISwitch (DYYY_FuturisticEffects)
- (void)applyFuturisticEffects;
- (void)updateFuturisticEffectsWithState:(BOOL)isOn animated:(BOOL)animated;
@end

@interface DYYYImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) void (^completionBlock)(NSDictionary *info);
@end

@interface DYYYSettingViewController ()
- (void)handleCleanCache;
- (void)backupSettings;
- (void)restoreSettings;
- (void)showColorPicker;
- (void)showImagePickerForCustomAlbum;
- (NSArray<NSIndexPath *> *)rowsForSection:(NSInteger)section;
@end

@implementation DYYYSettingViewController (Actions)

- (void)iconButtonTapped:(UIButton *)sender {
    NSInteger tag = sender.tag;
    NSInteger section = tag / 1000;
    NSInteger row = tag % 1000;
    
    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:section];
    if (row >= visibleItems.count) {
        return;
    }
    
    DYYYSettingItem *item = visibleItems[row];
    
    NSString *saveFilename = nil;
    if ([item.key isEqualToString:@"DYYYIconLikeBefore"]) {
        saveFilename = @"like_before.png";
    } else if ([item.key isEqualToString:@"DYYYIconLikeAfter"]) {
        saveFilename = @"like_after.png";
    } else if ([item.key isEqualToString:@"DYYYIconComment"]) {
        saveFilename = @"comment.png";
    } else if ([item.key isEqualToString:@"DYYYIconUnfavorite"]) {
        saveFilename = @"unfavorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconFavorite"]) {
        saveFilename = @"favorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconShare"]) {
        saveFilename = @"share.png";
    }
    
    if (saveFilename) {
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dyyyFolderPath = [DYYYPaths iconsDir];
        NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
        
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
        UIImage *previewImage = fileExists ? [UIImage imageWithContentsOfFile:imagePath] : nil;
        
        // 显示图标选择弹窗
        [self showIconOptionsDialogWithTitle:item.title previewImage:previewImage saveFilename:saveFilename];
    }
}

// 添加热更新功能实现方法

- (void)animatedSwitchToggled:(UISwitch *)sender {
    [sender applyFuturisticEffects];
    [sender updateFuturisticEffectsWithState:sender.isOn animated:YES];
    UITableViewCell *cell = (UITableViewCell *)sender.superview.superview;
    UIView *card = [cell.contentView viewWithTag:8888];
    // 卡片和switch联动弹跳+高光
    [UIView animateWithDuration:0.10 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.90, 0.90);
        sender.alpha = 0.7;
        sender.layer.shadowColor = [UIColor systemBlueColor].CGColor;
        sender.layer.shadowOpacity = 0.18;
        sender.layer.shadowRadius = 8;
        sender.layer.shadowOffset = CGSizeMake(0, 2);
        card.transform = CGAffineTransformMakeScale(0.97, 0.97);
               card.layer.shadowOpacity =0.18;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.7 options:0 animations:^{
            sender.transform = CGAffineTransformIdentity;
            sender.alpha = 1.0;
            sender.layer.shadowOpacity = 0.0;
            card.transform = CGAffineTransformIdentity;
            card.layer.shadowOpacity = 0.06;
        } completion:nil];
    }];
    [self switchToggled:sender];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 子分组标题行不打圆角 mask，保持纯文本样式
    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:indexPath.section];
    if (indexPath.row < visibleItems.count) {
        DYYYSettingItem *item = visibleItems[indexPath.row];
        if (item.type == DYYYSettingItemTypeGroupHeader) {
            cell.layer.mask = nil;
            return;
        }
    }

    CGFloat cornerRadius = 10.0;
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds
                                                  byRoundingCorners:(indexPath.row == 0 ? (UIRectCornerTopLeft | UIRectCornerTopRight) : 0) |
                                                                   (indexPath.row == [tableView numberOfRowsInSection:indexPath.section] - 1 ? (UIRectCornerBottomLeft | UIRectCornerBottomRight) : 0)
                                                        cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:indexPath.section];
    if (indexPath.row >= visibleItems.count) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    DYYYSettingItem *item = visibleItems[indexPath.row];
    
    // 子分组标题行：点击展开/折叠其条目
    if (item.type == DYYYSettingItemTypeGroupHeader) {
        [self toggleGroupHeaderAtIndexPath:indexPath];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加清理缓存功能处理
    if ([item.key isEqualToString:@"DYYYCleanCache"]) {
        [self handleCleanCache];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 一键自检功能处理
    if ([item.key isEqualToString:@"DYYYSelfTest"]) {
        [DYYYSelfTest presentFromViewController:self];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加清除设置功能
    if ([item.key isEqualToString:@"DYYYCleanSettings"]) {
        [DYYYBottomAlertView showAlertWithTitle:@"清除抖音设置"
                message:@"确定要清除抖音所有设置吗？\n这将无法恢复，应用会自动退出！"
                cancelButtonText:@"取消"
                confirmButtonText:@"确定"
                cancelAction:nil
                confirmAction:^{
                    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
                    if (paths.count > 0) {
                        NSString *preferencesPath = [paths.firstObject stringByAppendingPathComponent:@"Preferences"];
                        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
                        NSString *plistPath = [preferencesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleIdentifier]];

                        NSError *error = nil;
                        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:&error];

                        if (!error) {
                            [DYYYManager showToast:@"抖音设置已清除，应用即将退出"];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                              exit(0);
                            });
                        } else {
                            [DYYYManager showToast:[NSString stringWithFormat:@"清除失败: %@", error.localizedDescription]];
                        }
                    }
                }];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加备份设置功能处理
    if ([item.key isEqualToString:@"DYYYBackupSettings"]) {
        [self backupSettings];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加恢复设置功能处理
    if ([item.key isEqualToString:@"DYYYRestoreSettings"]) {
        [self restoreSettings];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 处理图标自定义项
    if ([item.key hasPrefix:@"DYYYIcon"]) {
        [self handleIconSelection:item];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 热更新功能处理
    if ([item.key isEqualToString:@"SaveCurrentABTestData"]) {
        [self saveCurrentABTestData];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    } else if ([item.key isEqualToString:@"LoadABTestConfigFile"]) {
        [self loadABTestConfigFile];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    } else if ([item.key isEqualToString:@"DeleteABTestConfigFile"]) {
        [self deleteABTestConfigFile];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    if (item.type == DYYYSettingItemTypeChoice) {
        [self showChoiceForItem:item fromIndexPath:indexPath];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    if (item.type == DYYYSettingItemTypeSlider) {
        [self showSliderForItem:item fromIndexPath:indexPath];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    if (item.type == DYYYSettingItemTypeCustomPicker && [item.key isEqualToString:@"DYYYScheduleStyle"]) {
        if (!DYYYCachedBool(@"DYYYisShowScheduleDisplay")) {
            [DYYYManager showToast:@"请先开启\"显示进度时长\"选项"];
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择进度条样式"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray *styles = @[
            @{@"title": @"进度条右侧剩余", @"value": @"进度条右侧剩余"},
            @{@"title": @"进度条右侧完整", @"value": @"进度条右侧完整"},
            @{@"title": @"进度条左侧剩余", @"value": @"进度条左侧剩余"},
            @{@"title": @"进度条左侧完整", @"value": @"进度条左侧完整"},
            @{@"title": @"进度条两侧左右", @"value": @"进度条两侧左右"}
        ];
        for (NSDictionary *style in styles) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:style[@"title"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] setObject:style[@"value"] forKey:@"DYYYScheduleStyle"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [self.tableView reloadData];
            }];
            [alert addAction:action];
        }
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
            alert.popoverPresentationController.sourceView = selectedCell;
            alert.popoverPresentationController.sourceRect = selectedCell.bounds;
        }
        [self presentViewController:alert animated:YES completion:nil];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    if (item.type == DYYYSettingItemTypeSpeedPicker) {
        [self showSpeedPicker];
    } else if (item.type == DYYYSettingItemTypeColorPicker) {
        [self showColorPicker];
    } else if ([item.key isEqualToString:@"DYYYfilterKeywords"]) {
        // 获取当前已保存的关键词
        NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"];
        
        // 创建并显示过滤设置视图
        DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"设置过滤关键词" text:currentKeywords];
        [filterView showWithConfirmBlock:^(NSString *selectedText) {
            [[NSUserDefaults standardUserDefaults] setObject:selectedText forKey:@"DYYYfilterKeywords"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        } cancelBlock:nil];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)handleIconSelection:(DYYYSettingItem *)item {
    NSString *saveFilename = nil;
    
    // 映射图标类型到文件名
    if ([item.key isEqualToString:@"DYYYIconLikeBefore"]) {
        saveFilename = @"like_before.png";
    } else if ([item.key isEqualToString:@"DYYYIconLikeAfter"]) {
        saveFilename = @"like_after.png";
    } else if ([item.key isEqualToString:@"DYYYIconComment"]) {
        saveFilename = @"comment.png";
    } else if ([item.key isEqualToString:@"DYYYIconUnfavorite"]) {
        saveFilename = @"unfavorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconFavorite"]) {
        saveFilename = @"favorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconShare"]) {
        saveFilename = @"share.png";
    }
    
    if (saveFilename) {
        // 获取图标路径
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dyyyFolderPath = [DYYYPaths iconsDir];
        NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
        
        // 检查是否已有自定义图标
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
        UIImage *previewImage = fileExists ? [UIImage imageWithContentsOfFile:imagePath] : nil;
        
        // 显示图标选项对话框
        [self showIconOptionsDialogWithTitle:item.title previewImage:previewImage saveFilename:saveFilename];
    }
}

// 添加这个辅助方法
- (void)showIconOptionsDialogWithTitle:(NSString *)title previewImage:(UIImage *)previewImage saveFilename:(NSString *)saveFilename {
    DYYYIconOptionsDialogView *optionsDialog = [[DYYYIconOptionsDialogView alloc] initWithTitle:title previewImage:previewImage];
    
    // 确保DYYY文件夹存在
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [DYYYPaths iconsDir];
    NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    __weak typeof(self) weakSelf = self;
    
    // 设置清除按钮回调
    optionsDialog.onClear = ^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:imagePath error:&error];
            if (!error) {
                [DYYYManager showToast:@"已恢复默认图标"];
                [weakSelf.tableView reloadData];
            }
        }
    };
    
    // 设置选择按钮回调
    optionsDialog.onSelect = ^{
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.allowsEditing = NO;
        picker.mediaTypes = @[@"public.image"];
        DYYYImagePickerDelegate *pickerDelegate = [[DYYYImagePickerDelegate alloc] init];
        pickerDelegate.completionBlock = ^(NSDictionary *info) {
            NSURL *imageURL = info[UIImagePickerControllerImageURL];
            if (!imageURL) {
                imageURL = info[UIImagePickerControllerReferenceURL];
            }
            
            if (imageURL) {
                NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
                if (imageData) {
                    // 检测是否为GIF
                    const char *bytes = (const char *)imageData.bytes;
                    BOOL isGIF = (imageData.length >= 6 && (memcmp(bytes, "GIF87a", 6) == 0 || memcmp(bytes, "GIF89a", 6) == 0));
                    
                    if (isGIF) {
                        [imageData writeToFile:imagePath atomically:YES];
                    } else {
                        UIImage *selectedImage = [UIImage imageWithData:imageData];
                        NSData *pngData = UIImagePNGRepresentation(selectedImage);
                        [pngData writeToFile:imagePath atomically:YES];
                    }
                    
                    [DYYYManager showToast:@"图标已设置，重启应用生效"];
                    [weakSelf.tableView reloadData];
                }
            }
        };
        
        static char kDYYYPickerDelegateKey;
        picker.delegate = pickerDelegate;
        objc_setAssociatedObject(picker, &kDYYYPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [weakSelf presentViewController:picker animated:YES completion:nil];
    };
    
    [optionsDialog show];
}

- (void)showChoiceForItem:(DYYYSettingItem *)item fromIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item.title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [item.options enumerateObjectsUsingBlock:^(NSString *option, NSUInteger index, BOOL *stop) {
        [alert addAction:[UIAlertAction actionWithTitle:option
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)index forKey:item.key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }]];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = selectedCell;
        alert.popoverPresentationController.sourceRect = selectedCell.bounds;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSliderForItem:(DYYYSettingItem *)item fromIndexPath:(NSIndexPath *)indexPath {
    NSNumber *stored = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    NSInteger value = stored ? stored.integerValue : item.defaultInteger;
    if (value < 0) value = 0;
    if (value > 100) value = 100;

    DYYYSliderViewController *sliderController =
        [[DYYYSliderViewController alloc] initWithTitle:item.title
                                                  value:value
                                             completion:^(NSInteger percent) {
        if (percent < 0) percent = 0;
        if (percent > 100) percent = 100;
        [[NSUserDefaults standardUserDefaults] setInteger:percent forKey:item.key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                                             }];
    [self presentViewController:sliderController animated:YES completion:nil];
}

- (void)showSpeedPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择倍速"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *speeds = @[@0.75, @1.0, @1.25, @1.5, @2.0, @2.5, @3.0];
    for (NSNumber *speed in speeds) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%.2f", speed.floatValue]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setFloat:speed.floatValue forKey:@"DYYYDefaultSpeed"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            for (NSInteger section = 0; section < self.settingSections.count; section++) {
                NSArray *items = self.settingSections[section];
                for (NSInteger row = 0; row < items.count; row++) {
                    DYYYSettingItem *item = items[row];
                    if (item.type == DYYYSettingItemTypeSpeedPicker) {
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                        UITextField *speedField = [cell.accessoryView viewWithTag:999];
                        if (speedField) {
                            speedField.text = [NSString stringWithFormat:@"%.2f", speed.floatValue];
                        }
                        break;
                    }
                }
            }
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:[self.tableView indexPathForSelectedRow]];
        alert.popoverPresentationController.sourceView = selectedCell;
        alert.popoverPresentationController.sourceRect = selectedCell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    // 添加防崩溃检查
    if (!sender) {
        return;
    }
    
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;

    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:section];
    if (row < 0 || row >= visibleItems.count) {
        return;
    }

    DYYYSettingItem *item = visibleItems[row];
    if (!item) {
        return;
    }

    // 使用开关管理器处理切换逻辑
    [[DYYYSwitchManager sharedManager] handleSwitchToggled:sender 
                                                  withItem:item 
                                                   section:section 
                                                       row:row
                                                 tableView:self.tableView
                                          settingSections:self.settingSections];

    // 触觉反馈
    [self.feedbackGenerator impactOccurred];

    // 进度时长依赖处理
    if ([item.key isEqualToString:@"DYYYisShowScheduleDisplay"]) {
        // 关闭时，清空样式设置
        if (!sender.isOn) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYScheduleStyle"];
        }
        // 刷新相关cell
        for (NSInteger s = 0; s < self.settingSections.count; s++) {
            NSArray *items = self.settingSections[s];
            for (NSInteger r = 0; r < items.count; r++) {
                DYYYSettingItem *subItem = items[r];
                if ([subItem.key isEqualToString:@"DYYYScheduleStyle"]) {
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
                    [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        }
    }

    // 安全地同步设置
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)updateClearButtonSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<NSString *> *subKeys = @[
        @"DYYYHideDanmaku",
        @"DYYYEnabshijianjindu", 
        @"DYYYHideTimeProgress",
        @"DYYYHideSlider",
        @"DYYYHideTabBar",
        @"DYYYHideSpeed"
    ];
    
    // 使用 DYYYSwitchManager 的方法
    [[DYYYSwitchManager sharedManager] updateSubSwitchesInSection:section 
                                                         withKeys:subKeys 
                                                          enabled:enabled 
                                                        tableView:self.tableView 
                                                 settingSections:self.settingSections];
}

- (void)updateLongPressSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<NSString *> *subKeys = @[
        @"DYYYLongPressSaveVideo",
        @"DYYYLongPressSaveAudio",
        @"DYYYEnableFLEX",
        @"DYYYLongPressSaveCurrentImage",
        @"DYYYLongPressSaveAllImages",
        @"DYYYLongPressCopyLink",
        @"DYYYLongPressApiDownload",
        @"DYYYLongPressFilterUser",
        @"DYYYLongPressFilterTitle",
        @"DYYYLongPressTimerClose",
        @"DYYYLongPressCreateVideo"
    ];
    
    // 使用 DYYYSwitchManager 的方法
    [[DYYYSwitchManager sharedManager] updateSubSwitchesInSection:section 
                                                         withKeys:subKeys 
                                                          enabled:enabled 
                                                        tableView:self.tableView 
                                                 settingSections:self.settingSections];
}

- (void)textFieldDidChange:(UITextField *)textField {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:textField.tag % 1000 inSection:textField.tag / 1000];
    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:indexPath.section];
    if (indexPath.row >= visibleItems.count) {
        return;
    }
    
    DYYYSettingItem *item = visibleItems[indexPath.row];
    
    // 添加对链接解析接口的特殊处理
    if ([item.key isEqualToString:@"DYYYInterfaceDownload"]) {
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (text.length == 0) {
            textField.text = @"https://api.qsy.ink/api/douyin?key=DYYY&url=";
            [[NSUserDefaults standardUserDefaults] setObject:@"https://api.qsy.ink/api/douyin?key=DYYY&url=" forKey:item.key];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
        }
    } 
    // 倍速数值设置的特殊处理
    else if ([item.key isEqualToString:@"DYYYSpeedSettings"]) {
        NSString *speedConfig = textField.text;
        if (speedConfig.length == 0) {
            speedConfig = @"1.0,1.25,1.5,2.0";
            textField.text = speedConfig;
        }
        [[NSUserDefaults standardUserDefaults] setObject:speedConfig forKey:item.key];
        [DYYYManager showToast:@"倍速选项已更新"];
    }
    // 倍速按钮大小的特殊处理
    else if ([item.key isEqualToString:@"DYYYSpeedButtonSize"]) {
        NSString *sizeStr = textField.text;
        if (sizeStr.length == 0 || [sizeStr floatValue] <= 0) {
            sizeStr = @"40";
            textField.text = sizeStr;
        }
        [[NSUserDefaults standardUserDefaults] setObject:sizeStr forKey:item.key];
        [DYYYManager showToast:@"倍速按钮大小已更新"];
    } 
    else {
        [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 在设置值保存后添加：
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYSettingChanged" object:nil userInfo:@{
        @"key": item.key,
        @"value": textField.text ?: [NSNull null]
    }];
    
    // 处理特殊键
    if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
        [self showImagePickerForCustomAlbum];
    }
}

- (void)avatarTextFieldDidChange:(UITextField *)textField {
    self.avatarTapLabel.text = textField.text.length > 0 ? textField.text : @"pxx917144686";
}

- (void)headerTapped:(UIButton *)sender {
    // 触发触觉反馈
    [self.feedbackGenerator impactOccurred];
    [self.feedbackGenerator prepare];
    
    NSInteger section = sender.tag;
    if (self.isSearching) {
        return; // 搜索模式下分区行恒显示，不参与折叠切换，避免污染普通模式状态
    }
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return;
    }
    
    BOOL isCurrentExpanded = [self.expandedSections containsObject:@(section)];
    
    // 获取所有需要更新的行信息 - 在修改expandedSections之前
    NSMutableArray<NSIndexPath *> *allRowsToUpdate = [NSMutableArray array];
    NSMutableArray<NSNumber *> *sectionsToUpdate = [NSMutableArray array];
    
    // 收集当前要点击的section的所有行
    NSArray<NSIndexPath *> *currentSectionRows = [self rowsForSection:section];
    [allRowsToUpdate addObjectsFromArray:currentSectionRows];
    [sectionsToUpdate addObject:@(section)];
    
    // 如果当前section不是展开的，需要收集其他已展开section的所有行
    if (!isCurrentExpanded) {
        for (NSNumber *expandedSection in [self.expandedSections copy]) {
            if (![expandedSection isEqualToNumber:@(section)]) {
                NSArray<NSIndexPath *> *expandedSectionRows = [self rowsForSection:[expandedSection integerValue]];
                [allRowsToUpdate addObjectsFromArray:expandedSectionRows];
                [sectionsToUpdate addObject:expandedSection];
            }
        }
        
        // 清空已展开sections，只保留当前section
        [self.expandedSections removeAllObjects];
        [self.expandedSections addObject:@(section)];
    } else {
        // 当前section已展开，需要将其关闭
        [self.expandedSections removeObject:@(section)];
    }
    
    // 更新所有涉及的section头部箭头
    for (NSNumber *sectionNumber in sectionsToUpdate) {
        NSInteger sectionIndex = [sectionNumber integerValue];
        UIView *headerView = [self.tableView headerViewForSection:sectionIndex];
        UIButton *headerButton = [headerView viewWithTag:sectionIndex];
        UIImageView *arrow = [headerButton viewWithTag:100];
        
        BOOL shouldBeExpanded = [self.expandedSections containsObject:sectionNumber];
        
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
            arrow.image = [[UIImage systemImageNamed:shouldBeExpanded ? @"chevron.down" : @"chevron.right"] imageWithConfiguration:config];
        } else {
            arrow.image = [UIImage systemImageNamed:shouldBeExpanded ? @"chevron.down" : @"chevron.right"];
        }
        
        // 动画过渡效果
        [UIView animateWithDuration:0.3 animations:^{
            arrow.transform = shouldBeExpanded ? CGAffineTransformMakeRotation(M_PI/2) : CGAffineTransformIdentity;
        }];
    }
    
    // 简单方式：直接刷新表格而不是试图追踪单独的行操作
    [self.tableView reloadData];
    
    // 如果展开了某个section，让表格视图滚动到该section的位置
    if (!isCurrentExpanded) {
        NSIndexPath *firstRowPath = [NSIndexPath indexPathForRow:0 inSection:section];
        if ([self.tableView numberOfRowsInSection:section] > 0) {
            [self.tableView scrollToRowAtIndexPath:firstRowPath 
                                  atScrollPosition:UITableViewScrollPositionTop 
                                          animated:YES];
        }
    }
}

// 添加主标题文字间距调整

@end
