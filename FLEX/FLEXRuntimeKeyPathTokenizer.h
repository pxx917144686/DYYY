//
//  FLEXRuntimeKeyPathTokenizer.h
//  FLEX
//
//  Created by Tanner on 3/22/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXRuntimeKeyPath.h"

@interface FLEXRuntimeKeyPathTokenizer : NSObject

+ (NSUInteger)tokenCountOfString:(NSString *)userInput;
+ (FLEXRuntimeKeyPath *)tokenizeString:(NSString *)userInput;

+ (BOOL)allowedInKeyPath:(NSString *)text;

@end
