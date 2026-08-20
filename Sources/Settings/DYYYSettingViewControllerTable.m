//
//  DYYYSettingViewControllerTable.m
//  DYYY
//
//  table data source / delegate、搜索过滤、分组图标与颜色。
//

#import "DYYYSettingViewController.h"
#import "DYYYSettingViewControllerPrivate.h"
#import "DYYYSettingViewControllerActions.h"
#import "DYYYSettingItem.h"
#import "DYYYUtils.h"
#import "DYYYPaths.h"

@implementation DYYYSettingViewController (Table)

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        self.filteredSections = nil;
        self.filteredSectionTitles = nil;
    } else {
        self.isSearching = YES;
        [self filterContentForSearchText:searchText];
    }
    
    [self.tableView reloadData];
}

- (void)filterContentForSearchText:(NSString *)searchText {
    NSMutableArray *filteredSections = [NSMutableArray array];
    NSMutableArray *filteredTitles = [NSMutableArray array];
    
    for (NSInteger i = 0; i < self.settingSections.count; i++) {
        NSArray *section = self.settingSections[i];
        NSMutableArray *filteredSection = [NSMutableArray array];
        DYYYSettingItem *currentGroupHeader = nil;
        
        for (DYYYSettingItem *item in section) {
            // 记录当前子分组标题，命中条目时随条目一起保留
            if (item.type == DYYYSettingItemTypeGroupHeader) {
                currentGroupHeader = item;
                continue;
            }
            
            // 搜索标题或key
            if ([item.title.lowercaseString containsString:searchText.lowercaseString] ||
                [item.key.lowercaseString containsString:searchText.lowercaseString]) {
                if (currentGroupHeader && ![filteredSection containsObject:currentGroupHeader]) {
                    [filteredSection addObject:currentGroupHeader];
                }
                [filteredSection addObject:item];
            }
        }
        
        if (filteredSection.count > 0) {
            [filteredSections addObject:filteredSection];
            [filteredTitles addObject:self.sectionTitles[i]];
        }
    }
    
    self.filteredSections = filteredSections;
    self.filteredSectionTitles = filteredTitles;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSArray *sections = self.isSearching ? self.filteredSections : self.settingSections;
    return sections ? sections.count : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    // 确保头部视图高度与返回的高度一致(35)
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 45)];
    headerView.backgroundColor = [UIColor clearColor];
    
    // 修正头部按钮的宽度和位置，使其居中且宽度适当
    UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    // 设置按钮水平居中，并设置合适的宽度
    CGFloat buttonWidth = tableView.bounds.size.width - 55;
    CGFloat buttonX = (tableView.bounds.size.width - buttonWidth) / 5; // 计算使按钮水平居中的X坐标
    headerButton.frame = CGRectMake(buttonX, 2, buttonWidth, 41);
    
    // 使用系统背景色并添加圆角
    headerButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9]; // 半透明白色背景
    headerButton.layer.cornerRadius = 10;
    headerButton.layer.masksToBounds = YES; // 确保内容不超出圆角范围
    
    // 设置标题按钮属性
    headerButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    headerButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [headerButton setTitle:self.isSearching ? self.filteredSectionTitles[section] : self.sectionTitles[section] forState:UIControlStateNormal];
    [headerButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
    headerButton.tag = section;
    [headerButton addTarget:self action:@selector(headerTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加左侧图标 - 使用iPhone原生界面大小
    UIImageView *leftIconImageView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        NSString *iconName = [self iconNameForSection:section];
        UIColor *iconColor = [self iconColorForSection:section];
        
        // 使用更大的图标尺寸，模仿iPhone原生设置界面
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        UIImage *iconImage = [[UIImage systemImageNamed:iconName] imageWithConfiguration:config];
        leftIconImageView.image = iconImage;
        leftIconImageView.tintColor = iconColor;
    } else {
        leftIconImageView.image = [UIImage systemImageNamed:@"gear"];
        leftIconImageView.tintColor = [UIColor systemBlueColor];
    }
    
    // 设置左侧图标位置 - 调整为更大的尺寸和位置
    CGFloat leftIconMargin = 15;
    CGFloat iconSize = 24; // 增大图标尺寸，模仿原生界面
    CGFloat iconY = (41 - iconSize) / 2; // 垂直居中
    leftIconImageView.frame = CGRectMake(leftIconMargin, iconY, iconSize, iconSize);
    leftIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    // 调整标题按钮的内容边距，为左侧图标留出空间
    headerButton.contentEdgeInsets = UIEdgeInsetsMake(0, leftIconMargin + iconSize + 10, 0, 35); // 左边距 = 图标左边距 + 图标宽度 + 间距
    
    // 添加右侧箭头指示器
    UIImageView *arrowImageView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImage *arrowImage = [UIImage systemImageNamed:(self.isSearching || [self.expandedSections containsObject:@(section)]) ? @"chevron.down" : @"chevron.right"];
        
        // 箭头也使用更大的尺寸
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        arrowImage = [arrowImage imageWithConfiguration:config];
        arrowImageView.image = arrowImage;
        arrowImageView.tintColor = [UIColor systemGrayColor];
    } else {
        arrowImageView.image = [UIImage systemImageNamed:(self.isSearching || [self.expandedSections containsObject:@(section)]) ? @"chevron.down" : @"chevron.right"];
        arrowImageView.tintColor = [UIColor systemGrayColor];
    }
    
    // 调整箭头位置到右侧 - 使用更大的尺寸
    CGFloat arrowRightMargin = 15;
    CGFloat arrowSize = 18; // 增大箭头尺寸
    CGFloat arrowY = (41 - arrowSize) / 2; // 垂直居中
    arrowImageView.frame = CGRectMake(buttonWidth - arrowSize - arrowRightMargin, arrowY, arrowSize, arrowSize);
    arrowImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    arrowImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    arrowImageView.layer.shadowOffset = CGSizeMake(0, 1);
    arrowImageView.layer.shadowOpacity = 0.2;
    arrowImageView.layer.shadowRadius = 1.5;
    arrowImageView.tag = 100;
    
    [headerView addSubview:headerButton];
    [headerButton addSubview:leftIconImageView];
    [headerButton addSubview:arrowImageView];
    
    return headerView;
}

