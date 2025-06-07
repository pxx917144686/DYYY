#import "FLEXRevealInspectorViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXObjectExplorerViewController.h"

@interface FLEXRevealInspectorViewController ()
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UILabel *instructionLabel;
@property (nonatomic, strong) UIView *controlPanel;
@property (nonatomic, strong) UIButton *constraintsButton;
@property (nonatomic, strong) UIButton *measurementsButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIButton *exportButton;
@end

@implementation FLEXRevealInspectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Reveal检查器";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupInspector];
    [self setupUI];
    [self setupNavigationBar];
}

- (void)setupInspector {
    self.inspector = [FLEXRevealLikeInspector sharedInstance];
    self.inspector.delegate = self;
}

- (void)setupUI {
    // 模式切换控制器
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"3D视图", @"平面视图", @"约束视图"]];
    self.modeControl.selectedSegmentIndex = 0;
    [self.modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 说明标签
    self.instructionLabel = [[UILabel alloc] init];
    self.instructionLabel.text = @"点击\"开始检查\"按钮，然后点击视图进行检查";
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.numberOfLines = 0;
    self.instructionLabel.font = [UIFont systemFontOfSize:16];
    self.instructionLabel.textColor = FLEXSecondaryLabelColor;
    
    // 控制面板
    [self setupControlPanel];
    
    // 布局
    [self setupLayout];
}

- (void)setupControlPanel {
    self.controlPanel = [[UIView alloc] init];
    self.controlPanel.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.controlPanel.layer.cornerRadius = 8;
    
    // 约束按钮
    self.constraintsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.constraintsButton setTitle:@"显示约束" forState:UIControlStateNormal];
    [self.constraintsButton addTarget:self action:@selector(toggleConstraints:) forControlEvents:UIControlEventTouchUpInside];
    self.constraintsButton.enabled = NO;
    
    // 测量按钮
    self.measurementsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.measurementsButton setTitle:@"显示测量" forState:UIControlStateNormal];
    [self.measurementsButton addTarget:self action:@selector(toggleMeasurements:) forControlEvents:UIControlEventTouchUpInside];
    self.measurementsButton.enabled = NO;
    
    // 编辑按钮
    self.editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.editButton setTitle:@"实时编辑" forState:UIControlStateNormal];
    [self.editButton addTarget:self action:@selector(startLiveEditing:) forControlEvents:UIControlEventTouchUpInside];
    self.editButton.enabled = NO;
    
    // 导出按钮
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"导出层次" forState:UIControlStateNormal];
    [self.exportButton addTarget:self action:@selector(exportHierarchy:) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加按钮到面板
    [self.controlPanel addSubview:self.constraintsButton];
    [self.controlPanel addSubview:self.measurementsButton];
    [self.controlPanel addSubview:self.editButton];
    [self.controlPanel addSubview:self.exportButton];
}

- (void)setupLayout {
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlPanel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.modeControl];
    [self.view addSubview:self.instructionLabel];
    [self.view addSubview:self.controlPanel];
    
    // 控制面板内部布局
    self.constraintsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.measurementsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.editButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // 模式控制器
        [self.modeControl.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:20],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // 说明标签
        [self.instructionLabel.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:40],
        [self.instructionLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.instructionLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // 控制面板
        [self.controlPanel.topAnchor constraintEqualToAnchor:self.instructionLabel.bottomAnchor constant:40],
        [self.controlPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.controlPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.controlPanel.heightAnchor constraintEqualToConstant:120],
        
        // 控制面板内的按钮
        [self.constraintsButton.topAnchor constraintEqualToAnchor:self.controlPanel.topAnchor constant:15],
        [self.constraintsButton.leadingAnchor constraintEqualToAnchor:self.controlPanel.leadingAnchor constant:15],
        [self.constraintsButton.trailingAnchor constraintEqualToAnchor:self.controlPanel.centerXAnchor constant:-5],
        
        [self.measurementsButton.topAnchor constraintEqualToAnchor:self.controlPanel.topAnchor constant:15],
        [self.measurementsButton.leadingAnchor constraintEqualToAnchor:self.controlPanel.centerXAnchor constant:5],
        [self.measurementsButton.trailingAnchor constraintEqualToAnchor:self.controlPanel.trailingAnchor constant:-15],
        
        [self.editButton.topAnchor constraintEqualToAnchor:self.constraintsButton.bottomAnchor constant:10],
        [self.editButton.leadingAnchor constraintEqualToAnchor:self.controlPanel.leadingAnchor constant:15],
        [self.editButton.trailingAnchor constraintEqualToAnchor:self.controlPanel.centerXAnchor constant:-5],
        
        [self.exportButton.topAnchor constraintEqualToAnchor:self.measurementsButton.bottomAnchor constant:10],
        [self.exportButton.leadingAnchor constraintEqualToAnchor:self.controlPanel.centerXAnchor constant:5],
        [self.exportButton.trailingAnchor constraintEqualToAnchor:self.controlPanel.trailingAnchor constant:-15],
    ]];
}

