#import "FLEXMemoryLeakDetectorViewController.h"
#import "FLEXDoKitMemoryLeakDetector.h"
#import "FLEXCompatibility.h"

@interface FLEXMemoryLeakDetectorViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISwitch *detectionSwitch;
@property (nonatomic, strong) NSArray *leakInfos;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation FLEXMemoryLeakDetectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"内存泄漏检测";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self setupNotifications];
    [self refreshLeakData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)setupUI {
    // 导航栏
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@"清除"
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(clearLeakData)];
    
    // 检测开关
    self.detectionSwitch = [[UISwitch alloc] init];
    [self.detectionSwitch addTarget:self action:@selector(detectionSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UILabel *switchLabel = [[UILabel alloc] init];
    switchLabel.text = @"启用泄漏检测";
    switchLabel.font = [UIFont systemFontOfSize:16];
    
    UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[switchLabel, self.detectionSwitch]];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.distribution = UIStackViewDistributionEqualSpacing;
    headerStack.layoutMargins = UIEdgeInsetsMake(15, 20, 15, 20);
    headerStack.layoutMarginsRelativeArrangement = YES;
    
    // 表格视图
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LeakCell"];
    
    [self.view addSubview:headerStack];
    [self.view addSubview:self.tableView];
    
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [headerStack.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [self.tableView.topAnchor constraintEqualToAnchor:headerStack.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(leakDetected:)
                                                 name:@"FLEXDoKitMemoryLeakDetected"
                                               object:nil];
}

- (void)detectionSwitchChanged:(UISwitch *)sender {
    FLEXDoKitMemoryLeakDetector *detector = [FLEXDoKitMemoryLeakDetector sharedInstance];
    
    if (sender.isOn) {
        [detector startLeakDetection];
        
        // 启动刷新定时器
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                             target:self
                                                           selector:@selector(refreshLeakData)
                                                           userInfo:nil
                                                            repeats:YES];
    } else {
        [detector stopLeakDetection];
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

- (void)refreshLeakData {
    FLEXDoKitMemoryLeakDetector *detector = [FLEXDoKitMemoryLeakDetector sharedInstance];
    self.leakInfos = detector.leakInfos;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)clearLeakData {
    FLEXDoKitMemoryLeakDetector *detector = [FLEXDoKitMemoryLeakDetector sharedInstance];
    [detector clearLeakInfos];
    [self refreshLeakData];
}

- (void)leakDetected:(NSNotification *)notification {
    [self refreshLeakData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.leakInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LeakCell" forIndexPath:indexPath];
    
    if (indexPath.row < self.leakInfos.count) {
        id leakInfo = self.leakInfos[indexPath.row];
        
        if ([leakInfo isKindOfClass:[FLEXDoKitLeakInfo class]]) {
            FLEXDoKitLeakInfo *info = (FLEXDoKitLeakInfo *)leakInfo;
            cell.textLabel.text = info.className ?: @"未知泄漏对象";
            
            cell.detailTextLabel.text = [NSString stringWithFormat:@"实例数量: %lu", 
                                       (unsigned long)info.instanceCount];
            
            // 添加检测时间信息
            if (info.detectedTime) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateStyle = NSDateFormatterShortStyle;
                formatter.timeStyle = NSDateFormatterShortStyle;
                NSString *timeStr = [formatter stringFromDate:info.detectedTime];
                
                cell.detailTextLabel.text = [NSString stringWithFormat:@"实例数: %lu | %@", 
                                           (unsigned long)info.instanceCount, timeStr];
            }
        } else {
            cell.textLabel.text = @"未知泄漏对象";
            cell.detailTextLabel.text = @"类型错误";
        }
        
        // 根据实例数量设置颜色警告
        if ([leakInfo isKindOfClass:[FLEXDoKitLeakInfo class]]) {
            FLEXDoKitLeakInfo *info = (FLEXDoKitLeakInfo *)leakInfo;
            if (info.instanceCount > 100) {
                cell.textLabel.textColor = [UIColor systemRedColor];
            } else if (info.instanceCount > 50) {
                cell.textLabel.textColor = [UIColor systemOrangeColor];
            } else {
                cell.textLabel.textColor = [UIColor labelColor];
            }
        }
    } else {
        cell.textLabel.text = @"数据错误";
        cell.detailTextLabel.text = @"索引越界";
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

// ✅ 添加点击详情查看功能
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row < self.leakInfos.count) {
        id leakInfo = self.leakInfos[indexPath.row];
        
        if ([leakInfo isKindOfClass:[FLEXDoKitLeakInfo class]]) {
            FLEXDoKitLeakInfo *info = (FLEXDoKitLeakInfo *)leakInfo;
            
            // 显示详细信息
            NSMutableString *message = [NSMutableString string];
            [message appendFormat:@"类名: %@\n", info.className];
            [message appendFormat:@"实例数量: %lu\n", (unsigned long)info.instanceCount];
            
            if (info.detectedTime) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateStyle = NSDateFormatterMediumStyle;
                formatter.timeStyle = NSDateFormatterMediumStyle;
                [message appendFormat:@"检测时间: %@\n", [formatter stringFromDate:info.detectedTime]];
            }
            
            if (info.suspiciousInstances && info.suspiciousInstances.count > 0) {
                [message appendFormat:@"可疑实例: %lu个", (unsigned long)info.suspiciousInstances.count];
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"泄漏详情"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                               style:UIAlertActionStyleDefault 
                                                             handler:nil];
            [alert addAction:okAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.refreshTimer invalidate];
}

@end