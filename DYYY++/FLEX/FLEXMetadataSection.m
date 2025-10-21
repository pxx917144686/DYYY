//
//  FLEXMetadataSection.m
//  FLEX
//
//  Created by Tanner Bennett on 9/19/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXMetadataSection.h"
#import "FLEXTableView.h"
#import "FLEXTableViewCell.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXFieldEditorViewController.h"
#import "FLEXMethodCallingViewController.h"
#import "FLEXIvar.h"
#import "NSArray+FLEX.h"
#import "FLEXRuntime+UIKitHelpers.h"

@interface FLEXMetadataSection ()
@property (nonatomic, readonly) FLEXObjectExplorer *explorer;
/// 已过滤
@property (nonatomic, copy) NSArray<id<FLEXRuntimeMetadata>> *metadata;
/// 未过滤
@property (nonatomic, copy) NSArray<id<FLEXRuntimeMetadata>> *allMetadata;
@end

@implementation FLEXMetadataSection

#pragma mark - 初始化

+ (instancetype)explorer:(FLEXObjectExplorer *)explorer kind:(FLEXMetadataKind)metadataKind {
    return [[self alloc] initWithExplorer:explorer kind:metadataKind];
}

- (id)initWithExplorer:(FLEXObjectExplorer *)explorer kind:(FLEXMetadataKind)metadataKind {
    self = [super init];
    if (self) {
        _explorer = explorer;
        _metadataKind = metadataKind;

        [self reloadData];
    }

    return self;
}

#pragma mark - 私有方法

- (NSString *)titleWithBaseName:(NSString *)baseName {
    unsigned long totalCount = self.allMetadata.count;
    unsigned long filteredCount = self.metadata.count;

    if (totalCount == filteredCount) {
        return [baseName stringByAppendingFormat:@" (%lu)", totalCount];
    } else {
        return [baseName stringByAppendingFormat:@" (%lu / %lu)", filteredCount, totalCount];
    }
}

- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row {
    return [self.metadata[row] suggestedAccessoryTypeWithTarget:self.explorer.object];
}

#pragma mark - 公共方法

- (void)setExcludedMetadata:(NSSet<NSString *> *)excludedMetadata {
    _excludedMetadata = excludedMetadata;
    [self reloadData];
}

#pragma mark - 重写方法

- (NSString *)titleForRow:(NSInteger)row {
    return [self.metadata[row] description];
}

- (NSString *)subtitleForRow:(NSInteger)row {
    return [self.metadata[row] previewWithTarget:self.explorer.object];
}

- (NSString *)title {
    switch (self.metadataKind) {
        case FLEXMetadataKindProperties:
            return [self titleWithBaseName:@"属性"];
        case FLEXMetadataKindClassProperties:
            return [self titleWithBaseName:@"类属性"];
        case FLEXMetadataKindIvars:
            return [self titleWithBaseName:@"实例变量"];
        case FLEXMetadataKindMethods:
            return [self titleWithBaseName:@"方法"];
        case FLEXMetadataKindClassMethods:
            return [self titleWithBaseName:@"类方法"];
        case FLEXMetadataKindClassHierarchy:
            return [self titleWithBaseName:@"类层次结构"];
        case FLEXMetadataKindProtocols:
            return [self titleWithBaseName:@"协议"];
        case FLEXMetadataKindOther:
            return @"杂项";
    }
}

- (NSInteger)numberOfRows {
    return self.metadata.count;
}

- (void)setFilterText:(NSString *)filterText {
    super.filterText = filterText;

    if (!self.filterText.length) {
        self.metadata = self.allMetadata;
    } else {
        self.metadata = [self.allMetadata flex_filtered:^BOOL(id<FLEXRuntimeMetadata> obj, NSUInteger idx) {
            return [obj.description localizedCaseInsensitiveContainsString:self.filterText];
        }];
    }
}

