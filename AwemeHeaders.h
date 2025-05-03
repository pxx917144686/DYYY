#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

#define DYYY 100

// 媒体类型枚举
typedef NS_ENUM(NSInteger, MediaType) {
    MediaTypeUnknown,
    MediaTypeImage,
    MediaTypeVideo,
    MediaTypeAudio,
    MediaTypeGIF,
    MediaTypeHeic,
    MediaTypeLivePhoto
};

// URLModel - 视频或图片的URL模型
@interface URLModel : NSObject
@property (nonatomic, strong) NSArray *originURLList;
- (NSURL *)getDYYYSrcURLDownload;
@end

@interface URLModel (DYYYAdditions)
- (NSURL *)getSafeDownloadURL;
- (NSString *)getFilename;
@end

// DUXToast - 显示提示信息
@interface DUXToast : NSObject
+ (void)showText:(NSString *)text;
@end

// AWEURLModel - 抖音URL模型
@interface AWEURLModel : NSObject
- (NSArray *)originURLList;
- (id)URI;
- (NSURL *)getDYYYSrcURLDownload;
@end

@interface AWEURLModel (DYYYAdditions)
- (NSURL *)getSafeDownloadURL;
- (NSString *)getFilename;
@end

// AWEVideoModel - 视频模型
@interface AWEVideoModel : NSObject
@property (retain, nonatomic) AWEURLModel *playURL;
@property (copy, nonatomic) NSArray *manualBitrateModels;
@property (copy, nonatomic) NSArray *bitrateModels;
@property (nonatomic, strong) URLModel *h264URL;
@property (nonatomic, strong) URLModel *coverURL;
@end

// AWEMusicModel - 音乐模型
@interface AWEMusicModel : NSObject
@property (nonatomic, strong) URLModel *playURL;
@end

// AWEImageAlbumImageModel - 相册图片模型
@interface AWEImageAlbumImageModel : NSObject
@property (nonatomic, strong) NSArray *urlList;
@property (retain, nonatomic) AWEVideoModel *clipVideo;
@end

// AWEAwemeTextExtraModel - 文本额外信息（如标签）
@interface AWEAwemeTextExtraModel : NSObject
@property (nonatomic, copy) NSString *hashtagName;
@end

// AWEAwemeStatisticsModel - 统计数据（如点赞数）
@interface AWEAwemeStatisticsModel : NSObject
@property (nonatomic, strong) NSNumber *diggCount;
@end

// AWESearchAwemeExtraModel - 搜索额外信息
@interface AWESearchAwemeExtraModel : NSObject
@end

// AWEAwemeModel - 抖音内容模型
@interface AWEAwemeModel : NSObject
@property (nonatomic, assign, readwrite) CGFloat videoDuration;
@property (nonatomic, strong) AWEVideoModel *video;
@property (nonatomic, strong) AWEMusicModel *music;
@property (nonatomic, strong) NSArray<AWEImageAlbumImageModel *> *albumImages;
@property (nonatomic, assign) NSInteger currentImageIndex;
@property (nonatomic, assign) NSInteger awemeType;
@property (nonatomic, strong) NSString *cityCode;
@property (nonatomic, strong) NSString *ipAttribution;
@property (nonatomic, strong) id currentAweme;
@property (nonatomic, copy) NSString *descriptionString;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, assign) BOOL isAds;
@property (nonatomic, assign) BOOL isLive;
@property (nonatomic, strong) NSString *shareURL;
@property (nonatomic, strong) id hotSpotLynxCardModel;
@property (nonatomic, strong) id liveReason;
@property (nonatomic, strong) id shareRecExtra;
@property (nonatomic, copy) NSString *itemTitle;
@property (nonatomic, strong) NSArray *textExtras;
@property (nonatomic, strong) NSNumber *createTime;
@property (nonatomic, strong) AWEAwemeStatisticsModel *statistics;
- (AWESearchAwemeExtraModel *)searchExtraModel;
- (BOOL)isLive;
@end

// AWELongPressPanelBaseViewModel - 长按面板基础模型
@interface AWELongPressPanelBaseViewModel : NSObject
@property (nonatomic, strong) id awemeModel;
@property (nonatomic, assign) NSInteger actionType;
@property (nonatomic, strong) NSString *duxIconName;
@property (nonatomic, strong) NSString *describeString;
@property (nonatomic, copy) void (^action)(void);
@end

