//
//  FLEXNetworkWeakViewController.m
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXNetworkWeakViewController.h"
#import "FLEXNetworkWeakTester.h"

@interface FLEXNetworkWeakViewController ()

@property (nonatomic, strong) NSArray *networkTypesList;

@end

@implementation FLEXNetworkWeakViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"弱网测试";
    self.networkTypesList = @[
        @{@"title": @"关闭", @"type": @(FLEXNetworkWeakTypeNone)},
        @{@"title": @"超慢 2G", @"type": @(FLEXNetworkWeakTypeSlow2G)},
        @{@"title": @"2G 网络", @"type": @(FLEXNetworkWeakType2G)},
        @{@"title": @"3G 网络", @"type": @(FLEXNetworkWeakType3G)},
        @{@"title": @"4G 网络", @"type": @(FLEXNetworkWeakType4G)},
        @{@"title": @"WiFi", @"type": @(FLEXNetworkWeakTypeWifi)},
        @{@"title": @"断网", @"type": @(FLEXNetworkWeakTypeDisconnect)}
    ];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"NetworkTypeCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.networkTypesList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NetworkTypeCell" forIndexPath:indexPath];
    
    NSDictionary *networkType = self.networkTypesList[indexPath.row];
    cell.textLabel.text = networkType[@"title"];
    
    // 检查当前选中的网络类型
    FLEXNetworkWeakType currentType = [FLEXNetworkWeakTester sharedInstance].currentWeakType;
    FLEXNetworkWeakType cellType = [networkType[@"type"] integerValue];
    
    cell.accessoryType = (currentType == cellType) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *networkType = self.networkTypesList[indexPath.row];
    FLEXNetworkWeakType type = [networkType[@"type"] integerValue];
    
    if (type == FLEXNetworkWeakTypeNone) {
        [[FLEXNetworkWeakTester sharedInstance] stopWeakNetwork];
    } else {
        [[FLEXNetworkWeakTester sharedInstance] startWeakNetworkWithType:type];
    }
    
    [self.tableView reloadData];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"选择网络类型";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"此功能使用请求延迟和连接限制来模拟不同网络环境。\n注意：仅影响使用NSURLSession的网络请求。";
}

@end