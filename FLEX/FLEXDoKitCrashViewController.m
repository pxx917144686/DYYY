#import "FLEXDoKitCrashViewController.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitCrashViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *crashLogs;
@end

@implementation FLEXDoKitCrashViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"崩溃记录";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self loadCrashLogs];
}

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CrashCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadCrashLogs {
    self.crashLogs = [NSMutableArray new];
    
    // 从沙盒中读取崩溃日志
    NSString *crashLogPath = [self getCrashLogDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:crashLogPath error:nil];
    
    for (NSString *fileName in files) {
        if ([fileName hasSuffix:@".crash"]) {
            NSString *filePath = [crashLogPath stringByAppendingPathComponent:fileName];
            NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
            
            if (content) {
                NSDictionary *crashInfo = @{
                    @"fileName": fileName,
                    @"filePath": filePath,
                    @"content": content,
                    @"date": [self getFileModificationDate:filePath]
                };
                [self.crashLogs addObject:crashInfo];
            }
        }
    }
    
    // 按时间排序
    [self.crashLogs sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj2[@"date"] compare:obj1[@"date"]];
    }];
    
    [self.tableView reloadData];
}

- (NSString *)getCrashLogDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths firstObject];
    NSString *crashPath = [documentsPath stringByAppendingPathComponent:@"CrashLogs"];
    
    // 确保目录存在
    [[NSFileManager defaultManager] createDirectoryAtPath:crashPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    return crashPath;
}

- (NSDate *)getFileModificationDate:(NSString *)filePath {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    return attributes[NSFileModificationDate];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.crashLogs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CrashCell" forIndexPath:indexPath];
    
    NSDictionary *crashInfo = self.crashLogs[indexPath.row];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    cell.textLabel.text = crashInfo[@"fileName"];
    cell.detailTextLabel.text = [formatter stringFromDate:crashInfo[@"date"]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *crashInfo = self.crashLogs[indexPath.row];
    [self showCrashDetail:crashInfo];
}

- (void)showCrashDetail:(NSDictionary *)crashInfo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:crashInfo[@"fileName"]
                                                                   message:crashInfo[@"content"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"分享" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self shareCrashLog:crashInfo];
    }];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:shareAction];
    [alert addAction:closeAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareCrashLog:(NSDictionary *)crashInfo {
    NSString *filePath = crashInfo[@"filePath"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end