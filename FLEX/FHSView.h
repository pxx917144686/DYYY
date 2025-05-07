// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSView.h
//  FLEX
//
//  Created by Tanner Bennett on 1/6/20.
//

#import <UIKit/UIKit.h>

@interface FHSView : NSObject {
    @private
    BOOL _inScrollView; // 是否在滚动视图内
}

+ (instancetype)forView:(UIView *)view isInScrollView:(BOOL)inScrollView;

/// 故意不使用 weak
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic, readonly) NSString *title;
/// 此视图项是否应在视觉上加以区分
@property (nonatomic, readwrite) BOOL important;

@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) BOOL hidden;
@property (nonatomic, readonly) UIImage *snapshotImage;

@property (nonatomic, readonly) NSArray<FHSView *> *children;
@property (nonatomic, readonly) NSString *summary;

/// @return 如果 .important 为真，则返回 importantAttr，否则返回 normalAttr
//- (id)ifImportant:(id)importantAttr ifNormal:(id)normalAttr; // 保持注释或根据需要翻译

@end
