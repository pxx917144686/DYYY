#import "DYYYSwitchManager.h"
#import "DYYYManager.h"

// 前向声明
@interface DYYYSettingItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, strong) NSString *placeholder;
@end

// 全局锁来保护设置修改
static NSLock *settingsLock = nil;

@implementation DYYYSwitchManager

+ (void)initialize {
    if (self == [DYYYSwitchManager class]) {
        settingsLock = [[NSLock alloc] init];
    }
}

+ (instancetype)sharedManager {
    static DYYYSwitchManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DYYYSwitchManager alloc] init];
    });
    return instance;
}

- (void)handleSwitchToggled:(UISwitch *)sender 
                  withItem:(DYYYSettingItem *)item 
                   section:(NSInteger)section 
                       row:(NSInteger)row
                 tableView:(UITableView *)tableView
          settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    if (!sender || !item) {
        return;
    }
    
    @try {
        // 保存设置值
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:item.key];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // 处理特殊开关类型
        [self handleSpecialSwitchTypes:item sender:sender section:section tableView:tableView settingSections:settingSections];

        // 互斥逻辑：按钮大/中/小只能选一个
        if (([item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
             [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
             [item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"]) && sender.isOn) {
            [self updateMutuallyExclusiveSwitches:section 
                                  excludingItemKey:item.key 
                                         tableView:tableView 
                                  settingSections:settingSections];
        }

        // 清屏功能总开关 - 只在从关闭变为打开时自动开启所有子功能
        if ([item.key isEqualToString:@"DYYYEnableFloatClearButton"] && sender.isOn) {
            NSArray<NSString *> *subKeys = @[
                @"DYYYHideDanmaku",
                @"DYYYEnabshijianjindu",
                @"DYYYHideTimeProgress",
                @"DYYYHideSlider",
                @"DYYYHideTabBar",
                @"DYYYHideSpeed"
            ];
            [self updateSubSwitchesInSection:section 
                                    withKeys:subKeys 
                                     enabled:YES
                                   tableView:tableView 
                            settingSections:settingSections];
        }

        // 处理功能提示
        [self showToastForItem:item enabled:sender.isOn];

        // 处理开关依赖关系
        [self updateSwitchDependencies:item.key 
                             isEnabled:sender.isOn 
                               section:section
                             tableView:tableView 
                      settingSections:settingSections];

        // 发送设置变更通知
        [self postSettingChangeNotification:item.key enabled:sender.isOn];

    } @catch (NSException *exception) {
        NSLog(@"开关切换失败: %@", exception);
        // 恢复开关状态
        sender.on = !sender.on;
    }
}

- (void)handleSpecialSwitchTypes:(DYYYSettingItem *)item 
                          sender:(UISwitch *)sender
                         section:(NSInteger)section
                       tableView:(UITableView *)tableView
                settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    // 处理属地显示子开关的特殊逻辑
    if ([item.key hasPrefix:@"DYYYisEnableArea"] && ![item.key isEqualToString:@"DYYYisEnableArea"]) {
        BOOL parentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
        sender.enabled = parentEnabled;
        
        NSArray<NSString *> *areaSubKeys = @[
            @"DYYYisEnableAreaProvince",
            @"DYYYisEnableAreaCity", 
            @"DYYYisEnableAreaDistrict", 
            @"DYYYisEnableAreaStreet"
        ];
        
        if ([areaSubKeys containsObject:item.key]) {
            // 检查是否有任何子开关启用
            BOOL anyEnabled = NO;
            for (NSString *key in areaSubKeys) {
                if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                    anyEnabled = YES;
                    break;
                }
            }
            
            if (anyEnabled && parentEnabled) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:item.key];
                sender.on = YES;
            } else {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:item.key];
                sender.on = NO;
            }
        } else {
            BOOL isOn = parentEnabled ? [[NSUserDefaults standardUserDefaults] boolForKey:item.key] : NO;
            sender.on = isOn;
        }
    }
    
    // 处理日期时间格式的互斥逻辑
    if ([item.key hasPrefix:@"DYYYDateTimeFormat_"] && sender.isOn) {
        [self updateDateTimeFormatExclusiveSwitch:section currentKey:item.key tableView:tableView settingSections:settingSections];
        
        // 确保主开关也开启
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYShowDateTime"];
        [self updateDateTimeFormatMainSwitchUI:section tableView:tableView settingSections:settingSections];
    }
    
    // 处理ABTest功能
    if ([item.key isEqualToString:@"DYYYABTestBlockEnabled"]) {
        [self handleABTestBlockEnabled:sender.isOn];
    } else if ([item.key isEqualToString:@"DYYYABTestPatchEnabled"]) {
        [self handleABTestPatchEnabled:sender.isOn];
    }
}

