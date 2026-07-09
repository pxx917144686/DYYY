//
//  DYYYFLEXRuntimeKeyPathTokenizer.h
//  FLEX
//
//  Created by Tanner on 3/22/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "DYYYFLEXRuntimeKeyPath.h"

@interface DYYYFLEXRuntimeKeyPathTokenizer : NSObject

+ (NSUInteger)tokenCountOfString:(NSString *)userInput;
+ (DYYYFLEXRuntimeKeyPath *)tokenizeString:(NSString *)userInput;

+ (BOOL)allowedInKeyPath:(NSString *)text;

@end
