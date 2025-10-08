import Foundation

@objc(LiquidGlassAvailability)
public class LiquidGlassAvailability: NSObject {
    // 插件开关（与 SwiftUI @AppStorage 同步使用的 Key）
    private static let kToggleKey = "com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"

    @objc public static func isSupported() -> Bool {
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
    }

    @objc public static func isEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: kToggleKey)
    }

    @objc public static func shouldActivate() -> Bool {
        return isSupported() && isEnabled()
    }
}


