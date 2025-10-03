import Foundation
import SwiftUI
import UIKit

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
}

@available(iOS 26.0, *)
struct LiquidGlassBridgeView: View {
    @AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
    private var liquidGlassEnabled: Bool = false

    var body: some View {
        // 进入 SwiftUI 渲染管线，交给系统 Liquid Glass 处理；不叠加任何自绘
        Color.clear
            .ignoresSafeArea()
            .opacity(liquidGlassEnabled ? 0.01 : 0.0)
            .accessibilityHidden(true)
    }
}


