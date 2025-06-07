#import "FLEXLookinHierarchyViewController.h"
#import "FLEXLookinComparisonViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXObjectExplorerViewController.h"

@interface FLEXLookinHierarchyViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *hierarchyTableView;
@property (nonatomic, strong) UIView *detailPanel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) NSArray<FLEXLookinViewNode *> *flattenedHierarchy;
@property (nonatomic, strong) UIButton *snapshotButton;
@property (nonatomic, strong) UIButton *compareButton;
@property (nonatomic, strong) NSMutableArray *hierarchySnapshots;
@end

@implementation FLEXLookinHierarchyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Lookin 层次检查";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    self.hierarchySnapshots = [NSMutableArray array];
    
    [self setupInspector];
    [self setupUI];
    [self setupLayout];
    [self setupNavigationBar];
}

- (void)setupInspector {
    self.inspector = [FLEXLookinInspector sharedInstance];
    self.inspector.delegate = self;
}

- (void)setupUI {
    // 模式控制器
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"层次结构", @"3D视图"]];
    self.modeControl.selectedSegmentIndex = 0;
    [self.modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 层次表格
    self.hierarchyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.hierarchyTableView.dataSource = self;
    self.hierarchyTableView.delegate = self;
    [self.hierarchyTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"HierarchyCell"];
    
    // 详情面板
    self.detailPanel = [[UIView alloc] init];
    self.detailPanel.backgroundColor = FLEXSecondarySystemBackgroundColor;
    self.detailPanel.layer.cornerRadius = 8;
    
    self.detailLabel = [[UILabel alloc] init];
    self.detailLabel.numberOfLines = 0;
    self.detailLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.detailLabel.text = @"选择一个视图查看详情";
    
    // 快照按钮
    self.snapshotButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.snapshotButton setTitle:@"保存快照" forState:UIControlStateNormal];
    [self.snapshotButton addTarget:self action:@selector(saveSnapshot:) forControlEvents:UIControlEventTouchUpInside];
    
    // 对比按钮
    self.compareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.compareButton setTitle:@"对比快照" forState:UIControlStateNormal];
    [self.compareButton addTarget:self action:@selector(compareSnapshot:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.detailPanel addSubview:self.detailLabel];
    [self.detailPanel addSubview:self.snapshotButton];
    [self.detailPanel addSubview:self.compareButton];
}

- (void)setupLayout {
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.hierarchyTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.snapshotButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.compareButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.modeControl];
    [self.view addSubview:self.hierarchyTableView];
    [self.view addSubview:self.detailPanel];
    
    [NSLayoutConstraint activateConstraints:@[
        // 模式控制器
        [self.modeControl.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:8],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        // 层次表格
        [self.hierarchyTableView.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:8],
        [self.hierarchyTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hierarchyTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hierarchyTableView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.6],
        
        // 详情面板
        [self.detailPanel.topAnchor constraintEqualToAnchor:self.hierarchyTableView.bottomAnchor constant:8],
        [self.detailPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.detailPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.detailPanel.bottomAnchor constraintEqualToAnchor:FLEXSafeAreaBottomAnchor(self) constant:-8],
        
        // 详情面板内容
        [self.detailLabel.topAnchor constraintEqualToAnchor:self.detailPanel.topAnchor constant:16],
        [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.detailPanel.leadingAnchor constant:16],
        [self.detailLabel.trailingAnchor constraintEqualToAnchor:self.detailPanel.trailingAnchor constant:-16],
        
        [self.snapshotButton.topAnchor constraintEqualToAnchor:self.detailLabel.bottomAnchor constant:16],
        [self.snapshotButton.leadingAnchor constraintEqualToAnchor:self.detailPanel.leadingAnchor constant:16],
        [self.snapshotButton.trailingAnchor constraintEqualToAnchor:self.detailPanel.centerXAnchor constant:-8],
        [self.snapshotButton.bottomAnchor constraintEqualToAnchor:self.detailPanel.bottomAnchor constant:-16],
        
        [self.compareButton.topAnchor constraintEqualToAnchor:self.detailLabel.bottomAnchor constant:16],
        [self.compareButton.leadingAnchor constraintEqualToAnchor:self.detailPanel.centerXAnchor constant:8],
        [self.compareButton.trailingAnchor constraintEqualToAnchor:self.detailPanel.trailingAnchor constant:-16],
        [self.compareButton.bottomAnchor constraintEqualToAnchor:self.detailPanel.bottomAnchor constant:-16],
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
        [self.inspector stopInspecting];
        button.title = @"开始检查";
    } else {
        [self.inspector startInspecting];
        button.title = @"停止检查";
        [self refreshHierarchy];
    }
}

