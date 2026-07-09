//
//  DYYYFLEXRuntimeBrowserToolbar.h
//  FLEX
//
//  Created by Tanner on 6/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "DYYYFLEXKeyboardToolbar.h"
#import "DYYYFLEXRuntimeKeyPath.h"

@interface DYYYFLEXRuntimeBrowserToolbar : DYYYFLEXKeyboardToolbar

+ (instancetype)toolbarWithHandler:(FLEXKBToolbarAction)tapHandler suggestions:(NSArray<NSString *> *)suggestions;

- (void)setKeyPath:(DYYYFLEXRuntimeKeyPath *)keyPath suggestions:(NSArray<NSString *> *)suggestions;

@end
