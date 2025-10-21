#import "FLEXDoKitLogViewController.h"

@interface FLEXDoKitLogViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *logEntries;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *filteredLogs;
@property (nonatomic, strong) UISwitch *autoScrollSwitch;
@property (nonatomic, assign) NSUInteger lastLogIndex;
@end

@implementation FLEXDoKitLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"实时日志";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.logEntries = [NSMutableArray array];
    [self setupUI];
    [self startLogMonitoring];
}

- (void)setupUI {
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜索日志内容";
    self.searchBar.delegate = self;
    
    // 自动滚动开关
    self.autoScrollSwitch = [[UISwitch alloc] init];
    self.autoScrollSwitch.on = YES;
    
    UILabel *scrollLabel = [[UILabel alloc] init];
    scrollLabel.text = @"自动滚动";
    scrollLabel.font = [UIFont systemFontOfSize:14];
    
    UIStackView *controlStack = [[UIStackView alloc] initWithArrangedSubviews:@[scrollLabel, self.autoScrollSwitch]];
    controlStack.axis = UILayoutConstraintAxisHorizontal;
    controlStack.spacing = 10;
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];
    
    // 清除按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                             initWithTitle:@"清除" 
                                             style:UIBarButtonItemStylePlain 
                                             target:self 
                                             action:@selector(clearLogs)];
    
    // 布局
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    controlStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.searchBar];
    [self.view addSubview:controlStack];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [controlStack.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:10],
        [controlStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [controlStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.tableView.topAnchor constraintEqualToAnchor:controlStack.bottomAnchor constant:10],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)startLogMonitoring {
    // 重定向控制台日志到文件
    [self redirectConsoleLogToDocuments];
    
    // 开始定期读取日志
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(readLogFile)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)redirectConsoleLogToDocuments {
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count == 0) {
            NSLog(@"❌ 无法获取Documents目录");
            return;
        }
        
        NSString *documentsDirectory = paths.firstObject;
        NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"flex_console.log"];
        
        // 检查文件操作权限
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager isWritableFileAtPath:documentsDirectory]) {
            NSLog(@"❌ Documents目录不可写");
            return;
        }
        
        // 检查freopen返回值
        FILE *logFile = freopen([logPath UTF8String], "a", stderr);
        if (logFile == NULL) {
            NSLog(@"❌ 日志重定向失败: %s", strerror(errno));
            return;
        }
        
        // 设置缓冲模式
        setbuf(logFile, NULL);  // 无缓冲，立即写入
        
        NSLog(@"✅ 日志重定向成功: %@", logPath);
        
    } @catch (NSException *exception) {
        NSLog(@"❌ 日志重定向异常: %@", exception.reason);
        
        // 异常恢复机制
        freopen("/dev/stderr", "a", stderr);
    }
}

- (void)readLogFile {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newLogEntries = [NSMutableArray array];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count == 0) return;
        
        NSString *documentsDirectory = paths.firstObject;
        NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"flex_console.log"];
        
        // 检查文件是否存在
        if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
            return;
        }
        
        NSError *error;
        NSString *logContent = [NSString stringWithContentsOfFile:logPath 
                                                         encoding:NSUTF8StringEncoding 
                                                            error:&error];
        
        if (error) {
            NSLog(@"❌ 读取日志文件失败: %@", error.localizedDescription);
            return;
        }
        
        if (!logContent || logContent.length == 0) {
            return;
        }
        
        // 解析日志内容
        NSArray *logLines = [logContent componentsSeparatedByString:@"\n"];
        
        for (NSString *line in logLines) {
            if (line.length > 0) {
                NSDictionary *logEntry = [self parseLogLine:line];
                if (logEntry) {
                    [newLogEntries addObject:logEntry];
                }
            }
        }
        
        // ✅ 修复：正确的代码块结构
        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized(self.logEntries) {
                [self.logEntries addObjectsFromArray:newLogEntries];
                
                // 限制日志数量，防止内存溢出
                if (self.logEntries.count > 1000) {
                    NSRange removeRange = NSMakeRange(0, self.logEntries.count - 1000);
                    [self.logEntries removeObjectsInRange:removeRange];
                }
                
                [self filterLogs];
                [self.tableView reloadData];
                
                // 自动滚动到底部
                if (self.autoScrollSwitch.isOn && self.filteredLogs.count > 0) {
                    NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:self.filteredLogs.count - 1 inSection:0];
                    [self.tableView scrollToRowAtIndexPath:lastIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
                }
            }
        });
    });
}

- (NSDictionary *)parseLogLine:(NSString *)line {
    // 简单的日志格式解析：[时间] 级别: 消息
    NSRange bracketRange = [line rangeOfString:@"]"];
    if (bracketRange.location != NSNotFound) {
        NSString *timestamp = [line substringToIndex:bracketRange.location + 1];
        NSString *remaining = [line substringFromIndex:bracketRange.location + 1];
        
        // 查找级别
        NSArray *levels = @[@"ERROR", @"WARNING", @"INFO", @"DEBUG"];
        NSString *level = @"INFO";
        NSString *message = remaining;
        
        for (NSString *levelString in levels) {
            if ([remaining containsString:levelString]) {
                level = levelString;
                NSRange levelRange = [remaining rangeOfString:levelString];
                message = [remaining substringFromIndex:levelRange.location + levelRange.length];
                break;
            }
        }
        
        return @{
            @"timestamp": timestamp,
            @"level": level,
            @"message": [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        };
    }
    
    return @{
        @"timestamp": @"",
        @"level": @"INFO",
        @"message": line
    };
}

- (void)filterLogs {
    if (self.searchBar.text.length == 0) {
        self.filteredLogs = [self.logEntries copy];
    } else {
        NSString *searchText = self.searchBar.text.lowercaseString;
        self.filteredLogs = [self.logEntries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *log, NSDictionary *bindings) {
            NSString *message = log[@"message"] ?: @"";
            return [message.lowercaseString containsString:searchText];
        }]];
    }
}

- (void)clearLogs {
    @synchronized(self.logEntries) {
        [self.logEntries removeAllObjects];
        [self filterLogs];
        [self.tableView reloadData];
    }
    
    // 清空日志文件
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        NSString *documentsDirectory = paths.firstObject;
        NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"flex_console.log"];
        [@"" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    @synchronized(self.logEntries) {
        return self.filteredLogs.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    @synchronized(self.logEntries) {
        // 严格边界检查
        if (indexPath.row >= self.filteredLogs.count) {
            UITableViewCell *errorCell = [[UITableViewCell alloc] init];
            errorCell.textLabel.text = @"⚠️ 数据索引错误";
            errorCell.textLabel.textColor = [UIColor systemRedColor];
            return errorCell;
        }
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LogCell" forIndexPath:indexPath];
        NSDictionary *logEntry = self.filteredLogs[indexPath.row];
        
        NSString *timestamp = logEntry[@"timestamp"] ?: @"";
        NSString *level = logEntry[@"level"] ?: @"INFO";
        NSString *message = logEntry[@"message"] ?: @"";
        
        cell.textLabel.text = message;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", timestamp, level];
        cell.textLabel.numberOfLines = 0;
        
        // 根据日志级别设置颜色
        if ([level isEqualToString:@"ERROR"]) {
            cell.textLabel.textColor = [UIColor systemRedColor];
        } else if ([level isEqualToString:@"WARNING"]) {
            cell.textLabel.textColor = [UIColor systemOrangeColor];
        } else {
            cell.textLabel.textColor = [UIColor labelColor];
        }
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterLogs];
    [self.tableView reloadData];
}

@end