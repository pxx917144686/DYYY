//
//  FLEXSystemAnalyzerViewController.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXSystemAnalyzerViewController.h"
#import "FLEXHookDetector.h"
#import "FLEXMemoryAnalyzer.h"
#import "FLEXRuntimeClient.h"
#import "FLEXPerformanceMonitor.h"
#import "UIBarButtonItem+FLEX.h"
#import "FLEXDetailViewController.h" // 添加导入

@interface FLEXSystemAnalyzerViewController ()
@property (nonatomic, strong) NSDictionary *systemAnalysis;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sectionData;
@end

@implementation FLEXSystemAnalyzerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"系统分析器";
    
    // 添加刷新和导出功能
    self.navigationItem.rightBarButtonItems = @[
        [UIBarButtonItem flex_itemWithTitle:@"导出" target:self action:@selector(exportAnalysis)],
        [UIBarButtonItem flex_itemWithTitle:@"刷新" target:self action:@selector(refreshSystemAnalysis)]
    ];
    
    [self refreshSystemAnalysis];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshSystemAnalysis) forControlEvents:UIControlEventValueChanged];
}

- (void)refreshSystemAnalysis {
    self.systemAnalysis = [self getCurrentSystemAnalysis];
    
    // 格式化数据用于表格视图
    NSMutableArray *formattedSections = [NSMutableArray array];
    NSMutableArray *sectionTitles = [NSMutableArray array];
    
    for (NSString *key in [self.systemAnalysis allKeys]) {
        [sectionTitles addObject:key];
        [formattedSections addObject:self.systemAnalysis[key]];
    }
    
    self.sectionTitles = sectionTitles;
    self.sectionData = formattedSections;
    
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (NSDictionary *)getCurrentSystemAnalysis {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 性能监控数据
    FLEXPerformanceMonitor *perfMonitor = [FLEXPerformanceMonitor sharedInstance];
    
    // 删除未使用的变量声明
    // NSArray *profilingResults = [perfMonitor getProfilingResults];
    
    // 添加性能分析
    analysis[@"性能分析"] = @{
        @"CPU使用率": [NSString stringWithFormat:@"%.1f%%", perfMonitor.cpuUsage],
        @"内存使用": [NSString stringWithFormat:@"%.1f MB", perfMonitor.memoryUsage],
        @"网络流量": [NSString stringWithFormat:@"上传: %.1f KB/s, 下载: %.1f KB/s",
                          perfMonitor.uploadFlowBytes / 1024.0, 
                          perfMonitor.downloadFlowBytes / 1024.0],
        @"是否正在分析": @(NO)
    };
    
    // 添加系统信息
    UIDevice *device = [UIDevice currentDevice];
    analysis[@"系统信息"] = @{
        @"设备名称": device.name,
        @"系统版本": [NSString stringWithFormat:@"%@ %@", device.systemName, device.systemVersion],
        @"设备型号": device.model,
        @"设备UUID": device.identifierForVendor.UUIDString,
        @"处理器数量": @([NSProcessInfo processInfo].processorCount),
        @"物理内存": [NSString stringWithFormat:@"%.1f GB", [NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0 / 1024.0]
    };
    
    // 其他系统分析数据...
    
    return analysis;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sectionDict = [self.sectionData objectAtIndex:section];
    return sectionDict.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *sectionDict = [self.sectionData objectAtIndex:indexPath.section];
    NSArray *keys = [[sectionDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSString *key = keys[indexPath.row];
    id value = sectionDict[key];
    
    cell.textLabel.text = key;
    
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu 项", (unsigned long)([value isKindOfClass:[NSArray class]] ? [value count] : [value allKeys].count)];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.detailTextLabel.text = [value description];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *sectionDict = [self.sectionData objectAtIndex:indexPath.section];
    NSArray *keys = [[sectionDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSString *key = keys[indexPath.row];
    id value = sectionDict[key];
    
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
        // 创建详细视图显示复杂数据
        FLEXDetailViewController *detailVC = [[FLEXDetailViewController alloc] init];
        detailVC.title = key;
        detailVC.data = value;
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (void)exportAnalysis {
    // 从 RuntimeBrowser 移植的导出功能
    NSString *jsonString = [self analysisToJSONString];
    
    NSString *fileName = [NSString stringWithFormat:@"system_analysis_%@.json", 
                         [NSDateFormatter localizedStringFromDate:[NSDate date] 
                                                         dateStyle:NSDateFormatterShortStyle 
                                                         timeStyle:NSDateFormatterShortStyle]];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    NSError *error;
    BOOL success = [jsonString writeToFile:tempPath 
                                atomically:YES 
                                  encoding:NSUTF8StringEncoding 
                                     error:&error];
    
    if (success) {
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
        UIActivityViewController *shareVC = [[UIActivityViewController alloc] 
                                           initWithActivityItems:@[fileURL] 
                                           applicationActivities:nil];
        [self presentViewController:shareVC animated:YES completion:nil];
    }
}

- (NSString *)analysisToJSONString {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.systemAnalysis 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    
    if (jsonData) {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    } else {
        return [self.systemAnalysis description];
    }
}

@end