#import "FLEXFPSMonitorViewController.h"
#import "FLEXPerformanceMonitor.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性头文件

@interface FLEXFPSMonitorViewController ()
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UISwitch *monitorSwitch;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) UIProgressView *fpsProgressView;
@end

@implementation FLEXFPSMonitorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"FPS监控";
    self.view.backgroundColor = FLEXSystemBackgroundColor;  // ✅ 现在已定义
    
    [self setupUI];
    [self startMonitoring];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopMonitoring];
}

- (void)setupUI {
    // FPS显示标签
    self.fpsLabel = [[UILabel alloc] init];
    self.fpsLabel.font = [UIFont boldSystemFontOfSize:48];
    self.fpsLabel.textAlignment = NSTextAlignmentCenter;
    self.fpsLabel.text = @"60";
    self.fpsLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:16];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"流畅";
    self.statusLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    
    // 开关
    self.monitorSwitch = [[UISwitch alloc] init];
    self.monitorSwitch.on = YES;
    [self.monitorSwitch addTarget:self action:@selector(monitorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 进度条
    self.fpsProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.fpsProgressView.progress = 1.0;
    self.fpsProgressView.progressTintColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    
    // 说明标签
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"实时监控应用帧率\n绿色: 60fps 流畅\n黄色: 30-59fps 一般\n红色: <30fps 卡顿";
    descLabel.numberOfLines = 0;
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
    
    // 布局
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.fpsLabel,
        self.statusLabel,
        self.fpsProgressView,
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
        [mainStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.fpsProgressView.widthAnchor constraintEqualToConstant:200]
    ]];
}

- (void)startMonitoring {
    [[FLEXPerformanceMonitor sharedInstance] startFPSMonitoring];
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                                      selector:@selector(updateFPS)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMonitoring {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    [[FLEXPerformanceMonitor sharedInstance] stopFPSMonitoring];
}

- (void)updateFPS {
    if (!self.monitorSwitch.on) return;
    
    // ✅ 修复：使用正确的属性访问方式
    CGFloat fps = [[FLEXPerformanceMonitor sharedInstance] currentFPS];
    
    // 更新显示
    self.fpsLabel.text = [NSString stringWithFormat:@"%.0f", fps];
    self.fpsProgressView.progress = fps / 60.0;
    
    // 根据FPS设置颜色和状态
    if (fps >= 55) {
        self.fpsLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
        self.statusLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
        self.fpsProgressView.progressTintColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
        self.statusLabel.text = @"流畅";
    } else if (fps >= 30) {
        self.fpsLabel.textColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
        self.statusLabel.textColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
        self.fpsProgressView.progressTintColor = FLEXSystemOrangeColor;  // ✅ 使用兼容性宏
        self.statusLabel.text = @"一般";
    } else {
        self.fpsLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
        self.statusLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
        self.fpsProgressView.progressTintColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
        self.statusLabel.text = @"卡顿";
    }
}

- (void)monitorSwitchChanged:(UISwitch *)sender {
    if (sender.on) {
        [self startMonitoring];
    } else {
        [self stopMonitoring];
        self.fpsLabel.text = @"--";
        self.statusLabel.text = @"已停止";
        self.fpsLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
        self.statusLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
        self.fpsProgressView.progress = 0;
    }
}

@end