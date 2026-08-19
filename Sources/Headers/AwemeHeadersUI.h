//
//  AwemeHeadersUI.h
//  DYYY
//
//  UI 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_UI_h
#define AwemeHeaders_UI_h

@class AWEIMEmoticonModel;
@class BDImageView;
@class UIView;
@interface YYAnimatedImageView : UIImageView
@end


@interface UIView (Transparency)
- (UIViewController *)firstAvailableUIViewController;
@end


@interface AWEBaseElementView : UIView

@end


@interface AWETextViewInternal : UITextView

@end


@interface AWEAdAvatarView : UIView

@end


// 隐藏好友分享私信
@interface AFDNewFastReplyView
@property(nonatomic, weak) UIView *superview;
@property(nonatomic) BOOL hidden;
@end


@interface AWEIMInputActionBarInteractor : UIView
- (void)p_setupUI;
@end


@interface BDXWebView : UIView
@end


@interface ACCStickerContainerView : UIView
@end


@interface AWEUserNameLabel : UIView
@end


@interface BDImageView : UIImageView
@end


@interface AWEIMEmoticonPreviewV2 : UIView
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) BDImageView *content;
@property(nonatomic, strong) AWEIMEmoticonModel *model;
- (void)dyyy_saveButtonTapped:(id)sender;
@end


@interface ACCGestureResponsibleStickerView : UIView
@end


@interface AWEInnerPushCommonView : UIView
@property(nonatomic, strong) UIView *leftExtraIconBackgroundView;
@property(nonatomic, strong) UIImageView *leftExtraIcon;
@property(nonatomic, strong) UIButton *rightActionButton;
@property(nonatomic, strong) UIStackView *middleContentTextStackView;
- (void)updateViewWithRequest:(id)request notificationContent:(id)content viewModel:(id)viewModel;
@end
#endif /* AwemeHeaders_UI_h */
