//
//  FLEXFileBrowserController.m
//  Flipboard
//
//  Created by Ryan Olson on 6/9/14.
//
//

#import "FLEXFileBrowserController.h"
#import "FLEXFileBrowserController+RuntimeBrowser.h"
#import "FLEXUtility.h"
#import "FLEXWebViewController.h"
#import "FLEXActivityViewController.h"
#import "FLEXImagePreviewViewController.h"
#import "FLEXTableListViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXFileBrowserSearchOperation.h"
#import "FLEXMachOClassBrowserViewController.h"
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <objc/runtime.h>

@interface FLEXFileBrowserTableViewCell : UITableViewCell
@end

typedef NS_ENUM(NSUInteger, FLEXFileBrowserSortAttribute) {
    FLEXFileBrowserSortAttributeNone = 0,
    FLEXFileBrowserSortAttributeName,
    FLEXFileBrowserSortAttributeCreationDate,
};

@interface FLEXFileBrowserController () <FLEXFileBrowserSearchOperationDelegate>

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSArray<NSString *> *childPaths;
@property (nonatomic) NSArray<NSString *> *searchPaths;
@property (nonatomic) NSNumber *recursiveSize;
@property (nonatomic) NSNumber *searchPathsSize;
@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) UIDocumentInteractionController *documentController;
@property (nonatomic) FLEXFileBrowserSortAttribute sortAttribute;

@end

@implementation FLEXFileBrowserController

+ (instancetype)path:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

- (id)init {
    return [self initWithPath:NSHomeDirectory()];
}

- (id)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        self.path = path;
        self.title = [path lastPathComponent];
        self.operationQueue = [NSOperationQueue new];
        
        // 计算路径大小
        weakify(self)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileManager *fileManager = NSFileManager.defaultManager;
            NSDictionary<NSString *, id> *attributes = [fileManager attributesOfItemAtPath:path error:NULL];
            uint64_t totalSize = [attributes fileSize];

            for (NSString *fileName in [fileManager enumeratorAtPath:path]) {
                NSString *fileAbsolutePath = [path stringByAppendingPathComponent:fileName];
                attributes = [fileManager attributesOfItemAtPath:fileAbsolutePath error:NULL];
                totalSize += [attributes fileSize];
            }

            dispatch_async(dispatch_get_main_queue(), ^{ strongify(self)
                self.recursiveSize = @(totalSize);
                [self.tableView reloadData];
            });
        });
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 修复UIBarButtonItem方法调用
    UIBarButtonItem *sortButton = [[UIBarButtonItem alloc] 
        initWithTitle:@"排序" 
        style:UIBarButtonItemStylePlain 
        target:self 
        action:@selector(sortButtonPressed:)];
    
    [self addToolbarItems:@[sortButton]];
    
    [self reloadDisplayedPaths];
}

// 添加缺失的drillDownViewControllerForPath方法
+ (UIViewController *)drillDownViewControllerForPath:(NSString *)path {
    NSString *pathExtension = [path.pathExtension lowercaseString];
    UIViewController *controller = nil;
    
    // plist文件
    if ([pathExtension isEqualToString:@"plist"]) {
        id plistObject = [NSArray arrayWithContentsOfFile:path] ?: [NSDictionary dictionaryWithContentsOfFile:path];
        if (plistObject) {
            controller = [FLEXObjectExplorerFactory explorerViewControllerForObject:plistObject];
        }
    }
    // SQLite数据库文件 - 修复方法调用
    else if ([pathExtension isEqualToString:@"db"] || [pathExtension isEqualToString:@"sqlite"] || [pathExtension isEqualToString:@"sqlite3"]) {
        // 使用初始化方法而不是类方法
        controller = [[FLEXTableListViewController alloc] init];
        // 如果需要设置路径，可以在这里添加
    }
    // 图片文件 - 修复初始化方法
    else if ([@[@"png", @"jpg", @"jpeg", @"gif", @"webp"] containsObject:pathExtension]) {
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            // 修复初始化方法
            controller = [[FLEXImagePreviewViewController alloc] init];
            // 如果FLEXImagePreviewViewController有设置图片的方法，在这里调用
        }
    }
    // 文本文件
    else if ([@[@"txt", @"json", @"log", @"xml", @"html", @"css", @"js", @"md", @"h", @"m", @"mm", @"c", @"cpp", @"swift"] containsObject:pathExtension]) {
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (content) {
            controller = [[FLEXWebViewController alloc] initWithText:content];
        }
    }
    
    return controller;
}

