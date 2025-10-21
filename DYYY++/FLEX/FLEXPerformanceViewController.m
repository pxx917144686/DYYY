//
//  FLEXPerformanceViewController.m
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXPerformanceViewController.h"
#import "FLEXPerformanceMonitor.h"
#import "FLEXUtility.h"

@interface FLEXPerformanceViewController ()

@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) UILabel *cpuLabel;
@property (nonatomic, strong) UILabel *memoryLabel;
@property (nonatomic, strong) UILabel *networkLabel;

@property (nonatomic, strong) NSTimer *updateTimer;

@end

@implementation FLEXPerformanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"性能监控";
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self setupUI];
    
    // 启动性能监控
    [[FLEXPerformanceMonitor sharedInstance] startAllMonitoring];
    
    // 定时更新UI
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                       target:self 
                                                     selector:@selector(updateUI) 
                                                     userInfo:nil 
                                                      repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 停止定时器
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    // 如果视图控制器被移除，停止监控
    if ([self isMovingFromParentViewController] || [self isBeingDismissed]) {
        [[FLEXPerformanceMonitor sharedInstance] stopAllMonitoring];
    }
}

- (void)setupUI {
    CGFloat padding = 20;
    CGFloat y = 100;
    CGFloat width = self.view.bounds.size.width - 2 * padding;
    CGFloat height = 30;
    
    // FPS 标签
    self.fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, height)];
    self.fpsLabel.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:self.fpsLabel];
    y += height + 20;
    
    // CPU 标签
    self.cpuLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, height)];
    self.cpuLabel.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:self.cpuLabel];
    y += height + 20;
    
    // 内存标签
    self.memoryLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, height)];
    self.memoryLabel.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:self.memoryLabel];
    y += height + 20;
    
    // 网络标签
    self.networkLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, height)];
    self.networkLabel.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:self.networkLabel];
}

- (void)updateUI {
    FLEXPerformanceMonitor *monitor = [FLEXPerformanceMonitor sharedInstance];
    
    // 更新 FPS
    NSString *fpsString = [NSString stringWithFormat:@"FPS: %.1f", monitor.currentFPS];
    self.fpsLabel.text = fpsString;
    
    // 更新 CPU
    NSString *cpuString = [NSString stringWithFormat:@"CPU: %.1f%%", monitor.cpuUsage];
    self.cpuLabel.text = cpuString;
    
    // 更新内存
    NSString *memoryString = [NSString stringWithFormat:@"内存: %.1f MB", monitor.memoryUsage];
    self.memoryLabel.text = memoryString;
    
    // 更新网络
    NSString *networkString = [NSString stringWithFormat:@"网络: ↑%.1f KB/s ↓%.1f KB/s", 
                             monitor.uploadFlowBytes / 1024.0, 
                             monitor.downloadFlowBytes / 1024.0];
    self.networkLabel.text = networkString;
}

@end