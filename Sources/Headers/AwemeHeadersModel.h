//
//  AwemeHeadersModel.h
//  DYYY
//
//  Model 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Model_h
#define AwemeHeaders_Model_h

@class AWEAwemeModel;
@class AWEAwemeStatisticsModel;
@class AWEAwemeTextExtraModel;
@class AWEImageAlbumImageModel;
@class AWELiveFollowFeedCellModel;
@class AWEMusicCardModel;
@class AWEMusicModel;
@class AWEPropGuideV2Model;
@class AWESearchAwemeExtraModel;
@class AWESettingBaseViewModel;
@class AWESettingItemModel;
@class AWEURLModel;
@class AWEUserModel;
@class AWEVideoModel;
@class URLModel;
@interface URLModel : NSObject
@property(nonatomic, strong) NSArray *originURLList;
- (NSURL *)getDYYYSrcURLDownload;
@end


@interface AWEURLModel : NSObject
@property(nonatomic, copy) NSArray *originURLList;
@property(nonatomic, assign) NSInteger imageWidth;
@property(nonatomic, assign) NSInteger imageHeight;
@property(nonatomic, copy) NSString *URLKey;
- (NSArray *)originURLList;
- (id)URI;
- (NSURL *)getDYYYSrcURLDownload;
@end


@interface AWEVideoModel : NSObject
@property(nonatomic, strong) AWEURLModel *playLowBitURL;
@property(retain, nonatomic) AWEURLModel *playURL;
@property(copy, nonatomic) NSArray *manualBitrateModels;
@property(copy, nonatomic) NSArray *bitrateModels;
@property(copy, nonatomic) NSArray *bitrateRawData;
@property(nonatomic, strong) URLModel *h264URL;
@property(nonatomic, strong) URLModel *coverURL;
@property(nonatomic, strong) NSNumber *width;
@property(nonatomic, strong) NSNumber *height;
@end


@interface AWEMusicModel : NSObject
@property(nonatomic, strong) URLModel *playURL;
@end


@interface AWEImageAlbumImageModel : NSObject
@property(nonatomic, strong) NSArray *urlList;
@property(retain, nonatomic) AWEVideoModel *clipVideo;
@end


@interface AWEAwemeStatisticsModel : NSObject
@property(nonatomic, strong) NSNumber *diggCount;
@end


@interface AWESearchAwemeExtraModel : NSObject
@end


@interface AWEAwemeTextExtraModel : NSObject
@property(nonatomic, copy) NSString *hashtagName;
@property(nonatomic, copy) NSString *hashtagId;
@property(nonatomic, copy) NSString *type;
@property(nonatomic, assign) NSRange textRange;
@property(nonatomic, copy) NSString *awemeId;
@property(nonatomic, copy) NSString *userId;
@property(nonatomic, copy) NSString *userUniqueId;
@property(nonatomic, copy) NSString *secUid;
@end


@interface AWEUserModel : NSObject
@property(copy, nonatomic) NSString *nickname;
@property(copy, nonatomic) NSString *shortID;
@end


@interface AWEPropGuideV2Model : NSObject
@property(nonatomic, copy) NSString *propName;
@end


@interface AWELiveFollowFeedCellModel : NSObject
@end


@interface AWEMusicCardModel : NSObject
@end


@interface AWEAwemeModel : NSObject
@property(nonatomic, strong, readwrite) NSNumber *createTime;
@property(nonatomic, assign, readwrite) CGFloat videoDuration;
@property(nonatomic, strong) AWEVideoModel *video;
@property(nonatomic, strong) AWEMusicModel *music;
@property(nonatomic, strong) NSArray<AWEImageAlbumImageModel *> *albumImages;
@property(nonatomic, assign) NSInteger currentImageIndex;
@property(nonatomic, assign) NSInteger awemeType;
@property(nonatomic, strong) NSString *cityCode;
@property(nonatomic, strong) NSString *ipAttribution;
@property(nonatomic, strong) id currentAweme;
@property(nonatomic, copy) NSString *descriptionString;
@property(nonatomic, assign) BOOL isAds;
@property(nonatomic, assign) BOOL isLive;
@property(nonatomic, assign) BOOL isNewTextMode;  // 文字图文专有属性
@property(nonatomic, strong) NSString *shareURL;
@property(nonatomic, strong) id hotSpotLynxCardModel;
@property(nonatomic, strong) AWELiveFollowFeedCellModel *cellRoom;
@property(nonatomic, strong) NSString *videoFeedTag;
@property(nonatomic, copy) NSString *liveReason;
@property(nonatomic, strong) id shareRecExtra; // 推荐视频专有属性
@property(nonatomic, copy) NSString *referString; // 推荐页为 homepage_hot
@property(nonatomic, strong) NSArray<AWEAwemeTextExtraModel *> *textExtras;
@property(nonatomic, copy) NSString *itemTitle;
@property(nonatomic, copy) NSString *descriptionSimpleString;
@property(nonatomic, strong) NSString *itemID;
@property(nonatomic, strong) AWEUserModel *author;
@property(nonatomic, strong) AWEPropGuideV2Model *propGuideV2;
@property(nonatomic, strong) AWEMusicCardModel *musicCard;
@property(nonatomic, assign) BOOL isShowLandscapeEntryView;

