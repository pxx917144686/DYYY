//
//  DYYYFLEXColorPreviewSection.h
//  FLEX
//
//  Created by Tanner Bennett on 12/12/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXSingleRowSection.h"
#import "FLEXObjectInfoSection.h"

@interface DYYYFLEXColorPreviewSection : DYYYFLEXSingleRowSection <FLEXObjectInfoSection>

+ (instancetype)forObject:(UIColor *)color;

@end
