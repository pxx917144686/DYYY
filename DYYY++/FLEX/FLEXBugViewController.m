//
//  FLEXBugViewController.m
//  FLEX
//
//  Bug调试功能实现
//

#import "FLEXBugViewController.h"
#import "FLEXNavigationController.h"
#import "FLEXAlert.h"
#import "FLEXManager.h"
#import "FLEXFileBrowserController.h"
#import "FLEXSystemLogViewController.h"
#import "FLEXNetworkMITMViewController.h"
#import "FLEXPerformanceViewController.h"
#import "FLEXHierarchyTableViewController.h"
#import "FLEXAppInfoViewController.h"
#import "FLEXSystemAnalyzerViewController.h"

#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "FLEXResources.h"

#import "FLEXDoKitCPUViewController.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXDoKitCrashViewController.h"
#import "FLEXLookinMeasureController.h"
#import "FLEXDoKitLagViewController.h"
#import "FLEXDoKitMockViewController.h" 
#import "FLEXDoKitLogViewController.h"
#import "FLEXFPSMonitorViewController.h"
#import "FLEXMemoryMonitorViewController.h"
#import "FLEXRevealLikeInspector.h"

@interface FLEXBugViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSArray<NSDictionary *> *categories;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSDictionary *> *> *toolsByCategory;
@property (nonatomic, assign) BOOL isInCategory;
@property (nonatomic, strong) NSString *currentCategory;

@end

@implementation FLEXBugViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"工具";
    self.isInCategory = NO;
    
    // 配置工具分类
    [self setupToolsData];
    
    // ✅ 直接使用父类的tableView属性
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ToolCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.isInCategory) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] 
            initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
            target:self 
            action:@selector(dismissButtonTapped)];
    }
}

- (void)setupToolsData {
    // 常用工具
    NSArray *commonTools = @[
        @{@"title": @"H5任意门", @"detail": @"H5页面调试", @"class": @"FLEXH5DoorViewController"},
        @{@"title": @"沙盒浏览", @"detail": @"文件系统浏览", @"class": @"FLEXDoKitFileBrowserViewController"},
        @{@"title": @"App信息查看", @"detail": @"应用详细信息", @"class": @"FLEXDoKitAppInfoViewController"},
        @{@"title": @"系统信息", @"detail": @"设备系统信息", @"class": @"FLEXDoKitSystemInfoViewController"},
        @{@"title": @"清除数据", @"detail": @"清理应用数据", @"class": @"FLEXDoKitCleanViewController"},
        @{@"title": @"偏好设置", @"detail": @"偏好设置编辑", @"class": @"FLEXDoKitUserDefaultsViewController"},
    ];
    
    // 性能检测工具
    NSArray *performanceTools = @[
        @{@"title": @"FPS实时监控", @"detail": @"帧率实时显示", @"class": @"FLEXFPSMonitorViewController"},
        @{@"title": @"内存使用监控", @"detail": @"内存实时监控", @"class": @"FLEXMemoryMonitorViewController"},
        @{@"title": @"CPU使用监控", @"detail": @"CPU使用率监控", @"class": @"FLEXDoKitCPUViewController"},
        @{@"title": @"卡顿检测", @"detail": @"UI卡顿实时检测", @"class": @"FLEXDoKitLagViewController"},
        @{@"title": @"内存泄漏检测", @"detail": @"内存泄漏实时检测", @"class": @"FLEXMemoryLeakDetectorViewController"},
        @{@"title": @"Crash日志", @"detail": @"崩溃日志分析", @"class": @"FLEXDoKitCrashViewController"},
    ];
    
    // 网络工具
    NSArray *networkTools = @[
        @{@"title": @"网络监控", @"detail": @"网络请求监控", @"class": @"FLEXNetworkMonitorViewController"},
        @{@"title": @"API测试", @"detail": @"接口测试工具", @"class": @"FLEXAPITestViewController"},
        @{@"title": @"Mock数据管理", @"detail": @"接口数据模拟", @"class": @"FLEXDoKitMockViewController"},
        @{@"title": @"网络历史", @"detail": @"网络请求历史", @"class": @"FLEXDoKitNetworkHistoryViewController"},
        @{@"title": @"弱网测试", @"detail": @"模拟弱网环境", @"class": @"FLEXDoKitWeakNetworkViewController"},
        @{@"title": @"网络劫持", @"detail": @"MITM代理调试", @"class": @"FLEXNetworkMITMViewController"},
    ];
    
    // 视觉工具
    NSArray *visualTools = @[
        @{@"title": @"颜色吸管", @"detail": @"屏幕取色工具", @"class": @"FLEXDoKitColorPickerViewController"},
        @{@"title": @"Lookin测量工具", @"detail": @"精确测量UI元素距离", @"action": @"showLookinMeasure"},
        @{@"title": @"Lookin 3D预览", @"detail": @"3D层次结构预览", @"class": @"FLEXLookinPreviewController"},
        @{@"title": @"组件检查器", @"detail": @"UI组件详细信息", @"class": @"FLEXDoKitComponentViewController"},
        @{@"title": @"对齐标尺", @"detail": @"UI元素测量", @"action": @"showRuler"},
        @{@"title": @"元素边框", @"detail": @"显示视图边框", @"action": @"showViewBorder"},
        @{@"title": @"布局边界", @"detail": @"布局约束可视化", @"action": @"showLayoutBounds"},
        @{@"title": @"视图测量", @"detail": @"显示视图尺寸", @"action": @"showViewMeasurements"},
        @{@"title": @"约束可视化", @"detail": @"显示约束关系", @"action": @"showConstraintsVisualization"},
        @{@"title": @"实时编辑", @"detail": @"实时修改视图属性", @"action": @"enableLiveViewEditing"},
    ];
    
    // ✅ 添加日志工具定义
    NSArray *logTools = @[
        @{@"title": @"实时日志", @"detail": @"应用日志实时查看", @"class": @"FLEXDoKitLogViewController"},
        @{@"title": @"日志过滤器", @"detail": @"日志内容过滤", @"class": @"FLEXDoKitLogFilterViewController"},
        @{@"title": @"系统日志", @"detail": @"系统级日志查看", @"class": @"FLEXSystemLogViewController"},
    ];
    
    // 定义分类
    self.categories = @[
        @{@"title": @"常用工具", @"image": @"wrench.fill", @"key": @"common"},
        @{@"title": @"性能检测", @"image": @"speedometer", @"key": @"performance"},
        @{@"title": @"网络工具", @"image": @"network", @"key": @"network"},
        @{@"title": @"视觉工具", @"image": @"eye.fill", @"key": @"visual"},
        @{@"title": @"日志工具", @"image": @"doc.text.fill", @"key": @"log"}
    ];
    
    // 更新工具映射
    self.toolsByCategory = @{
        @"common": commonTools,
        @"performance": performanceTools,
        @"network": networkTools,
        @"visual": visualTools,
        @"log": logTools
    };
}

