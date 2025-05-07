// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSSnapshotNodes.h
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//

#import "FHSViewSnapshot.h"
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 包含与快照关联的 SceneKit 节点引用的容器。
@interface FHSSnapshotNodes : NSObject

+ (instancetype)snapshot:(FHSViewSnapshot *)snapshot depth:(NSInteger)depth;

@property (nonatomic, readonly) FHSViewSnapshot *snapshotItem;
@property (nonatomic, readonly) NSInteger depth;

/// 视图图像本身
@property (nonatomic, nullable) SCNNode *snapshot;
/// 位于快照顶部，具有圆角顶部
@property (nonatomic, nullable) SCNNode *header;
/// 围绕快照绘制的边界框
@property (nonatomic, nullable) SCNNode *border;

/// 用于指示视图何时被选中
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
/// 用于指示视图何时被弱化显示
@property (nonatomic, getter=isDimmed) BOOL dimmed;

@property (nonatomic) BOOL forceHideHeader;

@end

NS_ASSUME_NONNULL_END
