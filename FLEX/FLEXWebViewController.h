//
//  FLEXWebViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 6/10/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@interface FLEXWebViewController : UIViewController

- (id)initWithURL:(NSURL *)url;
- (id)initWithText:(NSString *)text;

+ (BOOL)supportsPathExtension:(NSString *)extension;

@end
