//
//  FLEXRuntime+Compare.h
//  FLEX
//
//  Created by Tanner Bennett on 8/28/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>
#import "FLEXProperty.h"
#import "FLEXIvar.h"
#import "FLEXMethodBase.h"
#import "FLEXProtocol.h"

@interface FLEXProperty (Compare)
- (NSComparisonResult)compare:(FLEXProperty *)other;
@end

@interface FLEXIvar (Compare)
- (NSComparisonResult)compare:(FLEXIvar *)other;
@end

@interface FLEXMethodBase (Compare)
- (NSComparisonResult)compare:(FLEXMethodBase *)other;
@end

@interface FLEXProtocol (Compare)
- (NSComparisonResult)compare:(FLEXProtocol *)other;
@end
