#import "FLEXDoKitNetworkHistoryViewController.h"
#import "FLEXDoKitNetworkMonitor.h"

@interface FLEXDoKitNetworkHistoryViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *networkRequests;
@property (nonatomic, strong) NSArray *filteredRequests;
@end

@implementation FLEXDoKitNetworkHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"网络历史记录";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupUI];
    [self loadNetworkRequests];
    
    // 监听网络请求更新
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(networkRequestUpdated:) 
                                                 name:@"FLEXDoKitNetworkRequestRecorded" 
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索URL或方法...";
    self.searchBar.delegate = self;
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"NetworkHistoryCell"];
    
    // 清除按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                             initWithTitle:@"清除" 
                                             style:UIBarButtonItemStylePlain 
                                             target:self 
                                             action:@selector(clearHistory)];
    
    // 布局
    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.tableView];
    
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadNetworkRequests {
    FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
    self.networkRequests = [monitor.networkRequests copy];
    [self applyFilter];
}

- (void)applyFilter {
    if (self.searchBar.text.length == 0) {
        self.filteredRequests = self.networkRequests;
    } else {
        NSString *searchText = self.searchBar.text.lowercaseString;
        self.filteredRequests = [self.networkRequests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *request, NSDictionary *bindings) {
            NSString *url = request[@"url"] ?: @"";
            NSString *method = request[@"method"] ?: @"";
            return [url.lowercaseString containsString:searchText] || [method.lowercaseString containsString:searchText];
        }]];
    }
    [self.tableView reloadData];
}

- (void)networkRequestUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadNetworkRequests];
    });
}

- (void)clearHistory {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清除" 
                                                                   message:@"确定要清除所有网络历史记录吗？" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
        [monitor.networkRequests removeAllObjects];
        [self loadNetworkRequests];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:clearAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NetworkHistoryCell" forIndexPath:indexPath];
    
    NSDictionary *request = self.filteredRequests[indexPath.row];
    
    cell.textLabel.text = request[@"url"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", 
                               request[@"method"] ?: @"GET", 
                               request[@"statusCode"] ?: @"Unknown"];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *request = self.filteredRequests[indexPath.row];
    
    // 显示详细信息
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"请求详情" 
                                                                   message:[NSString stringWithFormat:@"URL: %@\n方法: %@\n状态码: %@", 
                                                                          request[@"url"], 
                                                                          request[@"method"], 
                                                                          request[@"statusCode"]]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilter];
}

@end