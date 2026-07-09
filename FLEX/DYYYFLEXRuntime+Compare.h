//
//  FLEXRuntime+Compare.h
//  FLEX
//
//  Created by Tanner Bennett on 8/28/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DYYYFLEXProperty.h"
#import "DYYYFLEXIvar.h"
#import "DYYYFLEXMethodBase.h"
#import "DYYYFLEXProtocol.h"

@interface DYYYFLEXProperty (Compare)
- (NSComparisonResult)compare:(DYYYFLEXProperty *)other;
@end

@interface DYYYFLEXIvar (Compare)
- (NSComparisonResult)compare:(DYYYFLEXIvar *)other;
@end

@interface DYYYFLEXMethodBase (Compare)
- (NSComparisonResult)compare:(DYYYFLEXMethodBase *)other;
@end

@interface DYYYFLEXProtocol (Compare)
- (NSComparisonResult)compare:(DYYYFLEXProtocol *)other;
@end
