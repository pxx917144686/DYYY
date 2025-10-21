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
            SystemLiquidGlassView()
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
            SystemLiquidGlassView()
            .onAppear {
                updateDouyinInterfaceInfo()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DYYYInterfaceStateChanged"))) { _ in
                updateDouyinInterfaceInfo()
            }
        } else {
            Color.clear
        }
    }
    
    private func getBaseOpacity() -> Double { 0.8 }
    
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
            SystemLiquidGlassView()
            .onAppear {
                updateDouyinInterfaceInfo()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DYYYInterfaceStateChanged"))) { _ in
                updateDouyinInterfaceInfo()
            }
        } else {
            Color.clear
        }
    }
    
    private func getBaseOpacity() -> Double { 0.8 }
    
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
    
    // 移除质量调节，保持严格系统材质
}