// AWELongPressPanelViewGroupModel - 长按面板分组模型
@interface AWELongPressPanelViewGroupModel : NSObject
@property (nonatomic, strong) NSArray *groupArr;
@property (nonatomic, assign) NSInteger groupType;
@property (nonatomic, copy) NSString *groupTitle;
- (void)setIsDYYYCustomGroup:(BOOL)isCustom;
- (BOOL)isDYYYCustomGroup;
@property (nonatomic, assign) BOOL isModern;
@end

// AWEModernLongPressHorizontalSettingCell - 现代长按水平设置单元格
@interface AWEModernLongPressHorizontalSettingCell : UIView
@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, strong) AWELongPressPanelViewGroupModel *longPressViewGroupModel;
@end

@interface AWEModernLongPressInteractiveCell : UICollectionViewCell
@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, strong) AWELongPressPanelViewGroupModel *longPressViewGroupModel;
@end

// AWELongPressPanelManager - 长按面板管理
@interface AWELongPressPanelManager : NSObject
+ (instancetype)shareInstance;
- (void)dismissWithAnimation:(BOOL)flag completion:(void (^)(void))completion;
- (id)awemeModel;
- (NSDictionary *)logExtraDict;
- (NSString *)referString;
@end

// AWELongPressPanelCustomViewModel - 自定义长按面板模型
@interface AWELongPressPanelCustomViewModel : AWELongPressPanelBaseViewModel
+ (instancetype)longPressPanelViewModel;
@property (nonatomic, strong) NSString *describeString;
@property (nonatomic, strong) NSString *duxIconName;
@property (nonatomic, strong) AWELongPressPanelManager *panelManager;
@property (nonatomic, strong) id awemeModel;
@property (nonatomic, strong) NSDictionary *logExtraDict;
@property (nonatomic, strong) NSString *referString;
@property (nonatomic, copy) void (^action)(void);
@end

// AWENormalModeTabBarGeneralButton - 通用按钮
@interface AWENormalModeTabBarGeneralButton : UIButton
@end

// AWEProgressLoadingView - 加载进度视图
@interface AWEProgressLoadingView : UIView
- (id)initWithType:(NSInteger)arg1 title:(NSString *)arg2;
- (id)initWithType:(NSInteger)arg1 title:(NSString *)arg2 progressTextFont:(UIFont *)arg3 progressCircleWidth:(NSNumber *)arg4;
- (void)dismissWithAnimated:(BOOL)arg1;
- (void)dismissAnimated:(BOOL)arg1;
- (void)showOnView:(id)arg1 animated:(BOOL)arg2;
- (void)showOnView:(id)arg1 animated:(BOOL)arg2 afterDelay:(CGFloat)arg3;
@end

// AWENormalModeTabBarBadgeContainerView - 标签容器视图
@interface AWENormalModeTabBarBadgeContainerView : UIView
@end

// AWEFeedContainerContentView - 内容容器视图
@interface AWEFeedContainerContentView : UIView
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@end

// AWELeftSideBarEntranceView - 左侧栏入口视图
@interface AWELeftSideBarEntranceView : UIView
@end

// AWEDanmakuContentLabel - 弹幕内容标签
@interface AWEDanmakuContentLabel : UILabel
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor;
@end

// AWELandscapeFeedEntryView - 横屏入口视图
@interface AWELandscapeFeedEntryView : UIView
@end

// AWEPlayInteractionViewController - 交互视图控制器
@interface AWEPlayInteractionViewController : UIViewController
@property (nonatomic, strong) UIView *view;
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
- (void)showDislikeOnVideo;
- (void)speedButtonTapped:(id)sender;
- (UIViewController *)firstAvailableUIViewController;
- (void)createFluentDesignDraggableMenuWithAwemeModel:(AWEAwemeModel *)awemeModel touchPoint:(CGPoint)touchPoint;
@end

// UIView 分类 - 获取视图控制器
@interface UIView (Transparency)
- (UIViewController *)firstAvailableUIViewController;
@end

// AWEFeedVideoButton - 视频按钮
@interface AWEFeedVideoButton : UIButton
@end

