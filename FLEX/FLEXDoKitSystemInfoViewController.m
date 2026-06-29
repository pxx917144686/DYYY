#import "FLEXDoKitSystemInfoViewController.h"
#import "FLEXCompatibility.h"
#import <sys/utsname.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/proc.h>

@interface FLEXDoKitSystemInfoViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *systemInfoData;
@end

@implementation FLEXDoKitSystemInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"系统信息";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupTableView];
    [self loadSystemInfo];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SystemInfoCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadSystemInfo {
    NSMutableArray *sections = [NSMutableArray array];
    
    // 系统信息
    NSMutableArray *systemInfo = [NSMutableArray array];
    struct utsname systemInfo_c;
    uname(&systemInfo_c);
    
    [systemInfo addObject:@{@"title": @"内核名称", @"value": [NSString stringWithCString:systemInfo_c.sysname encoding:NSUTF8StringEncoding]}];
    [systemInfo addObject:@{@"title": @"节点名称", @"value": [NSString stringWithCString:systemInfo_c.nodename encoding:NSUTF8StringEncoding]}];
    [systemInfo addObject:@{@"title": @"内核版本", @"value": [NSString stringWithCString:systemInfo_c.release encoding:NSUTF8StringEncoding]}];
    [systemInfo addObject:@{@"title": @"内核构建", @"value": [NSString stringWithCString:systemInfo_c.version encoding:NSUTF8StringEncoding]}];
    [systemInfo addObject:@{@"title": @"硬件平台", @"value": [NSString stringWithCString:systemInfo_c.machine encoding:NSUTF8StringEncoding]}];
    [sections addObject:@{@"title": @"系统内核", @"items": systemInfo}];
    
    // 内存信息
    NSMutableArray *memoryInfo = [NSMutableArray array];
    vm_size_t page_size;
    mach_port_t mach_port = mach_host_self();
    host_page_size(mach_port, &page_size);
    
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(natural_t);
    host_statistics64(mach_port, HOST_VM_INFO, (host_info64_t)&vm_stat, &host_size);
    
    uint64_t total_memory = [NSProcessInfo processInfo].physicalMemory;
    uint64_t used_memory = (uint64_t)(vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * page_size;
    uint64_t free_memory = total_memory - used_memory;
    
    [memoryInfo addObject:@{@"title": @"总内存", @"value": [self formatBytes:total_memory]}];
    [memoryInfo addObject:@{@"title": @"已使用", @"value": [self formatBytes:used_memory]}];
    [memoryInfo addObject:@{@"title": @"可用内存", @"value": [self formatBytes:free_memory]}];
    [memoryInfo addObject:@{@"title": @"页面大小", @"value": [self formatBytes:page_size]}];
    [sections addObject:@{@"title": @"内存信息", @"items": memoryInfo}];
    
    // 处理器信息 - 修复格式化错误
    NSMutableArray *cpuInfo = [NSMutableArray array];
    [cpuInfo addObject:@{@"title": @"处理器数量", @"value": [NSString stringWithFormat:@"%lu", (unsigned long)[NSProcessInfo processInfo].processorCount]}];
    [cpuInfo addObject:@{@"title": @"活跃处理器", @"value": [NSString stringWithFormat:@"%lu", (unsigned long)[NSProcessInfo processInfo].activeProcessorCount]}];
    [sections addObject:@{@"title": @"处理器信息", @"items": cpuInfo}];
    
    // 运行时信息 - 修复运行时间计算
    NSMutableArray *runtimeInfo = [NSMutableArray array];
    [runtimeInfo addObject:@{@"title": @"系统启动时间", @"value": [self formatUptime:[NSProcessInfo processInfo].systemUptime]}];
    
    // 修复进程运行时间计算
    NSTimeInterval processUptime = [[NSDate date] timeIntervalSince1970] - [[NSProcessInfo processInfo] systemUptime];
    [runtimeInfo addObject:@{@"title": @"进程运行时间", @"value": [self formatUptime:processUptime]}];
    [runtimeInfo addObject:@{@"title": @"进程ID", @"value": [NSString stringWithFormat:@"%d", [NSProcessInfo processInfo].processIdentifier]}];
    [sections addObject:@{@"title": @"运行时信息", @"items": runtimeInfo}];
    
    self.systemInfoData = [sections copy];
    [self.tableView reloadData];
}

- (NSString *)formatBytes:(uint64_t)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", bytes / 1024.0];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", bytes / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
    }
}

- (NSString *)formatUptime:(NSTimeInterval)uptime {
    int days = (int)(uptime / (24 * 3600));
    int hours = (int)((uptime - days * 24 * 3600) / 3600);
    int minutes = (int)((uptime - days * 24 * 3600 - hours * 3600) / 60);
    
    if (days > 0) {
        return [NSString stringWithFormat:@"%d天 %d小时 %d分钟", days, hours, minutes];
    } else if (hours > 0) {
        return [NSString stringWithFormat:@"%d小时 %d分钟", hours, minutes];
    } else {
        return [NSString stringWithFormat:@"%d分钟", minutes];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.systemInfoData.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sectionData = self.systemInfoData[section];
    return [sectionData[@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *sectionData = self.systemInfoData[section];
    return sectionData[@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"SystemInfoCell"];
    
    NSDictionary *sectionData = self.systemInfoData[indexPath.section];
    NSArray *items = sectionData[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"value"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

@end