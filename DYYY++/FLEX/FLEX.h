//
//  FLEX.h
//  FLEX
//
//  Created by Eric Horacek on 7/18/15.
//  Modified by Tanner Bennett on 3/12/20.
//  Copyright (c) 2025 for pxx917144686 FLEX Team. All rights reserved.
//

// === 核心架构 ===
#import "FLEXManager.h"
#import "FLEXManager+Extensibility.h"
#import "FLEXManager+Networking.h"
#import "FLEXManager+DoKitExtensions.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性

#import "FLEXExplorerToolbar.h"
#import "FLEXExplorerToolbarItem.h"
#import "FLEXGlobalsEntry.h"

#import "FLEX-Core.h"
#import "FLEX-Runtime.h"
#import "FLEX-Categories.h"
#import "FLEX-ObjectExploring.h"

#import "FLEXMacros.h"
#import "FLEXAlert.h"
#import "FLEXResources.h"

// === DoKit 核心组件 ===
#import "FLEXDoKitManager.h"
#import "FLEXDoKitPerformanceMonitor.h"
#import "FLEXDoKitNetworkMonitor.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXDoKitCrashMonitor.h"
#import "FLEXDoKitLogViewer.h"
#import "FLEXDoKitLogEntry.h"  // ✅ 类型定义
#import "FLEXDoKitMemoryLeakDetector.h"

// === 主控制器 ===
#import "FLEXBugViewController.h"

// === 性能监控 ===
#import "FLEXPerformanceViewController.h"
#import "FLEXMemoryMonitorViewController.h"
#import "FLEXFPSMonitorViewController.h"
#import "FLEXDoKitCPUViewController.h"
#import "FLEXDoKitLagViewController.h"
#import "FLEXMemoryLeakDetectorViewController.h"
#import "FLEXDoKitCrashViewController.h"

// === 网络工具 ===
#import "FLEXNetworkMonitorViewController.h"
#import "FLEXAPITestViewController.h"
#import "FLEXDoKitMockViewController.h"
#import "FLEXDoKitNetworkViewController.h"
#import "FLEXDoKitNetworkHistoryViewController.h"
#import "FLEXDoKitWeakNetworkViewController.h"
#import "FLEXNetworkMITMViewController.h"

// === 视觉工具 ===
#import "FLEXDoKitColorPickerViewController.h"
#import "FLEXDoKitComponentViewController.h"
#import "FLEXDoKitVisualToolsViewController.h" 

// === 日志工具 ===
#import "FLEXDoKitLogViewController.h"
#import "FLEXDoKitLogFilterViewController.h"

// === 常用工具 ===
#import "FLEXDoKitAppInfoViewController.h"
#import "FLEXDoKitSystemInfoViewController.h"
#import "FLEXDoKitCleanViewController.h"
#import "FLEXDoKitUserDefaultsViewController.h"
#import "FLEXFileBrowserController.h"
#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXDoKitH5ViewController.h"
#import "FLEXDoKitDatabaseViewController.h"

// === Reveal集成 ===
#import "FLEXRevealLikeInspector.h"
#import "FLEXRevealInspectorViewController.h"

// === Lookin集成 ===
#import "FLEXLookinInspector.h"
#import "FLEXLookinHierarchyViewController.h"
#import "FLEXLookinComparisonViewController.h"
#import "FLEXLookinMeasureController.h"
#import "FLEXLookinMeasureResultView.h"
#import "FLEXLookinDisplayItem.h"
#import "FLEXLookinPreviewController.h"
#import "FLEXLookinMeasureViewController.h"

// === 运行时分析 ===
#import "FLEXRuntimeClient.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXHookDetector.h"

// === 错误修复工具 ===
#import "FLEXSystemLogViewController.h"
#import "FLEXHierarchyTableViewController.h"

// === 系统分析 ===
#import "FLEXSystemAnalyzerViewController.h"
