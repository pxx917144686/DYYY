//
//  AwemeHeadersFeed.h
//  DYYY
//
//  Feed 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Feed_h
#define AwemeHeaders_Feed_h

@class AWEAwemeDetailTableViewController;
@class AWEFeedChannelObject;
@class AWENormalModeTabBar;
@class AWENormalModeTabBarPlusButton;
@class AWEPlayInteractionProgressController;
@class AWETabBarSkinContainerView;
@class UIView;
@interface AWENormalModeTabBarGeneralButton : UIButton
@property(nonatomic) NSInteger status;
@end


@interface AWENormalModeTabBarPlusButton : UIView
@end


@interface AWENormalModeTabBarGeneralPlusButton : AWENormalModeTabBarPlusButton
@end


@interface AWEHPTopTabItemBadgeContentView : UIView
@end


@interface AWEFeedTabJumpGuideView : UIView
@end


@interface AWEProgressLoadingView : UIView
- (id)initWithType:(NSInteger)arg1 title:(NSString *)arg2;
- (id)initWithType:(NSInteger)arg1 title:(NSString *)arg2 progressTextFont:(UIFont *)arg3 progressCircleWidth:(NSNumber *)arg4;
- (void)dismissWithAnimated:(BOOL)arg1;
- (void)dismissAnimated:(BOOL)arg1;
- (void)showOnView:(id)arg1 animated:(BOOL)arg2;
- (void)showOnView:(id)arg1 animated:(BOOL)arg2 afterDelay:(CGFloat)arg3;
@end


@interface AWENormalModeTabBarBadgeContainerView : UIView

@end


@interface AWEFeedContainerContentView : UIView
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@end


@interface AWELeftSideBarEntranceView : UIView
- (void)setNumericalRedDot:(id)numericalRedDot;
- (void)setRedDot:(id)redDot;
@end


@interface AWELandscapeFeedEntryView : UIView
@end


@interface AWEIMFeedVideoQuickReplayInputViewController : UIViewController
@end


@interface AWEHPSearchBubbleEntranceView : UIView
@end


@interface AWEFeedVideoButton : UIButton
@end


@interface AWEMusicCoverButton : UIButton
@end


@interface AWESearchEntranceView : UIView

@end


@interface AWENormalModeTabBarTextView : UIView

@end


@interface AWEFamiliarNavView : UIView
@end


@interface AWETabBarSkinContainerView : UIView
@end


@interface AWENormalModeTabBar : UITabBar
@property(nonatomic, assign, readonly) UITabBarController *yy_viewController;
@property(retain, nonatomic) AWETabBarSkinContainerView *skinContainerView;
@end


@interface AWEFeedTableViewController : UIViewController
@end


@interface AWEFeedTableView : UIView
@end


@interface AWEAwemeDetailTableView : UITableView
@end


@interface AWEAwemeDetailTableViewCell : UIView
@end


@interface AWEUserWorkCollectionViewComponentCell : UICollectionViewCell
@end


@interface AWEFeedRefreshFooter : UIView
@end


@interface AWERLSegmentView : UIView
@end


@interface AWEBaseListViewController : UIViewController
@end


// 隐藏视频定位
@interface AWEFeedTemplateAnchorView : UIView
@end


// 隐藏同城定位
@interface AWEMarkView : UIView
@property(nonatomic, readonly) UILabel *markLabel;
@end


@interface AWETemplateHotspotView : UIView
@end


@interface AWEAwemeMusicInfoView : UIView
@end


@interface AWETemplatePlayletView : UIView
@end


@interface AFDRecommendToFriendEntranceLabel : UILabel
@end


@interface AWEStoryContainerCollectionView : UIView
@end


#ifndef DYYYVC_DEFINED
#define DYYYVC_DEFINED
#endif

@interface AWEElementStackView : UIView
@property(nonatomic, copy) NSString *accessibilityLabel;
@property(nonatomic, assign) CGRect frame;
@property(nonatomic, strong) NSArray *subviews;
@property(nonatomic, assign) CGAffineTransform transform;
@end


@interface AWEFeedProgressSlider : UIView
@property(nonatomic, assign) float value;
@property(nonatomic, assign) float maximumValue;
@property(nonatomic, strong) UIView *leftLabelUI;
@property(nonatomic, strong) UIView *rightLabelUI;
@property(nonatomic) AWEPlayInteractionProgressController *progressSliderDelegate;
- (void)applyCustomProgressStyle;
- (void)applyWidthPercentToSubviews:(CGFloat)widthPercent;
@end


@interface AWEFeedProgressSlider (DYYYClassMethod)
+ (void)dyyy_refreshAllSlidersInView:(UIView *)view;
@end



@interface AWEFeedChannelObject : NSObject
@property(nonatomic, copy) NSString *channelID;
@property(nonatomic, copy) NSString *channelTitle;
@end


@interface AWEFeedChannelManager : NSObject
- (AWEFeedChannelObject *)getChannelWithChannelID:(NSString *)channelID;
@end


