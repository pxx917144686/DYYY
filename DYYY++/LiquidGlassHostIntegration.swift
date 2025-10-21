import Foundation
import UIKit

@objc(LiquidGlassHostIntegration)
public class LiquidGlassHostIntegration: NSObject {
    // 在指定容器视图插入系统原生材质视图
    @objc public static func attach(to container: UIView?) {
        guard let container = container else { return }
        guard LiquidGlassAvailability.shouldActivate() else { return }
        // 若容器包含宿主旧底部栏（UITabBar），直接跳过，避免冲突
        if containsTabBar(in: container) { return }
        guard let effectView = LiquidGlassUIKitView.makeViewIfAvailable() else { return }
        // 避免重复添加
        if container.subviews.contains(where: { $0 is UIVisualEffectView }) { return }
        effectView.frame = container.bounds
        container.addSubview(effectView)
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 启用 Vibrancy：仅用于提升前景对比度，不改变材质本身
        let vibrancyEnabled = UserDefaults.standard.bool(forKey: "DYYYLiquidGlassVibrancy")
        if vibrancyEnabled, let vev = effectView as? UIVisualEffectView, let blur = vev.effect as? UIBlurEffect {
            let vibrancy = UIVibrancyEffect(blurEffect: blur)
            let vibrancyView = UIVisualEffectView(effect: vibrancy)
            vibrancyView.frame = vev.contentView.bounds
            vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            vev.contentView.addSubview(vibrancyView)
        }

        // 为自定义容器应用连续圆角（不自绘阴影/高光/噪点）
        let radius = UserDefaults.standard.object(forKey: "DYYYLiquidGlassCornerRadius") as? NSNumber
        if let r = radius?.doubleValue, r > 0 {
            container.layer.cornerRadius = CGFloat(r)
            if #available(iOS 13.0, *) {
                container.layer.cornerCurve = .continuous
            }
            container.clipsToBounds = true
        }
    }

    private static func containsTabBar(in view: UIView) -> Bool {
        if view is UITabBar { return true }
        for sub in view.subviews {
            if containsTabBar(in: sub) { return true }
        }
        return false
    }

    // 从指定容器移除系统原生材质视图
    @objc public static func detach(from container: UIView?) {
        guard let container = container else { return }
        container.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.removeFromSuperview() }
    }
}


