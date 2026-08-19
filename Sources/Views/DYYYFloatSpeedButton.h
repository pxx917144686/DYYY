#ifndef DYYYFloatSpeedButton_h
#define DYYYFloatSpeedButton_h

#import <UIKit/UIKit.h>

@class AWEPlayInteractionViewController;

@interface DYYYFloatingSpeedButton : UIButton

@property (nonatomic, assign) CGPoint lastLocation;
@property (nonatomic, weak) AWEPlayInteractionViewController *interactionController;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, strong) NSTimer *firstStageTimer;
@property (nonatomic, assign) BOOL justToggledLock;
@property (nonatomic, assign) BOOL originalLockState;
@property (nonatomic, assign) BOOL isResponding;
@property (nonatomic, strong) NSTimer *statusCheckTimer;

- (void)saveButtonPosition;
- (void)loadSavedPosition;
- (void)resetButtonState;
- (void)toggleLockState;
- (void)setupGestureRecognizers;
- (void)checkAndRecoverButtonStatus;

@end

// 全局函数和变量声明（extern "C" 使 C 编译单元如 DYYYSelfTest.m 可正确链接）
#ifdef __cplusplus
extern "C" {
#endif
extern NSArray *getSpeedOptions(void);
extern NSInteger getCurrentSpeedIndex(void);
extern float getCurrentSpeed(void);
extern void setCurrentSpeedIndex(NSInteger index);
extern void updateSpeedButtonUI(void);
extern DYYYFloatingSpeedButton *getSpeedButton(void);
extern void showSpeedButton(void);
extern void hideSpeedButton(void);
extern void updateSpeedButtonVisibility(void);

// 添加全局变量声明
extern DYYYFloatingSpeedButton *speedButton;
#ifdef __cplusplus
}
#endif

#endif /* DYYYFloatSpeedButton_h */