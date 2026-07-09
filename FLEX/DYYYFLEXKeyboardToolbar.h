//
//  DYYYFLEXKeyboardToolbar.h
//  FLEX
//
//  Created by Tanner on 6/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "DYYYFLEXKBToolbarButton.h"

@interface DYYYFLEXKeyboardToolbar : UIView

+ (instancetype)toolbarWithButtons:(NSArray *)buttons;

@property (nonatomic) NSArray<DYYYFLEXKBToolbarButton*> *buttons;
@property (nonatomic) UIKeyboardAppearance appearance;

@end
