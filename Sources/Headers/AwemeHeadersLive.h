//
//  AwemeHeadersLive.h
//  DYYY
//
//  Live 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Live_h
#define AwemeHeaders_Live_h

@class IESLiveRoomComponent;
@class UIView;
@interface AWEFeedLiveMarkView : UIView

@end


@interface IESLiveFeedDrawerEntranceView : UIView
@end


@interface AWELiveNewPreStreamViewController : UIViewController
@end


@interface AWENewLiveSkylightViewController : UIViewController
- (void)showSkylight:(BOOL)arg0 animated:(BOOL)arg1 actionMethod:(unsigned long long)arg2;
- (void)updateIsSkylightShowing:(BOOL)arg0;
@end


@interface AWEIMCellLiveStatusContainerView : UIView
- (void)p_initUI;
@end


@interface AWELiveSkylightCatchView : UIView
- (void)setupUI;
@end


@interface AWELiveStatusIndicatorView : UIView
@end


@interface AWELiveFeedStatusLabel : UILabel
@end


@interface IESLiveActivityBannnerView : UIView
@end

// 直播发现
@interface AWEFeedLiveTabRevisitControlView : UIView
@end

// 直播 退出清屏、投屏按钮
@interface IESLiveButton : UIView
@end

// 直播右上关闭按钮
@interface IESLiveLayoutPlaceholderView : UIView
@end

// 直播点歌
@interface IESLiveKTVSongIndicatorView : UIView
@end


// 直播间流量提醒弹窗
@interface AWELiveFlowAlertView : UIView
@end


// 直播间商品信息
@interface IESECLivePluginLayoutView : UIView
@end


// 直播间点赞动画
@interface HTSLiveDiggView : UIView
@end

@interface IESLiveAudienceViewController : UIViewController
- (BOOL)prefersStatusBarHidden;
@end


@interface IESLiveRoomComponent : NSObject
@end


@interface HTSLiveStreamQualityFragment : IESLiveRoomComponent
@property(nonatomic, strong) NSArray *streamQualityArray;
- (NSArray *)getQualities;
- (void)setResolutionWithIndex:(NSInteger)index isManual:(BOOL)manual beginChange:(void (^)(void))beginChangeBlock completion:(void (^)(void))completionBlock;
@end
#endif /* AwemeHeaders_Live_h */