@interface AWEAntiAddictedNoticeBarView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEFeedAnchorContainerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEIMMessageTabOptPushBannerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEFeedStickerContainerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEECommerceEntryView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWETemplateTagsCommonView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AFDSkylightCellBubble : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface LOTAnimationView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWENearbySkyLightCapsuleView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AFDCancelMuteAwemeView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEFeedRelatedSearchTipView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEProfileMixCollectionViewCell : UIView
@end


@interface AWEProfileTaskCardStyleListCollectionViewCell : UIView
@end


@interface AWEStoryProgressSlideView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWECorrelationItemTag : UIView
- (void)layoutSubviews;
@end


@interface AWEHPDiscoverFeedEntranceView : UIView
- (void)configImage:(UIImageView *)imageView Label:(UILabel *)label position:(NSInteger)pos;
@end


@interface AWEIMFansGroupTopDynamicDomainTemplateView : UIView
- (void)layoutSubviews;
@end


@interface AWETemplateCommonView : UIView
- (void)layoutSubviews;
@end


@interface AWEVideoTypeTagView : UIView
@end


@interface AWEPOIEntryAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
- (void)p_processModels:(id)models withPOIName:(id)poiName;
@end


@interface AWEFeedTopBarContainer : UIView
- (void)applyDYYYTransparency;
@end


@interface AWEHPTopBarCTAContainer : UIView
- (void)applyDYYYTransparency;
@end

// 关注直播
@interface AWEConcernSkylightCapsuleView : UIView
@end

// 图片滑条
@interface AWEStoryProgressContainerView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
- (void)layoutSubviews;
- (void)updateIndicatorWithPageCount:(NSInteger)count;
@end


// 聊天视频底部快速回复视图
@interface AWEIMFeedBottomQuickEmojiInputBar : UIView
@end


@interface ACCEditTagStickerView : UIView
@end


@interface AWESearchFeedTagView : UIView
@end


@interface AFDRecommendToFriendTagView : UIView
@end


@interface AFDAIbumFolioView : UIView
@end


@interface AWEHPTopBarCTAItemView : UIView
@end


@interface AWEFakeProgressSliderView : UIView
- (void)applyCustomProgressStyle;
@end


@interface AWEProfileToggleView : UIView
@end


@interface AWELoadingAndVolumeView : UIView
@end


// 设置修改顶栏标题
@interface AWEHPTopTabItemTextContentView : UIView
- (void)setContentText:(NSString *)text;
@end


// 隐藏状态栏
@interface AWEFeedRootViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end

@interface AWEAwemeDetailTableViewController : UIViewController
@property(nonatomic, copy) NSString *referString;
- (BOOL)prefersStatusBarHidden;
- (BOOL)canShowFixedBottomBar;
- (void)setBottomBarHidden:(BOOL)hidden;
- (NSString *)realReferString;
@end


@interface AWEAwemeIMDetailTableViewController : AWEAwemeDetailTableViewController
@end

@interface AWEFullPageFeedNewContainerViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end


@interface AWEFeedUnfollowFamiliarFollowAndDislikeView : UIView
@end


@interface AWEDPlayerFeedPlayerViewController : UIViewController
@property(nonatomic) UIView *contentView;
- (void)setVideoControllerPlaybackRate:(double)arg0;
@end

@interface AWEConcernCellLastView : UIView
@end


// 底部热点提示框
@interface AWENewHotSpotBottomBarView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end


@interface AWEDemaciaChapterProgressSlider : UIView
@end


// 视频控制视图
@interface AWEFeedVideoControlView : UIView
- (void)handleVideoQualityLongPress:(UILongPressGestureRecognizer *)gesture;
@end


@interface AWESearchViewController : UIViewController
@property(nonatomic, strong) UITabBarController *tabBarController;
@end


@interface AWENormalModeTabBarFeedView : UIView
@end


@interface AWENormalModeTabBarController : UIViewController
@property(nonatomic, strong) AWENormalModeTabBar *awe_tabBar;
- (void)handleApplicationWillEnterForeground:(NSNotification *)notification;
@end


@interface AWELeftSideBarWeatherLabel : UILabel
@property(nonatomic, assign) BOOL userInteractionEnabled;
@property(nonatomic, strong) UIColor *textColor;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@interface AWELeftSideBarWeatherView : UIView
@property(nonatomic, readonly) NSArray<UIView *> *subviews;
- (UITapGestureRecognizer *)tapGestureForDYYY;
- (UITapGestureRecognizer *)tapGestureForSubview:(UIView *)subview;
- (void)openDYYYSettings;
@end

@interface AWELeftSideBarViewController : UIViewController
@end

@interface AWEFeedContainerViewController : UIViewController
@end


@interface AWETabViewController : UIViewController
@property (nonatomic, assign) BOOL isIncognitoModeActive;
@end
#endif /* AwemeHeaders_Feed_h */