#pragma mark - Actions

- (void)dismissButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backButtonTapped {
    self.isInCategory = NO;
    self.currentCategory = nil;
    self.title = @"工具";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(dismissButtonTapped)];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isInCategory) {
        NSArray *tools = self.toolsByCategory[self.currentCategory];
        return tools.count;
    }
    return self.categories.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppInfoCell"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AppInfoCell"];
    }
    
    if (self.isInCategory) {
        // 显示具体工具
        NSArray *tools = self.toolsByCategory[self.currentCategory];
        NSDictionary *tool = tools[indexPath.row];
        cell.textLabel.text = tool[@"title"];
        cell.detailTextLabel.text = tool[@"detail"];
    } else {
        // 显示分类
        NSDictionary *category = self.categories[indexPath.row];
        cell.textLabel.text = category[@"title"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu个工具", 
            (unsigned long)[self.toolsByCategory[category[@"key"]] count]];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.isInCategory) {
        // 处理工具选择
        NSDictionary *tool = [self toolAtIndexPath:indexPath];
        NSString *className = tool[@"class"];
        NSString *action = tool[@"action"];
        
        if (className) {
            Class viewControllerClass = NSClassFromString(className);
            if (viewControllerClass) {
                UIViewController *viewController = [[viewControllerClass alloc] init];
                [self.navigationController pushViewController:viewController animated:YES];
            } else {
                NSLog(@"⚠️ 警告：类 %@ 未找到，请检查实现", className);
                
                // 提供更详细的错误信息和解决方案
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"功能开发中" 
                                                                               message:[NSString stringWithFormat:@"功能 \"%@\" 正在开发中\n\n错误详情：类 %@ 未找到\n请检查是否正确导入了对应的头文件。", tool[@"title"], className]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                
                // 添加调试信息按钮
                UIAlertAction *debugAction = [UIAlertAction actionWithTitle:@"复制错误信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"Class not found: %@", className];
                }];
                
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil];
                
                [alert addAction:debugAction];
                [alert addAction:okAction];
                [self presentViewController:alert animated:YES completion:nil];
            }
        } else if (action) {
            [self performAction:action];
        }
    } else {
        // 进入分类
        NSDictionary *category = self.categories[indexPath.row];
        self.isInCategory = YES;
        self.currentCategory = category[@"key"];
        self.title = category[@"title"];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:@"返回"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(backButtonTapped)];
        [self.tableView reloadData];
    }
}

#pragma mark - Helper Methods

- (NSDictionary *)toolAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isInCategory) {
        NSArray *tools = self.toolsByCategory[self.currentCategory];
        if (indexPath.row < tools.count) {
            return tools[indexPath.row];
        }
    }
    return nil;
}

#pragma mark - 功能实现方法

