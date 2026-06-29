#import "FLEXMemoryMonitorViewController.h"
#import "FLEXPerformanceMonitor.h"
#import "FLEXCompatibility.h"  // ✅ 添加兼容性头文件导入
#import <mach/mach.h>
#import <sys/sysctl.h>

@interface FLEXMemoryMonitorViewController ()
@property (nonatomic, strong) UILabel *memoryLabel;
@property (nonatomic, strong) UILabel *availableLabel;
@property (nonatomic, strong) UIProgressView *memoryProgressView;
@property (nonatomic, strong) UISwitch *monitorSwitch;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *memoryHistory;
@end

@implementation FLEXMemoryMonitorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"内存监控";
    self.view.backgroundColor = FLEXSystemBackgroundColor;  // ✅ 现在已定义
    
    self.memoryHistory = [NSMutableArray new];
    
    [self setupUI];
    [self startMonitoring];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopMonitoring];
}

- (void)setupUI {
    // 内存使用显示
    self.memoryLabel = [[UILabel alloc] init];
    self.memoryLabel.font = [UIFont boldSystemFontOfSize:36];
    self.memoryLabel.textAlignment = NSTextAlignmentCenter;
    self.memoryLabel.text = @"0 MB";
    self.memoryLabel.textColor = FLEXSystemBlueColor;  // ✅ 使用兼容性宏
    
    // 可用内存显示
    self.availableLabel = [[UILabel alloc] init];
    self.availableLabel.font = [UIFont systemFontOfSize:16];
    self.availableLabel.textAlignment = NSTextAlignmentCenter;
    self.availableLabel.text = @"可用: 0 MB";
    self.availableLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
    
    // 内存使用进度条
    self.memoryProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.memoryProgressView.progress = 0.0;
    self.memoryProgressView.progressTintColor = FLEXSystemBlueColor;  // ✅ 使用兼容性宏
    
    // 监控开关
    self.monitorSwitch = [[UISwitch alloc] init];
    self.monitorSwitch.on = YES;
    [self.monitorSwitch addTarget:self action:@selector(monitorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 清理按钮
    UIButton *cleanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cleanButton setTitle:@"清理内存" forState:UIControlStateNormal];
    cleanButton.backgroundColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
    [cleanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cleanButton.layer.cornerRadius = 8;
    [cleanButton addTarget:self action:@selector(cleanMemory) forControlEvents:UIControlEventTouchUpInside];
    
    // 说明标签
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"实时监控应用内存使用情况\n蓝色: 正常 橙色: 较高 红色: 警告";
    descLabel.numberOfLines = 0;
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
    
    // 布局
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.memoryLabel,
        self.availableLabel,
        self.memoryProgressView,
        self.monitorSwitch,
        cleanButton,
        descLabel
    ]];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 20;
    mainStack.alignment = UIStackViewAlignmentCenter;
    
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [mainStack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [mainStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.memoryProgressView.widthAnchor constraintEqualToConstant:200],
        [cleanButton.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)startMonitoring {
    [[FLEXPerformanceMonitor sharedInstance] startMemoryMonitoring];
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateMemoryInfo)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMonitoring {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    [[FLEXPerformanceMonitor sharedInstance] stopMemoryMonitoring];
}

- (void)updateMemoryInfo {
    if (!self.monitorSwitch.on) return;
    
    // 获取内存信息
    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO64_COUNT;
    kern_return_t kernReturn = host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStats, &infoCount);
    
    if (kernReturn == KERN_SUCCESS) {
        // ✅ 优化：使用更简单的方法获取页面大小
        vm_size_t pageSize = vm_page_size;  // 使用系统宏，避免sysctlbyname
        
        // 计算内存使用情况
        uint64_t physicalMemory = [NSProcessInfo processInfo].physicalMemory;
        uint64_t freeMemory = vmStats.free_count * pageSize;
        uint64_t usedMemory = physicalMemory - freeMemory;
        uint64_t availableMemory = freeMemory + (vmStats.inactive_count * pageSize);
        
        // 转换为MB
        CGFloat usedMemoryMB = usedMemory / (1024.0 * 1024.0);
        CGFloat availableMemoryMB = availableMemory / (1024.0 * 1024.0);
        CGFloat physicalMemoryMB = physicalMemory / (1024.0 * 1024.0);
        
        // 计算使用百分比
        CGFloat memoryUsagePercent = usedMemoryMB / physicalMemoryMB;
        
        // 记录历史数据
        [self.memoryHistory addObject:@(usedMemoryMB)];
        if (self.memoryHistory.count > 60) { // 保持最近60个数据点
            [self.memoryHistory removeObjectAtIndex:0];
        }
        
        // 更新UI
        self.memoryLabel.text = [NSString stringWithFormat:@"%.1f MB", usedMemoryMB];
        self.availableLabel.text = [NSString stringWithFormat:@"可用: %.1f MB", availableMemoryMB];
        self.memoryProgressView.progress = memoryUsagePercent;
        
        // 根据内存使用设置颜色
        if (memoryUsagePercent < 0.6) {
            self.memoryLabel.textColor = FLEXSystemBlueColor;  // ✅ 使用兼容性宏
            self.memoryProgressView.progressTintColor = FLEXSystemBlueColor;  // ✅ 使用兼容性宏
        } else if (memoryUsagePercent < 0.8) {
            self.memoryLabel.textColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
            self.memoryProgressView.progressTintColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
        } else {
            self.memoryLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
            self.memoryProgressView.progressTintColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
        }
    }
}

- (void)monitorSwitchChanged:(UISwitch *)sender {
    if (sender.on) {
        [self startMonitoring];
    } else {
        [self stopMonitoring];
        self.memoryLabel.text = @"-- MB";
        self.availableLabel.text = @"已停止监控";
        self.memoryLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
        self.memoryProgressView.progress = 0;
    }
}

- (void)cleanMemory {
    // 执行内存清理
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    if (@available(iOS 6.0, *)) {
        [[NSURLCache sharedURLCache] diskCapacity];
    }
    
    // ✅ 强制垃圾回收（仅在Debug模式下有效）
    #if DEBUG
    if (@available(iOS 9.0, *)) {
        // 在现代iOS版本中，我们只能建议系统进行内存回收
        [[NSProcessInfo processInfo] performExpiringActivityWithReason:@"Memory cleanup" 
                                                            usingBlock:^(BOOL expired) {
            // 这里可以进行一些轻量级的清理操作
        }];
    }
    #endif
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"内存清理" 
                                                                   message:@"已清理缓存数据" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end