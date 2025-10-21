import Foundation
import SwiftUI
import UIKit

// MARK: - 基础桥接视图
@available(iOS 26.0, *)
public struct LiquidGlassBridgeView: View {
    public init() {}
    
    public var body: some View {
        SystemLiquidGlassView()
    }
}

// MARK: - 标签栏专用视图
@available(iOS 26.0, *)
public struct TabBarLiquidGlassView: View {
    @State private var isTabBarVisible: Bool = true
    
    public init() {}
    
    public var body: some View {
        Group {
            if isTabBarVisible && LiquidGlassAvailability.shouldActivate() {
                SystemLiquidGlassView()
                    .frame(height: 83) // 标准TabBar高度 + 安全区域
                    .clipped()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DYYYTabBarVisibilityChanged"))) { notification in
            if let visible = notification.object as? Bool {
                isTabBarVisible = visible
            }
        }
    }
}

// MARK: - 增强版视图
@available(iOS 26.0, *)
public struct EnhancedLiquidGlassView: View {
    @State private var isActive: Bool = false
    @State private var cornerRadius: CGFloat = 0
    @State private var vibrancyEnabled: Bool = false
    
    public init() {}
    
    public var body: some View {
        Group {
            if isActive {
                SystemLiquidGlassView()
                    .cornerRadius(cornerRadius)
                    .overlay(
                        vibrancyEnabled ? 
                        Rectangle()
                            .foregroundStyle(.ultraThinMaterial)
                            .opacity(0.1)
                        : nil
                    )
            }
        }
        .onAppear {
            updateSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            updateSettings()
        }
    }
    
    private func updateSettings() {
        isActive = LiquidGlassAvailability.shouldActivate()
        cornerRadius = CGFloat(UserDefaults.standard.double(forKey: "DYYYLiquidGlassCornerRadius"))
        vibrancyEnabled = UserDefaults.standard.bool(forKey: "DYYYLiquidGlassVibrancy")
    }
}

// MARK: - UIKit 集成助手
@objc(DYYYSwiftUIBridge)
public class DYYYSwiftUIBridge: NSObject {
    
    // 创建基础LiquidGlass视图控制器
    @objc public static func createLiquidGlassViewController() -> UIViewController? {
        guard LiquidGlassAvailability.shouldActivate() else { return nil }
        
        if #available(iOS 26.0, *) {
            let hostingController = UIHostingController(rootView: LiquidGlassBridgeView())
            hostingController.view.backgroundColor = .clear
            return hostingController
        }
        return nil
    }
    
    // 创建TabBar专用LiquidGlass视图控制器
    @objc public static func createTabBarLiquidGlassViewController() -> UIViewController? {
        guard LiquidGlassAvailability.shouldActivate() else { return nil }
        
        if #available(iOS 26.0, *) {
            let hostingController = UIHostingController(rootView: TabBarLiquidGlassView())
            hostingController.view.backgroundColor = .clear
            return hostingController
        }
        return nil
    }
    
    // 创建增强版LiquidGlass视图控制器
    @objc public static func createEnhancedLiquidGlassViewController() -> UIViewController? {
        guard LiquidGlassAvailability.shouldActivate() else { return nil }
        
        if #available(iOS 26.0, *) {
            let hostingController = UIHostingController(rootView: EnhancedLiquidGlassView())
            hostingController.view.backgroundColor = .clear
            return hostingController
        }
        return nil
    }
    
    // 将LiquidGlass视图添加到指定容器
    @objc public static func addLiquidGlassToContainer(_ container: UIView, type: Int = 0) {
        guard LiquidGlassAvailability.shouldActivate() else { return }
        
        var viewController: UIViewController?
        
        switch type {
        case 1:
            viewController = createTabBarLiquidGlassViewController()
        case 2:
            viewController = createEnhancedLiquidGlassViewController()
        default:
            viewController = createLiquidGlassViewController()
        }
        
        guard let vc = viewController else { return }
        
        // 避免重复添加
        if container.subviews.contains(where: { $0.tag == 9999 }) { return }
        
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.tag = 9999 // 标记为LiquidGlass视图
        container.addSubview(vc.view)
        container.sendSubviewToBack(vc.view)
    }
    
    // 从指定容器移除LiquidGlass视图
    @objc public static func removeLiquidGlassFromContainer(_ container: UIView) {
        container.subviews.filter { $0.tag == 9999 }.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let liquidGlassSettingsChanged = Notification.Name("LiquidGlassSettingsChanged")
    static let liquidGlassTabBarVisibilityChanged = Notification.Name("DYYYTabBarVisibilityChanged")
}