- (void)modeChanged:(UISegmentedControl *)control {
    self.inspector.viewMode = (FLEXLookinViewMode)control.selectedSegmentIndex;
    
    switch (control.selectedSegmentIndex) {
        case FLEXLookinViewModeHierarchy:
            // 显示层次表格
            self.hierarchyTableView.hidden = NO;
            break;
        case FLEXLookinViewMode3D:
            // 切换到3D模式
            [self.inspector show3DViewHierarchy];
            break;
        default:
            break;
    }
}

- (void)saveSnapshot:(UIButton *)button {
    if (self.flattenedHierarchy) {
        [self.hierarchySnapshots addObject:[self.flattenedHierarchy copy]];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"快照已保存" 
                                                                       message:[NSString stringWithFormat:@"当前已有 %lu 个快照", (unsigned long)self.hierarchySnapshots.count]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)compareSnapshot:(UIButton *)button {
    if (self.hierarchySnapshots.count < 2) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要更多快照" 
                                                                       message:@"至少需要两个快照才能进行比较"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    FLEXLookinComparisonViewController *comparisonVC = [[FLEXLookinComparisonViewController alloc] init];
    comparisonVC.snapshots = self.hierarchySnapshots;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:comparisonVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)refreshHierarchy {
    // ✅ 修复：使用正确的方法调用
    [self.inspector refreshViewHierarchy];
    self.flattenedHierarchy = [self.inspector flattenedHierarchy];
    [self.hierarchyTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.flattenedHierarchy.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"HierarchyCell" forIndexPath:indexPath];
    
    // 严格边界检查
    if (indexPath.row >= self.flattenedHierarchy.count) {
        cell.textLabel.text = @"⚠️ 索引越界";
        cell.textLabel.textColor = FLEXSystemRedColor;
        return cell;
    }
    
    FLEXLookinViewNode *node = self.flattenedHierarchy[indexPath.row];
    
    cell.textLabel.text = NSStringFromClass([node.view class]);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"<%p> depth:%lu", 
                                node.view, (unsigned long)node.depth];
    
    // 设置缩进
    cell.indentationLevel = node.depth;
    cell.indentationWidth = 20.0;
    
    // 设置颜色
    cell.detailTextLabel.textColor = FLEXSecondaryLabelColor;
    
    // 根据节点类型设置不同颜色
    if ([node.view isKindOfClass:[UILabel class]]) {
        cell.textLabel.textColor = FLEXSystemBlueColor;
    } else if ([node.view isKindOfClass:[UIButton class]]) {
        cell.textLabel.textColor = FLEXSystemGreenColor;
    } else {
        cell.textLabel.textColor = FLEXLabelColor;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row < self.flattenedHierarchy.count) {
        FLEXLookinViewNode *node = self.flattenedHierarchy[indexPath.row];
        [self showDetailsForNode:node];
        
        // 选择该视图
        [self.inspector selectView:node.view];
    }
}

- (void)showDetailsForNode:(FLEXLookinViewNode *)node {
    NSMutableString *details = [NSMutableString string];
    
    [details appendFormat:@"类名: %@\n", NSStringFromClass([node.view class])];
    [details appendFormat:@"内存地址: %p\n", node.view];
    [details appendFormat:@"层级深度: %lu\n", (unsigned long)node.depth];
    [details appendFormat:@"Frame: %@\n", NSStringFromCGRect(node.view.frame)];
    [details appendFormat:@"Bounds: %@\n", NSStringFromCGRect(node.view.bounds)];
    [details appendFormat:@"Hidden: %@\n", node.view.hidden ? @"YES" : @"NO"];
    [details appendFormat:@"Alpha: %.2f\n", node.view.alpha];
    
    if (node.view.backgroundColor) {
        [details appendFormat:@"背景色: %@\n", node.view.backgroundColor];
    }
    
    self.detailLabel.text = details;
}

#pragma mark - FLEXLookinInspectorDelegate

- (void)lookinInspector:(FLEXLookinInspector *)inspector didSelectView:(UIView *)view {
    [self refreshHierarchy];
    
    // 查找对应的node并显示详情
    for (FLEXLookinViewNode *node in self.flattenedHierarchy) {
        if (node.view == view) {
            [self showDetailsForNode:node];
            break;
        }
    }
}

- (void)lookinInspector:(FLEXLookinInspector *)inspector didUpdateHierarchy:(NSArray<FLEXLookinViewNode *> *)hierarchy {
    self.flattenedHierarchy = hierarchy;
    [self.hierarchyTableView reloadData];
}

@end