// AWEMusicCoverButton - 音乐封面按钮
@interface AWEMusicCoverButton : UIButton
@end

// AWEAwemePlayVideoViewController - 视频播放控制器
@interface AWEAwemePlayVideoViewController : UIViewController
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context;
- (void)setVideoControllerPlaybackRate:(double)arg0;
@end

// AWEDanmakuItemTextInfo - 弹幕文本信息
@interface AWEDanmakuItemTextInfo : NSObject
- (void)setDanmakuTextColor:(id)arg1;
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString;
@end

// AWECommentMiniEmoticonPanelView - 表情面板视图
@interface AWECommentMiniEmoticonPanelView : UIView
@end

// AWEBaseElementView - 基础元素视图
@interface AWEBaseElementView : UIView
@end

// AWETextViewInternal - 内部文本视图
@interface AWETextViewInternal : UITextView
@end

// AWECommentPublishGuidanceView - 评论引导视图
@interface AWECommentPublishGuidanceView : UIView
@end

// AWEPlayInteractionFollowPromptView - 关注提示视图
@interface AWEPlayInteractionFollowPromptView : UIView
@end

// AWENormalModeTabBarTextView - 文本视图
@interface AWENormalModeTabBarTextView : UIView
@end

// AWEPlayInteractionNewBaseController - 新交互基础控制器
@interface AWEPlayInteractionNewBaseController : UIView
@property (retain, nonatomic) AWEAwemeModel *model;
@end

// AWEPlayInteractionProgressController - 进度控制器
@interface AWEPlayInteractionProgressController : AWEPlayInteractionNewBaseController
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@property (retain, nonatomic) id progressSlider;
- (NSString *)formatTimeFromSeconds:(CGFloat)seconds;
- (NSString *)convertSecondsToTimeString:(NSInteger)totalSeconds;
@end

// AWEAdAvatarView - 广告头像视图
@interface AWEAdAvatarView : UIView
@end

// AWENormalModeTabBar - 普通模式标签栏
@interface AWENormalModeTabBar : UIView
@end

// AWEPlayInteractionListenFeedView - 听视频视图
@interface AWEPlayInteractionListenFeedView : UIView
@end

// AWEFeedLiveMarkView - 直播标记视图
@interface AWEFeedLiveMarkView : UIView
@end

// AWEPlayInteractionTimestampElement - 时间戳元素
@interface AWEPlayInteractionTimestampElement : UIView
@property (nonatomic, strong) AWEAwemeModel *model;
@end

// AWEFeedTableViewController - Feed 表格控制器
@interface AWEFeedTableViewController : UIViewController
@end

// AWEFeedTableView - Feed 表格视图
@interface AWEFeedTableView : UIView
@end

// AWEPlayInteractionProgressContainerView - 进度容器视图
@interface AWEPlayInteractionProgressContainerView : UIView
@end

// AFDFastSpeedView - 快速播放视图
@interface AFDFastSpeedView : UIView
@end

// AWEUserWorkCollectionViewComponentCell - 用户作品单元格
@interface AWEUserWorkCollectionViewComponentCell : UICollectionViewCell
@end

// AWEFeedRefreshFooter - Feed 刷新底部视图
@interface AWEFeedRefreshFooter : UIView
@end

// AWERLSegmentView - 分段视图
@interface AWERLSegmentView : UIView
@end

// AWEBaseListViewController - 基础列表控制器
@interface AWEBaseListViewController : UIViewController
- (void)applyBlurEffectIfNeeded;
- (UILabel *)findCommentLabel:(UIView *)view;
@end

// AWEFeedTemplateAnchorView - 模板锚点视图
@interface AWEFeedTemplateAnchorView : UIView
@end

// AWEPlayInteractionSearchAnchorView - 搜索锚点视图
@interface AWEPlayInteractionSearchAnchorView : UIView
@end

// AWETemplateHotspotView - 热点视图
@interface AWETemplateHotspotView : UIView
@end

// AWEAwemeMusicInfoView - 音乐信息视图
@interface AWEAwemeMusicInfoView : UIView
@end

// AWEStoryContainerCollectionView - 故事容器视图
@interface AWEStoryContainerCollectionView : UIView
@end