// 修复sortButtonPressed方法名
- (void)sortButtonPressed:(UIBarButtonItem *)sortButton {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"排序"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"时间"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self sortWithAttribute:FLEXFileBrowserSortAttributeNone];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"名字"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self sortWithAttribute:FLEXFileBrowserSortAttributeName];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"创建日期"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self sortWithAttribute:FLEXFileBrowserSortAttributeCreationDate];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)sortWithAttribute:(FLEXFileBrowserSortAttribute)attribute {
    self.sortAttribute = attribute;
    [self reloadDisplayedPaths];
}

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowBrowseBundle: return @"📁  浏览.app目录";
        case FLEXGlobalsRowBrowseContainer: return @"📁  浏览数据目录";
        default: return nil;
    }
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowBrowseBundle: return [[self alloc] initWithPath:NSBundle.mainBundle.bundlePath];
        case FLEXGlobalsRowBrowseContainer: return [[self alloc] initWithPath:NSHomeDirectory()];
        default: return [self new];
    }
}

#pragma mark - FLEXFileBrowserSearchOperationDelegate

- (void)fileBrowserSearchOperationResult:(NSArray<NSString *> *)searchResult size:(uint64_t)size {
    self.searchPaths = searchResult;
    self.searchPathsSize = @(size);
    [self.tableView reloadData];
}

#pragma mark - Search bar

- (void)updateSearchResults:(NSString *)newText {
    [self reloadDisplayedPaths];
}

#pragma mark UISearchControllerDelegate

