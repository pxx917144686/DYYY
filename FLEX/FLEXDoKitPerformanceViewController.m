#import "FLEXDoKitPerformanceViewController.h"
#import "FLEXPerformanceMonitor.h"
#import "FLEXCompatibility.h"  // ✅ 添加兼容性头文件

@interface FLEXDoKitPerformanceViewController ()
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) UILabel *cpuLabel;
@property (nonatomic, strong) UILabel *memoryLabel;
@property (nonatomic, strong) UILabel *networkLabel;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation FLEXDoKitPerformanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"性能监控";
    self.view.backgroundColor = FLEXSystemBackgroundColor;  // ✅ 现在已定义
    
    [self setupUI];
    [self startMonitoring];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopMonitoring];
}

- (void)setupUI {
    // FPS标签
    self.fpsLabel = [[UILabel alloc] init];
    self.fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    self.fpsLabel.text = @"FPS: --";
    self.fpsLabel.textColor = FLEXLabelColor;  // ✅ 使用兼容性宏
    
    // CPU标签
    self.cpuLabel = [[UILabel alloc] init];
    self.cpuLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    self.cpuLabel.text = @"CPU: --%";
    self.cpuLabel.textColor = FLEXLabelColor;  // ✅ 使用兼容性宏
    
    // 内存标签
    self.memoryLabel = [[UILabel alloc] init];
    self.memoryLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    self.memoryLabel.text = @"Memory: -- MB";
    self.memoryLabel.textColor = FLEXLabelColor;  // ✅ 使用兼容性宏
    
    // 网络标签
    self.networkLabel = [[UILabel alloc] init];
    self.networkLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    self.networkLabel.text = @"Network: ↑-- ↓--";
    self.networkLabel.textColor = FLEXLabelColor;  // ✅ 使用兼容性宏
    
    // 布局
    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.fpsLabel, self.cpuLabel, self.memoryLabel, self.networkLabel
    ]];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 20;
    stackView.alignment = UIStackViewAlignmentCenter;
    
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)startMonitoring {
    FLEXPerformanceMonitor *monitor = [FLEXPerformanceMonitor sharedInstance];
    [monitor startFPSMonitoring];
    [monitor startCPUMonitoring];
    [monitor startMemoryMonitoring];
    [monitor startNetworkMonitoring];
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                        target:self
                                                      selector:@selector(updateMetrics)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMonitoring {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    FLEXPerformanceMonitor *monitor = [FLEXPerformanceMonitor sharedInstance];
    [monitor stopFPSMonitoring];
    [monitor stopCPUMonitoring];
    [monitor stopMemoryMonitoring];
    [monitor stopNetworkMonitoring];
}

- (void)updateMetrics {
    FLEXPerformanceMonitor *monitor = [FLEXPerformanceMonitor sharedInstance];
    
    // ✅ 修复：使用正确的属性名称
    self.fpsLabel.text = [NSString stringWithFormat:@"FPS: %.1f", monitor.currentFPS];
    self.cpuLabel.text = [NSString stringWithFormat:@"CPU: %.1f%%", monitor.cpuUsage];
    self.memoryLabel.text = [NSString stringWithFormat:@"Memory: %.1f MB", monitor.memoryUsage];
    self.networkLabel.text = [NSString stringWithFormat:@"Network: ↑%.1fKB/s ↓%.1fKB/s", 
                             monitor.uploadFlowBytes / 1024.0, monitor.downloadFlowBytes / 1024.0];
    
    // ✅ 根据性能指标设置颜色
    [self updateLabelsColor:monitor];
}

- (void)updateLabelsColor:(FLEXPerformanceMonitor *)monitor {
    // FPS颜色设置
    if (monitor.currentFPS >= 55) {
        self.fpsLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    } else if (monitor.currentFPS >= 30) {
        self.fpsLabel.textColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
    } else {
        self.fpsLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
    }
    
    // CPU颜色设置
    if (monitor.cpuUsage < 30) {
        self.cpuLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    } else if (monitor.cpuUsage < 70) {
        self.cpuLabel.textColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
    } else {
        self.cpuLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
    }
    
    // 内存颜色设置
    if (monitor.memoryUsage < 100) {
        self.memoryLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    } else if (monitor.memoryUsage < 200) {
        self.memoryLabel.textColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
    } else {
        self.memoryLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
    }
    
    // 网络标签保持默认颜色
    self.networkLabel.textColor = FLEXLabelColor;  // ✅ 使用兼容性宏
}

@end