// AWELiveNewPreStreamViewController - 直播预览控制器
@interface AWELiveNewPreStreamViewController : UIViewController
@end

// CommentInputContainerView - 评论输入容器
@interface CommentInputContainerView : UIView
@end

// AWELongPressPanelTableViewController - 长按面板表格控制器
@interface AWELongPressPanelTableViewController : UIViewController
@property (nonatomic, strong) AWEAwemeModel *awemeModel;
@end

// AWEModernLongPressPanelTableViewController - 现代长按面板控制器
@interface AWEModernLongPressPanelTableViewController : UIViewController
@property (nonatomic, strong) AWEAwemeModel *awemeModel;
- (void)showVideoDebugInfo:(id)awemeModel;
- (void)refreshCurrentView;
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
@end

// AWESettingSectionModel - 设置分区模型
@interface AWESettingSectionModel : NSObject
@property (nonatomic, copy) NSString *sectionHeaderTitle;
@property (nonatomic, assign) CGFloat sectionHeaderHeight;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, strong) NSArray *itemArray;
@end

// AWESettingItemModel - 设置项模型
@interface AWESettingItemModel : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, copy) NSString *iconImageName;
@property (nonatomic, assign) NSInteger cellType;
@property (nonatomic, assign) NSInteger colorStyle;
@property (nonatomic, assign) BOOL isEnable;
@property (nonatomic, copy) void (^cellTappedBlock)(void);
@end

@interface AWESettingItemModel (DYYYAdditions)
@property (nonatomic, copy) NSString *svgIconImageName;
@property (nonatomic, assign) BOOL isSwitchOn;
@property (nonatomic, copy) void (^switchChangedBlock)(void);
@end

// AWESettingBaseViewModel - 设置基础模型
@interface AWESettingBaseViewModel : NSObject
@end

// AWESettingsViewModel - 设置视图模型
@interface AWESettingsViewModel : AWESettingBaseViewModel
@property (nonatomic, weak) UIViewController *controllerDelegate;
@property (nonatomic, copy) NSString *traceEnterFrom;
@property (nonatomic, assign) NSInteger colorStyle;
@property (nonatomic, strong) NSArray *sectionDataArray;
- (NSArray *)sectionDataArray;
@end

// DYYYSettingViewController - 自定义设置控制器
#ifndef DYYYVC_DEFINED
#define DYYYVC_DEFINED
@interface DYYYSettingViewController : UIViewController
@end
#endif

// AWEElementStackView - 元素堆栈视图
@interface AWEElementStackView : UIView
@property (nonatomic, copy) NSString *accessibilityLabel;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) NSArray *subviews;
@property (nonatomic, assign) CGAffineTransform transform;
@end

// AWECommentImageModel - 评论图片模型
@interface AWECommentImageModel : NSObject
@property (nonatomic, copy) NSString *originUrl;
@end

// AWECommentLongPressPanelContext - 评论长按面板上下文
@class AWECommentModel;
@class AWEIMStickerModel;
@class AWECommentLongPressPanelParam;

@interface AWECommentLongPressPanelContext : NSObject
- (AWECommentModel *)selectdComment;
- (AWECommentLongPressPanelParam *)params;
@end

// AWECommentLongPressPanelParam - 评论长按面板参数
@interface AWECommentLongPressPanelParam : NSObject
- (AWECommentModel *)selectdComment;
@end

// AWECommentModel - 评论模型
@interface AWECommentModel : NSObject
- (AWEIMStickerModel *)sticker;
- (NSString *)content;
@end

// AWEIMStickerModel - 贴纸模型
@interface AWEIMStickerModel : NSObject
- (AWEURLModel *)staticURLModel;
@end

// AWEUserActionSheetView - 用户操作表视图
@interface AWEUserActionSheetView : NSObject
- (instancetype)init;
- (void)setActions:(NSArray *)actions;
- (void)show;
@end

// AWEUserSheetAction - 用户操作表动作
@interface AWEUserSheetAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title imgName:(NSString *)imgName handler:(void (^)(void))handler;
@end

// AWEFeedTopBarContainer - 顶部栏容器
@interface AWEFeedTopBarContainer : UIView
@property (nonatomic, strong) UIColor *backgroundColor;
- (void)applyDYYYTransparency;
@end

