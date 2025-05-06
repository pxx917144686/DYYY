// 遇到问题联系中文翻译作者：pxx917144686
//
//  CALayer+FLEX.m
//  FLEX
//
//  Created by Tanner on 2/28/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "CALayer+FLEX.h"

@interface CALayer (Private)
// 私有属性，用于访问 continuousCorners
@property (nonatomic) BOOL continuousCorners;
@end

@implementation CALayer (FLEX)

// 静态变量，用于检查 CALayer 是否响应 continuousCorners 选择器
static BOOL respondsToContinuousCorners = NO;

+ (void)load {
    // 在类加载时检查 CALayer 实例是否响应 setContinuousCorners: 选择器
    respondsToContinuousCorners = [CALayer
        instancesRespondToSelector:@selector(setContinuousCorners:)
    ];
}

- (BOOL)flex_continuousCorners {
    // 如果 CALayer 响应 continuousCorners 选择器，则返回其值
    if (respondsToContinuousCorners) {
        return self.continuousCorners;
    }
    
    // 否则返回 NO
    return NO;
}

- (void)setFlex_continuousCorners:(BOOL)enabled {
    // 如果 CALayer 响应 continuousCorners 选择器
    if (respondsToContinuousCorners) {
        // 如果系统版本是 iOS 13 或更高
        if (@available(iOS 13, *)) {
            // 使用新的 cornerCurve API 设置连续圆角
            self.cornerCurve = enabled ? kCACornerCurveContinuous : kCACornerCurveCircular; // 根据 enabled 设置
        } else {
            // 对于旧版本系统，使用私有的 continuousCorners 属性
            self.continuousCorners = enabled;
//            self.masksToBounds = NO; // 保持注释状态
    //        self.allowsEdgeAntialiasing = YES; // 保持注释状态
    //        self.edgeAntialiasingMask = kCALayerLeftEdge | kCALayerRightEdge | kCALayerTopEdge | kCALayerBottomEdge; // 保持注释状态
        }
    }
}

@end
