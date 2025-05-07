// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXScopeCarousel.h
//  FLEX
//
//  由 Tanner Bennett 创建于 7/17/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

/// 仅在 iOS 10 及更高版本上使用。需要 iOS 10 API 来计算行大小。
@interface FLEXScopeCarousel : UIControl

@property (nonatomic, copy) NSArray<NSString *> *items;
@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic) void(^selectedIndexChangedAction)(NSInteger idx);

- (void)registerBlockForDynamicTypeChanges:(void(^)(FLEXScopeCarousel *))handler;

@end
