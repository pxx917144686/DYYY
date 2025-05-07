//
//  FLEXRuntimeBrowserToolbar.h
//  FLEX
//
//  Created by Tanner on 6/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXKeyboardToolbar.h"
#import "FLEXRuntimeKeyPath.h"

@interface FLEXRuntimeBrowserToolbar : FLEXKeyboardToolbar

+ (instancetype)toolbarWithHandler:(FLEXKBToolbarAction)tapHandler suggestions:(NSArray<NSString *> *)suggestions;

- (void)setKeyPath:(FLEXRuntimeKeyPath *)keyPath suggestions:(NSArray<NSString *> *)suggestions;

@end
