#import "FLEXLookinComparisonViewController.h"

@interface FLEXLookinComparisonViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISegmentedControl *snapshotSelector;
@property (nonatomic, strong) UITableView *comparisonTableView;
@property (nonatomic, strong) NSArray *comparisonResults;
@end

@implementation FLEXLookinComparisonViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"层次比较";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupUI];
    [self performComparison];
}

- (void)setupUI {
    // 快照选择器
    NSMutableArray *items = [NSMutableArray new];
    for (NSInteger i = 0; i < self.snapshots.count; i++) {
        [items addObject:[NSString stringWithFormat:@"快照 %ld", (long)i + 1]];
    }
    
    self.snapshotSelector = [[UISegmentedControl alloc] initWithItems:items];
    self.snapshotSelector.selectedSegmentIndex = 0;
    [self.snapshotSelector addTarget:self action:@selector(snapshotChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 比较结果表格
    self.comparisonTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.comparisonTableView.dataSource = self;
    self.comparisonTableView.delegate = self;
    [self.comparisonTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ComparisonCell"];
    
    // 布局
    self.snapshotSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.comparisonTableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.snapshotSelector];
    [self.view addSubview:self.comparisonTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.snapshotSelector.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.snapshotSelector.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.snapshotSelector.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.comparisonTableView.topAnchor constraintEqualToAnchor:self.snapshotSelector.bottomAnchor constant:16],
        [self.comparisonTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.comparisonTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.comparisonTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 导航栏
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                             target:self 
                                             action:@selector(doneButtonTapped)];
}

- (void)performComparison {
    if (self.snapshots.count < 2) {
        self.comparisonResults = @[];
        [self.comparisonTableView reloadData];
        return;
    }
    
    NSInteger selectedIndex = self.snapshotSelector.selectedSegmentIndex;
    NSInteger baseIndex = (selectedIndex == 0) ? 1 : 0;
    
    NSArray<FLEXLookinViewNode *> *baseSnapshot = self.snapshots[baseIndex];
    NSArray<FLEXLookinViewNode *> *currentSnapshot = self.snapshots[selectedIndex];
    
    NSMutableArray *results = [NSMutableArray array];
    
    // 找出新增的视图
    for (FLEXLookinViewNode *currentNode in currentSnapshot) {
        BOOL found = NO;
        for (FLEXLookinViewNode *baseNode in baseSnapshot) {
            if ([currentNode.className isEqualToString:baseNode.className] && 
                CGRectEqualToRect(currentNode.frame, baseNode.frame)) {
                found = YES;
                break;
            }
        }
        if (!found) {
            [results addObject:@{
                @"type": @"新增",
                @"node": currentNode,
                @"description": [NSString stringWithFormat:@"新增视图: %@", currentNode.className]
            }];
        }
    }
    
    // 找出删除的视图
    for (FLEXLookinViewNode *baseNode in baseSnapshot) {
        BOOL found = NO;
        for (FLEXLookinViewNode *currentNode in currentSnapshot) {
            if ([baseNode.className isEqualToString:currentNode.className] && 
                CGRectEqualToRect(baseNode.frame, currentNode.frame)) {
                found = YES;
                break;
            }
        }
        if (!found) {
            [results addObject:@{
                @"type": @"删除",
                @"node": baseNode,
                @"description": [NSString stringWithFormat:@"删除视图: %@", baseNode.className]
            }];
        }
    }
    
    // 找出修改的视图
    for (FLEXLookinViewNode *currentNode in currentSnapshot) {
        for (FLEXLookinViewNode *baseNode in baseSnapshot) {
            if ([currentNode.className isEqualToString:baseNode.className]) {
                if (!CGRectEqualToRect(currentNode.frame, baseNode.frame) ||
                    currentNode.alpha != baseNode.alpha ||
                    currentNode.hidden != baseNode.hidden) {
                    
                    [results addObject:@{
                        @"type": @"修改",
                        @"node": currentNode,
                        @"baseNode": baseNode,
                        @"description": [NSString stringWithFormat:@"修改视图: %@", currentNode.className]
                    }];
                }
                break;
            }
        }
    }
    
    self.comparisonResults = results;
    [self.comparisonTableView reloadData];
}

- (void)snapshotChanged:(UISegmentedControl *)control {
    [self performComparison];
}

- (void)doneButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.comparisonResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ComparisonCell" forIndexPath:indexPath];
    
    NSDictionary *result = self.comparisonResults[indexPath.row];
    NSString *type = result[@"type"];
    FLEXLookinViewNode *node = result[@"node"];
    
    cell.textLabel.text = result[@"description"];
    
    // 根据变化类型设置颜色
    if ([type isEqualToString:@"新增"]) {
        cell.textLabel.textColor = [UIColor systemGreenColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Frame: %@", NSStringFromCGRect(node.frame)];
    } else if ([type isEqualToString:@"删除"]) {
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Frame: %@", NSStringFromCGRect(node.frame)];
    } else if ([type isEqualToString:@"修改"]) {
        cell.textLabel.textColor = [UIColor systemOrangeColor];
        FLEXLookinViewNode *baseNode = result[@"baseNode"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Frame: %@ → %@", 
                                   NSStringFromCGRect(baseNode.frame), 
                                   NSStringFromCGRect(node.frame)];
    }
    
    cell.detailTextLabel.numberOfLines = 0;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.comparisonResults.count == 0) {
        return @"没有发现差异";
    }
    return [NSString stringWithFormat:@"发现 %lu 个差异", (unsigned long)self.comparisonResults.count];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *result = self.comparisonResults[indexPath.row];
    FLEXLookinViewNode *node = result[@"node"];
    NSString *type = result[@"type"];
    
    // 显示详细信息
    NSMutableString *detail = [NSMutableString string];
    [detail appendFormat:@"变化类型: %@\n", type];
    [detail appendFormat:@"视图类: %@\n", node.className];
    [detail appendFormat:@"Frame: %@\n", NSStringFromCGRect(node.frame)];
    [detail appendFormat:@"Alpha: %.2f\n", node.alpha];
    [detail appendFormat:@"Hidden: %@\n", node.hidden ? @"是" : @"否"];
    
    if ([type isEqualToString:@"修改"]) {
        FLEXLookinViewNode *baseNode = result[@"baseNode"];
        [detail appendString:@"\n--- 原始值 ---\n"];
        [detail appendFormat:@"Frame: %@\n", NSStringFromCGRect(baseNode.frame)];
        [detail appendFormat:@"Alpha: %.2f\n", baseNode.alpha];
        [detail appendFormat:@"Hidden: %@\n", baseNode.hidden ? @"是" : @"否"];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"视图详情" 
                                                                   message:detail
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end