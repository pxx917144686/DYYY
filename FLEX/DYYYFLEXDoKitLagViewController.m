#import "DYYYFLEXDoKitLagViewController.h"
#import "DYYYFLEXDoKitPerformanceMonitor.h"
#import "FLEXCompatibility.h"

@interface DYYYFLEXDoKitLagViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *lagCountLabel;
@property (nonatomic, strong) UISwitch *monitorSwitch;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation DYYYFLEXDoKitLagViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"卡顿检测";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self setupNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)setupUI {
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"卡顿检测已关闭";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:18];
    self.statusLabel.textColor = FLEXLabelColor;
    
    // 卡顿计数标签
    self.lagCountLabel = [[UILabel alloc] init];
    self.lagCountLabel.text = @"卡顿次数: 0";
    self.lagCountLabel.textAlignment = NSTextAlignmentCenter;
    self.lagCountLabel.font = [UIFont systemFontOfSize:16];
    self.lagCountLabel.textColor = FLEXSecondaryLabelColor;
    
    // 监控开关
    self.monitorSwitch = [[UISwitch alloc] init];
    [self.monitorSwitch addTarget:self action:@selector(monitorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UILabel *switchLabel = [[UILabel alloc] init];
    switchLabel.text = @"启用卡顿检测";
    switchLabel.font = [UIFont systemFontOfSize:16];
    switchLabel.textColor = FLEXLabelColor;
    
    UIStackView *switchStack = [[UIStackView alloc] initWithArrangedSubviews:@[switchLabel, self.monitorSwitch]];
    switchStack.axis = UILayoutConstraintAxisHorizontal;
    switchStack.distribution = UIStackViewDistributionEqualSpacing;
    
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.statusLabel,
        self.lagCountLabel,
        switchStack
    ]];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 30;
    mainStack.alignment = UIStackViewAlignmentFill;
    
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [mainStack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [mainStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],
        [mainStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40]
    ]];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lagDetected:)
                                                 name:@"FLEXDoKitLagDetected"
                                               object:nil];
}

- (void)monitorSwitchChanged:(UISwitch *)sender {
    DYYYFLEXDoKitPerformanceMonitor *monitor = [DYYYFLEXDoKitPerformanceMonitor sharedInstance];
    
    if (sender.isOn) {
        if ([monitor respondsToSelector:@selector(startLagDetection)]) {
            [monitor performSelector:@selector(startLagDetection)];
            self.statusLabel.text = @"卡顿检测已启动";
            self.statusLabel.textColor = FLEXSystemGreenColor;
            
            // 启动更新定时器
            self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(updateLagCount)
                                                             userInfo:nil
                                                              repeats:YES];
        } else {
            self.statusLabel.text = @"卡顿检测功能不可用";
            self.statusLabel.textColor = FLEXSystemRedColor;
            sender.on = NO;
        }
    } else {
        if ([monitor respondsToSelector:@selector(stopLagDetection)]) {
            [monitor performSelector:@selector(stopLagDetection)];
        }
        self.statusLabel.text = @"卡顿检测已关闭";
        self.statusLabel.textColor = FLEXSecondaryLabelColor;
        
        [self.updateTimer invalidate];
        self.updateTimer = nil;
    }
}

- (void)updateLagCount {
    // 这里可以从性能监控器获取卡顿计数
    static NSInteger lagCount = 0;
    self.lagCountLabel.text = [NSString stringWithFormat:@"卡顿次数: %ld", (long)lagCount];
}

- (void)lagDetected:(NSNotification *)notification {
    NSNumber *lagFrameCount = notification.object;
    if ([lagFrameCount isKindOfClass:[NSNumber class]]) {
        NSLog(@"🐛 检测到卡顿: %@帧", lagFrameCount);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateLagCount];
        });
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.updateTimer invalidate];
}

@end