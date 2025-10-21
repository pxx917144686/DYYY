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
        
        // 检查是否为视频播放相关的视图，如果是则跳过以避免影响视频渲染
        if isVideoPlaybackRelatedView(container) { return }
        
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
        // 但是避免对视频播放相关视图设置clipsToBounds，以免影响视频渲染
        let radius = UserDefaults.standard.object(forKey: "DYYYLiquidGlassCornerRadius") as? NSNumber
        if let r = radius?.doubleValue, r > 0 {
            container.layer.cornerRadius = CGFloat(r)
            container.layer.cornerCurve = .continuous
            // 只有在非视频播放视图时才设置clipsToBounds
            if !isVideoPlaybackRelatedView(container) {
                container.clipsToBounds = true
            }
        }
    }

    private static func containsTabBar(in view: UIView) -> Bool {
        if view is UITabBar { return true }
        for sub in view.subviews {
            if containsTabBar(in: sub) { return true }
        }
        return false
    }
    
    // 检查是否为视频播放相关的视图
    private static func isVideoPlaybackRelatedView(_ view: UIView) -> Bool {
        let className = NSStringFromClass(type(of: view))
        
        // 检查视频播放相关的类名
        let videoPlaybackClasses = [
            "AWEPlayInteractionViewController",
            "AWEAwemePlayVideoViewController", 
            "AWEDPlayerFeedPlayerViewController",
            "AWEVideoPlayerView",
            "AWEPlayerView",
            "AWEFeedVideoPlayerView",
            "IESVideoPlayerView",
            "TTVideoPlayerView",
            "AVPlayerLayer",
            "AVPlayerView"
        ]
        
        for videoClass in videoPlaybackClasses {
            if className.contains(videoClass) {
                return true
            }
        }
        
        // 检查父视图控制器是否为视频播放相关
        if let viewController = view.next as? UIViewController {
            let vcClassName = NSStringFromClass(type(of: viewController))
            for videoClass in videoPlaybackClasses {
                if vcClassName.contains(videoClass) {
                    return true
                }
            }
        }
        
        return false
    }

    // 从指定容器移除系统原生材质视图
    @objc public static func detach(from container: UIView?) {
        guard let container = container else { return }
        container.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.removeFromSuperview() }
    }
}


