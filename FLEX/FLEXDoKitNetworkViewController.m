#import "FLEXDoKitNetworkViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXDoKitNetworkMonitor.h"

@interface FLEXDoKitNetworkViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSArray *networkRequests;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation FLEXDoKitNetworkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"网络监控";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self setupNotifications];
    [self refreshData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 启动网络监控
    [[FLEXDoKitNetworkMonitor sharedInstance] startNetworkMonitoring];
    
    // 定时刷新
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(refreshData)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)setupUI {
    // 导航栏按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"清除"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(clearLogs)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"设置"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(showSettings)];
    
    // 分段控制器
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"成功", @"失败", @"慢请求"]];
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80;
    
    // 布局
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.segmentedControl];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:8],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.tableView.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkRequestRecorded:)
                                                 name:@"FLEXDoKitNetworkRequestRecorded"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkResponseRecorded:)
                                                 name:@"FLEXDoKitNetworkResponseRecorded"
                                               object:nil];
}

- (void)refreshData {
    NSArray *allRequests = [[FLEXDoKitNetworkMonitor sharedInstance] networkRequests];
    
    // 根据分段控制器过滤数据
    switch (self.segmentedControl.selectedSegmentIndex) {
        case 0: // 全部
            self.networkRequests = allRequests;
            break;
        case 1: // 成功
            self.networkRequests = [allRequests filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"statusCode >= 200 AND statusCode < 300"]];
            break;
        case 2: // 失败
            self.networkRequests = [allRequests filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"statusCode >= 400 OR error != nil"]];
            break;
        case 3: // 慢请求
            self.networkRequests = [allRequests filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"duration > 2.0"]];
            break;
    }
    
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self refreshData];
}

- (void)clearLogs {
    [[[FLEXDoKitNetworkMonitor sharedInstance] networkRequests] removeAllObjects];
    [self refreshData];
}

- (void)showSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"网络设置"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *mockAction = [UIAlertAction actionWithTitle:@"Mock数据管理"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [self showMockSettings];
    }];
    
    UIAlertAction *slowNetworkAction = [UIAlertAction actionWithTitle:@"弱网模拟"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
        [self showSlowNetworkSettings];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:mockAction];
    [alert addAction:slowNetworkAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMockSettings {
    // 实现Mock数据设置界面
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mock数据设置"
                                                                   message:@"启用Mock模式后，匹配的网络请求将返回预设数据"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
    BOOL isMockEnabled = NO;
    
    // 检查是否响应selector，然后安全调用
    if ([monitor respondsToSelector:@selector(isMockEnabled)]) {
        NSMethodSignature *signature = [monitor methodSignatureForSelector:@selector(isMockEnabled)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:monitor];
        [invocation setSelector:@selector(isMockEnabled)];
        [invocation invoke];
        [invocation getReturnValue:&isMockEnabled];
    }
    
    NSString *toggleTitle = isMockEnabled ? @"禁用Mock" : @"启用Mock";
    
    UIAlertAction *toggleAction = [UIAlertAction actionWithTitle:toggleTitle
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        if (isMockEnabled) {
            if ([monitor respondsToSelector:@selector(disableMockMode)]) {
                [monitor disableMockMode];
            }
        } else {
            if ([monitor respondsToSelector:@selector(enableMockMode)]) {
                [monitor enableMockMode];
            }
        }
    }];
    
    UIAlertAction *addRuleAction = [UIAlertAction actionWithTitle:@"添加Mock规则"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        [self showAddMockRule];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:toggleAction];
    [alert addAction:addRuleAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAddMockRule {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加Mock规则"
                                                                   message:@"输入URL和返回数据"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"URL (支持部分匹配)";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"状态码 (默认200)";
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"返回数据 (JSON格式)";
    }];
    
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        NSString *url = alert.textFields[0].text;
        NSString *statusCode = alert.textFields[1].text;
        NSString *responseData = alert.textFields[2].text;
        
        if (url.length > 0 && responseData.length > 0) {
            NSDictionary *rule = @{
                @"url": url,
                @"statusCode": @([statusCode integerValue] ?: 200),
                @"responseData": responseData,
                @"headers": @{@"Content-Type": @"application/json"}
            };
            
            [[FLEXDoKitNetworkMonitor sharedInstance] addMockRule:rule];
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:addAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSlowNetworkSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"弱网模拟"
                                                                   message:@"设置网络延迟和错误"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"延迟时间(秒) 0表示不延迟";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    UIAlertAction *setDelayAction = [UIAlertAction actionWithTitle:@"设置延迟"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        NSTimeInterval delay = [alert.textFields[0].text doubleValue];
        [[FLEXDoKitNetworkMonitor sharedInstance] simulateSlowNetwork:delay];
    }];
    
    UIAlertAction *simulateErrorAction = [UIAlertAction actionWithTitle:@"模拟网络错误"
                                                                 style:UIAlertActionStyleDestructive
                                                               handler:^(UIAlertAction *action) {
        [[FLEXDoKitNetworkMonitor sharedInstance] simulateNetworkError];
    }];
    
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"重置"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        [[FLEXDoKitNetworkMonitor sharedInstance] resetNetworkSimulation];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:setDelayAction];
    [alert addAction:simulateErrorAction];
    [alert addAction:resetAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)networkRequestRecorded:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshData];
    });
}

- (void)networkResponseRecorded:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshData];
    });
}

#pragma mark - UITableViewDataSource

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
    
    // 主标题：URL
    cell.textLabel.text = request[@"url"];
    cell.textLabel.numberOfLines = 0;
    
    // 副标题：方法、状态码、耗时
    NSMutableString *subtitle = [NSMutableString string];
    [subtitle appendFormat:@"%@ ", request[@"method"] ?: @"GET"];
    
    if (request[@"statusCode"]) {
        NSInteger statusCode = [request[@"statusCode"] integerValue];
        [subtitle appendFormat:@"%ld ", (long)statusCode];
        
        // 状态码颜色
        if (statusCode >= 200 && statusCode < 300) {
            cell.textLabel.textColor = [UIColor systemGreenColor];
        } else if (statusCode >= 400) {
            cell.textLabel.textColor = [UIColor systemRedColor];
        } else {
            cell.textLabel.textColor = [UIColor systemOrangeColor];
        }
    } else {
        cell.textLabel.textColor = FLEXLabelColor;
    }
    
    if (request[@"duration"]) {
        [subtitle appendFormat:@"%.2fs", [request[@"duration"] doubleValue]];
    }
    
    if (request[@"error"]) {
        [subtitle appendString:@" ❌"];
    }
    
    cell.detailTextLabel.text = subtitle;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *request = self.networkRequests[indexPath.row];
    [self showRequestDetail:request];
}

- (void)showRequestDetail:(NSDictionary *)request {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"请求详情"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    NSMutableString *detail = [NSMutableString string];
    [detail appendFormat:@"URL: %@\n\n", request[@"url"]];
    [detail appendFormat:@"Method: %@\n", request[@"method"]];
    
    if (request[@"statusCode"]) {
        [detail appendFormat:@"Status: %@\n", request[@"statusCode"]];
    }
    
    if (request[@"duration"]) {
        [detail appendFormat:@"Duration: %.2fs\n", [request[@"duration"] doubleValue]];
    }
    
    if (request[@"responseSize"]) {
        [detail appendFormat:@"Size: %@ bytes\n", request[@"responseSize"]];
    }
    
    if (request[@"error"]) {
        [detail appendFormat:@"Error: %@\n", request[@"error"]];
    }
    
    alert.message = detail;
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end