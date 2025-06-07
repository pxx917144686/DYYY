#import "FLEXViewBorderViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXDoKitVisualTools.h"

@interface FLEXViewBorderViewController ()
@property (nonatomic, strong) UISwitch *borderSwitch;
@property (nonatomic, strong) UISwitch *layoutSwitch;
@property (nonatomic, strong) UISwitch *rulerSwitch;
@end

@implementation FLEXViewBorderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"视觉调试工具";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
}

- (void)setupUI {
    // 视图边框开关
    UILabel *borderLabel = [[UILabel alloc] init];
    borderLabel.text = @"显示视图边框";
    borderLabel.font = [UIFont systemFontOfSize:16];
    
    self.borderSwitch = [[UISwitch alloc] init];
    [self.borderSwitch addTarget:self action:@selector(borderSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIStackView *borderStack = [[UIStackView alloc] initWithArrangedSubviews:@[borderLabel, self.borderSwitch]];
    borderStack.axis = UILayoutConstraintAxisHorizontal;
    borderStack.distribution = UIStackViewDistributionFill;
    borderStack.alignment = UIStackViewAlignmentCenter;
    
    // 布局边界开关
    UILabel *layoutLabel = [[UILabel alloc] init];
    layoutLabel.text = @"显示布局边界";
    layoutLabel.font = [UIFont systemFontOfSize:16];
    
    self.layoutSwitch = [[UISwitch alloc] init];
    [self.layoutSwitch addTarget:self action:@selector(layoutSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIStackView *layoutStack = [[UIStackView alloc] initWithArrangedSubviews:@[layoutLabel, self.layoutSwitch]];
    layoutStack.axis = UILayoutConstraintAxisHorizontal;
    layoutStack.distribution = UIStackViewDistributionFill;
    layoutStack.alignment = UIStackViewAlignmentCenter;
    
    // 标尺开关
    UILabel *rulerLabel = [[UILabel alloc] init];
    rulerLabel.text = @"显示网格标尺";
    rulerLabel.font = [UIFont systemFontOfSize:16];
    
    self.rulerSwitch = [[UISwitch alloc] init];
    [self.rulerSwitch addTarget:self action:@selector(rulerSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIStackView *rulerStack = [[UIStackView alloc] initWithArrangedSubviews:@[rulerLabel, self.rulerSwitch]];
    rulerStack.axis = UILayoutConstraintAxisHorizontal;
    rulerStack.distribution = UIStackViewDistributionFill;
    rulerStack.alignment = UIStackViewAlignmentCenter;
    
    // 主容器
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        borderStack, layoutStack, rulerStack
    ]];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 20;
    mainStack.alignment = UIStackViewAlignmentFill;
    
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:40],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

- (void)borderSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [[FLEXDoKitVisualTools sharedInstance] showViewBorders];
    } else {
        [[FLEXDoKitVisualTools sharedInstance] hideViewBorders];
    }
}

- (void)layoutSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [[FLEXDoKitVisualTools sharedInstance] showLayoutBounds];
    } else {
        [[FLEXDoKitVisualTools sharedInstance] hideLayoutBounds];
    }
}

- (void)rulerSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [[FLEXDoKitVisualTools sharedInstance] showRuler];
    } else {
        [[FLEXDoKitVisualTools sharedInstance] hideRuler];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 清理所有视觉工具
    [[FLEXDoKitVisualTools sharedInstance] hideViewBorders];
    [[FLEXDoKitVisualTools sharedInstance] hideLayoutBounds];
    [[FLEXDoKitVisualTools sharedInstance] hideRuler];
}

@end