//
//  DYYYFLEXArgumentInputStructView.h
//  Flipboard
//
//  Created by Ryan Olson on 6/16/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXArgumentInputView.h"

@interface DYYYFLEXArgumentInputStructView : DYYYFLEXArgumentInputView

/// Enable displaying ivar names for custom struct types
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding;

@end
