#import "FLEXDoKitDatabaseViewController.h"
#import "FLEXCompatibility.h"  // 添加兼容性导入
#import <sqlite3.h>

@interface FLEXDoKitDatabaseViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSString *> *databaseFiles;
@end

@implementation FLEXDoKitDatabaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"数据库查看";
    self.view.backgroundColor = FLEXSystemBackgroundColor;  // ✅ 使用兼容性宏
    
    self.databaseFiles = [NSMutableArray new];
    [self scanForDatabases];
    [self setupTableView];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DatabaseCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],  // ✅ 使用兼容性函数
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:FLEXSafeAreaBottomAnchor(self)]  // ✅ 使用兼容性函数
    ]];
}

- (void)scanForDatabases {
    [self.databaseFiles removeAllObjects];
    
    // 搜索Documents目录
    [self scanDirectory:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject];
    
    // 搜索Library目录
    [self scanDirectory:NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject];
    
    // 搜索Caches目录
    [self scanDirectory:NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject];
    
    [self.tableView reloadData];
}

- (void)scanDirectory:(NSString *)directoryPath {
    if (!directoryPath) return;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        NSLog(@"扫描目录失败 %@: %@", directoryPath, error.localizedDescription);
        return;
    }
    
    for (NSString *item in contents) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:item];
        NSString *extension = [item pathExtension].lowercaseString;
        
        if ([extension isEqualToString:@"sqlite"] || 
            [extension isEqualToString:@"db"] || 
            [extension isEqualToString:@"sqlite3"]) {
            [self.databaseFiles addObject:fullPath];
        }
        
        // 递归搜索子目录
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory] && isDirectory) {
            [self scanDirectory:fullPath];
        }
    }
}

- (void)viewDatabase:(NSString *)databasePath {
    sqlite3 *db = NULL;
    sqlite3_stmt *statement = NULL;
    
    @try {
        int result = sqlite3_open([databasePath UTF8String], &db);
        
        if (result != SQLITE_OK) {
            NSString *errorMessage = [NSString stringWithFormat:@"打开数据库失败: %s", 
                                    db ? sqlite3_errmsg(db) : "无法分配内存"];
            [self showAlert:@"数据库错误" message:errorMessage];
            return;
        }
        
        const char *sql = "SELECT name FROM sqlite_master WHERE type=? ORDER BY name;";
        result = sqlite3_prepare_v2(db, sql, -1, &statement, NULL);
        
        if (result != SQLITE_OK) {
            NSString *errorMessage = [NSString stringWithFormat:@"SQL准备失败: %s", sqlite3_errmsg(db)];
            [self showAlert:@"SQL错误" message:errorMessage];
            return;
        }
        
        sqlite3_bind_text(statement, 1, "table", -1, SQLITE_STATIC);
        
        NSMutableArray *tables = [NSMutableArray array];
        
        while ((result = sqlite3_step(statement)) == SQLITE_ROW) {
            char *nameChars = (char *)sqlite3_column_text(statement, 0);
            if (nameChars) {
                NSString *tableName = [NSString stringWithUTF8String:nameChars];
                if (tableName && tableName.length > 0) {
                    [tables addObject:tableName];
                }
            }
        }
        
        if (result != SQLITE_DONE) {
            NSLog(@"⚠️ SQLite查询警告: %s", sqlite3_errmsg(db));
        }
        
        [self showTablesForDatabase:databasePath tables:tables];
        
    } @catch (NSException *exception) {
        NSLog(@"❌ 数据库操作异常: %@", exception.reason);
        [self showAlert:@"数据库异常" message:exception.reason];
        
    } @finally {
        // 确保资源始终被释放
        if (statement) {
            sqlite3_finalize(statement);
        }
        if (db) {
            sqlite3_close(db);
        }
    }
}

- (void)showTablesForDatabase:(NSString *)databasePath tables:(NSArray *)tables {
    NSString *message;
    if (tables.count == 0) {
        message = @"数据库中没有找到表";
    } else {
        message = [NSString stringWithFormat:@"数据库包含 %lu 个表:\n%@", 
                  (unsigned long)tables.count, [tables componentsJoinedByString:@"\n"]];
    }
    
    [self showAlert:@"数据库表" message:message];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.databaseFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DatabaseCell" forIndexPath:indexPath];
    
    NSString *databasePath = self.databaseFiles[indexPath.row];
    cell.textLabel.text = [databasePath lastPathComponent];
    cell.detailTextLabel.text = databasePath;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *databasePath = self.databaseFiles[indexPath.row];
    [self viewDatabase:databasePath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"找到 %lu 个数据库文件", (unsigned long)self.databaseFiles.count];
}

@end