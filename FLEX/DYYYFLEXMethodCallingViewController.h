//
//  DYYYFLEXMethodCallingViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 5/23/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXVariableEditorViewController.h"
#import "DYYYFLEXMethod.h"

@interface DYYYFLEXMethodCallingViewController : DYYYFLEXVariableEditorViewController

+ (instancetype)target:(id)target method:(DYYYFLEXMethod *)method;

@end
