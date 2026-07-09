//
//  FLEX.h
//  FLEX
//
//  Created by Eric Horacek on 7/18/15.
//  Modified by Tanner Bennett on 3/12/20.
//  Copyright (c) 2025 for pxx917144686 FLEX Team. All rights reserved.
//

// === 核心架构 ===
#import "DYYYFLEXManager.h"
#import "DYYYFLEXManager+Extensibility.h"
#import "DYYYFLEXManager+Networking.h"
#import "DYYYFLEXManager+DoKitExtensions.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性

#import "DYYYFLEXExplorerToolbar.h"
#import "DYYYFLEXExplorerToolbarItem.h"
#import "DYYYFLEXGlobalsEntry.h"

#import "FLEX-Core.h"
#import "FLEX-Runtime.h"
#import "FLEX-Categories.h"
#import "FLEX-ObjectExploring.h"

#import "FLEXMacros.h"
#import "DYYYFLEXAlert.h"
#import "DYYYFLEXResources.h"

// === DoKit 核心组件 ===
#import "DYYYFLEXDoKitManager.h"
#import "DYYYFLEXDoKitPerformanceMonitor.h"
#import "DYYYFLEXDoKitNetworkMonitor.h"
#import "DYYYFLEXDoKitVisualTools.h"
#import "DYYYFLEXDoKitCrashMonitor.h"
#import "DYYYFLEXDoKitLogViewer.h"
#import "DYYYFLEXDoKitLogEntry.h"  // ✅ 类型定义
#import "DYYYFLEXDoKitMemoryLeakDetector.h"

// === 主控制器 ===
//#import "FLEXBugViewController.h"

// === 性能监控 ===
#import "DYYYFLEXPerformanceViewController.h"
#import "DYYYFLEXMemoryMonitorViewController.h"
#import "DYYYFLEXFPSMonitorViewController.h"
#import "DYYYFLEXDoKitCPUViewController.h"
#import "DYYYFLEXDoKitLagViewController.h"
#import "DYYYFLEXMemoryLeakDetectorViewController.h"
#import "DYYYFLEXDoKitCrashViewController.h"

// === 网络工具 ===
#import "DYYYFLEXNetworkMonitorViewController.h"
#import "DYYYFLEXAPITestViewController.h"
#import "DYYYFLEXDoKitMockViewController.h"
#import "DYYYFLEXDoKitNetworkViewController.h"
#import "DYYYFLEXDoKitNetworkHistoryViewController.h"
#import "DYYYFLEXDoKitWeakNetworkViewController.h"
#import "DYYYFLEXNetworkMITMViewController.h"

// === 视觉工具 ===
#import "DYYYFLEXDoKitColorPickerViewController.h"
#import "DYYYFLEXDoKitComponentViewController.h"
#import "DYYYFLEXDoKitVisualToolsViewController.h" 

// === 日志工具 ===
#import "DYYYFLEXDoKitLogViewController.h"
#import "DYYYFLEXDoKitLogFilterViewController.h"

// === 常用工具 ===
#import "DYYYFLEXDoKitAppInfoViewController.h"
#import "DYYYFLEXDoKitSystemInfoViewController.h"
#import "DYYYFLEXDoKitCleanViewController.h"
#import "DYYYFLEXDoKitUserDefaultsViewController.h"
#import "DYYYFLEXFileBrowserController.h"
#import "DYYYFLEXDoKitFileBrowserViewController.h"
#import "DYYYFLEXDoKitH5ViewController.h"
#import "DYYYFLEXDoKitDatabaseViewController.h"

// === Reveal集成 ===
#import "DYYYFLEXRevealLikeInspector.h"
#import "DYYYFLEXRevealInspectorViewController.h"

// === Lookin集成 ===
#import "DYYYFLEXLookinInspector.h"
#import "DYYYFLEXLookinHierarchyViewController.h"
#import "DYYYFLEXLookinComparisonViewController.h"
#import "DYYYFLEXLookinMeasureController.h"
#import "DYYYFLEXLookinMeasureResultView.h"
#import "DYYYFLEXLookinDisplayItem.h"
#import "DYYYFLEXLookinPreviewController.h"
#import "DYYYFLEXLookinMeasureViewController.h"

// === 运行时分析 ===
#import "DYYYFLEXRuntimeClient.h"
#import "DYYYFLEXRuntimeClient+RuntimeBrowser.h"
#import "DYYYFLEXHookDetector.h"

// === 错误修复工具 ===
#import "DYYYFLEXSystemLogViewController.h"
#import "DYYYFLEXHierarchyTableViewController.h"

// === 系统分析 ===
#import "DYYYFLEXSystemAnalyzerViewController.h"
