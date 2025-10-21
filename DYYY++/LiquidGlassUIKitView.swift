import Foundation
import UIKit

@objc(LiquidGlassUIKitView)
public class LiquidGlassUIKitView: NSObject {
    @objc public static func makeViewIfAvailable() -> UIView? {
        guard LiquidGlassAvailability.shouldActivate() else { return nil }
        if #available(iOS 26.0, *) {
            // 仅使用系统材质的视觉效果视图（不做自定义替代）
            let blur = UIBlurEffect(style: .systemUltraThinMaterial)
            let visual = UIVisualEffectView(effect: blur)
            visual.backgroundColor = .clear
            visual.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            return visual
        } else {
            return nil
        }
    }
}