// CommentLongPressPanelSaveImageElement - 保存图片元素
@interface _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end

// CommentLongPressPanelCopyElement - 复制元素
@interface _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end

// AWEFeedProgressSlider - 进度滑块
@interface AWEFeedProgressSlider : UIView
@property (nonatomic, strong) UIView *leftLabelUI;
@property (nonatomic, strong) UIView *rightLabelUI;
@property (nonatomic) AWEPlayInteractionProgressController *progressSliderDelegate;
@end

@interface AWEFeedProgressSlider (DYYYAdditions)
- (void)applyCustomProgressStyle;
@end

// AWEFeedChannelObject - Feed 频道对象
@interface AWEFeedChannelObject : NSObject
@property (nonatomic, copy) NSString *channelID;
@property (nonatomic, copy) NSString *channelTitle;
@end

// AWEFeedChannelManager - Feed 频道管理
@interface AWEFeedChannelManager : NSObject
- (AWEFeedChannelObject *)getChannelWithChannelID:(NSString *)channelID;
@end

// AWEHPTopTabItemModel - 顶部标签项模型
@interface AWEHPTopTabItemModel : NSObject
@property (nonatomic, copy) NSString *channelID;
@property (nonatomic, copy) NSString *channelTitle;
@end

// AWEFakeProgressSliderView - 伪进度滑块视图
@interface AWEFakeProgressSliderView : UIView
@property (nonatomic, strong) UIView *superview;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) NSArray *subviews;
- (void)applyCustomProgressStyle;
@end

// AWEPlayInteractionDescriptionScrollView - 描述滚动视图
@interface AWEPlayInteractionDescriptionScrollView : UIView
@property (nonatomic, strong) UIView *superview;
@property (nonatomic, assign) CGAffineTransform transform;
@end

// AWEPlayInteractionDescriptionLabel - 描述标签
@interface AWEPlayInteractionDescriptionLabel : UIView
@property (nonatomic, strong) UIView *superview;
@property (nonatomic, assign) CGAffineTransform transform;
@end

// AWEUserNameLabel - 用户名标签
@interface AWEUserNameLabel : UILabel
@property (nonatomic, strong) UIView *superview;
@property (nonatomic, assign) CGAffineTransform transform;
@end

// AWEInnerNotificationWindow - 内部通知窗口
@interface AWEInnerNotificationWindow : UIWindow
- (void)setupBlurEffectForNotificationView;
- (void)applyBlurEffectToView:(UIView *)containerView;
- (void)setLabelsColorWhiteInView:(UIView *)view;
- (void)clearBackgroundRecursivelyInView:(UIView *)view;
@end

// LOTAnimationView - 动画视图
@interface LOTAnimationView : UIView
@end

// AWENearbySkyLightCapsuleView - 附近天窗胶囊视图
@interface AWENearbySkyLightCapsuleView : UIView
@end

// AWEPlayInteractionCoCreatorNewInfoView - 共同创作者信息视图
@interface AWEPlayInteractionCoCreatorNewInfoView : UIView
@end

// AFDCancelMuteAwemeView - 取消静音视图
@interface AFDCancelMuteAwemeView : UIView
@end

// AWEPlayDanmakuInputContainView - 弹幕输入容器
@interface AWEPlayDanmakuInputContainView : UIView
@end

// AWEECommerceEntryView - 电商入口视图
@interface AWEECommerceEntryView : UIView
@end

// AWECommentSearchAnchorView - 评论搜索锚点视图
@interface AWECommentSearchAnchorView : UIView
@end

// AWECommentGuideLunaAnchorView - 评论引导锚点视图
@interface AWECommentGuideLunaAnchorView : UIView
@end

// AWETemplateTagsCommonView - 模板标签视图
@interface AWETemplateTagsCommonView : UIView
@end

// AFDSkylightCellBubble - 天窗单元气泡
@interface AFDSkylightCellBubble : UIView
@end

// AWEAntiAddictedNoticeBarView - 防沉迷通知栏
@interface AWEAntiAddictedNoticeBarView : UIView
@end

// AWEPlayInteractionStrongifyShareContentView - 分享内容视图
@interface AWEPlayInteractionStrongifyShareContentView : UIView
@end

