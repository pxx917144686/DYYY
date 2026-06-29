#import "FLEXDoKitFileBrowserViewController.h"

@interface FLEXDoKitFileBrowserViewController ()
@property (nonatomic, strong) NSArray *directoryContents;
@property (nonatomic, strong) NSString *currentPath;
@end

@implementation FLEXDoKitFileBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"文件浏览器";
    
    // 如果没有设置根路径，使用Documents目录
    if (!self.rootPath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        self.rootPath = paths.firstObject;
    }
    
    self.currentPath = self.rootPath;
    [self loadDirectoryContents];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FileCell"];
}

- (void)loadDirectoryContents {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:self.currentPath error:&error];
    
    if (error) {
        NSLog(@"❌ 读取目录失败: %@", error.localizedDescription);
        self.directoryContents = @[];
    } else {
        // 按类型和名称排序
        self.directoryContents = [contents sortedArrayUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
            NSString *path1 = [self.currentPath stringByAppendingPathComponent:file1];
            NSString *path2 = [self.currentPath stringByAppendingPathComponent:file2];
            
            BOOL isDir1, isDir2;
            [[NSFileManager defaultManager] fileExistsAtPath:path1 isDirectory:&isDir1];
            [[NSFileManager defaultManager] fileExistsAtPath:path2 isDirectory:&isDir2];
            
            // 目录优先
            if (isDir1 && !isDir2) return NSOrderedAscending;
            if (!isDir1 && isDir2) return NSOrderedDescending;
            
            // 同类型按名称排序
            return [file1 localizedCaseInsensitiveCompare:file2];
        }];
    }
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.directoryContents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FileCell" forIndexPath:indexPath];
    
    NSString *fileName = self.directoryContents[indexPath.row];
    NSString *filePath = [self.currentPath stringByAppendingPathComponent:fileName];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    cell.textLabel.text = fileName;
    cell.accessoryType = isDirectory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    // 设置图标
    if (isDirectory) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
    } else {
        cell.imageView.image = [UIImage systemImageNamed:@"doc.fill"];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *fileName = self.directoryContents[indexPath.row];
    NSString *filePath = [self.currentPath stringByAppendingPathComponent:fileName];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    if (isDirectory) {
        // 进入子目录
        FLEXDoKitFileBrowserViewController *subDirVC = [[FLEXDoKitFileBrowserViewController alloc] init];
        subDirVC.rootPath = filePath;
        subDirVC.title = fileName;
        [self.navigationController pushViewController:subDirVC animated:YES];
    } else {
        // 显示文件信息
        [self showFileInfo:filePath];
    }
}

- (void)showFileInfo:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
    
    NSString *fileName = [filePath lastPathComponent];
    NSString *fileSize = [self formatFileSize:[attributes[NSFileSize] unsignedLongLongValue]];
    NSDate *modDate = attributes[NSFileModificationDate];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    NSString *modDateStr = [formatter stringFromDate:modDate];
    
    NSString *message = [NSString stringWithFormat:@"文件名: %@\n大小: %@\n修改时间: %@", fileName, fileSize, modDateStr];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"文件信息"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)formatFileSize:(unsigned long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%llu B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end