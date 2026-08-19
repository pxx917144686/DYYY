//
//  DYYYCommentGlass.h
//  DYYY
//
//  评论区液态玻璃对外只暴露最近接管的两个槽位，供调试导出采集其状态。
//  玻璃层挂在槽位的最底层，探针从槽位自己推出来即可。
//

#ifndef DYYYCommentGlass_h
#define DYYYCommentGlass_h

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 最近接管的评论面板槽位；从未接管过时为 nil。
UIView *DYYYCommentGlassCurrentSlot(void);

/// 最近接管的输入框槽位（那枚圆角胶囊）；从未接管过时为 nil。
/// 它的尺寸由抖音在常驻态与回复态之间来回改，探针据此核对玻璃有没有跟上。
UIView *DYYYCommentGlassCurrentField(void);

/// 评论液态玻璃总开关是否在当前系统上实际生效。
BOOL DYYYCommentGlassOn(void);

#ifdef __cplusplus
}
#endif

#endif /* DYYYCommentGlass_h */
