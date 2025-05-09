//
//  FLEXColorPreviewSection.m
//  FLEX
//
//  Created by Tanner Bennett on 12/12/19.
//  版权所有 © 2020 FLEX 团队. 保留所有权利.
//

#import "FLEXColorPreviewSection.h"

@implementation FLEXColorPreviewSection

+ (instancetype)forObject:(UIColor *)color {
    return [self title:@"颜色" reuse:nil cell:^(__kindof UITableViewCell *cell) {
        cell.backgroundColor = color;
    }];
}

- (BOOL)canSelectRow:(NSInteger)row {
    return NO;
}

- (BOOL (^)(NSString *))filterMatcher {
    return ^BOOL(NSString *filterText) {
        // 搜索时隐藏
        return !filterText.length;
    };
}

@end