- (void)updateMutuallyExclusiveSwitches:(NSInteger)section 
                        excludingItemKey:(NSString *)excludedKey
                               tableView:(UITableView *)tableView
                        settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    if (section >= settingSections.count) {
        return;
    }
    
    NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        if (([item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
             [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
             [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"]) &&
            ![item.key isEqualToString:excludedKey]) {
            
            // 先更新数据
            [defaults setBool:NO forKey:item.key];
            
            // 再更新UI（如果cell可见）
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
            if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *cellSwitch = (UISwitch *)cell.accessoryView;
                cellSwitch.on = NO;
            }
        }
    }
    [defaults synchronize];
}

- (void)updateSubSwitchesInSection:(NSInteger)section 
                          withKeys:(NSArray<NSString *> *)keys 
                           enabled:(BOOL)enabled
                         tableView:(UITableView *)tableView
                  settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    if (section >= settingSections.count) {
        return;
    }
    
    [settingsLock lock]; // 加锁保护
    
    @try {
        // 获取当前section的items
        NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
        
        // 先更新数据
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in keys) {
            [defaults setBool:enabled forKey:key];
        }
        [defaults synchronize];
        
        // 再更新UI
        for (NSUInteger row = 0; row < sectionItems.count; row++) {
            DYYYSettingItem *item = sectionItems[row];
            
            if ([keys containsObject:item.key]) {
                NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
                
                if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                    UISwitch *switchControl = (UISwitch *)cell.accessoryView;
                    switchControl.on = enabled;
                }
            }
        }
    }
    @finally {
        [settingsLock unlock];
    }
}

- (void)updateSwitchDependencies:(NSString *)key 
                       isEnabled:(BOOL)enabled 
                         section:(NSInteger)section
                       tableView:(UITableView *)tableView
                settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    if (section >= settingSections.count) {
        return;
    }
    
    // 处理清屏功能子选项
    if ([key isEqualToString:@"DYYYEnableFloatClearButton"]) {
        NSArray<NSString *> *subKeys = @[
            @"DYYYHideDanmaku",
            @"DYYYEnabshijianjindu", 
            @"DYYYHideTimeProgress",
            @"DYYYHideSlider",
            @"DYYYHideTabBar",
            @"DYYYHideSpeed"
        ];
        // 注意：这里不再自动更新子开关，只在总开关开启时才更新
        if (enabled) {
            [self updateSubSwitchesInSection:section 
                                    withKeys:subKeys 
                                     enabled:enabled
                                   tableView:tableView 
                            settingSections:settingSections];
        }
    }
    // 处理长按功能子选项
    else if ([key isEqualToString:@"DYYYLongPressDownload"]) {
        NSArray<NSString *> *subKeys = @[
            @"DYYYLongPressSaveVideo",
            @"DYYYLongPressSaveAudio", 
            @"DYYYEnableFLEX",
            @"DYYYLongPressPip",
            @"DYYYLongPressSaveCurrentImage",
            @"DYYYLongPressSaveAllImages",
            @"DYYYLongPressCopyLink",
            @"DYYYLongPressApiDownload",
            @"DYYYLongPressFilterUser",
            @"DYYYLongPressFilterTitle",
            @"DYYYLongPressTimerClose",
            @"DYYYLongPressCreateVideo"
        ];
        [self updateSubSwitchesInSection:section 
                                withKeys:subKeys 
                                 enabled:enabled
                               tableView:tableView 
                        settingSections:settingSections];
    }
    // 处理时间属地显示的子选项
    else if ([key isEqualToString:@"DYYYisEnableArea"]) {
        [self updateAreaSubSwitchesUI:section enabled:enabled tableView:tableView settingSections:settingSections];
    }
    // 处理视频显示日期时间的子选项
    else if ([key isEqualToString:@"DYYYShowDateTime"]) {
        [self updateDateTimeFormatSubSwitchesUI:section enabled:enabled tableView:tableView settingSections:settingSections];
    }
    // 处理复制功能子选项
    else if ([key isEqualToString:@"DYYYCopyText"]) {
        NSArray<NSString *> *subKeys = @[@"DYYYCopyOriginalText", @"DYYYCopyShareLink"];
        [self updateSubSwitchesInSection:section withKeys:subKeys enabled:enabled tableView:tableView settingSections:settingSections];
    }
    // 处理双击功能子选项
    else if ([key isEqualToString:@"DYYYEnableDoubleOpenAlertController"]) {
        NSArray<NSString *> *subKeys = @[
            @"DYYYDoubleTapDownload", 
            @"DYYYDoubleTapDownloadAudio", 
            @"DYYYDoubleTapCopyDesc", 
            @"DYYYDoubleTapComment", 
            @"DYYYDoubleTapLike", 
            @"DYYYDoubleTapPip",
            @"DYYYDoubleTapshowSharePanel", 
            @"DYYYDoubleTapshowDislikeOnVideo", 
            @"DYYYDoubleInterfaceDownload"
        ];
        [self updateSubSwitchesInSection:section withKeys:subKeys enabled:enabled tableView:tableView settingSections:settingSections];
    }
    // 处理主页自定义总开关
    else if ([key isEqualToString:@"DYYYEnableSocialStatsCustom"]) {
        // 这里不需要更新子开关，因为它们是文本框，不是开关
    }
    // 处理视频自定义总开关
    else if ([key isEqualToString:@"DYYYEnableVideoStatsCustom"]) {
        // 这里不需要更新子开关，因为它们是文本框，不是开关
    }
}

