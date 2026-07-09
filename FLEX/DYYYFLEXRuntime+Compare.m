//
//  FLEXRuntime+Compare.m
//  FLEX
//
//  Created by Tanner Bennett on 8/28/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXRuntime+Compare.h"

@implementation DYYYFLEXProperty (Compare)

- (NSComparisonResult)compare:(DYYYFLEXProperty *)other {
    NSComparisonResult r = [self.name caseInsensitiveCompare:other.name];
    if (r == NSOrderedSame) {
        // TODO make sure empty image name sorts above an image name
        return [self.imageName ?: @"" compare:other.imageName];
    }

    return r;
}

@end

@implementation DYYYFLEXIvar (Compare)

- (NSComparisonResult)compare:(DYYYFLEXIvar *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

@end

@implementation DYYYFLEXMethodBase (Compare)

- (NSComparisonResult)compare:(DYYYFLEXMethodBase *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

@end

@implementation DYYYFLEXProtocol (Compare)

- (NSComparisonResult)compare:(DYYYFLEXProtocol *)other {
    return [self.name caseInsensitiveCompare:other.name];
}

@end
