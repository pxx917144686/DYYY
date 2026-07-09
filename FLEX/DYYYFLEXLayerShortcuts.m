//
//  DYYYFLEXLayerShortcuts.m
//  FLEX
//
//  Created by Tanner Bennett on 12/12/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXLayerShortcuts.h"
#import "DYYYFLEXShortcut.h"
#import "DYYYFLEXImagePreviewViewController.h"

@implementation DYYYFLEXLayerShortcuts

+ (instancetype)forObject:(CALayer *)layer {
    return [self forObject:layer additionalRows:@[
        [DYYYFLEXActionShortcut title:@"预览图片" subtitle:nil
            viewer:^UIViewController *(CALayer *layer) {
                return [DYYYFLEXImagePreviewViewController previewForLayer:layer];
            }
            accessoryType:^UITableViewCellAccessoryType(CALayer *layer) {
                return CGRectIsEmpty(layer.bounds) ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
            }
        ]
    ]];
}

@end
