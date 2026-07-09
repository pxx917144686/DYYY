//
//  DYYYFLEXManager+DoKitExtensions.m
//  FLEX
//
//  DoKit 功能增强扩展实现
//

#import "DYYYFLEXManager+DoKitExtensions.h"
#import "DYYYFLEXManager+Extensibility.h"
#import "DYYYFLEXDoKitManager.h"
#import "DYYYFLEXDoKitPerformanceMonitor.h"
#import "DYYYFLEXDoKitNetworkMonitor.h"
#import "DYYYFLEXDoKitVisualTools.h"

#import "DYYYFLEXDoKitCPUViewController.h"
#import "DYYYFLEXMemoryMonitorViewController.h"
#import "DYYYFLEXDoKitLagViewController.h"
#import "DYYYFLEXDoKitNetworkViewController.h"
#import "DYYYFLEXDoKitMockViewController.h"
#import "DYYYFLEXDoKitWeakNetworkViewController.h"
#import "DYYYFLEXDoKitColorPickerViewController.h"
#import "DYYYFLEXDoKitVisualToolsViewController.h"
#import "DYYYFLEXRevealInspectorViewController.h"
#import "DYYYFLEXDoKitFileBrowserViewController.h"
#import "DYYYFLEXDoKitDatabaseViewController.h"
#import "DYYYFLEXDoKitUserDefaultsViewController.h"
#import "DYYYFLEXDoKitLogViewController.h"
#import "DYYYFLEXDoKitCrashViewController.h"
#import "DYYYFLEXDoKitCrashMonitor.h"
#import "DYYYFLEXDoKitMemoryLeakDetector.h"
#import "DYYYFLEXMemoryLeakDetectorViewController.h" 
#import "DYYYFLEXLookinMeasureController.h"
#import "DYYYFLEXLookinPreviewController.h"
#import "DYYYFLEXLookinHierarchyViewController.h"

@implementation DYYYFLEXManager (DoKitExtensions)

- (void)registerDoKitEnhancements {
    [self registerPerformanceMonitoring];
    [self registerNetworkDebugging];
    [self registerUIDebugging];
    [self registerMemoryDebugging];
    [self registerAdvancedDebugging];
    [self registerLookinEnhancements];
    
    NSLog(@"DoKit + Lookin 完整功能已注册完成");
}

- (void)registerPerformanceMonitoring {
    // CPU监控
    [self registerGlobalEntryWithName:@"CPU使用率监控"
                   objectFutureBlock:^id{
                       // ✅ respondsToSelector检查
                       if ([[DYYYFLEXDoKitPerformanceMonitor sharedInstance] respondsToSelector:@selector(startCPUMonitoring)]) {
                           [[DYYYFLEXDoKitPerformanceMonitor sharedInstance] startCPUMonitoring];
                       } else {
                           NSLog(@"⚠️ 警告：DYYYFLEXDoKitPerformanceMonitor 不支持 startCPUMonitoring 方法");
                       }
                       return [DYYYFLEXDoKitCPUViewController new];
                   }];
    
    // 内存监控
    [self registerGlobalEntryWithName:@"内存使用监控"
                   objectFutureBlock:^id{
                       return [DYYYFLEXMemoryMonitorViewController new];
                   }];
    
    // 卡顿检测 - ✅ 修复方法名
    [self registerGlobalEntryWithName:@"卡顿检测"
                   objectFutureBlock:^id{
                       if ([[DYYYFLEXDoKitPerformanceMonitor sharedInstance] respondsToSelector:@selector(startLagDetection)]) {
                           [[DYYYFLEXDoKitPerformanceMonitor sharedInstance] startLagDetection];
                       } else {
                           NSLog(@"⚠️ 警告：DYYYFLEXDoKitPerformanceMonitor 不支持 startLagDetection 方法");
                       }
                       return [DYYYFLEXDoKitLagViewController new];
                   }];
}

