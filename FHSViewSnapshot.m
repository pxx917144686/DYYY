// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSViewSnapshot.m
//  FLEX
//
//  Created by Tanner Bennett on 1/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FHSViewSnapshot.h"
#import "NSArray+FLEX.h"

@implementation FHSViewSnapshot

+ (instancetype)snapshotWithView:(FHSView *)view {
    // 递归地为子视图创建快照
    NSArray *children = [view.children flex_mapped:^id(FHSView *v, NSUInteger idx) {
        return [self snapshotWithView:v];
    }];
    // 使用视图和子快照初始化
    return [[self alloc] initWithView:view children:children];
}

- (id)initWithView:(FHSView *)view children:(NSArray<FHSViewSnapshot *> *)children {
    NSParameterAssert(view); NSParameterAssert(children); // 确保参数不为空

    self = [super init];
    if (self) {
        // 从 FHSView 复制属性
        _view = view;
        _title = view.title;
        _important = view.important;
        _frame = view.frame;
        _hidden = view.hidden;
        _snapshotImage = view.snapshotImage;
        _children = children;
        _summary = view.summary;
    }

    return self;
}

- (UIColor *)headerColor {
    // 根据视图是否重要返回不同的标题颜色
    if (self.important) {
        // 重要视图的颜色（蓝色）
        return [UIColor colorWithRed: 0.000 green: 0.533 blue: 1.000 alpha: 0.900];
    } else {
        // 普通视图的颜色（橙色）
        return [UIColor colorWithRed:0.961 green: 0.651 blue: 0.137 alpha: 0.900];
    }
}

- (FHSViewSnapshot *)snapshotForView:(UIView *)view {
    // 检查当前快照是否对应目标视图
    if (view == self.view.view) {
        return self;
    }

    // 递归地在子快照中查找目标视图
    for (FHSViewSnapshot *child in self.children) {
        FHSViewSnapshot *snapshot = [child snapshotForView:view];
        if (snapshot) {
            return snapshot; // 找到则返回
        }
    }

    return nil; // 未找到
}

@end