// AWEPlayInteractionRelatedVideoView - 相关视频视图
@interface AWEPlayInteractionRelatedVideoView : UIView
@end

// AWEFeedRelatedSearchTipView - 相关搜索提示视图
@interface AWEFeedRelatedSearchTipView : UIView
@end

// AWETemplatePlayletView - 模板播放视图
@interface AWETemplatePlayletView : UIView
@end

// AWESearchEntranceView - 搜索入口视图
@interface AWESearchEntranceView : UIView
@end

// AWEStoryProgressSlideView - 故事进度滑块
@interface AWEStoryProgressSlideView : UIView
@end

// AFDNewFastReplyView - 快速回复视图
@interface AFDNewFastReplyView : UIView
@end

// AWEFeedLiveTabRevisitControlView - 直播标签重访控制视图
@interface AWEFeedLiveTabRevisitControlView : UIView
@end

// IESLiveKTVSongIndicatorView - KTV歌曲指示视图
@interface IESLiveKTVSongIndicatorView : UIView
@end

// AWECorrelationItemTag - 相关项标签
@interface AWECorrelationItemTag : UIView
@end

// AWEPlayInteractionTemplateButtonGroup - 模板按钮组
@interface AWEPlayInteractionTemplateButtonGroup : UIView
@end

// AWEHPDiscoverFeedEntranceView - 发现Feed入口视图
@interface AWEHPDiscoverFeedEntranceView : UIView
@end

// AWELiveFeedStatusLabel - 直播状态标签
@interface AWELiveFeedStatusLabel : UIView
@end

// AWELiveStatusIndicatorView - 直播状态指示视图
@interface AWELiveStatusIndicatorView : UIView
@end

// AWELiveSkylightCatchView - 直播天窗捕捉视图
@interface AWELiveSkylightCatchView : UIView
@end

// AWEHPTopTabItemBadgeContentView - 顶部标签徽章内容视图
@interface AWEHPTopTabItemBadgeContentView : UIView
@end

// AWEIMFansGroupTopDynamicDomainTemplateView - 粉丝群动态模板视图
@interface AWEIMFansGroupTopDynamicDomainTemplateView : UIView
@end

// AWEIMInputActionBarInteractor - 输入动作栏交互
@interface AWEIMInputActionBarInteractor : UIView
@end

// AWETemplateCommonView - 通用模板视图
@interface AWETemplateCommonView : UIView
@end

// AWEHPTopBarCTAItemView - 顶部栏CTA项视图
@interface AWEHPTopBarCTAItemView : UIView
@end

// ACCStickerContainerView - 贴纸容器视图
@interface ACCStickerContainerView : UIView
@end

// BDXWebView - Web视图
@interface BDXWebView : UIView
@end

// IESLiveActivityBannnerView - 直播活动横幅视图
@interface IESLiveActivityBannnerView : UIView
@end

// IESLiveFeedDrawerEntranceView - 直播Feed抽屉入口视图
@interface IESLiveFeedDrawerEntranceView : UIView
@end

// IESLiveButton - 直播按钮
@interface IESLiveButton : UIView
@end

// AWELiveFlowAlertView - 直播流提醒视图
@interface AWELiveFlowAlertView : UIView
@end

// AWEIMFeedBottomQuickEmojiInputBar - 底部快速表情输入栏
@interface AWEIMFeedBottomQuickEmojiInputBar : UIView
@end

// AWEConcernSkylightCapsuleView - 关注天窗胶囊视图
@interface AWEConcernSkylightCapsuleView : UIView
@end

// AWEProfileMixCollectionViewCell - 混合内容单元格
@interface AWEProfileMixCollectionViewCell : UIView
@end

// AWEProfileTaskCardStyleListCollectionViewCell - 任务卡片样式单元格
@interface AWEProfileTaskCardStyleListCollectionViewCell : UIView
@end

// AFDRecommendToFriendEntranceLabel - 推荐好友入口标签
@interface AFDRecommendToFriendEntranceLabel : UIView
@property (nonatomic, strong) UIView *superview;
@property (nonatomic, assign) BOOL hidden;
@end

// UIView 分类 - 获取视图控制器
@interface UIView (ViewControllerCategory)
- (UIViewController *)yy_viewController;
@end

