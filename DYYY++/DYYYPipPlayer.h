#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "AwemeHeaders.h"

NS_ASSUME_NONNULL_BEGIN

// DYYYPipContainerView 类声明
@interface DYYYPipContainerView : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIView *mediaDecorationLayer;
@property (nonatomic, strong) UIView *contentContainerLayer;
@property (nonatomic, strong) UIView *danmakuContainerLayer;
@property (nonatomic, strong) UIView *diggAnimationContainer;
@property (nonatomic, strong) UIView *operationContainerLayer;
@property (nonatomic, strong) UIView *floatContainerLayer;
@property (nonatomic, strong) UIView *keyboardContainerLayer;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, weak) UIView *originalParentView;
@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, weak) UIView *playerView;
@property (nonatomic, strong) AWEAwemeModel *awemeModel;
@property (nonatomic, strong) AVPlayer *pipPlayer;
@property (nonatomic, strong) AVPlayerLayer *pipPlayerLayer;
@property (nonatomic, assign) BOOL isPlayingInPip;

- (void)dyyy_restoreFullScreen;
- (NSString *)getAwemeId;
- (void)setupPipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)updatePipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)dyyy_closeAndStopPip;

@end

// PIP 管理器类声明
@interface DYYYPipManager : NSObject

+ (instancetype)sharedManager;
+ (DYYYPipContainerView * _Nullable)sharedPipContainer;
+ (void)setSharedPipContainer:(DYYYPipContainerView * _Nullable)container;
+ (void)handlePipButtonWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)createPipWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)closePip;

@end

// 扩展接口
@interface AWEAwemeModel (DYYYExtension)
- (NSString *)awemeId;
- (NSString *)awemeID;
@end

@interface UIView (DYYYSnapshot)
- (UIImage *)dyyy_snapshotImage;
@end

NS_ASSUME_NONNULL_END