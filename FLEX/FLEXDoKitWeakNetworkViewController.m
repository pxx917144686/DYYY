#import "FLEXDoKitWeakNetworkViewController.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性宏

@interface FLEXDoKitWeakNetworkViewController ()
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UISlider *delaySlider;
@property (nonatomic, strong) UILabel *delayLabel;
@property (nonatomic, strong) UIButton *errorButton;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation FLEXDoKitWeakNetworkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"弱网模拟";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
}

- (void)setupUI {
    // 启用开关
    UILabel *enableLabel = [[UILabel alloc] init];
    enableLabel.text = @"启用弱网模拟";
    enableLabel.font = [UIFont systemFontOfSize:16];
    enableLabel.textColor = FLEXLabelColor;
    
    self.enableSwitch = [[UISwitch alloc] init];
    [self.enableSwitch addTarget:self action:@selector(enableSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIStackView *enableStack = [[UIStackView alloc] initWithArrangedSubviews:@[enableLabel, self.enableSwitch]];
    enableStack.axis = UILayoutConstraintAxisHorizontal;
    enableStack.distribution = UIStackViewDistributionEqualSpacing;
    
    // 延迟设置
    UILabel *delayTitleLabel = [[UILabel alloc] init];
    delayTitleLabel.text = @"网络延迟";
    delayTitleLabel.font = [UIFont systemFontOfSize:16];
    delayTitleLabel.textColor = FLEXLabelColor;
    
    self.delayLabel = [[UILabel alloc] init];
    self.delayLabel.text = @"0.0秒";
    self.delayLabel.textAlignment = NSTextAlignmentRight;
    self.delayLabel.font = [UIFont systemFontOfSize:16];
    self.delayLabel.textColor = FLEXSecondaryLabelColor;  // ✅ 现在已经定义了
    
    self.delaySlider = [[UISlider alloc] init];
    self.delaySlider.minimumValue = 0.0;
    self.delaySlider.maximumValue = 5.0;
    self.delaySlider.value = 0.0;
    [self.delaySlider addTarget:self action:@selector(delaySliderChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 错误模拟按钮
    self.errorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.errorButton setTitle:@"模拟网络错误" forState:UIControlStateNormal];
    [self.errorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.errorButton.backgroundColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
    self.errorButton.layer.cornerRadius = 8;
    [self.errorButton addTarget:self action:@selector(errorButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 重置按钮
    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [resetButton setTitle:@"重置网络" forState:UIControlStateNormal];
    [resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    resetButton.backgroundColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
    resetButton.layer.cornerRadius = 8;
    [resetButton addTarget:self action:@selector(resetButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"网络模拟已关闭";
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = FLEXSecondaryLabelColor;  // ✅ 现在已经定义了
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    
    // 布局
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        enableStack,
        delayTitleLabel,
        self.delaySlider,
        self.delayLabel,
        self.errorButton,
        resetButton,
        self.statusLabel
    ]];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 20;
    mainStack.alignment = UIStackViewAlignmentFill;
    
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:30],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.errorButton.heightAnchor constraintEqualToConstant:44],
        [resetButton.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)enableSwitchChanged:(UISwitch *)sender {
    FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
    
    if (sender.isOn) {
        [monitor simulateSlowNetwork:self.delaySlider.value];
        self.statusLabel.text = [NSString stringWithFormat:@"弱网模拟已启用\n延迟: %.1f秒", self.delaySlider.value];
        self.statusLabel.textColor = FLEXSystemOrangeColor;  // ✅ 现在已定义
    } else {
        [monitor resetNetworkSimulation];
        self.statusLabel.text = @"网络模拟已关闭";
        self.statusLabel.textColor = FLEXSystemGrayColor;  // ✅ 现在已定义
    }
}

- (void)delaySliderChanged:(UISlider *)sender {
    self.delayLabel.text = [NSString stringWithFormat:@"%.1f秒", sender.value];
    
    if (self.enableSwitch.isOn) {
        [self enableSwitchChanged:self.enableSwitch];
    }
}

- (void)errorButtonTapped {
    FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
    [monitor simulateNetworkError];
    
    self.statusLabel.text = @"网络错误模拟已触发";
    self.statusLabel.textColor = FLEXSystemRedColor;  // ✅ 使用兼容性宏
}

- (void)resetButtonTapped {
    FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
    [monitor resetNetworkSimulation];
    
    self.enableSwitch.on = NO;
    self.delaySlider.value = 0.0;
    self.delayLabel.text = @"0.0秒";
    self.statusLabel.text = @"网络已重置为正常状态";
    self.statusLabel.textColor = FLEXSystemGreenColor;  // ✅ 使用兼容性宏
}

@end