// 从 DYYYSettingViewController 转移过来的方法
- (void)updateAreaSubSwitchesUI:(NSInteger)section 
                        enabled:(BOOL)enabled
                      tableView:(UITableView *)tableView
               settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    // 定义属地显示的子开关键名列表
    NSArray<NSString *> *areaSubKeys = @[
        @"DYYYisEnableAreaProvince",
        @"DYYYisEnableAreaCity", 
        @"DYYYisEnableAreaDistrict", 
        @"DYYYisEnableAreaStreet"
    ];
    
    // 添加此行：将变量声明移到方法开头，确保在整个方法范围内可见
    NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
    
    // 使用锁保护设置修改
    [settingsLock lock];
    
    @try {
        // 先更新数据部分
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        for (NSUInteger row = 0; row < sectionItems.count; row++) {
            DYYYSettingItem *item = sectionItems[row];
            
            // 严格只更新属地显示的子开关，其他所有开关都不修改
            if ([areaSubKeys containsObject:item.key]) {
                [defaults setBool:enabled forKey:item.key];
            }
        }
        [defaults synchronize];
        
        // 添加日志确认哪些键被修改
        NSLog(@"DYYY: updateAreaSubSwitchesUI - 只修改了属地子开关，总开关状态: %@", enabled ? @"开" : @"关");
    }
    @finally {
        [settingsLock unlock];
    }
    
    // 再更新UI部分 - 只在cell可见时执行
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([areaSubKeys containsObject:item.key]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
            
            if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *switchControl = (UISwitch *)cell.accessoryView;
                switchControl.on = enabled;
            }
        }
    }
}

- (void)updateAreaMainSwitchUI:(NSInteger)section
                     tableView:(UITableView *)tableView
              settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([item.key isEqualToString:@"DYYYisEnableArea"]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
            
            // 增加nil检查
            if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *mainSwitch = (UISwitch *)cell.accessoryView;
                BOOL shouldBeOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
                mainSwitch.on = shouldBeOn;
            }
            break;
        }
    }
}

- (void)updateDateTimeFormatSubSwitchesUI:(NSInteger)section 
                                  enabled:(BOOL)enabled
                                tableView:(UITableView *)tableView
                         settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
            // 直接更新数据，确保状态一致
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:item.key];
            
            // 更新UI（如果单元格可见）
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
            
            // 添加保护
            if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = enabled;
            }
        }
    }
    
    // 确保同步数据
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateDateTimeFormatMainSwitchUI:(NSInteger)section
                               tableView:(UITableView *)tableView
                        settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
            
            // 增加nil检查
            if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *mainSwitch = (UISwitch *)cell.accessoryView;
                BOOL shouldBeOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYShowDateTime"];
                mainSwitch.on = shouldBeOn;
            }
            break;
        }
    }
}