- (NSString *)iconNameForSection:(NSInteger)section {
    NSArray *iconNames = @[
        @"play.rectangle.fill",                 // 播放
        @"hand.tap.fill",                       // 手势与快捷
        @"paintpalette.fill",                   // 页面设置
        @"line.3.horizontal.decrease.circle.fill", // 内容与过滤
        @"message.fill",                        // 互动
        @"clock.fill"                           // 数据与维护
    ];
    
    // 获取搜索时的原始分组索引
    NSInteger originalSection = section;
    if (self.isSearching && section < self.filteredSectionTitles.count) {
        NSString *sectionTitle = self.filteredSectionTitles[section];
        originalSection = [self.sectionTitles indexOfObject:sectionTitle];
        if (originalSection == NSNotFound) {
            originalSection = section;
        }
    }
    
    if (originalSection < iconNames.count) {
        return iconNames[originalSection];
    }
    return @"slider.horizontal.3";
}

- (UIColor *)iconColorForSection:(NSInteger)section {
    NSArray *colors = @[
        [UIColor systemRedColor],       // 播放
        [UIColor systemOrangeColor],    // 手势与快捷
        [UIColor systemPurpleColor],    // 页面设置
        [UIColor systemGreenColor],     // 内容与过滤
        [UIColor systemBlueColor],      // 互动
        [UIColor systemGrayColor]       // 数据与维护
    ];
    
    // 获取搜索时的原始分组索引
    NSInteger originalSection = section;
    if (self.isSearching && section < self.filteredSectionTitles.count) {
        NSString *sectionTitle = self.filteredSectionTitles[section];
        originalSection = [self.sectionTitles indexOfObject:sectionTitle];
        if (originalSection == NSNotFound) {
            originalSection = section;
        }
    }
    
    if (originalSection < colors.count) {
        return colors[originalSection];
    }
    return [UIColor systemBlueColor];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:indexPath.section];
    if (indexPath.row < visibleItems.count) {
        DYYYSettingItem *item = visibleItems[indexPath.row];
        if (item.type == DYYYSettingItemTypeGroupHeader) {
            return 32.0;
        }
    }
    return 44.0; // 使用标准行高
}

#pragma mark - 子分组折叠

// 分区当前可见条目：子分组标题始终可见，普通条目仅在其子分组展开时可见。
- (NSArray<DYYYSettingItem *> *)visibleItemsForSection:(NSInteger)section {
    NSArray *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (!sections || section < 0 || section >= sections.count) {
        return @[];
    }
    NSArray<DYYYSettingItem *> *allItems = sections[section];
    if (self.isSearching) {
        return allItems; // 搜索模式：命中条目与所属子分组标题原样显示
    }
    NSMutableArray<DYYYSettingItem *> *visible = [NSMutableArray array];
    NSInteger groupIndex = -1;
    for (DYYYSettingItem *item in allItems) {
        if (item.type == DYYYSettingItemTypeGroupHeader) {
            groupIndex++;
            [visible addObject:item];
            continue;
        }
        if (groupIndex < 0 ||
            [self.expandedGroups containsObject:@(section * 1000 + groupIndex)]) {
            [visible addObject:item];
        }
    }
    return visible;
}