@property(nonatomic, strong) AWEAwemeStatisticsModel *statistics;
- (BOOL)isLive;
- (BOOL)contentFilter;
- (BOOL)checkIsAd;
- (BOOL)isHardAdModel;
- (BOOL)isHardAd;
- (AWESearchAwemeExtraModel *)searchExtraModel;
@end


@interface AWELongPressPanelBaseViewModel : NSObject
@property(nonatomic, copy) NSString *describeString;
@property(nonatomic, assign) NSInteger enterMethod;
@property(nonatomic, assign) NSInteger actionType;
@property(nonatomic, assign) BOOL showIfNeed;
@property(nonatomic, copy) NSString *duxIconName;
@property(nonatomic, copy) void (^action)(void);
@property(nonatomic) BOOL isModern;
@property(nonatomic, strong) AWEAwemeModel *awemeModel;
- (void)setDuxIconName:(NSString *)iconName;
- (void)setDescribeString:(NSString *)descString;
- (void)setAction:(void (^)(void))action;
@end


@interface AWELongPressPanelViewGroupModel : NSObject
@property(nonatomic) unsigned long long groupType;
@property(nonatomic) NSArray *groupArr;
@property(nonatomic) long long numberOfRowsInSection;
@property(nonatomic) long long cellHeight;
@property(nonatomic) BOOL hasMore;
@property(nonatomic) BOOL isModern;
@property(nonatomic) BOOL isDYYYCustomGroup;
@end


@interface AWEIMStickerModel : NSObject
- (AWEURLModel *)staticURLModel;
@end


@interface AWEHPTopTabItemModel : NSObject
@property(nonatomic, copy) NSString *channelID;
@property(nonatomic, copy) NSString *channelTitle;
@property(nonatomic, copy) NSString *title;
@end


@interface AWENearbyFullScreenViewModel : NSObject
- (void)setShowSkyLight:(id)arg1;
- (void)setHaveSkyLight:(id)arg1;
@end


@interface AWESearchAnchorListModel : NSObject
- (id)init;
@end


@interface AWEBinding : NSObject
@end


@interface AWESettingItemModel : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, assign) NSInteger type;
@property(nonatomic, copy) NSString *iconImageName;
@property(nonatomic, copy) NSString *svgIconImageName;
@property(nonatomic, assign) NSInteger cellType;
@property(nonatomic, assign) NSInteger colorStyle;
@property(nonatomic, assign) BOOL isEnable;
@property(nonatomic, assign) BOOL isSwitchOn;
@property(nonatomic, copy) void (^cellTappedBlock)(void);
@property(nonatomic, copy) void (^switchChangedBlock)(void);
@end


@interface AWESettingBaseViewModel : NSObject
@end


@interface AWESettingsViewModel : AWESettingBaseViewModel
@property(nonatomic, assign) NSInteger colorStyle;
@property(nonatomic, strong) NSArray *sectionDataArray;
@property(nonatomic, weak) id controllerDelegate;
@property(nonatomic, strong) NSString *traceEnterFrom;

- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict;
- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict cellTapHandlers:(NSMutableDictionary *)cellTapHandlers;

- (void)refreshTableView;
- (void)updateSectionDataArray;
- (void)handleConflictsAndDependenciesForSetting:(NSString *)identifier isEnabled:(BOOL)isEnabled;
- (void)updateDependentItemsForSetting:(NSString *)identifier value:(id)value;
- (void)handleConflictsAndDependenciesForSetting:(NSString *)identifier isEnabled:(BOOL)isEnabled;
- (void)applyDependencyRulesForItem:(AWESettingItemModel *)item;
- (void)updateConflictingItemUIState:(NSString *)identifier withValue:(BOOL)value;
- (NSDictionary *)settingsDependencyConfig;
@end


@interface AWESettingSectionModel : NSObject
@property(nonatomic, assign) NSInteger type;
@property(nonatomic, assign) CGFloat sectionHeaderHeight;
@property(nonatomic, copy) NSString *sectionHeaderTitle;
@property(nonatomic, strong) NSArray *itemArray;
@property(retain, nonatomic) NSString *identifier;
@property(copy, nonatomic) NSString *title;
- (id)initWithIdentifier:(id)arg1;
- (void)setIsSelect:(BOOL)arg1;
- (BOOL)isSelect;
- (void)setCellTappedBlock:(id)arg1;
- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict;
- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict cellTapHandlers:(NSMutableDictionary *)cellTapHandlers;
- (void)applyDependencyRulesForItem:(AWESettingItemModel *)item;
- (void)handleConflictsAndDependenciesForSetting:(NSString *)identifier isEnabled:(BOOL)isEnabled;
- (void)updateDependentItemsForSetting:(NSString *)identifier value:(id)value;
@end


@interface AWEIMEmoticonModel : NSObject
- (id)valueForKey:(NSString *)key;
@end
#endif /* AwemeHeaders_Model_h */
