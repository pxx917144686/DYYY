//
//  DYYYLongPressPanelSupport.h
//  DYYY
//
//  长按面板拆分后的共享声明：辅助 category 与快照方法。
//  实现见 DYYYLongPressPanelSupport.m，hook 见 DYYYLongPressPanelHooks.xm /
//  DYYYLongPressPanelCellHooks.xm。
//

#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"
#import "DYYYCustomInputView.h"

NS_ASSUME_NONNULL_BEGIN

@class DYYYBottomAlertView;
@class DYYYToast;

// 自定义分类声明
@interface AWELongPressPanelViewGroupModel (DYYY)
@property (nonatomic, assign) BOOL isDYYYCustomGroup;
@end

@interface AWEModernLongPressPanelTableViewController (DYYY_FLEX)
- (void)fixFLEXMenu:(AWEAwemeModel *)awemeModel;
- (NSArray *)applyOriginalArrayFilters:(NSArray *)originalArray;
- (NSArray<NSNumber *> *)calculateButtonDistribution:(NSInteger)totalButtons;
- (AWELongPressPanelViewGroupModel *)createCustomGroup:(NSArray<AWELongPressPanelBaseViewModel *> *)buttons;
@end

@interface AWEModernLongPressPanelTableViewController (DYYYBackgroundColorView)
@property (nonatomic, strong) UIView *dyyy_backgroundColorView;
@end

// AWEPlayInteractionViewController的方法声明
@interface AWEPlayInteractionViewController (DYYYExtension)
- (NSString *)dyyy_getAwemeId:(AWEAwemeModel *)model;
- (void)setAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)dyyy_forceRefreshPlayer:(AWEAwemeModel *)awemeModel;
- (UIView *)dyyy_findPlayerView:(UIView *)view;
- (void)dyyy_handleForceRefreshPlayer:(NSNotification *)notification;
- (void)dyyy_switchToAwemeModel:(NSNotification *)notification;
- (BOOL)dyyy_isSameAwemeModel:(AWEAwemeModel *)model1 target:(AWEAwemeModel *)model2;
- (void)dyyy_refreshPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)dyyy_tryRefreshPlayerView:(AWEAwemeModel *)awemeModel;
@end

@interface UIView (DYYYSnapshot)
- (UIImage *)dyyy_snapshotImage;
@end

NS_ASSUME_NONNULL_END
