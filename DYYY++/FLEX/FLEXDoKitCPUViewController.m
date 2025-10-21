#import "FLEXDoKitCPUViewController.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性宏
#import <mach/mach.h>
#import <sys/sysctl.h>

@interface FLEXDoKitCPUViewController ()
@property (nonatomic, strong) UILabel *cpuLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *cpuProgressView;
@property (nonatomic, strong) UISwitch *monitorSwitch;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *cpuHistory;
@end

@implementation FLEXDoKitCPUViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"CPU监控";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    self.cpuHistory = [NSMutableArray new];
    
    [self setupUI];
    [self startMonitoring];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopMonitoring];
}

- (void)setupUI {
    // CPU使用率显示
    self.cpuLabel = [[UILabel alloc] init];
    self.cpuLabel.font = [UIFont boldSystemFontOfSize:36];
    self.cpuLabel.textAlignment = NSTextAlignmentCenter;
    self.cpuLabel.text = @"0%";
    self.cpuLabel.textColor = FLEXSystemGreenColor;
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:16];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"正常";
    self.statusLabel.textColor = FLEXSystemGreenColor;
    
    // CPU使用率进度条
    self.cpuProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.cpuProgressView.progress = 0.0;
    self.cpuProgressView.progressTintColor = FLEXSystemGreenColor;
    
    // 监控开关
    self.monitorSwitch = [[UISwitch alloc] init];
    self.monitorSwitch.on = YES;
    [self.monitorSwitch addTarget:self action:@selector(monitorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 说明标签
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"实时监控CPU使用率\n绿色: 正常(<30%) 橙色: 较高(30-70%) 红色: 过高(>70%)";
    descLabel.numberOfLines = 0;
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = FLEXSystemGrayColor;
    
    // 布局
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.cpuLabel,
        self.statusLabel,
        self.cpuProgressView,
        self.monitorSwitch,
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
        [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.cpuProgressView.widthAnchor constraintEqualToConstant:200]
    ]];
}

- (void)startMonitoring {
    if (self.updateTimer) {
        [self.updateTimer invalidate];
    }
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateCPUUsage)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMonitoring {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)updateCPUUsage {
    if (!self.monitorSwitch.on) return;
    
    CGFloat cpuUsage = [self getCPUUsage];
    
    // 添加到历史记录
    [self.cpuHistory addObject:@(cpuUsage)];
    if (self.cpuHistory.count > 60) { // 保留最近60秒的数据
        [self.cpuHistory removeObjectAtIndex:0];
    }
    
    [self updateCPUUsage:cpuUsage];
}

- (void)updateCPUUsage:(CGFloat)cpuUsage {
    // 更新显示
    self.cpuLabel.text = [NSString stringWithFormat:@"%.1f%%", cpuUsage];
    self.cpuProgressView.progress = cpuUsage / 100.0;
    
    // 根据CPU使用率设置颜色
    if (cpuUsage < 30) {
        self.cpuLabel.textColor = FLEXSystemGreenColor;  // ✅ 现在已定义
        self.statusLabel.textColor = FLEXSystemGreenColor;  // ✅ 现在已定义
        self.cpuProgressView.progressTintColor = FLEXSystemGreenColor;  // ✅ 现在已定义
        self.statusLabel.text = @"正常";
    } else if (cpuUsage < 70) {
        self.cpuLabel.textColor = FLEXSystemOrangeColor;  // ✅ 现在已定义
        self.statusLabel.textColor = FLEXSystemOrangeColor;  // ✅ 现在已定义
        self.cpuProgressView.progressTintColor = FLEXSystemOrangeColor;  // ✅ 现在已定义
        self.statusLabel.text = @"较高";
    } else {
        self.cpuLabel.textColor = FLEXSystemRedColor;  // ✅ 现在已定义
        self.statusLabel.textColor = FLEXSystemRedColor;  // ✅ 现在已定义
        self.cpuProgressView.progressTintColor = FLEXSystemRedColor;  // ✅ 现在已定义
        self.statusLabel.text = @"过高";
    }
}

- (CGFloat)getCPUUsage {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    
    kern_return_t kr = task_threads(mach_task_self(), &threads, &threadCount);
    if (kr != KERN_SUCCESS) {
        return 0.0;
    }
    
    CGFloat totalCPU = 0.0;
    
    for (unsigned int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        
        kr = thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount);
        if (kr == KERN_SUCCESS) {
            thread_basic_info_t basicInfo = (thread_basic_info_t)threadInfo;
            
            if (!(basicInfo->flags & TH_FLAGS_IDLE)) {
                totalCPU += basicInfo->cpu_usage / (CGFloat)TH_USAGE_SCALE * 100.0;
            }
        }
    }
    
    // 清理资源
    vm_deallocate(mach_task_self(), (vm_offset_t)threads, threadCount * sizeof(thread_t));
    
    return totalCPU;
}

- (void)monitorSwitchChanged:(UISwitch *)sender {
    if (!sender.on) {
        [self stopMonitoring];
        self.cpuLabel.text = @"--";
        self.statusLabel.text = @"已停止";
        self.cpuLabel.textColor = FLEXSystemGrayColor;
        self.statusLabel.textColor = FLEXSystemGrayColor;
        self.cpuProgressView.progress = 0;
    } else {
        [self startMonitoring];
    }
}

@end