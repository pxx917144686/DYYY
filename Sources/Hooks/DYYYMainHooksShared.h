//
//  DYYYMainHooksShared.h
//  DYYY
//
//  DYYY.xm 拆分后跨 hook 文件共享的声明：倍速、tab 高度、评论可见状态等
//  全局变量与 C 函数。定义位于 DYYYMainSupport.m。
//

#import "DYYYHookShared.h"

NS_ASSUME_NONNULL_BEGIN

// —— 全局变量（定义于 DYYYMainSupport.m）——
extern CGFloat tabHeight;
extern CGFloat originalTabHeight;
extern BOOL dyyyCommentViewVisible;
extern BOOL dyyyCurrentLandscapeVideo;
extern __weak AWEPlayInteractionViewController *dyyyCurrentFullScreenInteractionVC;
extern __weak AWEAwemeModel *dyyyCurrentSpeedAweme;
extern BOOL dyyyLongPressFastSpeedActive;
extern BOOL dyyyLongPressLockedSpeedActive;

// —— 倍速相关函数 ——
BOOL DYYYShouldHandleSpeedFeatures(void);
void DYYYClearLongPressSpeedState(void);
void DYYYRestoreFloatSpeedButtonForAwemeIfNeeded(AWEAwemeModel *aweme);
id DYYYCurrentSpeedInteractionController(void);
void DYYYEnsureFloatSpeedButton(AWEPlayInteractionViewController *interactionController);
void DYYYRefreshFloatSpeedButton(void);
BOOL DYYYApplyPlaybackSpeed(AWEPlayInteractionViewController *interactionController, double speed);
double DYYYConfiguredPlaybackSpeed(void);
double DYYYPreparedPlaybackSpeedForPlayer(id playerViewController);
void DYYYApplyPreparedPlaybackSpeedToPlayer(id playerViewController);
void DYYYScheduleConfiguredPlaybackSpeedRestore(void);
void DYYYEndLockedLongPressSpeedAndRestoreIfNeeded(void);

// —— 全屏/评论可见状态 ——
BOOL DYYYFullScreenCommentOriginalLayoutActive(void);
BOOL DYYYLegacyCommentBlurActive(void);

NS_ASSUME_NONNULL_END
