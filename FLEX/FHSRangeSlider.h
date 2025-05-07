// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSRangeSlider.h
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FHSRangeSlider : UIControl

// 允许的最小值
@property (nonatomic) CGFloat allowedMinValue;
// 允许的最大值
@property (nonatomic) CGFloat allowedMaxValue;
// 当前最小值
@property (nonatomic) CGFloat minValue;
// 当前最大值
@property (nonatomic) CGFloat maxValue;

@end

NS_ASSUME_NONNULL_END
