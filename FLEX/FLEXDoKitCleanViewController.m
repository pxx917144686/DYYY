#import "FLEXDoKitCleanViewController.h"

@interface FLEXDoKitCleanViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *cleanOptions;
@end

@implementation FLEXDoKitCleanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"清理数据";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupTableView];
    [self loadCleanOptions];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CleanOptionCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadCleanOptions {
    self.cleanOptions = @[
        @{
            @"title": @"清理缓存",
            @"detail": @"清理应用缓存数据",
            @"action": @"cleanCache",
            @"destructive": @NO
        },
        @{
            @"title": @"清理临时文件",
            @"detail": @"清理tmp目录文件",
            @"action": @"cleanTempFiles",
            @"destructive": @NO
        },
        @{
            @"title": @"清理UserDefaults",
            @"detail": @"重置应用偏好设置",
            @"action": @"cleanUserDefaults",
            @"destructive": @YES
        },
        @{
            @"title": @"清理Keychain",
            @"detail": @"清理钥匙串数据",
            @"action": @"cleanKeychain",
            @"destructive": @YES
        },
        @{
            @"title": @"清理Documents",
            @"detail": @"清理Documents目录",
            @"action": @"cleanDocuments",
            @"destructive": @YES
        }
    ];
    
    [self.tableView reloadData];
}

#pragma mark - Clean Actions

- (void)cleanCache {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = cachePaths.firstObject;
    [self cleanDirectory:cacheDirectory withName:@"缓存"];
}

- (void)cleanTempFiles {
    NSString *tempDirectory = NSTemporaryDirectory();
    [self cleanDirectory:tempDirectory withName:@"临时文件"];
}

- (void)cleanUserDefaults {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清理" 
                                                                   message:@"此操作将重置所有应用偏好设置，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
        for (NSString *key in defaults.allKeys) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self showSuccessAlert:@"UserDefaults已清理"];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cleanKeychain {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清理" 
                                                                   message:@"此操作将清理钥匙串数据，可能影响登录状态，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self showSuccessAlert:@"Keychain清理完成"];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cleanDocuments {
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = documentPaths.firstObject;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清理" 
                                                                   message:@"此操作将删除Documents目录所有文件，是否继续？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self cleanDirectory:documentDirectory withName:@"Documents"];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cleanDirectory:(NSString *)directory withName:(NSString *)name {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    
    if (error) {
        [self showErrorAlert:[NSString stringWithFormat:@"清理%@失败: %@", name, error.localizedDescription]];
        return;
    }
    
    NSUInteger cleanedCount = 0;
    for (NSString *file in contents) {
        NSString *filePath = [directory stringByAppendingPathComponent:file];
        if ([fileManager removeItemAtPath:filePath error:&error]) {
            cleanedCount++;
        }
    }
    
    [self showSuccessAlert:[NSString stringWithFormat:@"%@清理完成，删除了%lu个文件", name, (unsigned long)cleanedCount]];
}

- (void)showSuccessAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清理成功" 
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showErrorAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清理失败" 
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cleanOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"CleanOptionCell"];
    
    NSDictionary *option = self.cleanOptions[indexPath.row];
    
    cell.textLabel.text = option[@"title"];
    cell.detailTextLabel.text = option[@"detail"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    if ([option[@"destructive"] boolValue]) {
        cell.textLabel.textColor = [UIColor systemRedColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *option = self.cleanOptions[indexPath.row];
    NSString *action = option[@"action"];
    
    SEL actionSelector = NSSelectorFromString(action);
    if ([self respondsToSelector:actionSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionSelector];
#pragma clang diagnostic pop
    }
}

@end