- (void)setupNavigationBar {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                             initWithTitle:@"开始检查"
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(toggleInspection:)];
}

#pragma mark - Actions

- (void)toggleInspection:(UIBarButtonItem *)button {
    if (self.inspector.isInspecting) {
        [self.inspector hide3DViewHierarchy];
        button.title = @"开始检查";
        self.instructionLabel.text = @"点击\"开始检查\"按钮，然后点击视图进行检查";
        [self disableControlButtons];
    } else {
        [self.inspector show3DViewHierarchy];
        [self.inspector enableLiveEditing];
        button.title = @"停止检查";
        self.instructionLabel.text = @"点击视图进行选择，双击进行编辑，长按显示菜单";
    }
}

- (void)modeChanged:(UISegmentedControl *)control {
    switch (control.selectedSegmentIndex) {
        case 0: // 3D视图
            if (self.inspector.isInspecting) {
                [self.inspector show3DViewHierarchy];
            }
            break;
        case 1: // 平面视图
            // TODO: 实现平面视图模式
            break;
        case 2: // 约束视图
            // TODO: 实现约束视图模式
            break;
    }
}

- (void)toggleConstraints:(UIButton *)button {
    static BOOL showingConstraints = NO;
    
    if (showingConstraints) {
        [self.inspector hideViewConstraints];
        [button setTitle:@"显示约束" forState:UIControlStateNormal];
        showingConstraints = NO;
    } else {
        if (self.inspector.selectedView) {
            [self.inspector showViewConstraints:self.inspector.selectedView];
            [button setTitle:@"隐藏约束" forState:UIControlStateNormal];
            showingConstraints = YES;
        }
    }
}

- (void)toggleMeasurements:(UIButton *)button {
    static BOOL showingMeasurements = NO;
    
    if (showingMeasurements) {
        [self.inspector hideViewMeasurements];
        [button setTitle:@"显示测量" forState:UIControlStateNormal];
        showingMeasurements = NO;
    } else {
        if (self.inspector.selectedView) {
            [self.inspector showViewMeasurements:self.inspector.selectedView];
            [button setTitle:@"隐藏测量" forState:UIControlStateNormal];
            showingMeasurements = YES;
        }
    }
}

- (void)startLiveEditing:(UIButton *)button {
    if (self.inspector.selectedView) {
        [self.inspector enableLiveEditing];
        // 直接触发编辑面板
        [self.inspector showLiveEditingPanelForView:self.inspector.selectedView];
    }
}

- (void)exportHierarchy:(UIButton *)button {
    [self.inspector exportViewHierarchyDescription];
}

- (void)disableControlButtons {
    self.constraintsButton.enabled = NO;
    self.measurementsButton.enabled = NO;
    self.editButton.enabled = NO;
    
    [self.constraintsButton setTitle:@"显示约束" forState:UIControlStateNormal];
    [self.measurementsButton setTitle:@"显示测量" forState:UIControlStateNormal];
}

- (void)enableControlButtons {
    self.constraintsButton.enabled = YES;
    self.measurementsButton.enabled = YES;
    self.editButton.enabled = YES;
}

#pragma mark - FLEXRevealInspectorDelegate

- (void)revealInspector:(id)inspector didSelectView:(UIView *)view {
    [self enableControlButtons];
    
    // 更新说明文本
    self.instructionLabel.text = [NSString stringWithFormat:@"已选择: %@\nFrame: %.1f, %.1f, %.1f, %.1f", 
                                 NSStringFromClass([view class]),
                                 view.frame.origin.x, view.frame.origin.y,
                                 view.frame.size.width, view.frame.size.height];
}

- (void)revealInspector:(id)inspector didDeselectView:(UIView *)view {
    [self disableControlButtons];
    self.instructionLabel.text = @"点击视图进行选择，双击进行编辑，长按显示菜单";
}

@end