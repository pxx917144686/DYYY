//
//  DYYYAudioVisualizer.h
//  DYYY
//
//  悬浮玻璃底栏的音频可视化。三个位置三选一，两种形态二选一。
//

#ifndef DYYYAudioVisualizer_h
#define DYYYAudioVisualizer_h

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 由 DYYYGlassUpdate 末尾调用（此时胶囊与圆键的几何刚算完）。
/// 不另开 %hook AWENormalModeTabBar：靠 Logos 的 hook 链顺序拿不到已完成布局的几何。
///
/// 每次都重读设置，位置或形态变了即整套重建——设置项因此不需要额外的即时刷新通路。
void DYYYAudioVisualizerLayout(UIView *douyinBar);

#ifdef __cplusplus
}
#endif

#endif /* DYYYAudioVisualizer_h */
