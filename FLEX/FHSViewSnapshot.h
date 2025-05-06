// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSViewSnapshot.h
//  FLEX
//
//  Created by Tanner Bennett on 1/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FHSView.h"

NS_ASSUME_NONNULL_BEGIN

// 表示视图层次结构中单个视图快照的模型对象
@interface FHSViewSnapshot : NSObject

// 使用给定的 FHSView 创建快照（递归创建子快照）
+ (instancetype)snapshotWithView:(FHSView *)view;

// 关联的 FHSView 对象
@property (nonatomic, readonly) FHSView *view;

// 从 FHSView 复制的属性
@property (nonatomic, readonly) NSString *title;
/// 此视图项是否应在视觉上加以区分
@property (nonatomic, readwrite) BOOL important;
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) BOOL hidden;
@property (nonatomic, readonly) UIImage *snapshotImage;
@property (nonatomic, readonly) NSArray<FHSViewSnapshot *> *children;
@property (nonatomic, readonly) NSString *summary;

/// 根据视图是否重要返回不同的颜色
@property (nonatomic, readonly) UIColor *headerColor;

// 在快照层次结构中查找与给定 UIView 关联的快照
- (nullable FHSViewSnapshot *)snapshotForView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
