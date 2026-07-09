//
//  DYYYFLEXGlobalsSection.h
//  FLEX
//
//  Created by Tanner Bennett on 7/11/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXTableViewSection.h"
#import "DYYYFLEXGlobalsEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface DYYYFLEXGlobalsSection : DYYYFLEXTableViewSection

+ (instancetype)title:(NSString *)title rows:(NSArray<DYYYFLEXGlobalsEntry *> *)rows;

@end

NS_ASSUME_NONNULL_END