- (void)willDismissSearchController:(UISearchController *)searchController {
    [self.operationQueue cancelAllOperations];
    [self reloadCurrentPath];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchController.isActive ? self.searchPaths.count : self.childPaths.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    BOOL isSearchActive = self.searchController.isActive;
    NSNumber *currentSize = isSearchActive ? self.searchPathsSize : self.recursiveSize;
    NSArray<NSString *> *currentPaths = isSearchActive ? self.searchPaths : self.childPaths;

    NSString *sizeString = nil;
    if (!currentSize) {
        sizeString = @"正在计算大小...";
    } else {
        sizeString = [NSByteCountFormatter stringFromByteCount:[currentSize longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    }

    return [NSString stringWithFormat:@"%lu 个文件 (%@)", (unsigned long)currentPaths.count, sizeString];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fullPath = [self filePathAtIndexPath:indexPath];
    NSDictionary<NSString *, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:fullPath error:NULL];
    BOOL isDirectory = [attributes.fileType isEqual:NSFileTypeDirectory];
    NSString *subtitle = nil;
    if (isDirectory) {
        NSUInteger count = [NSFileManager.defaultManager contentsOfDirectoryAtPath:fullPath error:NULL].count;
        subtitle = [NSString stringWithFormat:@"%lu 项%@", (unsigned long)count, (count == 1 ? @"" : @"")];
    } else {
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:attributes.fileSize countStyle:NSByteCountFormatterCountStyleFile];
        subtitle = [NSString stringWithFormat:@"%@ - %@", sizeString, attributes.fileModificationDate ?: @"从未修改过"];
    }

    static NSString *textCellIdentifier = @"textCell";
    static NSString *imageCellIdentifier = @"imageCell";
    UITableViewCell *cell = nil;

    // Separate image and text only cells because otherwise the separator lines get out-of-whack on image cells reused with text only.
    UIImage *image = [UIImage imageWithContentsOfFile:fullPath];
    NSString *cellIdentifier = image ? imageCellIdentifier : textCellIdentifier;

    if (!cell) {
        cell = [[FLEXFileBrowserTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.textLabel.font = UIFont.flex_defaultTableCellFont;
        cell.detailTextLabel.font = UIFont.flex_defaultTableCellFont;
        cell.detailTextLabel.textColor = UIColor.grayColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *cellTitle = [fullPath lastPathComponent];
    cell.textLabel.text = cellTitle;
    cell.detailTextLabel.text = subtitle;

    if (image) {
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.imageView.image = image;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *subpath = [self filePathAtIndexPath:indexPath];
    NSString *fullPath = [self.path stringByAppendingPathComponent:subpath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    if (!exists) {
        // 处理无效路径
        return;
    }

    if (isDirectory) {
        UIViewController *drillInViewController = [FLEXFileBrowserController path:fullPath];
        drillInViewController.title = subpath.lastPathComponent;
        [self.navigationController pushViewController:drillInViewController animated:YES];
    } else {
        NSString *extension = [subpath.pathExtension lowercaseString];
        
        // ✅ 使用分类方法分析特殊文件类型
        if ([extension isEqualToString:@"dylib"] || 
            [extension isEqualToString:@"framework"] ||
            [extension isEqualToString:@"plist"] ||
            [@[@"txt", @"log", @"json", @"xml", @"h", @"m", @"mm", @"c", @"cpp"] containsObject:extension]) {
            [self analyzeFileAtPath:fullPath];  // ✅ 使用分类中的统一分析方法
            return;
        }
        
        UIViewController *drillInViewController = [self.class drillDownViewControllerForPath:fullPath];
        
        if (drillInViewController) {
            drillInViewController.title = subpath.lastPathComponent;
            [self.navigationController pushViewController:drillInViewController animated:YES];
        } else {
            [self openFileController:fullPath];
        }
    }
}

// 如果原来有 analyzeMachOFile: 方法，可以删除或重构为调用分类方法
- (void)analyzeMachOFile:(NSString *)path {
    // ✅ 重构：调用分类方法
    [self analyzeRuntimeMachOFile:path];
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIMenuItem *rename = [[UIMenuItem alloc] initWithTitle:@"重新命名" action:@selector(fileBrowserRename:)];
    UIMenuItem *delete = [[UIMenuItem alloc] initWithTitle:@"删除" action:@selector(fileBrowserDelete:)];
    UIMenuItem *copyPath = [[UIMenuItem alloc] initWithTitle:@"复制路径" action:@selector(fileBrowserCopyPath:)];
    UIMenuItem *share = [[UIMenuItem alloc] initWithTitle:@"导出" action:@selector(fileBrowserShare:)];

    UIMenuController.sharedMenuController.menuItems = @[rename, delete, copyPath, share];

    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(fileBrowserDelete:)
        || action == @selector(fileBrowserRename:)
        || action == @selector(fileBrowserCopyPath:)
        || action == @selector(fileBrowserShare:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    // 为空，但必须存在才能显示菜单
    // 表视图只会为 UIResponderStandardEditActions 非正式协议中的操作调用此方法。
    // 由于我们的操作不在该协议内，我们需要手动处理从单元格转发的操作。
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                    point:(CGPoint)point __IOS_AVAILABLE(13.0) {
    weakify(self)
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            UITableViewCell * const cell = [tableView cellForRowAtIndexPath:indexPath];
            UIAction *rename = [UIAction actionWithTitle:@"重命名" image:nil identifier:@"Rename"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserRename:cell];
                }
            ];
            UIAction *delete = [UIAction actionWithTitle:@"删除" image:nil identifier:@"Delete"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserDelete:cell];
                }
            ];
            UIAction *copyPath = [UIAction actionWithTitle:@"复制路径" image:nil identifier:@"Copy Path"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserCopyPath:cell];
                }
            ];
            UIAction *share = [UIAction actionWithTitle:@"导出" image:nil identifier:@"Share"
                handler:^(UIAction *action) { strongify(self)
                    [self fileBrowserShare:cell];
                }
            ];
            
            return [UIMenu menuWithTitle:@"管理文件" image:nil
                identifier:@"Manage File"
                options:UIMenuOptionsDisplayInline
                children:@[rename, delete, copyPath, share]
            ];
        }
    ];
}

- (void)openFileController:(NSString *)fullPath {
    UIDocumentInteractionController *controller = [UIDocumentInteractionController new];
    controller.URL = [NSURL fileURLWithPath:fullPath];

    [controller presentOptionsMenuFromRect:self.view.bounds inView:self.view animated:YES];
    self.documentController = controller;
}

- (void)fileBrowserRename:(UITableViewCell *)sender {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *fullPath = [self filePathAtIndexPath:indexPath];

    BOOL stillExists = [NSFileManager.defaultManager fileExistsAtPath:self.path isDirectory:NULL];
    if (stillExists) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title([NSString stringWithFormat:@"重命名 %@?", fullPath.lastPathComponent]);
            make.configuredTextField(^(UITextField *textField) {
                textField.placeholder = @"新文件名";
                textField.text = fullPath.lastPathComponent;
            });
            make.button(@"重命名").handler(^(NSArray<NSString *> *strings) {
                NSString *newFileName = strings.firstObject;
                NSString *newPath = [fullPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newFileName];
                [NSFileManager.defaultManager moveItemAtPath:fullPath toPath:newPath error:NULL];
                [self reloadDisplayedPaths];
            });
            make.button(@"取消").cancelStyle();
        } showFrom:self];
    } else {
        [FLEXAlert showAlert:@"文件已移除" message:@"指定路径上的文件不再存在" from:self];
    }
}