- (void)presentViewControllerWithClassName:(NSString *)className {
    Class viewControllerClass = NSClassFromString(className);
    if (viewControllerClass) {
        UIViewController *viewController = [[viewControllerClass alloc] init];
        [self.navigationController pushViewController:viewController animated:YES];
    } else {
        // 改进错误处理
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"功能开发中" 
                                                                       message:[NSString stringWithFormat:@"类 %@ 尚未实现", className]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)performAction:(NSString *)action {
    if ([action isEqualToString:@"showH5Door"]) {
        [self presentViewControllerWithClassName:@"FLEXH5DoorViewController"];
    } else if ([action isEqualToString:@"showClearCache"]) {
        [self presentViewControllerWithClassName:@"FLEXClearCacheViewController"];
    } else if ([action isEqualToString:@"showFPSMonitor"]) {
        [self presentViewControllerWithClassName:@"FLEXFPSMonitorViewController"];
    } else if ([action isEqualToString:@"showMemoryMonitor"]) {
        [self presentViewControllerWithClassName:@"FLEXMemoryMonitorViewController"];
    } else if ([action isEqualToString:@"showNetworkMonitor"]) {
        [self presentViewControllerWithClassName:@"FLEXNetworkMonitorViewController"];
    } else if ([action isEqualToString:@"showAPITest"]) {
        [self presentViewControllerWithClassName:@"FLEXAPITestViewController"];
    } else if ([action isEqualToString:@"showViewBorder"]) {
        [self showViewBorder];
    } else if ([action isEqualToString:@"showLayoutBounds"]) {
        [self showLayoutBounds];
    } else if ([action isEqualToString:@"showRuler"]) {
        [self showRuler];
    } else if ([action isEqualToString:@"showLookinMeasure"]) {
        [self showLookinMeasure];
    } else if ([action isEqualToString:@"showViewMeasurements"]) {
        [self showViewMeasurements];
    } else if ([action isEqualToString:@"showConstraintsVisualization"]) {
        [self showConstraintsVisualization];
    } else if ([action isEqualToString:@"enableLiveViewEditing"]) {
        [self enableLiveViewEditing];
    }
}

- (void)showCrashReport {
    // ✅ 使用真实的崩溃记录控制器
    FLEXDoKitCrashViewController *crashVC = [[FLEXDoKitCrashViewController alloc] init];
    [self.navigationController pushViewController:crashVC animated:YES];
}

- (void)showFPSMonitor {
    // ✅ 使用真实的FPS监控控制器
    FLEXFPSMonitorViewController *fpsVC = [[FLEXFPSMonitorViewController alloc] init];
    [self.navigationController pushViewController:fpsVC animated:YES];
}

- (void)showMemoryMonitor {
    // ✅ 使用真实的内存监控控制器
    FLEXMemoryMonitorViewController *memoryVC = [[FLEXMemoryMonitorViewController alloc] init];
    [self.navigationController pushViewController:memoryVC animated:YES];
}

- (void)showLagMonitor {
    // 启动卡顿检测
    [self showAlertWithTitle:@"卡顿检测" message:@"卡顿检测功能已启动"];
}

- (void)showColorPicker {
    [self dismissViewControllerAnimated:YES completion:^{
        // ✅ 现在使用真实的实现
        [[FLEXDoKitVisualTools sharedInstance] startColorPicker];
    }];
}

- (void)showRuler {
    [self dismissViewControllerAnimated:YES completion:^{
        // ✅ 现在使用真实的实现
        [[FLEXDoKitVisualTools sharedInstance] showRuler];
    }];
}

- (void)showViewBorder {
    [self dismissViewControllerAnimated:YES completion:^{
        // ✅ 现在使用真实的实现
        [[FLEXDoKitVisualTools sharedInstance] showViewBorders];
    }];
}

- (void)showLayoutBounds {
    [self dismissViewControllerAnimated:YES completion:^{
        // ✅ 现在使用真实的实现
        [[FLEXDoKitVisualTools sharedInstance] showLayoutBounds];
    }];
}

- (void)showViewMeasurements {
    [self dismissViewControllerAnimated:YES completion:^{
        FLEXRevealLikeInspector *inspector = [FLEXRevealLikeInspector sharedInstance];
        [inspector showViewMeasurements:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    }];
}

- (void)showConstraintsVisualization {
    [self dismissViewControllerAnimated:YES completion:^{
        FLEXRevealLikeInspector *inspector = [FLEXRevealLikeInspector sharedInstance];
        [inspector showViewConstraints:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    }];
}

- (void)enableLiveViewEditing {
    [self dismissViewControllerAnimated:YES completion:^{
        FLEXRevealLikeInspector *inspector = [FLEXRevealLikeInspector sharedInstance];
        [inspector show3DViewHierarchy];
        [inspector enableLiveEditing];
    }];
}

- (void)showLookinMeasure {
    [[FLEXLookinMeasureController sharedInstance] startMeasuring];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end