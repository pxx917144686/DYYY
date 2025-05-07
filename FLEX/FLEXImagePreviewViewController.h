//
//  FLEXImagePreviewViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 6/12/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@interface FLEXImagePreviewViewController : UIViewController

+ (instancetype)previewForView:(UIView *)view;
+ (instancetype)previewForLayer:(CALayer *)layer;
+ (instancetype)forImage:(UIImage *)image;

@end
