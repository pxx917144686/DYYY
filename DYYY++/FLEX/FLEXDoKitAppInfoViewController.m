#import "FLEXDoKitAppInfoViewController.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitAppInfoViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *appInfoData;
@end

@implementation FLEXDoKitAppInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"App信息";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupTableView];
    [self loadAppInfo];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AppInfoCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadAppInfo {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDictionary = mainBundle.infoDictionary;
    UIDevice *device = [UIDevice currentDevice];
    
    NSMutableArray *sections = [NSMutableArray array];
    
    // App基本信息
    NSMutableArray *appInfo = [NSMutableArray array];
    [appInfo addObject:@{@"title": @"应用名", @"value": infoDictionary[@"CFBundleDisplayName"] ?: infoDictionary[@"CFBundleName"] ?: @"未知"}];
    [appInfo addObject:@{@"title": @"Bundle ID", @"value": infoDictionary[@"CFBundleIdentifier"] ?: @"未知"}];
    [appInfo addObject:@{@"title": @"版本号", @"value": infoDictionary[@"CFBundleShortVersionString"] ?: @"未知"}];
    [appInfo addObject:@{@"title": @"Build号", @"value": infoDictionary[@"CFBundleVersion"] ?: @"未知"}];
    [appInfo addObject:@{@"title": @"Bundle路径", @"value": mainBundle.bundlePath}];
    [sections addObject:@{@"title": @"应用信息", @"items": appInfo}];
    
    // 设备信息
    NSMutableArray *deviceInfo = [NSMutableArray array];
    [deviceInfo addObject:@{@"title": @"设备名", @"value": device.name}];
    [deviceInfo addObject:@{@"title": @"设备型号", @"value": device.model}];
    [deviceInfo addObject:@{@"title": @"系统名称", @"value": device.systemName}];
    [deviceInfo addObject:@{@"title": @"系统版本", @"value": device.systemVersion}];
    [deviceInfo addObject:@{@"title": @"本地化版本", @"value": device.localizedModel}];
    [sections addObject:@{@"title": @"设备信息", @"items": deviceInfo}];
    
    // 屏幕信息
    UIScreen *screen = [UIScreen mainScreen];
    NSMutableArray *screenInfo = [NSMutableArray array];
    [screenInfo addObject:@{@"title": @"屏幕尺寸", @"value": NSStringFromCGSize(screen.bounds.size)}];
    [screenInfo addObject:@{@"title": @"屏幕比例", @"value": NSStringFromCGSize(screen.nativeBounds.size)}];
    [screenInfo addObject:@{@"title": @"像素密度", @"value": [NSString stringWithFormat:@"%.1fx", screen.scale]}];
    [screenInfo addObject:@{@"title": @"亮度", @"value": [NSString stringWithFormat:@"%.2f", screen.brightness]}];
    [sections addObject:@{@"title": @"屏幕信息", @"items": screenInfo}];
    
    self.appInfoData = [sections copy];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.appInfoData.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sectionData = self.appInfoData[section];
    return [sectionData[@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *sectionData = self.appInfoData[section];
    return sectionData[@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"AppInfoCell"];
    
    NSDictionary *sectionData = self.appInfoData[indexPath.section];
    NSArray *items = sectionData[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"value"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // 设置字体和颜色
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.detailTextLabel.textColor = FLEXSecondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 0;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 复制到剪贴板
    NSDictionary *sectionData = self.appInfoData[indexPath.section];
    NSArray *items = sectionData[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    NSString *valueText = item[@"value"];
    if (valueText && valueText.length > 0) {
        [UIPasteboard generalPasteboard].string = valueText;
        
        // 显示复制成功提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制" 
                                                                       message:[NSString stringWithFormat:@"已复制 \"%@\" 到剪贴板", item[@"title"]]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

@end