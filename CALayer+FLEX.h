// 遇到问题联系中文翻译作者：pxx917144686
//
//  CALayer+FLEX.h
//  FLEX
//
//  Created by Tanner on 2/28/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayer (FLEX)

/// 是否使用连续圆角（iOS 13+ 使用 `cornerCurve`，旧版本使用私有 API）。
@property (nonatomic) BOOL flex_continuousCorners;

@end
