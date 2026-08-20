//
//  DYYYSettingViewControllerPresentation.m
//  DYYY
//
//  颜色选择、样式选择、源码弹窗、长按和重置，以及图标选项弹窗视图。
//

#import "DYYYSettingViewController.h"
#import "DYYYSettingViewControllerPrivate.h"
#import "DYYYSettingItem.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYSwitchManager.h"
#import <objc/runtime.h>

@implementation DYYYIconOptionsDialogView

- (instancetype)initWithTitle:(NSString *)title previewImage:(UIImage *)previewImage {
    self = [super init];
    if (self) {
        // 基本设置
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        
        // 创建内容视图
        UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(50, 200, self.bounds.size.width - 100, 300)];
        contentView.backgroundColor = [UIColor systemBackgroundColor];
        contentView.layer.cornerRadius = 15;
        contentView.clipsToBounds = YES;
        
        // 标题标签
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, contentView.bounds.size.width - 40, 30)];
        titleLabel.text = title;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [contentView addSubview:titleLabel];
        
        // 预览图片视图
        if (previewImage) {
            UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:CGRectMake((contentView.bounds.size.width - 100) / 2, 60, 100, 100)];
            previewImageView.image = previewImage;
            previewImageView.contentMode = UIViewContentModeScaleAspectFit;
            previewImageView.layer.cornerRadius = 10;
            previewImageView.clipsToBounds = YES;
            [contentView addSubview:previewImageView];
        }
        
        // 按钮容器
        UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 180, contentView.bounds.size.width - 40, 80)];
        
        // 清除按钮
        UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
        clearButton.frame = CGRectMake(0, 0, (buttonContainer.bounds.size.width - 10) / 2, 35);
        [clearButton setTitle:@"清除" forState:UIControlStateNormal];
        clearButton.backgroundColor = [UIColor systemRedColor];
        [clearButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        clearButton.layer.cornerRadius = 8;
        [clearButton addTarget:self action:@selector(clearButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [buttonContainer addSubview:clearButton];
        
        // 选择按钮
        UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
        selectButton.frame = CGRectMake((buttonContainer.bounds.size.width + 10) / 2, 0, (buttonContainer.bounds.size.width - 10) / 2, 35);
        [selectButton setTitle:@"选择" forState:UIControlStateNormal];
        selectButton.backgroundColor = [UIColor systemBlueColor];
        [selectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        selectButton.layer.cornerRadius = 8;
        [selectButton addTarget:self action:@selector(selectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [buttonContainer addSubview:selectButton];
        
        // 取消按钮
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelButton.frame = CGRectMake(0, 45, buttonContainer.bounds.size.width, 35);
        [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        cancelButton.backgroundColor = [UIColor systemGrayColor];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        cancelButton.layer.cornerRadius = 8;
        [cancelButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [buttonContainer addSubview:cancelButton];
        
        [contentView addSubview:buttonContainer];
        [self addSubview:contentView];
    }
    return self;
}

- (void)show {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self];
    
    self.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
    }];
}

- (void)clearButtonTapped {
    [self dismiss];
    if (self.onClear) {
        self.onClear();
    }
}

- (void)selectButtonTapped {
    [self dismiss];
    if (self.onSelect) {
        self.onSelect();
    }
}

- (void)cancelButtonTapped {
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

@implementation DYYYSettingViewController (Presentation)

#pragma mark - Color Picker

- (void)showColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
        UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
        picker.selectedColor = currentColor;
        picker.delegate = (id)self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择背景颜色"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray<NSDictionary *> *colors = @[
            @{@"name": @"粉红", @"color": [UIColor systemRedColor]},
            @{@"name": @"蓝色", @"color": [UIColor systemBlueColor]},
            @{@"name": @"绿色", @"color": [UIColor systemGreenColor]},
            @{@"name": @"黄色", @"color": [UIColor systemYellowColor]},
            @{@"name": @"紫色", @"color": [UIColor systemPurpleColor]},
            @{@"name": @"橙色", @"color": [UIColor systemOrangeColor]},
            @{@"name": @"粉色", @"color": [UIColor systemPinkColor]},
            @{@"name": @"灰色", @"color": [UIColor systemGrayColor]},
            @{@"name": @"白色", @"color": [UIColor whiteColor]},
            @{@"name": @"黑色", @"color": [UIColor blackColor]}
        ];
        for (NSDictionary *colorInfo in colors) {
            NSString *name = colorInfo[@"name"];
            UIColor *color = colorInfo[@"color"];
            UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                self.backgroundColorView.backgroundColor = color;
                NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
                [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                NSIndexPath *indexPath = [self visibleIndexPathForSettingKey:@"DYYYBackgroundColor"];
                if (indexPath) {
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                          withRowAnimation:UITableViewRowAnimationFade];
                }
            }];
            UIImage *colorImage = [self imageWithColor:color size:CGSizeMake(20, 20)];
            [action setValue:colorImage forKey:@"image"];
            [alert addAction:action];
        }
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = self.tableView.bounds;
        }
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 支持 UIColorPickerViewController 回调
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    UIColor *color = viewController.selectedColor;
    self.backgroundColorView.backgroundColor = color;
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // 通知弹窗刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYBackgroundColorChanged" object:nil];
    NSIndexPath *indexPath = [self visibleIndexPathForSettingKey:@"DYYYBackgroundColor"];
    if (indexPath) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    [self colorPickerViewControllerDidSelectColor:viewController];
}
#endif

- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [color setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, size.width - 2, size.height - 2)];
    path.lineWidth = 1.0;
    [path fill];
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - 长按与重置

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (!indexPath) {
            return;
        }
        
        NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:indexPath.section];
        if (indexPath.row >= visibleItems.count) {
            return;
        }
        
        DYYYSettingItem *item = visibleItems[indexPath.row];
        
        // 子分组标题行不响应长按
        if (item.type == DYYYSettingItemTypeGroupHeader) {
            return;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选项"
                                                                      message:item.title
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
        
        if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
            [alert addAction:[UIAlertAction actionWithTitle:@"从相册选择"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary forCustomAlbum:YES];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"使用相机"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera forCustomAlbum:YES];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认图片"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomAlbumImagePath"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:@"自定义相册图片已设置"];
                [self.tableView reloadData];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
            }]];
        }
        
        // 默认重置选项
        UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"重置"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:item.key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // 特殊处理清屏按钮尺寸重置
            if ([item.key isEqualToString:@"DYYYEnableFloatClearButton"] || 
                [item.key isEqualToString:@"DYYYFloatClearButtonSizePreference"]) {
                [[NSUserDefaults standardUserDefaults] setInteger:DYYYButtonSizeMedium 
                                                           forKey:@"DYYYFloatClearButtonSizePreference"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            // 特殊处理日期时间格式相关设置
            if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
                // 重置主开关也重置所有子开关和格式设置
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                
                // 使用 DYYYSwitchManager 的方法更新UI中子开关的状态
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [[DYYYSwitchManager sharedManager] updateDateTimeFormatSubSwitchesUI:section 
                                                                                 enabled:NO 
                                                                               tableView:self.tableView 
                                                                         settingSections:self.settingSections];
                }
            }
            else if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
                // 重置一个子开关时检查是否有其他子开关启用
                BOOL anyEnabled = NO;
                for (NSString *checkKey in @[@"DYYYDateTimeFormat_YMDHM", @"DYYYDateTimeFormat_MDHM", 
                                             @"DYYYDateTimeFormat_HMS", @"DYYYDateTimeFormat_HM", 
                                             @"DYYYDateTimeFormat_YMD"]) {
                    if (![checkKey isEqualToString:item.key] && [[NSUserDefaults standardUserDefaults] boolForKey:checkKey]) {
                        anyEnabled = YES;
                        break;
                    }
                }
                
                // 如果所有子开关都关闭，也关闭主开关并清除格式
                if (!anyEnabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                    for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                        [[DYYYSwitchManager sharedManager] updateDateTimeFormatMainSwitchUI:section 
                                                                                  tableView:self.tableView 
                                                                           settingSections:self.settingSections];
                    }
                }
            }
            
            // 特殊处理时间属地显示开关组
            if ([item.key isEqualToString:@"DYYYisEnableArea"]) {
                // 重置主开关也重置所有子开关
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaProvince"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaCity"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaDistrict"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaStreet"];
                
                // 使用 DYYYSwitchManager 的方法更新UI
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [[DYYYSwitchManager sharedManager] updateAreaSubSwitchesUI:section 
                                                                       enabled:NO 
                                                                     tableView:self.tableView 
                                                               settingSections:self.settingSections];
                }
            }
            
            // 针对自定义相册图片和大小，重置后刷新按钮
            if ([item.key isEqualToString:@"DYYYCustomAlbumImagePath"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
                [item.key isEqualToString:@"DYYYEnableCustomAlbum"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
            }
            
            // 处理头像文本
            if ([item.key isEqualToString:@"DYYYAvatarTapText"]) {
                self.avatarTapLabel.text = @"pxx917144686";
            }
            
            // 刷新UI
            [self.tableView reloadData];
            
            // 显示提示
            [DYYYManager showToast:[NSString stringWithFormat:@"已重置: %@", item.title]];
            NSLog(@"DYYY: Reset %@", item.key);
        }];
        
        // 重置操作到弹出菜单
        [alert addAction:resetAction];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = CGRectMake(point.x, point.y, 1, 1);
        }
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)showImagePickerForCustomAlbum {
    // 检查自定义选择相册图片功能是否启用
    if (!DYYYCachedBool(@"DYYYEnableCustomAlbum")) {
        [DYYYManager showToast:@"请先开启「自定义选择相册图片」"];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择图片来源" 
                                                                  message:nil 
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"相册" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary forCustomAlbum:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"相机" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera forCustomAlbum:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomAlbumImagePath"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [DYYYManager showToast:@"已恢复默认相册图片"];
        [self.tableView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                   self.view.bounds.size.height / 2, 
                                                                   0, 0);
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType forCustomAlbum:(BOOL)isCustomAlbum {
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) {
        [DYYYManager showToast:@"设备不支持该图片来源"];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    picker.allowsEditing = YES;
    
    objc_setAssociatedObject(picker, "isCustomAlbumPicker", isCustomAlbum ? @YES : @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetButtonTapped:(UIButton *)sender {
    NSString *key = sender.accessibilityLabel;
    if (!key) return;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 特殊处理清屏按钮尺寸重置
    if ([key isEqualToString:@"DYYYEnableFloatClearButton"] || 
        [key isEqualToString:@"DYYYFloatClearButtonSizePreference"]) {
        [[NSUserDefaults standardUserDefaults] setInteger:DYYYButtonSizeMedium 
                                                           forKey:@"DYYYFloatClearButtonSizePreference"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 特殊处理日期时间格式相关设置
    if ([key isEqualToString:@"DYYYShowDateTime"]) {
        // 重置主开关也重置所有子开关和格式设置
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
        
        // 使用 DYYYSwitchManager 的方法更新UI中子开关的状态
        for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
            [[DYYYSwitchManager sharedManager] updateDateTimeFormatSubSwitchesUI:section 
                                                                         enabled:NO 
                                                                       tableView:self.tableView 
                                                                 settingSections:self.settingSections];
        }
    }
    else if ([key hasPrefix:@"DYYYDateTimeFormat_"]) {
        // 重置一个子开关时检查是否有其他子开关启用
        BOOL anyEnabled = NO;
        for (NSString *checkKey in @[@"DYYYDateTimeFormat_YMDHM", @"DYYYDateTimeFormat_MDHM", 
                                     @"DYYYDateTimeFormat_HMS", @"DYYYDateTimeFormat_HM", 
                                     @"DYYYDateTimeFormat_YMD"]) {
            if (![checkKey isEqualToString:key] && [[NSUserDefaults standardUserDefaults] boolForKey:checkKey]) {
                anyEnabled = YES;
                break;
            }
        }
        
        // 如果所有子开关都关闭，也关闭主开关并清除格式
        if (!anyEnabled) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
            for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                [[DYYYSwitchManager sharedManager] updateDateTimeFormatMainSwitchUI:section 
                                                                          tableView:self.tableView 
                                                                   settingSections:self.settingSections];
            }
        }
    }
    
    // 特殊处理时间属地显示开关组
    if ([key isEqualToString:@"DYYYisEnableArea"]) {
        // 重置主开关也重置所有子开关
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaProvince"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaCity"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaDistrict"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaStreet"];
        
        // 使用 DYYYSwitchManager 的方法更新UI
        for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
            [[DYYYSwitchManager sharedManager] updateAreaSubSwitchesUI:section 
                                                               enabled:NO 
                                                             tableView:self.tableView 
                                                       settingSections:self.settingSections];
        }
    }
    
    // 针对自定义相册图片和大小，重置后刷新按钮
    if ([key isEqualToString:@"DYYYCustomAlbumImagePath"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
        [key isEqualToString:@"DYYYEnableCustomAlbum"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
    }
    
    // 处理头像文本
    if ([key isEqualToString:@"DYYYAvatarTapText"]) {
        self.avatarTapLabel.text = @"pxx917144686";
    }
    
    // 刷新UI
    [self.tableView reloadData];
    
    // 显示提示
    [DYYYManager showToast:[NSString stringWithFormat:@"已重置: %@", key]];
}

- (void)showSourceCodePopup {
    NSString *githubURL = @"https://github.com/pxx917144686/DYYY";
    
    // 添加跳转前的动画效果
    CAKeyframeAnimation *pulseAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.values = @[@1.0, @1.08, @1.0];
    pulseAnimation.keyTimes = @[@0, @0.5, @1.0];
    pulseAnimation.duration = 0.5;
    pulseAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    
    UIButton *sourceCodeButton = (UIButton *)[self.tableView.tableFooterView viewWithTag:101];
    [sourceCodeButton.layer addAnimation:pulseAnimation forKey:@"pulse"];
    
    // 跳转到GitHub页面
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:githubURL] options:@{} completionHandler:nil];
}

- (void)showScheduleStylePicker {
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
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 辅助方法用于显示更简短的样式名称
- (NSString *)getShortNameForStyleValue:(NSString *)styleValue {
    if ([styleValue isEqualToString:@"进度条右侧剩余"]) return @"右侧剩余";
    if ([styleValue isEqualToString:@"进度条右侧完整"]) return @"右侧完整";
    if ([styleValue isEqualToString:@"进度条左侧剩余"]) return @"左侧剩余";
    if ([styleValue isEqualToString:@"进度条左侧完整"]) return @"左侧完整";
    if ([styleValue isEqualToString:@"进度条两侧左右"]) return @"两侧左右";
    return styleValue;
}

@end
