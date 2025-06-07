#import "FLEXNetworkMonitorViewController.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXCompatibility.h"  // ✅ 添加兼容性头文件

@interface FLEXNetworkMonitorViewController ()
@property (nonatomic, strong) NSArray *networkRequests;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation FLEXNetworkMonitorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"网络监控";
    
    // 开始网络监控
    [[FLEXDoKitNetworkMonitor sharedInstance] startNetworkMonitoring];
    
    // 导航栏按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"清除"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(clearNetworkLogs)];
    
    // 定时刷新
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(refreshData)
                                                       userInfo:nil
                                                        repeats:YES];
    
    [self refreshData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)refreshData {
    self.networkRequests = [[[FLEXDoKitNetworkMonitor sharedInstance] networkRequests] copy];
    [self.tableView reloadData];
}

- (void)clearNetworkLogs {
    [[[FLEXDoKitNetworkMonitor sharedInstance] networkRequests] removeAllObjects];
    [self refreshData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.networkRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"NetworkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    NSDictionary *request = self.networkRequests[indexPath.row];
    
    // 主标题：URL的最后部分
    NSURL *url = [NSURL URLWithString:request[@"url"]];
    cell.textLabel.text = url.path.lastPathComponent ?: url.host;
    cell.textLabel.numberOfLines = 2;
    
    // 副标题：方法、状态码、耗时
    NSMutableString *subtitle = [NSMutableString string];
    [subtitle appendFormat:@"%@ ", request[@"method"] ?: @"GET"];
    
    if (request[@"statusCode"]) {
        NSInteger statusCode = [request[@"statusCode"] integerValue];
        [subtitle appendFormat:@"%ld ", (long)statusCode];
        
        // 状态码颜色
        if (statusCode >= 200 && statusCode < 300) {
            cell.textLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
        } else if (statusCode >= 400) {
            cell.textLabel.textColor = FLEXSystemRedColor;    // ✅ 使用兼容性宏
        } else {
            cell.textLabel.textColor = FLEXSystemOrangeColor; // ✅ 使用兼容性宏
        }
    } else {
        cell.textLabel.textColor = FLEXLabelColor;
    }
    
    if (request[@"duration"]) {
        [subtitle appendFormat:@"%.0fms", [request[@"duration"] doubleValue] * 1000];
    }
    
    cell.detailTextLabel.text = subtitle;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *request = self.networkRequests[indexPath.row];
    
    // 显示网络请求详情
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"网络请求详情" 
                                                                   message:[NSString stringWithFormat:@"URL: %@\n方法: %@\n状态码: %@", 
                                                                           request[@"url"], 
                                                                           request[@"method"] ?: @"GET", 
                                                                           request[@"statusCode"] ?: @"未知"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end