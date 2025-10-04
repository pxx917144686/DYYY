import Foundation
import SwiftUI
import UIKit

// 在 keyWindow 根视图全局注入 SwiftUI Hosting（仅 iOS26 + 开关为真，且防重复）。
@objc public class DYYYSwiftUIBridge: NSObject {
    @objc public static func makeHostingController() -> UIViewController? {
        if #available(iOS 26.0, *) {
            let view = LiquidGlassBridgeView()
            let host = UIHostingController(rootView: view)
            host.view.backgroundColor = .clear
            return host
        } else {
            return nil
        }
    }
    
    @objc public static func makeTabBarHostingController() -> UIViewController? {
        if #available(iOS 26.0, *) {
            let view = TabBarLiquidGlassView()
            let host = UIHostingController(rootView: view)
            host.view.backgroundColor = .clear
            return host
        } else {
            return nil
        }
    }
    
    @objc public static func makeEnhancedHostingController() -> UIViewController? {
        if #available(iOS 26.0, *) {
            let view = EnhancedLiquidGlassView()
            let host = UIHostingController(rootView: view)
            host.view.backgroundColor = .clear
            return host
        } else {
            return nil
        }
    }
}

// 基础 Liquid Glass 桥接视图 - 是按照 Apple 官方指导
@available(iOS 26.0, *)
struct LiquidGlassBridgeView: View {
    @AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
    private var liquidGlassEnabled: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if liquidGlassEnabled {
            ZStack {
                // 使用 Apple 官方推荐的 .background(.material) 方法
                Rectangle()
                    .background(.ultraThinMaterial) // 官方推荐：超薄材质
                    .opacity(0.9)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                // 动态响应层 - 根据系统主题调整
                Rectangle()
                    .background(colorScheme == .dark ? .thickMaterial : .thinMaterial)
                    .opacity(0.4)
                    .offset(y: -1)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                // 顶部高光效果
                Rectangle()
                    .background(.regularMaterial)
                    .opacity(0.3)
                    .frame(height: 0.5)
                    .offset(y: -20)
                    .blendMode(.overlay)
            }
            .compositingGroup() // 优化渲染性能
        } else {
            Color.clear
        }
    }
}

// 标签栏 Liquid Glass 效果 - 按照 Apple 官方指导
@available(iOS 26.0, *)
struct TabBarLiquidGlassView: View {
    @AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
    private var liquidGlassEnabled: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 抖音界面状态信息
    @State private var currentViewController: String = ""
    @State private var selectedTabIndex: Int = -1
    @State private var tabBarButtons: [String] = []
    @State private var isVideoPlaying: Bool = false
    @State private var currentTheme: String = "light"
    @State private var renderQuality: Double = 1.0
    
    // DYYY 功能状态
    @State private var isClearButtonActive: Bool = false
    @State private var isSpeedButtonActive: Bool = false
    @State private var currentPlaybackSpeed: Double = 1.0
    @State private var hiddenElementsCount: Int = 0
    
