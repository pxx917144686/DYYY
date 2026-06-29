#import "FLEXNetworkMonitorViewController.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXCompatibility.h"
#import "FLEXNetworkMITMViewController.h"
#import "FLEXNetworkSettingsController.h"
#import "FLEXNetworkWeakViewController.h"
#import "FLEXDoKitWeakNetworkViewController.h"
#import "FLEXDoKitMockViewController.h"

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
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc]
            initWithTitle:@"清除"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(clearNetworkLogs)],
        [[UIBarButtonItem alloc]
            initWithTitle:@"设置"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(showSettings)]
    ];
    
    // 监听网络请求通知，实现实时更新
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRequestUpdate:)
                                                 name:FLEXDoKitNetworkRequestRecordedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRequestUpdate:)
                                                 name:FLEXDoKitNetworkResponseRecordedNotification
                                               object:nil];
    
    // 定时刷新（作为兜底）
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 数据刷新

- (void)handleRequestUpdate:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshData];
    });
}

- (void)refreshData {
    self.networkRequests = [[[FLEXDoKitNetworkMonitor sharedInstance] networkRequests] copy];
    [self.tableView reloadData];
}

- (void)clearNetworkLogs {
    [[FLEXDoKitNetworkMonitor sharedInstance] clearAllNetworkRequests];
    [self refreshData];
}

- (void)showSettings {
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"网络工具" 
        message:@"选择要打开的功能"
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"MITM 抓包详情" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        FLEXNetworkMITMViewController *mitmVC = [FLEXNetworkMITMViewController new];
        [self.navigationController pushViewController:mitmVC animated:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"网络设置" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        FLEXNetworkSettingsController *settingsVC = [FLEXNetworkSettingsController new];
        [self.navigationController pushViewController:settingsVC animated:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"弱网模拟" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        FLEXDoKitWeakNetworkViewController *weakVC = [FLEXDoKitWeakNetworkViewController new];
        [self.navigationController pushViewController:weakVC animated:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Mock 数据" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        FLEXDoKitMockViewController *mockVC = [FLEXDoKitMockViewController new];
        [self.navigationController pushViewController:mockVC animated:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    // iPad 适配
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    
    [self presentViewController:alert animated:YES completion:nil];
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
    cell.textLabel.font = [UIFont systemFontOfSize:14.0];
    
    // 副标题：方法、状态码、耗时
    NSMutableString *subtitle = [NSMutableString string];
    [subtitle appendFormat:@"%@ ", request[@"method"] ?: @"GET"];
    
    UIColor *statusColor = FLEXLabelColor;
    
    if (request[@"statusCode"]) {
        NSInteger statusCode = [request[@"statusCode"] integerValue];
        [subtitle appendFormat:@"%ld ", (long)statusCode];
        
        // 状态码颜色
        if (statusCode >= 200 && statusCode < 300) {
            statusColor = FLEXSystemGreenColor;
        } else if (statusCode >= 400) {
            statusColor = FLEXSystemRedColor;
        } else if (statusCode >= 300) {
            statusColor = FLEXSystemOrangeColor;
        }
    } else {
        // 进行中的请求
        NSInteger state = [request[@"state"] integerValue];
        if (state == 0 || state == 1) {
            [subtitle appendString:@"请求中..."];
            statusColor = FLEXSystemOrangeColor;
        }
    }
    
    cell.textLabel.textColor = statusColor;
    
    if (request[@"duration"]) {
        NSTimeInterval duration = [request[@"duration"] doubleValue];
        [subtitle appendFormat:@"%.0fms", duration * 1000];
    }
    
    if (request[@"error"]) {
        [subtitle appendFormat:@" ❌ %@", request[@"error"]];
    }
    
    cell.detailTextLabel.text = subtitle;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    cell.detailTextLabel.textColor = FLEXSecondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *request = self.networkRequests[indexPath.row];
    
    // 显示网络请求详情
    NSMutableString *message = [NSMutableString string];
    [message appendFormat:@"URL: %@\n", request[@"url"] ?: @""];
    [message appendFormat:@"方法: %@\n", request[@"method"] ?: @"GET"];
    
    if (request[@"statusCode"]) {
        [message appendFormat:@"状态码: %@\n", request[@"statusCode"]];
    }
    
    if (request[@"duration"]) {
        [message appendFormat:@"耗时: %.0fms\n", [request[@"duration"] doubleValue] * 1000];
    }
    
    if (request[@"receivedDataLength"]) {
        [message appendFormat:@"数据大小: %lld bytes\n", [request[@"receivedDataLength"] longLongValue]];
    }
    
    if (request[@"error"]) {
        [message appendFormat:@"错误: %@\n", request[@"error"]];
    }
    
    if (request[@"requestMechanism"]) {
        [message appendFormat:@"机制: %@\n", request[@"requestMechanism"]];
    }
    
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"网络请求详情" 
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制 URL" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = request[@"url"] ?: @"";
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"查看响应" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showResponseDetail:request];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showResponseDetail:(NSDictionary *)request {
    NSString *responseData = request[@"responseData"] ?: @"暂无响应数据";
    
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"响应数据"
        message:responseData
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = responseData;
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