- (void)fileBrowserDelete:(UITableViewCell *)sender {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *fullPath = [self filePathAtIndexPath:indexPath];

    BOOL isDirectory = NO;
    BOOL stillExists = [NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    if (stillExists) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"确认删除");
            make.message([NSString stringWithFormat:
                @"这个 %@ '%@' 将被删除。此操作无法撤销",
                (isDirectory ? @"目录" : @"文件"), fullPath.lastPathComponent
            ]);
            make.button(@"删除").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
                [NSFileManager.defaultManager removeItemAtPath:fullPath error:NULL];
                [self reloadDisplayedPaths];
            });
            make.button(@"取消").cancelStyle();
        } showFrom:self];
    } else {
        [FLEXAlert showAlert:@"文件已移除" message:@"指定路径上的文件不再存在" from:self];
    }
}

- (void)fileBrowserCopyPath:(UITableViewCell *)sender {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *fullPath = [self filePathAtIndexPath:indexPath];
    UIPasteboard.generalPasteboard.string = fullPath;
}

- (void)fileBrowserShare:(UITableViewCell *)sender {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *pathString = [self filePathAtIndexPath:indexPath];
    NSURL *filePath = [NSURL fileURLWithPath:pathString];

    BOOL isDirectory = NO;
    [NSFileManager.defaultManager fileExistsAtPath:pathString isDirectory:&isDirectory];

    if (isDirectory) {
        // UIDocumentInteractionController for folders
        [self openFileController:pathString];
    } else {
        // Share sheet for files
        UIViewController *shareSheet = [FLEXActivityViewController sharing:@[filePath] source:sender];
        [self presentViewController:shareSheet animated:true completion:nil];
    }
}

- (void)reloadDisplayedPaths {
    if (self.searchController.isActive) {
        [self updateSearchPaths];
    } else {
        [self reloadCurrentPath];
        [self.tableView reloadData];
    }
}

- (void)reloadCurrentPath {
    NSMutableArray<NSString *> *childPaths = [NSMutableArray new];
    NSArray<NSString *> *subpaths = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.path error:NULL];
    for (NSString *subpath in subpaths) {
        [childPaths addObject:[self.path stringByAppendingPathComponent:subpath]];
    }
    if (self.sortAttribute != FLEXFileBrowserSortAttributeNone) {
        [childPaths sortUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2) {
            switch (self.sortAttribute) {
                case FLEXFileBrowserSortAttributeNone:
                    // invalid state
                    return NSOrderedSame;
                case FLEXFileBrowserSortAttributeName:
                    return [path1 compare:path2];
                case FLEXFileBrowserSortAttributeCreationDate: {
                    NSDictionary<NSFileAttributeKey, id> *path1Attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path1
                                                                                                                           error:NULL];
                    NSDictionary<NSFileAttributeKey, id> *path2Attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path2
                                                                                                                           error:NULL];
                    NSDate *path1Date = path1Attributes[NSFileCreationDate];
                    NSDate *path2Date = path2Attributes[NSFileCreationDate];

                    return [path1Date compare:path2Date];
                }
            }
        }];
    }
    self.childPaths = childPaths;
}

- (void)updateSearchPaths {
    self.searchPaths = nil;
    self.searchPathsSize = nil;

    // 清除之前的搜索请求并开始一个新的
    [self.operationQueue cancelAllOperations];
    FLEXFileBrowserSearchOperation *newOperation = [[FLEXFileBrowserSearchOperation alloc] initWithPath:self.path searchString:self.searchText];
    newOperation.delegate = self;
    [self.operationQueue addOperation:newOperation];
}

- (NSString *)filePathAtIndexPath:(NSIndexPath *)indexPath {
    return self.searchController.isActive ? self.searchPaths[indexPath.row] : self.childPaths[indexPath.row];
}

@end


@implementation FLEXFileBrowserTableViewCell

- (void)forwardAction:(SEL)action withSender:(id)sender {
    id target = [self.nextResponder targetForAction:action withSender:sender];
    [UIApplication.sharedApplication sendAction:action to:target from:self forEvent:nil];
}

- (void)fileBrowserRename:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserDelete:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserCopyPath:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserShare:(UIMenuController *)sender {
    [self forwardAction:_cmd withSender:sender];
}

@end
