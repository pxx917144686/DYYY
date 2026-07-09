//
//  DYYYFHSSnapshotView.h
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFHSViewSnapshot.h"
#import "DYYYFHSRangeSlider.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FHSSnapshotViewDelegate <NSObject>

- (void)didSelectView:(DYYYFHSViewSnapshot *)snapshot;
- (void)didDeselectView:(DYYYFHSViewSnapshot *)snapshot;
- (void)didLongPressView:(DYYYFHSViewSnapshot *)snapshot;

@end

@interface DYYYFHSSnapshotView : UIView

+ (instancetype)delegate:(id<FHSSnapshotViewDelegate>)delegate;

@property (nonatomic, weak) id<FHSSnapshotViewDelegate> delegate;

@property (nonatomic) NSArray<DYYYFHSViewSnapshot *> *snapshots;
@property (nonatomic, nullable) DYYYFHSViewSnapshot *selectedView;

/// Views of these classes will have their headers hidden
@property (nonatomic) NSArray<Class> *headerExclusions;

@property (nonatomic, readonly) UISlider *spacingSlider;
@property (nonatomic, readonly) DYYYFHSRangeSlider *depthSlider;

- (void)emphasizeViews:(NSArray<UIView *> *)emphasizedViews;

- (void)toggleShowHeaders;
- (void)toggleShowBorders;

- (void)hideView:(DYYYFHSViewSnapshot *)view;

@end

NS_ASSUME_NONNULL_END
