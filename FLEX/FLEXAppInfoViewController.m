//
//  FLEXAppInfoViewController.m
//  FLEX
//
//  Created for DoKit integration
//

#import "FLEXAppInfoViewController.h"
#import "FLEXUtility.h"
#import <mach/mach.h>   // 添加 mach API 相关头文件
#import <mach/task.h>   // 添加 task_info 函数声明

@interface FLEXAppInfoViewController ()

@property (nonatomic, strong) NSDictionary *appInfo;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sectionData;

@end

@implementation FLEXAppInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"应用信息";
    [self loadAppInfo];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"InfoCell"];
}

- (void)loadAppInfo {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *buildVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
    NSString *bundleIdentifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    NSString *bundleName = [infoDictionary objectForKey:@"CFBundleName"];
    NSString *minimumOSVersion = [infoDictionary objectForKey:@"MinimumOSVersion"];
    
    // 修复：从 systemUptime 创建日期对象
    NSDate *appLaunchDate = [NSDate dateWithTimeIntervalSinceNow:-[NSProcessInfo processInfo].systemUptime];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    NSString *appLaunchTime = [dateFormatter stringFromDate:appLaunchDate];
    
    self.sectionTitles = @[
        @"应用信息",
        @"系统信息",
        @"资源使用"
    ];
    
    NSMutableArray *appSection = [NSMutableArray array];
    [appSection addObject:@{@"title": @"应用名称", @"value": bundleName ?: @"未知"}];
    [appSection addObject:@{@"title": @"包标识符", @"value": bundleIdentifier ?: @"未知"}];
    [appSection addObject:@{@"title": @"版本号", @"value": [NSString stringWithFormat:@"%@ (%@)", appVersion ?: @"未知", buildVersion ?: @"未知"]}];
    [appSection addObject:@{@"title": @"最低系统版本", @"value": minimumOSVersion ?: @"未知"}];
    [appSection addObject:@{@"title": @"启动时间", @"value": appLaunchTime ?: @"未知"}];
    
    NSMutableArray *systemSection = [NSMutableArray array];
    [systemSection addObject:@{@"title": @"设备名称", @"value": [UIDevice currentDevice].name}];
    [systemSection addObject:@{@"title": @"系统版本", @"value": [NSString stringWithFormat:@"%@ %@", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion]}];
    [systemSection addObject:@{@"title": @"设备型号", @"value": [UIDevice currentDevice].model}];
    
    NSMutableArray *resourceSection = [NSMutableArray array];
    [resourceSection addObject:@{@"title": @"内存使用", @"value": [self formattedMemorySize:[self getApplicationMemoryUsage]]}];
    [resourceSection addObject:@{@"title": @"可用磁盘空间", @"value": [self formattedMemorySize:[self getFreeDiskSpace]]}];
    [resourceSection addObject:@{@"title": @"CPU核心数", @"value": [NSString stringWithFormat:@"%lu", (unsigned long)[NSProcessInfo processInfo].processorCount]}];
    
    self.sectionData = @[appSection, systemSection, resourceSection];
}

- (NSString *)formattedMemorySize:(uint64_t)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)bytes / 1024];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)bytes / (1024 * 1024 * 1024)];
    }
}

- (uint64_t)getApplicationMemoryUsage {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    }
    return 0;
}

- (uint64_t)getFreeDiskSpace {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sectionData[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoCell" forIndexPath:indexPath];
    
    NSDictionary *item = self.sectionData[indexPath.section][indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"value"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

@end