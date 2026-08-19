//
//  AwemeHeadersPanel.h
//  DYYY
//
//  Panel 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Panel_h
#define AwemeHeaders_Panel_h

@protocol AFDPrivacyHalfScreenViewControllerProtocol;
@class AWEAwemeModel;
@class AWEButton;
@class AWEHalfScreenBaseViewController;
@class AWELongPressPanelBaseViewModel;
@class AWELongPressPanelViewGroupModel;
@class AWESettingBaseViewModel;
@class DUXContentSheet;
@class UIView;
@interface DUXToast : NSObject
+ (void)showText:(NSString *)text;
@end


@interface AWELongPressPanelManager : NSObject
+ (instancetype)shareInstance;
- (void)dismissWithAnimation:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)shouldShowMordenLongPressPanel;
- (BOOL)showShareFriends;
@end


@interface AWELongPressPanelTableViewController : UIViewController
@property(nonatomic, strong) AWEAwemeModel *awemeModel;
@end


@interface AWEModernLongPressPanelTableViewController : UIViewController
@property(nonatomic, strong) AWEAwemeModel *awemeModel;
@end


@interface AWEModernLongPressHorizontalSettingCell : UITableViewCell
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) NSArray *dataArray;
@property(nonatomic, strong) AWELongPressPanelViewGroupModel *longPressViewGroupModel;
@end


@interface AWEModernLongPressHorizontalSettingItemCell : UICollectionViewCell
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, strong) UIImageView *buttonIcon;
@property(nonatomic, strong) UILabel *buttonLabel;
@property(nonatomic, strong) UIView *separator;
@property(nonatomic, strong) AWELongPressPanelBaseViewModel *longPressPanelVM;

- (void)updateUI:(AWELongPressPanelBaseViewModel *)viewModel;
@end


@interface AWEModernLongPressInteractiveCell : UITableViewCell
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) AWELongPressPanelViewGroupModel *longPressViewGroupModel;
@property(nonatomic, strong) NSArray *dataArray;
@property(nonatomic, assign) BOOL isAppearing;
@end


@interface AWEUIAlertView : UIView
- (void)show;
@end


@interface AWETeenModeAlertView : UIView
- (BOOL)show;
@end


@interface AWETeenModeSimpleAlertView : UIView
- (BOOL)show;
@end


@interface AWEUserActionSheetView : UIView
- (instancetype)init;
- (UIView *)containerView;
- (void)setActions:(NSArray *)actions;
- (void)show;
@end


@interface AWEUserSheetAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title imgName:(NSString *)imgName handler:(id)handler;
+ (instancetype)actionWithTitle:(NSString *)title style:(NSUInteger)style imgName:(NSString *)imgName handler:(id)handler;
@end


@interface DUXBadge : UIView
@end


// 应用内推送容器
@interface AWEInnerNotificationWindow : UIWindow
@end


// 添加 DUXContentSheet 相关声明
@protocol IESIMContentSheetVCProtocol
, AWEMRGlobalAlertTrackProtocol;

@interface DUXBasicSheet : UIViewController
@end


@interface AWESettingBaseViewController : UIViewController
@property(nonatomic, strong) UIView *view;
@property(nonatomic, strong) UITableView *tableView;
- (AWESettingBaseViewModel *)viewModel;
@end


@interface AWENavigationBar : UIView
@property(nonatomic, strong) UILabel *titleLabel;
@end


@interface AWEPrivacySettingActionSheetConfig : NSObject
@property(copy, nonatomic) NSArray *models;
@property(copy, nonatomic) NSString *headerText;
@property(copy, nonatomic) NSString *headerTitleText;
@property(nonatomic) BOOL needHighLight;
@property(nonatomic) BOOL useCardUIStyle;
@property(nonatomic) BOOL fromHalfScreen;
@property(retain, nonatomic) UIImage *headerLabelIcon;
@property(nonatomic) CGFloat sheetWidth;
@property(nonatomic) BOOL adaptIpadFromHalfVC;
@end


