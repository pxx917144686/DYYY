//
//  AwemeHeadersComment.h
//  DYYY
//
//  Comment 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Comment_h
#define AwemeHeaders_Comment_h

@class AWECommentAudioModel;
@class AWECommentImageModel;
@class AWECommentLivePhotoModel;
@class AWECommentLongPressPanelContext;
@class AWECommentLongPressPanelParam;
@class AWECommentModel;
@class AWEIMStickerModel;
@class AWEURLModel;
@class AWEUserModel;
@class UIView;
@interface AWEDanmakuContentLabel : UILabel
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor;
@end


@interface AWEDanmakuItemTextInfo : NSObject
- (void)setDanmakuTextColor:(id)arg1;
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString;
@end


@interface AWECommentMiniEmoticonPanelView : UIView

@end


@interface AWECommentPublishGuidanceView : UIView

@end


@interface AWECommentInputViewController : UIViewController
@end


@interface CommentInputContainerView : UIView
@end


// 评论区实况照片模型
@interface AWECommentLivePhotoModel : NSObject
@property(nonatomic, copy) NSArray *videoUrl;
@end


@interface AWECommentImageModel : NSObject
@property(nonatomic, strong) AWEURLModel *originUrl;
@property(nonatomic, strong) AWEURLModel *mediumUrl;
@property(nonatomic, strong) AWECommentLivePhotoModel *livePhotoModel;
@end


@class AWECommentModel;
@class AWECommentLongPressPanelParam;
@class AWEIMStickerModel;
@class AWEURLModel;
@class AWECommentAudioModel;

@interface AWECommentLongPressPanelContext : NSObject
- (AWECommentModel *)selectdComment;
- (AWECommentLongPressPanelParam *)params;
@end


@interface AWECommentLongPressPanelParam : NSObject
- (AWECommentModel *)selectdComment;
- (NSDictionary *)extraParams;
@end


@interface AWECommentAudioModel : NSObject
@property (nonatomic, copy, readwrite) NSString *content;
@end


@interface AWECommentModel : NSObject
@property (nonatomic, strong, readwrite) AWECommentAudioModel *audioModel;
@property (nonatomic, strong, readwrite) AWEUserModel *author;
@property (nonatomic, strong, readwrite) NSNumber *createTime;
- (AWEIMStickerModel *)sticker;
- (NSString *)content;
- (NSArray<AWECommentImageModel *> *)imageList;
@end


@interface _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end


@interface _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end


@interface AWEPlayDanmakuInputContainView : UIView
@property(nonatomic, strong, readonly) UIView *superview;
@property(nonatomic, assign, getter=isHidden) BOOL hidden;
@end

@interface AWECommentSearchAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
@end


@interface AWECommentGuideLunaAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
@end


// 搜索视频底部评论视图
@interface AWECommentInputBackgroundView : UIView
@end


@interface AWEVideoPlayDanmakuContainerView : UIView
@end


// 评论区免费去看短剧
@interface AWEShowPlayletCommentHeaderView : UIView
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (void)layoutSubviews;
@end


@interface AWEIMCommentShareUserHorizontalSectionController : UIViewController
- (void)configCell:(id)cell index:(NSInteger)index model:(id)model;
@end


@interface AWEIMCommentShareUserHorizontalCollectionViewCell : UIView
@end


@interface AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView : UIView
- (void)setHidden:(BOOL)hidden;
@end


@interface AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView : UIView
- (void)setHidden:(BOOL)hidden;
@end


@interface AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView : UIView
- (void)setHidden:(BOOL)hidden;
@end


// 添加缺失的类声明
@interface AWECommentInputViewSwiftImpl_CommentInputContainerView : UIView
@end


@interface AWECommentInputViewSwiftImpl_CommentInputBackgroundView : UIView
@end


@interface AWETextViewContainer : UIView
@end


@interface AWECommentInputViewSwiftImpl_CommentInputBar : UIView
@end


@interface AWECommentContainerViewController : UIViewController
@property (nonatomic, strong) UIView *view;
@end


@interface AWEListKitMagicCollectionView : UICollectionView
@end


@interface DDanmakuPlayerView : UIView
@end


@interface AWECommentMediaFeedViewController : UIViewController
@property(nonatomic, assign) long long currentIndex;
@property(nonatomic, strong) UIButton *backButton;
- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)previewDismissByClickBackBtn;
@end


@interface AWECommentMediaFeedImageCell : UICollectionViewCell
- (UIView *)mediaContainerView;
@end
#endif /* AwemeHeaders_Comment_h */