    var body: some View {
        if liquidGlassEnabled {
            ZStack {
                // 使用 Apple 官方推荐的 .background(.material) 方法
                Rectangle()
                    .background(.ultraThinMaterial) // 基础材质
                    .opacity(getBaseOpacity() * renderQuality)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                // 动态响应层 - 根据标签栏状态
                if selectedTabIndex >= 0 && selectedTabIndex < tabBarButtons.count {
                    Rectangle()
                        .background(.thinMaterial)
                        .opacity(0.4)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // 视频播放状态响应层
                if isVideoPlaying {
                    Rectangle()
                        .background(.regularMaterial)
                        .opacity(0.3)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // 主题适配层 - 使用系统主题响应
                Rectangle()
                    .background(colorScheme == .dark ? .thickMaterial : .ultraThinMaterial)
                    .opacity(0.2)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                // DYYY 清屏功能响应层
                if isClearButtonActive {
                    Rectangle()
                        .background(.ultraThinMaterial)
                        .opacity(0.15 * Double(hiddenElementsCount))
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // DYYY 倍速功能响应层
                if isSpeedButtonActive && currentPlaybackSpeed != 1.0 {
                    Rectangle()
                        .background(.thinMaterial)
                        .opacity(0.1 * currentPlaybackSpeed)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
            }
            .compositingGroup() // 优化渲染性能
            .onAppear {
                updateDouyinInterfaceInfo()
                adjustRenderQuality()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DYYYInterfaceStateChanged"))) { _ in
                updateDouyinInterfaceInfo()
            }
        } else {
            Color.clear
        }
    }
    
    private func getBaseOpacity() -> Double {
        // 根据当前状态动态调整基础透明度
        var opacity: Double = 0.8
        
        if isVideoPlaying {
            opacity *= 0.7 // 视频播放时降低透明度
        }
        
        if currentTheme == "dark" {
            opacity *= 1.2 // 暗色主题时增加透明度
        }
        
        return min(opacity, 1.0)
    }
    
    private func updateDouyinInterfaceInfo() {
        // 从 UserDefaults 读取抖音界面信息
        let userDefaults = UserDefaults.standard
        
        if let interfaceInfo = userDefaults.dictionary(forKey: "DYYYInterfaceInfo") {
            currentViewController = interfaceInfo["currentViewController"] as? String ?? ""
            selectedTabIndex = interfaceInfo["selectedTabIndex"] as? Int ?? -1
            tabBarButtons = interfaceInfo["tabBarButtons"] as? [String] ?? []
            isVideoPlaying = interfaceInfo["isVideoPlaying"] as? Bool ?? false
            currentTheme = interfaceInfo["currentTheme"] as? String ?? "light"
            
            // DYYY 功能状态
            isClearButtonActive = interfaceInfo["isClearButtonActive"] as? Bool ?? false
            isSpeedButtonActive = interfaceInfo["isSpeedButtonActive"] as? Bool ?? false
            currentPlaybackSpeed = interfaceInfo["currentPlaybackSpeed"] as? Double ?? 1.0
            hiddenElementsCount = interfaceInfo["hiddenElementsCount"] as? Int ?? 0
        }
    }
    
    private func adjustRenderQuality() {
        // 根据设备性能调整渲染质量
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(totalMemory) / (1024 * 1024 * 1024)
        
        if memoryGB >= 6.0 {
            renderQuality = 1.0 // 高性能设备
        } else if memoryGB >= 4.0 {
            renderQuality = 0.8 // 中等性能设备
        } else {
            renderQuality = 0.6 // 低性能设备
        }
    }
}

// 增强版 Liquid Glass 效果 - 按照 Apple 官方指导
@available(iOS 26.0, *)
struct EnhancedLiquidGlassView: View {
    @AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
    private var liquidGlassEnabled: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 抖音界面状态信息
    @State private var currentViewController: String = ""
    @State private var selectedTabIndex: Int = -1
    @State private var tabBarButtons: [String] = []
    @State private var isVideoPlaying: Bool = false
    @State private var currentTheme: String = "light"
    @State private var renderQuality: Double = 1.0
    
    // 精确的界面元素状态
    @State private var tabBarState: [String: Any] = [:]
    @State private var videoState: [String: Any] = [:]
    @State private var uiElements: [String: Any] = [:]
    @State private var screenScale: Double = 1.0
    
    // DYYY 功能状态集成
    @State private var isClearButtonActive: Bool = false
    @State private var isSpeedButtonActive: Bool = false
    @State private var currentPlaybackSpeed: Double = 1.0
    @State private var hiddenElementsCount: Int = 0
    
    var body: some View {
        if liquidGlassEnabled {
            ZStack {
                // 使用 Apple 官方推荐的 .background(.material) 方法
                Rectangle()
                    .background(.ultraThinMaterial) // 基础材质
                    .opacity(getBaseOpacity() * renderQuality)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                // 动态响应层 - 根据标签栏状态
                if selectedTabIndex >= 0 && selectedTabIndex < tabBarButtons.count {
                    Rectangle()
                        .background(.thinMaterial)
                        .opacity(0.4)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // 视频播放状态响应层
                if isVideoPlaying {
                    Rectangle()
                        .background(.regularMaterial)
                        .opacity(0.3)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // 主题适配层 - 使用系统主题响应
                Rectangle()
                    .background(colorScheme == .dark ? .thickMaterial : .ultraThinMaterial)
                    .opacity(0.2)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                // DYYY 清屏功能响应层
                if isClearButtonActive {
                    Rectangle()
                        .background(.ultraThinMaterial)
                        .opacity(0.15 * Double(hiddenElementsCount))
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // DYYY 倍速功能响应层
                if isSpeedButtonActive && currentPlaybackSpeed != 1.0 {
                    Rectangle()
                        .background(.thinMaterial)
                        .opacity(0.1 * currentPlaybackSpeed)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
            }
            .compositingGroup() // 优化渲染性能
            .onAppear {
                updateDouyinInterfaceInfo()
                adjustRenderQuality()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DYYYInterfaceStateChanged"))) { _ in
                updateDouyinInterfaceInfo()
            }
        } else {
            Color.clear
        }
    }
    
    private func getBaseOpacity() -> Double {
        // 根据当前状态动态调整基础透明度
        var opacity: Double = 0.8
        
        if isVideoPlaying {
            opacity *= 0.7 // 视频播放时降低透明度
        }
        
        if currentTheme == "dark" {
            opacity *= 1.2 // 暗色主题时增加透明度
        }
        
        return min(opacity, 1.0)
    }
    
    private func updateDouyinInterfaceInfo() {
        // 从 UserDefaults 读取抖音界面信息
        let userDefaults = UserDefaults.standard
        
        if let interfaceInfo = userDefaults.dictionary(forKey: "DYYYInterfaceInfo") {
            currentViewController = interfaceInfo["currentViewController"] as? String ?? ""
            selectedTabIndex = interfaceInfo["selectedTabIndex"] as? Int ?? -1
            tabBarButtons = interfaceInfo["tabBarButtons"] as? [String] ?? []
            isVideoPlaying = interfaceInfo["isVideoPlaying"] as? Bool ?? false
            currentTheme = interfaceInfo["currentTheme"] as? String ?? "light"
            
            // DYYY 功能状态
            isClearButtonActive = interfaceInfo["isClearButtonActive"] as? Bool ?? false
            isSpeedButtonActive = interfaceInfo["isSpeedButtonActive"] as? Bool ?? false
            currentPlaybackSpeed = interfaceInfo["currentPlaybackSpeed"] as? Double ?? 1.0
            hiddenElementsCount = interfaceInfo["hiddenElementsCount"] as? Int ?? 0
        }
    }
    
    private func adjustRenderQuality() {
        // 根据设备性能调整渲染质量
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(totalMemory) / (1024 * 1024 * 1024)
        
        if memoryGB >= 6.0 {
            renderQuality = 1.0 // 高性能设备
        } else if memoryGB >= 4.0 {
            renderQuality = 0.8 // 中等性能设备
        } else {
            renderQuality = 0.6 // 低性能设备
        }
    }
}