- (void)registerNetworkDebugging {
    // 网络监控
    [self registerGlobalEntryWithName:@"网络请求监控"
                   objectFutureBlock:^id{
                       [[DYYYFLEXDoKitNetworkMonitor sharedInstance] startNetworkMonitoring];
                       return [DYYYFLEXDoKitNetworkViewController new];
                   }];
    
    // Mock数据
    [self registerGlobalEntryWithName:@"Mock数据管理"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitMockViewController new];
                   }];
    
    // 弱网模拟
    [self registerGlobalEntryWithName:@"弱网环境模拟"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitWeakNetworkViewController new];
                   }];
}

- (void)registerUIDebugging {
    // 颜色吸管
    [self registerGlobalEntryWithName:@"颜色吸管工具"
                   objectFutureBlock:^id{
                       [[DYYYFLEXDoKitVisualTools sharedInstance] startColorPicker];
                       return [DYYYFLEXDoKitColorPickerViewController new];
                   }];
    
    // 视觉工具套件
    [self registerGlobalEntryWithName:@"视觉调试工具"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitVisualToolsViewController new];
                   }];
    
    // ✅ 修复：使用正确的方法名（不带category参数）
    [self registerGlobalEntryWithName:@"3D视图检查器"
                   objectFutureBlock:^id{
                       return [DYYYFLEXRevealInspectorViewController new];
                   }];
}

- (void)registerCommonTools {
    // 沙盒浏览增强
    [self registerGlobalEntryWithName:@"沙盒文件浏览器"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitFileBrowserViewController new];
                   }];
    
    // 数据库查看器
    [self registerGlobalEntryWithName:@"数据库查看器"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitDatabaseViewController new];
                   }];
    
    // UserDefaults编辑器
    [self registerGlobalEntryWithName:@"UserDefaults编辑"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitUserDefaultsViewController new];
                   }];
}

- (void)registerMemoryDebugging {
    // 内存泄漏检测
    [self registerGlobalEntryWithName:@"内存泄漏检测"
                   objectFutureBlock:^id{
                       [[DYYYFLEXDoKitMemoryLeakDetector sharedInstance] startLeakDetection];
                       return [DYYYFLEXMemoryLeakDetectorViewController new];
                   }];
}

- (void)registerAdvancedDebugging {
    // 实时日志查看器
    [self registerGlobalEntryWithName:@"实时日志查看"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitLogViewController new];
                   }];
    
    // Crash日志分析
    [self registerGlobalEntryWithName:@"Crash日志分析"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitCrashViewController new];
                   }];
    
    // 崩溃监控
    [self registerGlobalEntryWithName:@"崩溃监控"
                   objectFutureBlock:^id{
                       [[DYYYFLEXDoKitCrashMonitor sharedInstance] startCrashMonitoring];
                       return [DYYYFLEXDoKitCrashViewController new];
                   }];
    
    // 视觉工具集合
    [self registerGlobalEntryWithName:@"视觉调试工具集"
                   objectFutureBlock:^id{
                       return [DYYYFLEXDoKitVisualToolsViewController new];
                   }];
}

- (void)registerLookinEnhancements {
    // 注册Lookin测量工具
    [self registerGlobalEntryWithName:@"Lookin测量工具"
                   objectFutureBlock:^id{
                       [[DYYYFLEXLookinMeasureController sharedInstance] startMeasuring];
                       return nil;
                   }];
    
    // 注册Lookin 3D预览
    [self registerGlobalEntryWithName:@"Lookin 3D预览"
                   objectFutureBlock:^id{
                       return [[DYYYFLEXLookinPreviewController alloc] init];
                   }];
    
    // 注册Lookin层次分析
    [self registerGlobalEntryWithName:@"Lookin层次分析"
                   objectFutureBlock:^id{
                       return [[DYYYFLEXLookinHierarchyViewController alloc] init];
                   }];
}

@end