import Foundation
import SwiftUI

// "系统原生 Liquid Glass"：仅在系统支持时渲染系统材质，不做任何自定义替代。
@available(iOS 26.0, *)
public struct SystemLiquidGlassView: View {
    public init() {}

    public var body: some View {
        // 仅使用系统提供的 Material，避免任何自定义渲染
        Rectangle()
            .background(.ultraThinMaterial)
            .ignoresSafeArea(.all)
    }
}


