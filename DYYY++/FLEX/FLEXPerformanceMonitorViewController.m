//
//  FLEXPerformanceMonitorViewController.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXPerformanceMonitorViewController.h"
#import "FLEXPerformanceMonitor.h"

@interface FLEXPerformanceMonitorViewController ()
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, assign) BOOL isProfiling;
@end

@implementation FLEXPerformanceMonitorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"性能监控";
    
    self.sectionTitles = @[
        @"方法性能分析",
        @"类加载时间"
    ];
    
    self.sections = @[@[], @[]];
    self.isProfiling = NO;
    
    UIBarButtonItem *startStopButton = [[UIBarButtonItem alloc] 
                                       initWithTitle:@"开始分析" 
                                       style:UIBarButtonItemStylePlain 
                                       target:self 
                                       action:@selector(toggleProfiling)];
    self.navigationItem.rightBarButtonItem = startStopButton;
    
    // 开始跟踪类加载时间
    [[FLEXPerformanceMonitor sharedInstance] startTrackingClassLoadTime];
}

- (void)toggleProfiling {
    if (self.isProfiling) {
        // 停止分析
        [[FLEXPerformanceMonitor sharedInstance] stopMethodProfiling];
        self.navigationItem.rightBarButtonItem.title = @"开始分析";
        
        // 获取结果
        NSArray *results = [[FLEXPerformanceMonitor sharedInstance] getProfilingResults];
        NSMutableArray *section0 = [NSMutableArray arrayWithArray:self.sections[0]];
        [section0 addObjectsFromArray:results];
        
        self.sections = @[section0, self.sections[1]];
        [self.tableView reloadData];
    } else {
        // 开始分析
        [[FLEXPerformanceMonitor sharedInstance] startMethodProfiling];
        self.navigationItem.rightBarButtonItem.title = @"停止分析";
    }
    
    self.isProfiling = !self.isProfiling;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 更新类加载时间
    NSArray *classLoadTimes = [[FLEXPerformanceMonitor sharedInstance] getClassLoadTimeInfo];
    self.sections = @[self.sections[0], classLoadTimes];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSArray *sectionArray = self.sections[indexPath.section];
    NSDictionary *item = sectionArray[indexPath.row];
    
    if (indexPath.section == 0) {
        // 方法性能数据
        cell.textLabel.text = item[@"methodName"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2fms", [item[@"executionTime"] doubleValue] * 1000];
    } else {
        // 类加载时间
        cell.textLabel.text = item[@"className"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2fms", [item[@"loadTime"] doubleValue]];
    }
    
    return cell;
}

@end