- (NSIndexPath *)visibleIndexPathForSettingKey:(NSString *)key {
    if (key.length == 0) return nil;
    NSArray *sections = self.isSearching ? self.filteredSections : self.settingSections;
    for (NSInteger section = 0; section < (NSInteger)sections.count; section++) {
        if (!self.isSearching && ![self.expandedSections containsObject:@(section)]) continue;
        NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:section];
        for (NSInteger row = 0; row < (NSInteger)visibleItems.count; row++) {
            DYYYSettingItem *item = visibleItems[row];
            if ([item.key isEqualToString:key]) {
                return [NSIndexPath indexPathForRow:row inSection:section];
            }
        }
    }
    return nil;
}

// 条目所属子分组序号（flat 数组内第几个子分组标题）
- (NSInteger)groupIndexForItem:(DYYYSettingItem *)targetItem inSection:(NSInteger)section {
    NSArray *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (!sections || section >= sections.count) {
        return -1;
    }
    NSInteger groupIndex = -1;
    for (DYYYSettingItem *item in sections[section]) {
        if (item.type == DYYYSettingItemTypeGroupHeader) {
            groupIndex++;
        }
        if (item == targetItem) {
            return groupIndex;
        }
    }
    return -1;
}

// 点击子分组标题：展开/折叠其条目
- (void)toggleGroupHeaderAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching) {
        return; // 搜索模式下子分组标题不可折叠
    }
    NSArray<DYYYSettingItem *> *visible = [self visibleItemsForSection:indexPath.section];
    if (indexPath.row >= visible.count) {
        return;
    }
    DYYYSettingItem *item = visible[indexPath.row];
    if (item.type != DYYYSettingItemTypeGroupHeader) {
        return;
    }
    NSInteger groupIndex = [self groupIndexForItem:item inSection:indexPath.section];
    if (groupIndex < 0) {
        return;
    }
    NSNumber *groupID = @(indexPath.section * 1000 + groupIndex);
    if ([self.expandedGroups containsObject:groupID]) {
        [self.expandedGroups removeObject:groupID];
    } else {
        [self.expandedGroups addObject:groupID];
    }
    [self.tableView reloadData];
    // 展开子分组后重新挂载备份/恢复按钮（它们依赖可见 cell）
    [self setupBackupFunctions];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 35.0; // 保持一致的分组头部高度
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *visible = [self visibleItemsForSection:section];
    if (self.isSearching) {
        return visible.count; // 搜索模式始终显示命中条目
    }
    return [self.expandedSections containsObject:@(section)] ? visible.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<DYYYSettingItem *> *visibleItems = [self visibleItemsForSection:indexPath.section];
    if (indexPath.row >= visibleItems.count) return [[UITableViewCell alloc] init];
    
    DYYYSettingItem *item = visibleItems[indexPath.row];

    // 子分组标题行（大分区内的小分类，点击展开/折叠）
    if (item.type == DYYYSettingItemTypeGroupHeader) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GroupHeaderCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"GroupHeaderCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.textLabel.text = item.title;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.imageView.image = nil;
        if (!self.isSearching) {
            NSInteger groupIndex = [self groupIndexForItem:item inSection:indexPath.section];
            BOOL expanded = [self.expandedGroups containsObject:@(indexPath.section * 1000 + groupIndex)];
            UIImage *chevron = [UIImage systemImageNamed:expanded ? @"chevron.down" : @"chevron.right"];
            if (@available(iOS 13.0, *)) {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                chevron = [chevron imageWithConfiguration:config];
            }
            UIImageView *chevronView = [[UIImageView alloc] initWithImage:chevron];
            chevronView.tintColor = [UIColor tertiaryLabelColor];
            cell.accessoryView = chevronView;
        } else {
            cell.accessoryView = nil;
        }
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SettingCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    // 移除旧的重置按钮和其他自定义视图
    for (UIView *view in cell.contentView.subviews) {
        if (view.tag == 555) {
            [view removeFromSuperview];
        }
    }
    
    // 调整文字间距
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 2;
    paragraphStyle.paragraphSpacing = 0;
    NSAttributedString *attributedText = [[NSAttributedString alloc]
                                         initWithString:item.title
                                         attributes:@{
                                             NSParagraphStyleAttributeName: paragraphStyle,
                                             NSFontAttributeName: [UIFont systemFontOfSize:16],
                                             NSForegroundColorAttributeName: [UIColor labelColor],
                                             NSKernAttributeName: @(-0.5)
                                         }];
    cell.textLabel.attributedText = attributedText;
    cell.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = nil;
    
    // 特殊处理备份和恢复功能
    if ([item.key isEqualToString:@"DYYYBackupSettings"] || [item.key isEqualToString:@"DYYYRestoreSettings"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    // 特殊处理清理功能
    if ([item.key isEqualToString:@"DYYYCleanCache"] || [item.key isEqualToString:@"DYYYCleanSettings"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    // 特殊处理一键自检
    if ([item.key isEqualToString:@"DYYYSelfTest"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    // 特殊处理热更新功能
    if ([item.key isEqualToString:@"SaveCurrentABTestData"] ||
        [item.key isEqualToString:@"LoadABTestConfigFile"] ||
        [item.key isEqualToString:@"DeleteABTestConfigFile"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    // 特殊处理图标自定义功能
    if ([item.key hasPrefix:@"DYYYIcon"]) {
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
            NSString *dyyyFolderPath = [DYYYPaths iconsDir];
            NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
            UIButton *iconButton = [UIButton buttonWithType:UIButtonTypeCustom];
            iconButton.frame = CGRectMake(0, 0, 40, 40);
            iconButton.layer.cornerRadius = 20;
            iconButton.clipsToBounds = YES;
            iconButton.layer.borderWidth = 1.0;
            iconButton.layer.borderColor = [UIColor systemGrayColor].CGColor;
            iconButton.backgroundColor = [UIColor systemBackgroundColor];
            if (fileExists) {
                UIImage *icon = [UIImage imageWithContentsOfFile:imagePath];
                if (icon) {
                    [iconButton setImage:icon forState:UIControlStateNormal];
                    iconButton.contentMode = UIViewContentModeScaleAspectFit;
                } else {
                    [iconButton setImage:[UIImage systemImageNamed:@"photo"] forState:UIControlStateNormal];
                    [iconButton setTintColor:[UIColor systemBlueColor]];
                }
            } else {
                [iconButton setImage:[UIImage systemImageNamed:@"plus.circle"] forState:UIControlStateNormal];
                [iconButton setTintColor:[UIColor systemBlueColor]];
            }
            [iconButton addTarget:self action:@selector(iconButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            iconButton.tag = indexPath.section * 1000 + indexPath.row;
            cell.accessoryView = iconButton;
            return cell;
        }
    }
    // 为单元格添加左侧彩色图标
    UIImage *icon = [self iconImageForSettingItem:item];
    if (icon) {
        cell.imageView.image = icon;
        cell.imageView.tintColor = [self colorForSettingItem:item];
    }
    // 微软风格卡片背景
    UIView *card = [cell.contentView viewWithTag:8888];
    if (!card) {
        card = [[UIView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 8, 4)];
        card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        card.layer.cornerRadius = 12;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOpacity = 0.06;
        card.layer.shadowOffset = CGSizeMake(0, 2);
        card.layer.shadowRadius = 4;
        card.tag = 8888;
        [cell.contentView insertSubview:card atIndex:0];
    }
    // 创建单元格的配件视图
    UIView *accessoryView = nil;
    // 针对scheduleStyle的特殊处理
    if ([item.key isEqualToString:@"DYYYScheduleStyle"]) {
        UIButton *styleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        styleButton.frame = CGRectMake(0, 0, 120, 30);
        NSString *currentStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
        BOOL displayEnabled = DYYYCachedBool(@"DYYYisShowScheduleDisplay");
        if (currentStyle.length == 0) {
            [styleButton setTitle:@"默认" forState:UIControlStateNormal];
        } else {
            NSString *displayValue = currentStyle;
            if ([currentStyle containsString:@"-"]) {
                displayValue = [currentStyle componentsSeparatedByString:@"-"].lastObject;
            }
            [styleButton setTitle:displayValue forState:UIControlStateNormal];
        }
        styleButton.enabled = displayEnabled;
        styleButton.alpha = displayEnabled ? 1.0 : 0.5;
        if (!displayEnabled) {
            cell.detailTextLabel.text = @"需先开启显示进度时长";
            cell.detailTextLabel.textColor = [UIColor systemRedColor];
        } else {
            cell.detailTextLabel.text = nil;
        }
        [styleButton addTarget:self action:@selector(showScheduleStylePicker) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = styleButton;
        return cell;
    }
    if (item.type == DYYYSettingItemTypeSwitch) {
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        if ([item.key hasPrefix:@"DYYYisEnableArea"] &&
            ![item.key isEqualToString:@"DYYYisEnableArea"]) {
            BOOL parentEnabled = DYYYCachedBool(@"DYYYisEnableArea");
            switchView.enabled = parentEnabled;
            BOOL isOn = parentEnabled ? [[NSUserDefaults standardUserDefaults] boolForKey:item.key] : NO;
            [switchView setOn:isOn];
        } else {
            [switchView setOn:[[NSUserDefaults standardUserDefaults] boolForKey:item.key]];
        }
        [switchView applyFuturisticEffects];
        [switchView updateFuturisticEffectsWithState:switchView.isOn animated:NO];
        [switchView addTarget:self action:@selector(animatedSwitchToggled:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.section * 1000 + indexPath.row;
        accessoryView = switchView;
    } else if (item.type == DYYYSettingItemTypeTextField) {
        if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
            NSString *imagePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCustomAlbumImagePath"];
            BOOL fileExists = imagePath && [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
            if (fileExists) {
                UIButton *previewButton = [UIButton buttonWithType:UIButtonTypeCustom];
                previewButton.frame = CGRectMake(0, 0, 40, 40);
                previewButton.layer.cornerRadius = 8;
                previewButton.clipsToBounds = YES;
                UIImage *img = [UIImage imageWithContentsOfFile:imagePath];
                [previewButton setImage:img forState:UIControlStateNormal];
                [previewButton addTarget:self action:@selector(showImagePickerForCustomAlbum) forControlEvents:UIControlEventTouchUpInside];
                accessoryView = previewButton;
            } else {
                UIButton *chooseButton = [UIButton buttonWithType:UIButtonTypeSystem];
                [chooseButton setTitle:@"选择图片" forState:UIControlStateNormal];
                [chooseButton addTarget:self action:@selector(showImagePickerForCustomAlbum) forControlEvents:UIControlEventTouchUpInside];
                chooseButton.frame = CGRectMake(0, 0, 80, 30);
                accessoryView = chooseButton;
            }
        } else {
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 110, 30)];
            textField.layer.cornerRadius = 8;
            textField.clipsToBounds = YES;
            textField.backgroundColor = [UIColor tertiarySystemFillColor];
            textField.textColor = [UIColor labelColor];
            textField.placeholder = item.placeholder;
            textField.textAlignment = NSTextAlignmentRight;
            textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
            [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingDidEnd];
            textField.tag = indexPath.section * 1000 + indexPath.row;
            accessoryView = textField;
            if ([item.key isEqualToString:@"DYYYAvatarTapText"]) {
                [textField addTarget:self action:@selector(avatarTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            }
        }
    } else if (item.type == DYYYSettingItemTypeSpeedPicker || item.type == DYYYSettingItemTypeColorPicker) {
        if (item.type == DYYYSettingItemTypeSpeedPicker) {
            UITextField *speedField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
            speedField.text = [NSString stringWithFormat:@"%.2f", DYYYCachedFloat(@"DYYYDefaultSpeed")];
            speedField.textColor = [UIColor labelColor];
            speedField.borderStyle = UITextBorderStyleNone;
            speedField.backgroundColor = [UIColor clearColor];
            speedField.textAlignment = NSTextAlignmentRight;
            speedField.enabled = NO;
            speedField.tag = 999;
            accessoryView = speedField;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            UIView *colorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
            colorView.layer.cornerRadius = 15;
            colorView.clipsToBounds = YES;
            colorView.layer.borderWidth = 1.0;
            colorView.layer.borderColor = [UIColor whiteColor].CGColor;
            NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
            UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
            CAGradientLayer *gradientLayer = [CAGradientLayer layer];
            gradientLayer.frame = colorView.bounds;
            gradientLayer.cornerRadius = 15;
            if ([currentColor isEqual:[UIColor whiteColor]] || [currentColor isEqual:[UIColor systemBackgroundColor]]) {
                gradientLayer.colors = @[
                    (id)[UIColor systemRedColor].CGColor,
                    (id)[UIColor systemOrangeColor].CGColor,
                    (id)[UIColor systemYellowColor].CGColor,
                    (id)[UIColor systemGreenColor].CGColor,
                    (id)[UIColor systemBlueColor].CGColor,
                    (id)[UIColor systemPurpleColor].CGColor
                ];
                gradientLayer.startPoint = CGPointMake(0, 0);
                gradientLayer.endPoint = CGPointMake(1, 1);
            } else {
                gradientLayer.colors = @[
                    (id)[currentColor colorWithAlphaComponent:0.7].CGColor,
                    (id)currentColor.CGColor,
                    (id)[currentColor colorWithAlphaComponent:0.9].CGColor
                ];
                gradientLayer.startPoint = CGPointMake(0, 0);
                gradientLayer.endPoint = CGPointMake(1, 1);
            }
            [colorView.layer insertSublayer:gradientLayer atIndex:0];
            accessoryView = colorView;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (item.type == DYYYSettingItemTypeChoice || item.type == DYYYSettingItemTypeSlider) {
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 130, 30)];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.textColor = [UIColor secondaryLabelColor];
        valueLabel.font = [UIFont systemFontOfSize:15];
        if (item.type == DYYYSettingItemTypeChoice) {
            NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:item.key];
            if (index < 0 || index >= (NSInteger)item.options.count) index = 0;
            valueLabel.text = index < (NSInteger)item.options.count ? item.options[index] : @"";
        } else {
            NSNumber *stored = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
            NSInteger percent = stored ? stored.integerValue : item.defaultInteger;
            if (percent <= 0) valueLabel.text = @"抖音默认";
            else if (percent >= 100) valueLabel.text = @"胶囊";
            else valueLabel.text = [NSString stringWithFormat:@"%ld%%", (long)percent];
        }
        accessoryView = valueLabel;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (accessoryView) {
        cell.accessoryView = accessoryView;
    }
    return cell;
}

// 根据设置项返回图标名称
- (UIImage *)iconImageForSettingItem:(DYYYSettingItem *)item {
    NSString *iconName;
    
    // 为新增功能添加图标
    if ([item.key isEqualToString:@"DYYYEnableVideoHighestQuality"]) {
        iconName = @"4k.tv.fill";
    } else if ([item.key isEqualToString:@"DYYYEnableNoiseFilter"]) {
        iconName = @"waveform.path.ecg";
    } else if ([item.key isEqualToString:@"DYYYisEnableAutoPlay"]) {
        iconName = @"play.circle.fill";
    } else if ([item.key isEqualToString:@"DYYYisEnableModern"]) {
        iconName = @"rectangle.3.group.fill";
    } else if ([item.key isEqualToString:@"DYYYEnableSaveAvatar"]) {
        iconName = @"person.crop.circle.badge.plus";
    } else if ([item.key containsString:@"Comment"] && [item.key containsString:@"NotWaterMark"]) {
        iconName = @"bubble.left.and.bubble.right.fill";
    } else if ([item.key isEqualToString:@"DYYYFourceDownloadEmotion"]) {
        iconName = @"face.smiling.inverse";
    } 
    // 为彩色取色器添加特殊处理
    else if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
        iconName = @"paintpalette.fill";
    } 
    // 为侧栏简化功能添加特殊处理
    else if ([item.key isEqualToString:@"DYYYStreamlinethesidebar"]) {
        iconName = @"sidebar.left";
    }
    // 为深色键盘功能添加特殊处理
    else if ([item.key isEqualToString:@"DYYYisDarkKeyBoard"]) {
        iconName = @"keyboard";
    }
    // 其他根据设置项的key选择合适的图标...
    else if ([item.key containsString:@"Danmu"] || [item.key containsString:@"弹幕"]) {
        iconName = @"text.bubble.fill";
    } else if ([item.key containsString:@"Color"] || [item.key containsString:@"颜色"]) {
        iconName = @"paintbrush.fill";
    } else if ([item.key containsString:@"Hide"] || [item.key containsString:@"hidden"]) {
        iconName = @"eye.slash.fill";
    } else if ([item.key containsString:@"Download"] || [item.key containsString:@"下载"]) {
        iconName = @"arrow.down.circle.fill";
    } else if ([item.key containsString:@"Video"] || [item.key containsString:@"视频"]) {
        iconName = @"video.fill";
    } else if ([item.key containsString:@"Audio"] || [item.key containsString:@"音频"]) {
        iconName = @"speaker.wave.2.fill";
    } else if ([item.key containsString:@"Image"] || [item.key containsString:@"图片"]) {
        iconName = @"photo.fill";
    } else if ([item.key containsString:@"Speed"] || [item.key containsString:@"倍速"]) {
        iconName = @"speedometer";
    } else if ([item.key containsString:@"Enable"] || [item.key containsString:@"启用"]) {
        iconName = @"checkmark.circle.fill";
    } else if ([item.key containsString:@"Disable"] || [item.key containsString:@"禁用"]) {
        iconName = @"xmark.circle.fill";
    } else if ([item.key containsString:@"Time"] || [item.key containsString:@"时间"]) {
        iconName = @"clock.fill";
    } else if ([item.key containsString:@"Date"] || [item.key containsString:@"日期"]) {
        iconName = @"calendar";
    } else if ([item.key containsString:@"Button"] || [item.key containsString:@"按钮"]) {
        iconName = @"hand.tap.fill";
    } else if ([item.key containsString:@"Avatar"] || [item.key containsString:@"头像"]) {
        iconName = @"person.crop.circle.fill";
    } else if ([item.key containsString:@"Comment"] || [item.key containsString:@"评论"]) {
        iconName = @"message.fill";
    } else if ([item.key containsString:@"Clean"] || [item.key containsString:@"清理"] || [item.key containsString:@"清屏"]) {
        iconName = @"trash.fill";
    } else if ([item.key containsString:@"Share"] || [item.key containsString:@"分享"]) {
        iconName = @"square.and.arrow.up.fill";
    } else if ([item.key containsString:@"Background"] || [item.key containsString:@"背景"]) {
        iconName = @"rectangle.fill.on.rectangle.fill";
    } else if ([item.key containsString:@"Like"] || [item.key containsString:@"点赞"]) {
        iconName = @"heart.fill";
    } else if ([item.key containsString:@"Notification"] || [item.key containsString:@"通知"]) {
        iconName = @"bell.fill";
    } else if ([item.key containsString:@"Copy"] || [item.key containsString:@"复制"]) {
        iconName = @"doc.on.doc.fill";
    } else if ([item.key containsString:@"Emotion"] || [item.key containsString:@"表情"]) {
        iconName = @"face.smiling.fill";
    } else if ([item.key containsString:@"Text"] || [item.key containsString:@"文本"]) {
        iconName = @"text.alignleft";
    } else if ([item.key containsString:@"Location"] || [item.key containsString:@"位置"] || [item.key containsString:@"属地"]) {
        iconName = @"location.fill";
    } else if ([item.key containsString:@"Area"] || [item.key containsString:@"地区"]) {
        iconName = @"mappin.and.ellipse";
    } else if ([item.key containsString:@"Layout"] || [item.key containsString:@"布局"]) {
        iconName = @"square.grid.2x2.fill";
    } else if ([item.key containsString:@"Transparent"] || [item.key containsString:@"透明"]) {
        iconName = @"square.on.circle.fill";
    } else if ([item.key containsString:@"Live"] || [item.key containsString:@"直播"]) {
        iconName = @"antenna.radiowaves.left.and.right";
    } else if ([item.key containsString:@"Double"] || [item.key containsString:@"双击"]) {
        iconName = @"hand.tap.fill";
    } else if ([item.key containsString:@"Long"] || [item.key containsString:@"长按"]) {
        iconName = @"hand.draw.fill";
    } else if ([item.key containsString:@"ScreenDisplay"] || [item.key containsString:@"全屏"]) {
        iconName = @"rectangle.expand.vertical";
    } else if ([item.key containsString:@"Index"] || [item.key containsString:@"首页"]) {
        iconName = @"house.fill";
    } else if ([item.key containsString:@"Friends"] || [item.key containsString:@"朋友"]) {
        iconName = @"person.2.fill";
    } else if ([item.key containsString:@"Msg"] || [item.key containsString:@"消息"]) {
        iconName = @"envelope.fill";
    } else if ([item.key containsString:@"Self"] || [item.key containsString:@"我的"]) {
        iconName = @"person.crop.square.fill";
    } else if ([item.key containsString:@"NoAds"] || [item.key containsString:@"广告"]) {
        iconName = @"xmark.octagon.fill";
    } else if ([item.key containsString:@"NoUpdates"] || [item.key containsString:@"更新"]) {
        iconName = @"arrow.triangle.2.circlepath";
    } else if ([item.key containsString:@"InterfaceDownload"] || [item.key containsString:@"接口"]) {
        iconName = @"link.circle.fill";
    } else if ([item.key containsString:@"Scale"] || [item.key containsString:@"缩放"]) {
        iconName = @"arrow.up.left.and.down.right.magnifyingglass";
    } else if ([item.key containsString:@"Blur"] || [item.key containsString:@"模糊"] || [item.key containsString:@"玻璃"]) {
        iconName = @"drop.fill";
    } else if ([item.key containsString:@"Shop"] || [item.key containsString:@"商城"]) {
        iconName = @"cart.fill";
    } else if ([item.key containsString:@"Tips"] || [item.key containsString:@"提示"]) {
        iconName = @"exclamationmark.bubble.fill";
    } else if ([item.key containsString:@"Format"] || [item.key containsString:@"格式"]) {
        iconName = @"textformat";
    } else if ([item.key containsString:@"Filter"] || [item.key containsString:@"过滤"]) {
        iconName = @"line.horizontal.3.decrease.circle.fill";
    } else {
        // 默认图标
        iconName = @"gearshape.fill";
    }
    
    UIImage *icon = [UIImage systemImageNamed:iconName];
    if (@available(iOS 15.0, *)) {
        // 为颜色背景特殊处理
        if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
            return [icon imageWithConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[UIColor systemPinkColor]]];
        }
        return [icon imageWithConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[self colorForSettingItem:item]]];
    } else {
        return icon;
    }
}

// 根据设置项返回颜色
- (UIColor *)colorForSettingItem:(DYYYSettingItem *)item {
    // 为取色器和特定功能设置特殊颜色
    if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
        return [UIColor systemPinkColor];
    } else if ([item.key isEqualToString:@"DYYYStreamlinethesidebar"]) {
        return [UIColor systemIndigoColor];
    } else if ([item.key isEqualToString:@"DYYYisDarkKeyBoard"]) {
        return [UIColor systemGrayColor];
    }
    
    // 根据设置项类型返回不同颜色
    if ([item.key containsString:@"Hide"] || [item.key containsString:@"hidden"]) {
        return [UIColor systemRedColor];
    } else if ([item.key containsString:@"Enable"] || [item.key containsString:@"启用"]) {
        return [UIColor systemGreenColor];
    } else if ([item.key containsString:@"Color"] || [item.key containsString:@"颜色"]) {
        return [UIColor systemPurpleColor];
    } else if ([item.key containsString:@"Copy"] || [item.key containsString:@"复制"]) {
        return [UIColor systemTealColor];
    } else if ([item.key containsString:@"Emotion"] || [item.key containsString:@"表情"]) {
        return [UIColor systemYellowColor];
    } else if ([item.key containsString:@"Double"] || [item.key containsString:@"双击"]) {
        return [UIColor systemOrangeColor];
    } else if ([item.key containsString:@"Download"] || [item.key containsString:@"下载"]) {
        return [UIColor systemBlueColor];
    } else if ([item.key containsString:@"Video"] || [item.key containsString:@"视频"]) {
        return [UIColor systemIndigoColor];
    } else if ([item.key containsString:@"Audio"] || [item.key containsString:@"音频"]) {
        return [UIColor systemTealColor];
    } else if ([item.key containsString:@"Speed"] || [item.key containsString:@"倍速"]) {
        return [UIColor systemYellowColor];
    } else if ([item.key containsString:@"Time"] || [item.key containsString:@"时间"]) {
        return [UIColor systemOrangeColor];
    }
    
    // 默认颜色
    return [UIColor systemBlueColor];
}

// 微软风格UISwitch动画，联动卡片
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UIView class]]) {
        UIButton *headerButton = [view viewWithTag:section];
        if ([headerButton isKindOfClass:[UIButton class]]) {
            // 调整标题文字的属性
            UIColor *textColor;
            if (@available(iOS 13.0, *)) {
                textColor = [UIColor labelColor];
            } else {
                textColor = [UIColor darkTextColor];
            }
            
            NSAttributedString *attributedTitle = [[NSAttributedString alloc] 
                                                 initWithString:headerButton.titleLabel.text 
                                                 attributes:@{
                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:17],
                                                     NSForegroundColorAttributeName: textColor,
                                                     NSKernAttributeName: @(-0.8) // 减小字符间距
                                                 }];
            [headerButton setAttributedTitle:attributedTitle forState:UIControlStateNormal];
        }
    }
}

- (NSArray<NSIndexPath *> *)rowsForSection:(NSInteger)section {
    NSArray *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section < 0 || section >= (NSInteger)sections.count) {
        return @[];
    }
    if (!self.isSearching && ![self.expandedSections containsObject:@(section)]) {
        return @[];
    }
    NSInteger rowCount = [self visibleItemsForSection:section].count;
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:rowCount];
    for (NSInteger row = 0; row < rowCount; row++) {
        [rows addObject:[NSIndexPath indexPathForRow:row inSection:section]];
    }
    return rows;
}

@end
