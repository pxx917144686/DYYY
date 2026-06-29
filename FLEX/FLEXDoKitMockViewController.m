#import "FLEXDoKitMockViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXDoKitNetworkMonitor.h"

@interface FLEXDoKitMockViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *mockRules;
@property (nonatomic, strong) UISwitch *mockSwitch;
@end

@implementation FLEXDoKitMockViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Mock数据管理";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    self.mockRules = [NSMutableArray array];
    [self setupUI];
    [self loadDefaultMockRules];
}

- (void)setupUI {
    // Mock总开关
    self.mockSwitch = [[UISwitch alloc] init];
    [self.mockSwitch addTarget:self action:@selector(mockSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UILabel *switchLabel = [[UILabel alloc] init];
    switchLabel.text = @"启用Mock";
    switchLabel.font = [UIFont systemFontOfSize:16];
    
    UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[switchLabel, self.mockSwitch]];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.distribution = UIStackViewDistributionEqualSpacing;
    headerStack.alignment = UIStackViewAlignmentCenter;
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"MockRuleCell"];
    
    // 添加按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
                                             target:self 
                                             action:@selector(addMockRule)];
    
    // 布局
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:headerStack];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [headerStack.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:20],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.tableView.topAnchor constraintEqualToAnchor:headerStack.bottomAnchor constant:20],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadDefaultMockRules {
    // 添加一些示例Mock规则
    [self.mockRules addObjectsFromArray:@[
        @{
            @"url": @"api/user/info",
            @"method": @"GET",
            @"statusCode": @200,
            @"responseData": @"{\"name\":\"测试用户\",\"id\":123}",
            @"enabled": @YES
        },
        @{
            @"url": @"api/login",
            @"method": @"POST", 
            @"statusCode": @200,
            @"responseData": @"{\"token\":\"mock_token_123\",\"success\":true}",
            @"enabled": @NO
        }
    ]];
    [self.tableView reloadData];
}

- (void)mockSwitchChanged:(UISwitch *)sender {
    if (sender.on) {
        [[FLEXDoKitNetworkMonitor sharedInstance] enableMockMode];
        // 添加所有启用的Mock规则
        for (NSDictionary *rule in self.mockRules) {
            if ([rule[@"enabled"] boolValue]) {
                [[FLEXDoKitNetworkMonitor sharedInstance] addMockRule:rule];
            }
        }
    } else {
        [[FLEXDoKitNetworkMonitor sharedInstance] disableMockMode];
    }
}

- (void)addMockRule {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加Mock规则" 
                                                                   message:@"配置URL和响应数据" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"URL (如: api/user/info)";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"响应数据 (JSON格式)";
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *addAction = [UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *url = alert.textFields[0].text;
        NSString *responseData = alert.textFields[1].text;
        
        if (url.length > 0 && responseData.length > 0) {
            NSDictionary *rule = @{
                @"url": url,
                @"method": @"GET",
                @"statusCode": @200,
                @"responseData": responseData,
                @"enabled": @YES
            };
            [self.mockRules addObject:rule];
            [self.tableView reloadData];
        }
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:addAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mockRules.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MockRuleCell" forIndexPath:indexPath];
    
    NSDictionary *rule = self.mockRules[indexPath.row];
    cell.textLabel.text = rule[@"url"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", rule[@"method"], rule[@"statusCode"]];
    cell.accessoryType = [rule[@"enabled"] boolValue] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSMutableDictionary *rule = [self.mockRules[indexPath.row] mutableCopy];
    rule[@"enabled"] = @(![rule[@"enabled"] boolValue]);
    self.mockRules[indexPath.row] = rule;
    
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end