@interface AWEPrivacySettingActionSheet : UIView
+ (id)sheetWithConfig:(id)arg1;
@property(copy, nonatomic) id closeBlock;
@end


@interface DUXContentSheet : UIViewController
- (void)showOnViewController:(id)arg1 completion:(id)arg2;
- (instancetype)initWithRootViewController:(UIViewController *)controller withTopType:(NSInteger)topType withSheetAligment:(NSInteger)alignment;
- (void)setAutoAlignmentCenter:(BOOL)center;
- (void)setSheetCornerRadius:(CGFloat)radius;
@property(retain, nonatomic) UIView *fullScreenView;
@end


@protocol AFDPrivacyHalfScreenViewControllerProtocol <NSObject>
@end


@interface AWEHalfScreenBaseViewController : UIViewController
- (void)setCornerRadius:(CGFloat)radius;
- (void)setOnlyTopCornerClips:(BOOL)onlyTop;
@end


@interface AWEButton : UIButton
@end


@interface AFDButton : UIButton
@end


@interface DUXAbandonedButton : UIButton
@end


@interface AFDPrivacyHalfScreenViewController : AWEHalfScreenBaseViewController <AFDPrivacyHalfScreenViewControllerProtocol>
@property(retain, nonatomic) UILabel *titleLabel;
@property(retain, nonatomic) UILabel *contentLabel;
@property(retain, nonatomic) UIImageView *imageView;
@property(copy, nonatomic) void (^rightBtnClickedBlock)(void);
@property(copy, nonatomic) void (^leftButtonClickedBlock)(void);
@property(retain, nonatomic) AWEButton *leftCancelButton;
@property(retain, nonatomic) AWEButton *rightConfirmButton;

- (void)configWithImageView:(UIImageView *)imageView
                  lockImage:(UIImage *)lockImage
           defaultLockState:(BOOL)defaultLockState
             titleLabelText:(NSString *)titleText
           contentLabelText:(NSString *)contentText
       leftCancelButtonText:(NSString *)leftButtonText
     rightConfirmButtonText:(NSString *)rightButtonText
       rightBtnClickedBlock:(void (^)(void))rightBtnBlock
     leftButtonClickedBlock:(void (^)(void))leftBtnBlock;

- (void)setCornerRadius:(CGFloat)radius;
- (void)setOnlyTopCornerClips:(BOOL)onlyTop;
- (void)setUseCardUIStyle:(BOOL)arg1;
- (void)setShouldShowToggle:(BOOL)arg1;
- (NSUInteger)animationStyle;
- (NSUInteger)viewStyle;
- (void)setSlideDismissBlock:(void (^)(void))slideDismissBlock;
- (void)setTapDismissBlock:(void (^)(void))tapDismissBlock;
- (void)setAfterDismissBlock:(void (^)(void))afterDismissBlock;
- (void)updateDarkModeAppearance;
@end


@interface AWEMixVideoPanelMoreView : UIView
@end

@interface DUXPopover : UIView
@end


@interface AWEIMEmoticonPanelContainerView : UIView
@end


@interface AWESharePanelContainerViewController : UIViewController
@end


@interface AWESharePanelViewController : UIViewController
- (void)awe_themeReload;
@end


@interface AWESharePanelFunctionCell : UICollectionViewCell
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, strong) UIImageView *smallImageView;
- (void)updateWithViewModel:(id)viewModel bigFontAdapter:(id)adapter;
- (void)updateImageViewWithViewModel:(id)viewModel;
@end


@interface AWEInnerNotificationContainerView : UIView
@property(nonatomic, strong) UIView *containerView;
@property(nonatomic, strong) UIView *contentView;
@property(nonatomic, strong) UIStackView *contentContainerView;
- (void)renderModel:(id)model context:(id)context;
- (void)viewDidDisappear:(BOOL)animated reason:(long long)reason;
@end
#endif /* AwemeHeaders_Panel_h */
