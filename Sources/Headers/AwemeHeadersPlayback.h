//
//  AwemeHeadersPlayback.h
//  DYYY
//
//  Playback 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Playback_h
#define AwemeHeaders_Playback_h

@class AWEAwemeModel;
@class AWEPlayInteractionNewBaseController;
@class AWEURLModel;
@class UIView;
@interface AWEPlayInteractionViewController : UIViewController
@property(nonatomic, strong) UIView *view;
@property(nonatomic, strong) NSString *referString;
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
- (void)showDislikeOnVideo;
- (void)onVideoPlayerViewDoubleClicked:(id)arg1;
- (UIViewController *)firstAvailableUIViewController;
- (void)speedButtonTapped:(id)sender;
- (void)buttonTouchDown:(id)sender;
- (void)buttonTouchUp:(id)sender;
@end


@interface AWEAwemePlayVideoViewController : UIViewController
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context;
- (void)setVideoControllerPlaybackRate:(double)arg0;

@end


@interface AWEPlayInteractionFollowPromptView : UIView
@end


@interface AWEPlayInteractionNewBaseController : UIView
@property(retain, nonatomic) AWEAwemeModel *model;
@end


@interface AWEPlayInteractionProgressController : AWEPlayInteractionNewBaseController
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@property(retain, nonatomic) id progressSlider;
- (NSString *)formatTimeFromSeconds:(CGFloat)seconds;
- (NSString *)convertSecondsToTimeString:(NSInteger)totalSeconds;
@end


@interface AWEPlayInteractionListenFeedView : UIView

@end


@interface AWEPlayInteractionTimestampElement : UIView
@property(nonatomic, strong) AWEAwemeModel *model;
@end


@interface AWEPlayInteractionProgressContainerView : UIView
@end


@interface AWEDPlayerProgressContainerView : UIView
@end


@interface AFDFastSpeedView : UIView
@end


@interface AWEPlayInteractionSearchAnchorView : UIView
@end


@interface AWEPlayInteractionStrongifyShareContentView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEPlayInteractionCoCreatorNewInfoView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEPlayInteractionRelatedVideoView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEPlayInteractionTemplateButtonGroup : UIView
- (void)layoutSubviews;
@end


@interface AWEPlayInteractionDescriptionScrollView : UIScrollView
@end


@interface AWEPlayInteractionDescriptionLabel : UILabel
@end


@interface AWEPlayInteractionAvatarView : UIView
@property(nonatomic, readonly) NSArray *subviews;
@property(nonatomic, readonly) CGRect frame;
@end


@interface AWEDPlayerViewController_Merge : UIViewController
@property(nonatomic) UIView *contentView;
@property(nonatomic, strong) AWEAwemeModel *model;
@property(nonatomic, assign) BOOL hasInlandscape;
@property(nonatomic, strong) UIView *gradientBackgroundView;
@property(nonatomic, copy) NSString *referString;
- (void)setVideoControllerPlaybackRate:(double)arg0;
- (BOOL)isInLandscapeFeedStatus;
- (void)videoDidShrink;
- (BOOL)isPlaying;
- (void)play;
- (void)pause;
- (BOOL)shouldPreventPlay;
- (BOOL)videoShouldPlay;
@end


@interface AWEPlayVideoViewController : UIViewController
@property(nonatomic, strong) AWEAwemeModel *model;
@property(nonatomic, strong) UIView *playerBackgroundView;
- (void)playerWillLoopPlaying:(id)player;
@end


@interface TTMetalView : UIView
@end

@interface TTMetalViewNew : UIView
@end

@interface TTMetalViewVP : UIView
@end


// 视频播放控制处理器
@interface AWEPlayerPlayControlHandler : NSObject
@property (nonatomic, strong) AVAudioUnitEQ *audioEQ;
@property (nonatomic, strong) AVAudioUnitReverb *reverb;
@property (nonatomic, assign) BOOL noiseFilterEnabled;
@property (nonatomic, strong) UIButton *qualityButton;
@property (nonatomic, strong) NSArray *availableQualities;
@property (nonatomic, assign) NSInteger currentQualityIndex;

- (void)parseAvailableQualities:(AWEURLModel *)urlModel;
- (void)addQualityButton;
- (void)applyDefaultQuality:(AVPlayerItem *)item;
- (void)switchToQuality:(NSInteger)index;
- (void)showQualityOptions;
- (void)setupNoiseFilter;
- (void)addNoiseFilterButton;
- (void)toggleNoiseFilter;
- (id)player;
@end


@interface AWEPlayInteractionUserAvatarElement : UIView
@property(nonatomic, readonly) NSArray *subviews;
@property(nonatomic, readonly) CGRect frame;
- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture;
@end
#endif /* AwemeHeaders_Playback_h */
