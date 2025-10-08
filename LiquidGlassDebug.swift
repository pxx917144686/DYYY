import Foundation

@objc(LiquidGlassDebug)
public class LiquidGlassDebug: NSObject {
    @objc public static func logStatus(tag: String = "") {
        let supported = LiquidGlassAvailability.isSupported()
        let enabled = LiquidGlassAvailability.isEnabled()
        let should = LiquidGlassAvailability.shouldActivate()
        NSLog("[LiquidGlass] %@ supported=%@ enabled=%@ shouldActivate=%@", tag, supported.description, enabled.description, should.description)
    }
}


