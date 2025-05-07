//
//  FLEXLayerShortcuts.m
//  FLEX
//
//  Created by Tanner Bennett on 12/12/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXLayerShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXImagePreviewViewController.h"

@implementation FLEXLayerShortcuts

+ (instancetype)forObject:(CALayer *)layer {
    return [self forObject:layer additionalRows:@[
        [FLEXActionShortcut title:@"预览图像" subtitle:nil
            viewer:^UIViewController *(CALayer *layer) {
                return [FLEXImagePreviewViewController previewForLayer:layer];
            }
            accessoryType:^UITableViewCellAccessoryType(CALayer *layer) {
                return CGRectIsEmpty(layer.bounds) ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
            }
        ]
    ]];
}

@end
