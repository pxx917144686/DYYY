#import "FLEXLookinMeasureViewController.h"
#import "FLEXLookinMeasureController.h"
#import "FLEXCompatibility.h"  // ✅ 添加兼容性导入

@interface FLEXLookinMeasureViewController ()
@property (nonatomic, strong) UISwitch *measureSwitch;
@property (nonatomic, strong) UILabel *instructionLabel;
@end

@implementation FLEXLookinMeasureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Lookin测量工具";
    self.view.backgroundColor = FLEXSystemBackgroundColor;  // ✅ 使用兼容性宏
    
    [self setupUI];
}

- (void)setupUI {
    // 测量开关
    self.measureSwitch = [[UISwitch alloc] init];
    [self.measureSwitch addTarget:self action:@selector(measureSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 说明标签
    self.instructionLabel = [[UILabel alloc] init];
    self.instructionLabel.text = @"开启测量模式后，可以通过拖拽来测量两个视图间的距离\n\n操作说明：\n1. 开启测量开关\n2. 拖拽选择两个视图\n3. 双击锁定测量结果";
    self.instructionLabel.numberOfLines = 0;
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.font = [UIFont systemFontOfSize:16];
    
    // 布局
    self.measureSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.measureSwitch];
    [self.view addSubview:self.instructionLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.measureSwitch.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.measureSwitch.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-50],
        
        [self.instructionLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.instructionLabel.topAnchor constraintEqualToAnchor:self.measureSwitch.bottomAnchor constant:30],
        [self.instructionLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.instructionLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

- (void)measureSwitchChanged:(UISwitch *)sender {
    FLEXLookinMeasureController *controller = [FLEXLookinMeasureController sharedInstance];
    
    if (sender.isOn) {
        [controller startMeasuring];
        self.instructionLabel.text = @"测量模式已开启！\n\n现在可以:\n• 拖拽屏幕选择两个视图进行测量\n• 双击锁定当前测量结果\n• 关闭开关退出测量模式";
    } else {
        [controller stopMeasuring];
        self.instructionLabel.text = @"开启测量模式后，可以通过拖拽来测量两个视图间的距离\n\n操作说明：\n1. 开启测量开关\n2. 拖拽选择两个视图\n3. 双击锁定测量结果";
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 退出时自动关闭测量模式
    if (self.measureSwitch.isOn) {
        [[FLEXLookinMeasureController sharedInstance] stopMeasuring];
    }
}

@end