- (void)reloadData {
    switch (self.metadataKind) {
        case FLEXMetadataKindProperties:
            self.allMetadata = self.explorer.properties;
            break;
        case FLEXMetadataKindClassProperties:
            self.allMetadata = self.explorer.classProperties;
            break;
        case FLEXMetadataKindIvars:
            self.allMetadata = self.explorer.ivars;
            break;
        case FLEXMetadataKindMethods:
            self.allMetadata = self.explorer.methods;
            break;
        case FLEXMetadataKindClassMethods:
            self.allMetadata = self.explorer.classMethods;
            break;
        case FLEXMetadataKindProtocols:
            self.allMetadata = self.explorer.conformedProtocols;
            break;
        case FLEXMetadataKindClassHierarchy:
            self.allMetadata = self.explorer.classHierarchy;
            break;
        case FLEXMetadataKindOther:
            self.allMetadata = @[self.explorer.instanceSize, self.explorer.imageName];
            break;
    }

    // 移除被排除的元数据
    if (self.excludedMetadata.count) {
        id filterBlock = ^BOOL(id<FLEXRuntimeMetadata> obj, NSUInteger idx) {
            return ![self.excludedMetadata containsObject:obj.name];
        };

        // 过滤排除项并排序
        self.allMetadata = [[self.allMetadata flex_filtered:filterBlock]
            sortedArrayUsingSelector:@selector(compare:)
        ];
    }

    // 重新过滤数据
    self.filterText = self.filterText;
}

- (BOOL)canSelectRow:(NSInteger)row {
    UITableViewCellAccessoryType accessory = [self accessoryTypeForRow:row];
    return accessory == UITableViewCellAccessoryDisclosureIndicator ||
        accessory == UITableViewCellAccessoryDetailDisclosureButton;
}

- (NSString *)reuseIdentifierForRow:(NSInteger)row {
    return [self.metadata[row] reuseIdentifierWithTarget:self.explorer.object] ?: kFLEXCodeFontCell;
}

- (UIViewController *)viewControllerToPushForRow:(NSInteger)row {
    return [self.metadata[row] viewerWithTarget:self.explorer.object];
}

- (void (^)(__kindof UIViewController *))didPressInfoButtonAction:(NSInteger)row {
    return ^(UIViewController *host) {
        [host.navigationController pushViewController:[self editorForRow:row] animated:YES];
    };
}

- (UIViewController *)editorForRow:(NSInteger)row {
    return [self.metadata[row] editorWithTarget:self.explorer.object section:self];
}

- (void)configureCell:(__kindof FLEXTableViewCell *)cell forRow:(NSInteger)row {
    cell.titleLabel.text = [self titleForRow:row];
    cell.subtitleLabel.text = [self subtitleForRow:row];
    cell.accessoryType = [self accessoryTypeForRow:row];
}

- (NSString *)menuSubtitleForRow:(NSInteger)row {
    return [self.metadata[row] contextualSubtitleWithTarget:self.explorer.object];
}

- (NSArray<UIMenuElement *> *)menuItemsForRow:(NSInteger)row sender:(UIViewController *)sender {
    NSArray<UIMenuElement *> *existingItems = [super menuItemsForRow:row sender:sender];
    
    // 这两种元数据类型不需要下面的额外选项
    switch (self.metadataKind) {
        case FLEXMetadataKindClassHierarchy:
        case FLEXMetadataKindOther:
            return existingItems;
            
        default: break;
    }
    
    id<FLEXRuntimeMetadata> metadata = self.metadata[row];
    NSMutableArray<UIMenuElement *> *menuItems = [NSMutableArray new];
    
    [menuItems addObject:[UIAction
        actionWithTitle:@"浏览元数据"
        image:nil
        identifier:nil
        handler:^(__kindof UIAction *action) {
            [sender.navigationController pushViewController:[FLEXObjectExplorerFactory
                explorerViewControllerForObject:metadata
            ] animated:YES];
        }
    ]];
    [menuItems addObjectsFromArray:[metadata
        additionalActionsWithTarget:self.explorer.object sender:sender
    ]];
    [menuItems addObjectsFromArray:existingItems];
    
    return menuItems.copy;
}

- (NSArray<NSString *> *)copyMenuItemsForRow:(NSInteger)row {
    return [self.metadata[row] copiableMetadataWithTarget:self.explorer.object];
}

@end