- (void)updateDateTimeFormatExclusiveSwitch:(NSInteger)section 
                                 currentKey:(NSString *)currentKey
                                  tableView:(UITableView *)tableView
                           settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections {
    
    NSArray<NSString *> *allFormatKeys = @[@"DYYYDateTimeFormat_YMDHM", 
                                          @"DYYYDateTimeFormat_MDHM", 
                                          @"DYYYDateTimeFormat_HMS", 
                                          @"DYYYDateTimeFormat_HM", 
                                          @"DYYYDateTimeFormat_YMD"];
    
    // 先更新数据
    for (NSString *key in allFormatKeys) {
        [[NSUserDefaults standardUserDefaults] setBool:[key isEqualToString:currentKey] forKey:key];
    }
    
    // 再更新UI
    NSArray<DYYYSettingItem *> *sectionItems = settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:cellPath];
            
            // 增加nil检查
            if (cell && [cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = [item.key isEqualToString:currentKey];
            }
        }
    }
}

- (void)handleABTestBlockEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"DYYYABTestBlockEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DYYYManager showToast:enabled ? @"已启用ABTest拦截" : @"已关闭ABTest拦截"];
}

- (void)handleABTestPatchEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"DYYYABTestPatchEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DYYYManager showToast:enabled ? @"已启用ABTest补丁模式" : @"已关闭ABTest补丁模式"];
}

- (void)showToastForItem:(DYYYSettingItem *)item enabled:(BOOL)enabled {
    NSString *message = nil;
    
    if ([item.key isEqualToString:@"DYYYStreamlinethesidebar"]) {
        message = enabled ? @"侧栏简化已启用，重新打开侧栏生效" : @"侧栏简化已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYisDarkKeyBoard"]) {
        message = enabled ? @"深色键盘已启用" : @"深色键盘已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYEnableVideoHighestQuality"]) {
        message = enabled ? @"默认最高画质已启用" : @"默认最高画质已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYEnableNoiseFilter"]) {
        message = enabled ? @"视频降噪增强已启用" : @"视频降噪增强已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYisEnableAutoPlay"]) {
        message = enabled ? @"自动播放已启用，重启应用生效" : @"自动播放已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYisEnableModern"]) {
        message = enabled ? @"现代面板已启用" : @"现代面板已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYEnableSaveAvatar"]) {
        message = enabled ? @"保存头像功能已启用" : @"保存头像功能已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYfollowTips"]) {
        message = enabled ? @"关注二次确认已启用" : @"关注二次确认已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYcollectTips"]) {
        message = enabled ? @"收藏二次确认已启用" : @"收藏二次确认已关闭";
    }
    else if ([item.key isEqualToString:@"DYYYABTestBlockEnabled"]) {
        message = enabled ? @"已启用ABTest拦截" : @"已关闭ABTest拦截";
    }
    else if ([item.key isEqualToString:@"DYYYABTestPatchEnabled"]) {
        message = enabled ? @"已启用ABTest补丁模式" : @"已关闭ABTest补丁模式";
    }
    
    if (message) {
        [DYYYManager showToast:message];
    }
}

- (void)postSettingChangeNotification:(NSString *)key enabled:(BOOL)enabled {
    // 主动发送设置变更通知，确保清屏按钮、隐藏功能、倍速按钮等立即响应
    NSArray *notificationKeys = @[
        // 清屏相关
        @"DYYYEnableFloatClearButton",
        @"DYYYEnableFloatClearButtonSize",
        @"DYYYCustomAlbumSizeLarge",
        @"DYYYCustomAlbumSizeMedium",
        @"DYYYCustomAlbumSizeSmall",
        @"DYYYCustomAlbumImagePath",
        @"DYYYEnableCustomAlbum",
        @"DYYYHideTabBar",
        @"DYYYHideDanmaku",
        @"DYYYHideSlider",
        // 倍速相关
        @"DYYYEnableFloatSpeedButton",
        @"DYYYSpeedSettings",
        @"DYYYSpeedButtonShowX",
        @"DYYYSpeedButtonSize"
    ];
    
    if ([notificationKeys containsObject:key] || [key hasPrefix:@"DYYYHide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYSettingChanged"
                                                            object:nil
                                                          userInfo:@{@"key": key, @"value": @(enabled)}];
    }
}

@end