//
//  FLEXManager+DoKitExtensions.m
//  FLEX
//
//  DoKit 功能增强扩展实现
//

#import "FLEXManager+DoKitExtensions.h"
#import "FLEXManager+Extensibility.h"
#import "FLEXBugViewController.h"
#import "FLEXDoKitManager.h"
#import "FLEXDoKitPerformanceMonitor.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXDoKitVisualTools.h"

#import "FLEXDoKitCPUViewController.h"
#import "FLEXMemoryMonitorViewController.h"
#import "FLEXDoKitLagViewController.h"
#import "FLEXDoKitNetworkViewController.h"
#import "FLEXDoKitMockViewController.h"
#import "FLEXDoKitWeakNetworkViewController.h"
#import "FLEXDoKitColorPickerViewController.h"
#import "FLEXDoKitVisualToolsViewController.h"
#import "FLEXRevealInspectorViewController.h"
#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXDoKitDatabaseViewController.h"
#import "FLEXDoKitUserDefaultsViewController.h"
#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitCrashViewController.h"
#import "FLEXDoKitCrashMonitor.h"
#import "FLEXDoKitMemoryLeakDetector.h"
#import "FLEXMemoryLeakDetectorViewController.h" 
#import "FLEXLookinMeasureController.h"
#import "FLEXLookinPreviewController.h"
#import "FLEXLookinHierarchyViewController.h"

@implementation FLEXManager (DoKitExtensions)

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
                       if ([[FLEXDoKitPerformanceMonitor sharedInstance] respondsToSelector:@selector(startCPUMonitoring)]) {
                           [[FLEXDoKitPerformanceMonitor sharedInstance] startCPUMonitoring];
                       } else {
                           NSLog(@"⚠️ 警告：FLEXDoKitPerformanceMonitor 不支持 startCPUMonitoring 方法");
                       }
                       return [FLEXDoKitCPUViewController new];
                   }];
    
    // 内存监控
    [self registerGlobalEntryWithName:@"内存使用监控"
                   objectFutureBlock:^id{
                       return [FLEXMemoryMonitorViewController new];
                   }];
    
    // 卡顿检测 - ✅ 修复方法名
    [self registerGlobalEntryWithName:@"卡顿检测"
                   objectFutureBlock:^id{
                       if ([[FLEXDoKitPerformanceMonitor sharedInstance] respondsToSelector:@selector(startLagDetection)]) {
                           [[FLEXDoKitPerformanceMonitor sharedInstance] startLagDetection];
                       } else {
                           NSLog(@"⚠️ 警告：FLEXDoKitPerformanceMonitor 不支持 startLagDetection 方法");
                       }
                       return [FLEXDoKitLagViewController new];
                   }];
}

- (void)registerNetworkDebugging {
    // 网络监控
    [self registerGlobalEntryWithName:@"网络请求监控"
                   objectFutureBlock:^id{
                       [[FLEXDoKitNetworkMonitor sharedInstance] startNetworkMonitoring];
                       return [FLEXDoKitNetworkViewController new];
                   }];
    
    // Mock数据
    [self registerGlobalEntryWithName:@"Mock数据管理"
                   objectFutureBlock:^id{
                       return [FLEXDoKitMockViewController new];
                   }];
    
    // 弱网模拟
    [self registerGlobalEntryWithName:@"弱网环境模拟"
                   objectFutureBlock:^id{
                       return [FLEXDoKitWeakNetworkViewController new];
                   }];
}

- (void)registerUIDebugging {
    // 颜色吸管
    [self registerGlobalEntryWithName:@"颜色吸管工具"
                   objectFutureBlock:^id{
                       [[FLEXDoKitVisualTools sharedInstance] startColorPicker];
                       return [FLEXDoKitColorPickerViewController new];
                   }];
    
    // 视觉工具套件
    [self registerGlobalEntryWithName:@"视觉调试工具"
                   objectFutureBlock:^id{
                       return [FLEXDoKitVisualToolsViewController new];
                   }];
    
    // ✅ 修复：使用正确的方法名（不带category参数）
    [self registerGlobalEntryWithName:@"3D视图检查器"
                   objectFutureBlock:^id{
                       return [FLEXRevealInspectorViewController new];
                   }];
}

- (void)registerCommonTools {
    // 沙盒浏览增强
    [self registerGlobalEntryWithName:@"沙盒文件浏览器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitFileBrowserViewController new];
                   }];
    
    // 数据库查看器
    [self registerGlobalEntryWithName:@"数据库查看器"
                   objectFutureBlock:^id{
                       return [FLEXDoKitDatabaseViewController new];
                   }];
    
    // UserDefaults编辑器
    [self registerGlobalEntryWithName:@"UserDefaults编辑"
                   objectFutureBlock:^id{
                       return [FLEXDoKitUserDefaultsViewController new];
                   }];
}

- (void)registerMemoryDebugging {
    // 内存泄漏检测
    [self registerGlobalEntryWithName:@"内存泄漏检测"
                   objectFutureBlock:^id{
                       [[FLEXDoKitMemoryLeakDetector sharedInstance] startLeakDetection];
                       return [FLEXMemoryLeakDetectorViewController new];
                   }];
}

- (void)registerAdvancedDebugging {
    // 实时日志查看器
    [self registerGlobalEntryWithName:@"实时日志查看"
                   objectFutureBlock:^id{
                       return [FLEXDoKitLogViewController new];
                   }];
    
    // Crash日志分析
    [self registerGlobalEntryWithName:@"Crash日志分析"
                   objectFutureBlock:^id{
                       return [FLEXDoKitCrashViewController new];
                   }];
    
    // 崩溃监控
    [self registerGlobalEntryWithName:@"崩溃监控"
                   objectFutureBlock:^id{
                       [[FLEXDoKitCrashMonitor sharedInstance] startCrashMonitoring];
                       return [FLEXDoKitCrashViewController new];
                   }];
    
    // 视觉工具集合
    [self registerGlobalEntryWithName:@"视觉调试工具集"
                   objectFutureBlock:^id{
                       return [FLEXDoKitVisualToolsViewController new];
                   }];
}

- (void)registerLookinEnhancements {
    // 注册Lookin测量工具
    [self registerGlobalEntryWithName:@"Lookin测量工具"
                   objectFutureBlock:^id{
                       [[FLEXLookinMeasureController sharedInstance] startMeasuring];
                       return nil;
                   }];
    
    // 注册Lookin 3D预览
    [self registerGlobalEntryWithName:@"Lookin 3D预览"
                   objectFutureBlock:^id{
                       return [[FLEXLookinPreviewController alloc] init];
                   }];
    
    // 注册Lookin层次分析
    [self registerGlobalEntryWithName:@"Lookin层次分析"
                   objectFutureBlock:^id{
                       return [[FLEXLookinHierarchyViewController alloc] init];
                   }];
}

@end