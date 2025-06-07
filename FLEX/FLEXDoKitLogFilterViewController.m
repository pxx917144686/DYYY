#import "FLEXDoKitLogFilterViewController.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性宏

@interface FLEXDoKitLogFilterViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *levelControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<FLEXDoKitLogEntry *> *filteredLogs;
@end

@implementation FLEXDoKitLogFilterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"日志过滤器";
    self.view.backgroundColor = FLEXSystemBackgroundColor;  // ✅ 使用兼容性宏
    
    [self setupUI];
    [self loadLogs];
}

- (void)setupUI {
    // 级别过滤控制
    self.levelControl = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"ERROR", @"WARNING", @"INFO", @"DEBUG"]];
    self.levelControl.selectedSegmentIndex = 0;
    [self.levelControl addTarget:self action:@selector(levelChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索日志内容...";
    self.searchBar.delegate = self;
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FilteredLogCell"];
    
    // 布局
    [self.view addSubview:self.levelControl];
    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.tableView];
    
    self.levelControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.levelControl.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:10],  // ✅ 使用兼容性函数
        [self.levelControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.levelControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.searchBar.topAnchor constraintEqualToAnchor:self.levelControl.bottomAnchor constant:10],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadLogs {
    FLEXDoKitLogViewer *logViewer = [FLEXDoKitLogViewer sharedInstance];
    self.filteredLogs = logViewer.logEntries;  // ✅ 现在类型匹配了
    [self applyFilters];
}

- (void)levelChanged:(UISegmentedControl *)sender {
    [self applyFilters];
}

- (void)applyFilters {
    FLEXDoKitLogViewer *logViewer = [FLEXDoKitLogViewer sharedInstance];
    NSArray<FLEXDoKitLogEntry *> *allLogs = logViewer.logEntries;  // ✅ 正确的类型
    
    // 按级别过滤
    if (self.levelControl.selectedSegmentIndex > 0) {
        FLEXDoKitLogLevel targetLevel = self.levelControl.selectedSegmentIndex - 1;  // ERROR=0, WARNING=1等
        NSPredicate *levelPredicate = [NSPredicate predicateWithFormat:@"level >= %d", targetLevel];
        allLogs = [allLogs filteredArrayUsingPredicate:levelPredicate];
    }
    
    // 按搜索文本过滤
    if (self.searchBar.text.length > 0) {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"message CONTAINS[cd] %@", self.searchBar.text];
        allLogs = [allLogs filteredArrayUsingPredicate:searchPredicate];
    }
    
    self.filteredLogs = allLogs;
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredLogs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"FilteredLogCell"];
    
    // 严格的边界检查
    if (indexPath.row >= self.filteredLogs.count || indexPath.row < 0) {
        cell.textLabel.text = @"⚠️ 数据索引错误";
        cell.textLabel.textColor = FLEXSystemRedColor;  // ✅ 现在已定义
        cell.detailTextLabel.text = [NSString stringWithFormat:@"索引: %ld, 数组长度: %lu", 
                                   (long)indexPath.row, (unsigned long)self.filteredLogs.count];
        return cell;
    }
    
    FLEXDoKitLogEntry *logEntry = self.filteredLogs[indexPath.row];
    
    // 类型安全检查
    if (![logEntry isKindOfClass:[FLEXDoKitLogEntry class]]) {
        cell.textLabel.text = @"⚠️ 数据类型错误";
        cell.textLabel.textColor = FLEXSystemRedColor;  // ✅ 现在已定义
        cell.detailTextLabel.text = [NSString stringWithFormat:@"预期: FLEXDoKitLogEntry, 实际: %@", 
                                   NSStringFromClass([logEntry class])];
        return cell;
    }
    
    NSString *message = logEntry.message;
    NSString *levelString = [self stringForLogLevel:logEntry.level];
    
    // 空值检查
    if (!message || ![message isKindOfClass:[NSString class]]) {
        cell.textLabel.text = @"⚠️ 消息数据缺失";
        cell.textLabel.textColor = FLEXSystemRedColor;  // ✅ 现在已定义
        cell.detailTextLabel.text = @"日志消息为空或类型错误";
        return cell;
    }
    
    cell.textLabel.text = message;
    cell.detailTextLabel.text = levelString ?: @"UNKNOWN";
    
    // 根据日志级别设置颜色
    switch (logEntry.level) {
        case FLEXDoKitLogLevelError:
            cell.textLabel.textColor = FLEXSystemRedColor;  // ✅ 现在已定义
            break;
        case FLEXDoKitLogLevelWarning:
            cell.textLabel.textColor = FLEXSystemOrangeColor;  // ✅ 现在已定义
            break;
        default:
            cell.textLabel.textColor = FLEXLabelColor;  // ✅ 现在已定义
            break;
    }
    
    return cell;
}

- (NSString *)stringForLogLevel:(FLEXDoKitLogLevel)level {
    switch (level) {
        case FLEXDoKitLogLevelVerbose: return @"VERBOSE";
        case FLEXDoKitLogLevelDebug: return @"DEBUG";
        case FLEXDoKitLogLevelInfo: return @"INFO";
        case FLEXDoKitLogLevelWarning: return @"WARNING";
        case FLEXDoKitLogLevelError: return @"ERROR";
        default: return @"UNKNOWN";
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilters];
}

@end