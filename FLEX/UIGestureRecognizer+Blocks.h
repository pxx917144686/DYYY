// filepath: UIGestureRecognizer+Blocks.h
// 遇到问题联系中文翻译作者：pxx917144686
//
//  UIGestureRecognizer+Blocks.h
//  FLEX
//
//  由 Tanner Bennett 创建于 12/20/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

typedef void (^GestureBlock)(UIGestureRecognizer *gesture);


@interface UIGestureRecognizer (Blocks)

+ (instancetype)flex_action:(GestureBlock)action;

@property (nonatomic, setter=flex_setAction:) GestureBlock flex_action;

@end

