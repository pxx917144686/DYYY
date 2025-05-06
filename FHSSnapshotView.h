// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSSnapshotView.h
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FHSViewSnapshot.h"
#import "FHSRangeSlider.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FHSSnapshotViewDelegate <NSObject>

// 当选中视图时调用
- (void)didSelectView:(FHSViewSnapshot *)snapshot;
// 当取消选中视图时调用
- (void)didDeselectView:(FHSViewSnapshot *)snapshot;
// 当长按视图时调用
- (void)didLongPressView:(FHSViewSnapshot *)snapshot;

@end

@interface FHSSnapshotView : UIView

+ (instancetype)delegate:(id<FHSSnapshotViewDelegate>)delegate;

@property (nonatomic, weak) id<FHSSnapshotViewDelegate> delegate;

@property (nonatomic) NSArray<FHSViewSnapshot *> *snapshots;
@property (nonatomic, nullable) FHSViewSnapshot *selectedView;

/// 这些类的视图将隐藏其头部
@property (nonatomic) NSArray<Class> *headerExclusions;

@property (nonatomic, readonly) UISlider *spacingSlider;
@property (nonatomic, readonly) FHSRangeSlider *depthSlider;

// 强调指定的视图
- (void)emphasizeViews:(NSArray<UIView *> *)emphasizedViews;

// 切换显示/隐藏头部
- (void)toggleShowHeaders;
// 切换显示/隐藏边框
- (void)toggleShowBorders;

// 隐藏指定的视图快照
- (void)hideView:(FHSViewSnapshot *)view;

@end

NS_ASSUME_NONNULL_END
