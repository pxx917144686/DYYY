//
//  FLEXColorPickerTool.h
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FLEXColorPickerTool : UIView

+ (instancetype)sharedInstance;

- (void)show;
- (void)hide;

@end