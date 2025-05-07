//
//  NSMapTable+FLEX_Subscripting.m
//  FLEX
//
//  Created by Tanner Bennett on 1/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "NSMapTable+FLEX_Subscripting.h"

@implementation NSMapTable (FLEX_Subscripting)

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
    [self setObject:obj forKey:key];
}

@end