// AWENormalModeTabBar 分类 - 获取视图控制器
@interface AWENormalModeTabBar (DYYYAdditions)
- (UIViewController *)yy_viewController;
@end

// AWEFeedRootViewController - Feed根控制器
@interface AWEFeedRootViewController : UIViewController
@end

// AWEPOIEntryAnchorView - POI入口锚点视图
@interface AWEPOIEntryAnchorView : UIView
- (void)p_addViews;
- (void)setIconUrls:(id)arg1 defaultImage:(id)arg2;
- (void)setContentSize:(CGSize)arg1;
@end

// AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView - 评论面板通用头部视图
@interface AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView : UIView
@end

// AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView - 评论面板商品头部视图
@interface AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView : UIView
@end

// AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView - 评论面板模板锚点头部视图
@interface AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView : UIView
@end

// AWESearchAnchorListModel - 搜索锚点列表模型
@interface AWESearchAnchorListModel : NSObject
- (void)setHideWords:(BOOL)arg1;
- (void)setScene:(id)arg1;
@end

// AWEDiscoverFeedEntranceView - 发现Feed入口视图
@interface AWEDiscoverFeedEntranceView : NSObject
@end

// AWEFeedStickerContainerView - Feed贴纸容器视图
@interface AWEFeedStickerContainerView : UIView
- (BOOL)isHidden;
- (void)setHidden:(BOOL)hidden;
@end

// AWEPostWorkViewController - 发布作品控制器
@interface AWEPostWorkViewController : UIViewController
- (BOOL)isDouGuideTipViewShow;
@end

// AWEIMMessageTabOptPushBannerView - 消息标签推送横幅视图
@interface AWEIMMessageTabOptPushBannerView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
@end

// AWEFeedAnchorContainerView - Feed锚点容器视图
@interface AWEFeedAnchorContainerView : UIView
- (BOOL)isHidden;
- (void)setHidden:(BOOL)hidden;
@end

// AWEPlayInteractionUserAvatarElement - 用户头像元素
@interface AWEPlayInteractionUserAvatarElement : UIView
- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture;
@end

// AWENormalModeTabBarGeneralPlusButton - 通用加号按钮
@interface AWENormalModeTabBarGeneralPlusButton : UIButton
+ (id)button;
@end

// AWEVersionUpdateManager - 版本更新管理
@interface AWEVersionUpdateManager : NSObject
- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2;
- (id)workflow;
- (id)badgeModule;
@end

// AFDProfileAvatarFunctionManager - 头像功能管理
@interface AFDProfileAvatarFunctionManager : NSObject
- (BOOL)shouldShowSaveAvatarItem;
@end

// AWECommentLongPressPanelSaveImageElement - 保存图片元素
@interface AWECommentLongPressPanelSaveImageElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
- (BOOL)elementShouldShow;
- (void)elementTapped;
@end

// AWECommentLongPressPanelCopyElement - 复制元素
@interface AWECommentLongPressPanelCopyElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
- (void)elementTapped;
@end

// AWECommentMediaDownloadConfigLivePhoto - 直播照片下载配置
@interface AWECommentMediaDownloadConfigLivePhoto : NSObject
- (BOOL)needClientWaterMark;
- (BOOL)needClientEndWaterMark;
- (id)watermarkConfig;
@end

// AWEVideoDownloadHandler - 视频下载处理
@interface AWEVideoDownloadHandler : NSObject
+ (instancetype)sharedInstance;
- (void)downloadVideoWithAwemeModel:(AWEAwemeModel *)awemeModel completion:(void(^)(NSURL *localURL, NSError *error))completion;
- (BOOL)canDownloadVideo:(AWEAwemeModel *)awemeModel;
@end

@interface AWEModernLongPressPanelTableViewController (DYYYExtension)
- (UIView *)findButtonWithAccessibilityLabel:(NSString *)label inView:(UIView *)view;
- (void)refreshCurrentView;
- (void)showVideoDebugInfo:(id)awemeModel;
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
@end

@interface AWEModernLongPressPanelTableViewController (DYYYAdditions)
- (void)showVideoDebugInfo:(id)awemeModel;
- (void)extractVideoHashtags:(id)awemeModel;
- (void)shareToThirdParty:(id)awemeModel;
- (void)refreshCurrentView;
@end
