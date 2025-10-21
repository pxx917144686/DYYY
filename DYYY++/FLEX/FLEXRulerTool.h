//
//  FLEXRulerTool.h
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FLEXRulerTool : UIView

+ (instancetype)sharedInstance;

- (void)show;
- (void)hide;

@end