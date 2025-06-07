#import "FLEXDoKitColorPickerViewController.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitColorPickerViewController ()
@property (nonatomic, strong) UIView *colorPreview;
@property (nonatomic, strong) UILabel *colorInfoLabel;
@property (nonatomic, strong) UILabel *instructionLabel;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *stopButton;
@end

@implementation FLEXDoKitColorPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"颜色吸管";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
}

- (void)setupUI {
    // 说明标签
    self.instructionLabel = [[UILabel alloc] init];
    self.instructionLabel.text = @"点击「开始取色」后，在屏幕上任意点击获取该位置的颜色";
    self.instructionLabel.numberOfLines = 0;
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.font = [UIFont systemFontOfSize:16];
    self.instructionLabel.textColor = FLEXSecondaryLabelColor;
    
    // 颜色预览
    self.colorPreview = [[UIView alloc] init];
    self.colorPreview.backgroundColor = [UIColor lightGrayColor];
    self.colorPreview.layer.borderWidth = 1;
    self.colorPreview.layer.borderColor = FLEXSystemGrayColor.CGColor;
    self.colorPreview.layer.cornerRadius = 8;
    
    // 颜色信息标签
    self.colorInfoLabel = [[UILabel alloc] init];
    self.colorInfoLabel.text = @"暂未选择颜色";
    self.colorInfoLabel.textAlignment = NSTextAlignmentCenter;
    self.colorInfoLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.colorInfoLabel.numberOfLines = 0;
    self.colorInfoLabel.textColor = FLEXLabelColor;
    
    // 开始按钮
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"开始取色" forState:UIControlStateNormal];
    self.startButton.backgroundColor = FLEXSystemBlueColor;
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startButton.layer.cornerRadius = 8;
    [self.startButton addTarget:self action:@selector(startColorPicker) forControlEvents:UIControlEventTouchUpInside];
    
    // 停止按钮
    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopButton setTitle:@"停止取色" forState:UIControlStateNormal];
    self.stopButton.backgroundColor = FLEXSystemRedColor;
    [self.stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.stopButton.layer.cornerRadius = 8;
    self.stopButton.enabled = NO;
    [self.stopButton addTarget:self action:@selector(stopColorPicker) forControlEvents:UIControlEventTouchUpInside];
    
    // 布局
    UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.startButton, self.stopButton]];
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 16;
    buttonStack.distribution = UIStackViewDistributionFillEqually;
    
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.instructionLabel,
        self.colorPreview,
        self.colorInfoLabel,
        buttonStack
    ]];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 20;
    mainStack.alignment = UIStackViewAlignmentFill;
    
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [mainStack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        
        [self.colorPreview.heightAnchor constraintEqualToConstant:100],
        [self.startButton.heightAnchor constraintEqualToConstant:44],
        [self.stopButton.heightAnchor constraintEqualToConstant:44]
    ]];
    
    // 监听颜色选择通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(colorPicked:)
                                                 name:@"FLEXDoKitColorPicked"
                                               object:nil];
}

- (void)startColorPicker {
    [[FLEXDoKitVisualTools sharedInstance] startColorPicker];
    self.startButton.enabled = NO;
    self.stopButton.enabled = YES;
    // ✅ 修复：使用转义字符或者更改引号为英文引号
    self.instructionLabel.text = @"取色模式已启动，点击屏幕任意位置获取颜色";
}

- (void)stopColorPicker {
    [[FLEXDoKitVisualTools sharedInstance] stopColorPicker];
    self.startButton.enabled = YES;
    self.stopButton.enabled = NO;
    // ✅ 修复：使用转义字符或者更改引号为英文引号
    self.instructionLabel.text = @"点击「开始取色」后，在屏幕上任意点击获取该位置的颜色";
}

- (void)colorPicked:(NSNotification *)notification {
    UIColor *color = notification.object;
    if (color) {
        self.colorPreview.backgroundColor = color;
        
        CGFloat red, green, blue, alpha;
        [color getRed:&red green:&green blue:&blue alpha:&alpha];
        
        NSString *hexColor = [NSString stringWithFormat:@"#%02X%02X%02X",
                             (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
        NSString *rgbColor = [NSString stringWithFormat:@"RGB(%.0f, %.0f, %.0f)",
                             red * 255, green * 255, blue * 255];
        
        self.colorInfoLabel.text = [NSString stringWithFormat:@"Hex: %@\n%@\nAlpha: %.2f", hexColor, rgbColor, alpha];
        
        // 复制到剪贴板
        [UIPasteboard generalPasteboard].string = hexColor;
        
        // 显示提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"颜色已获取"
                                                                       message:[NSString stringWithFormat:@"颜色值 %@ 已复制到剪贴板", hexColor]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[FLEXDoKitVisualTools sharedInstance] stopColorPicker];
}

@end