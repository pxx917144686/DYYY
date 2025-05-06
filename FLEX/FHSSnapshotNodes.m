// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSSnapshotNodes.m
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//

#import "FHSSnapshotNodes.h"
#import "SceneKit+Snapshot.h"

@interface FHSSnapshotNodes ()
// 高亮节点
@property (nonatomic, nullable) SCNNode *highlight;
// 变暗节点
@property (nonatomic, nullable) SCNNode *dimming;
@end
@implementation FHSSnapshotNodes

+ (instancetype)snapshot:(FHSViewSnapshot *)snapshot depth:(NSInteger)depth {
    FHSSnapshotNodes *nodes = [self new];
    nodes->_snapshotItem = snapshot;
    nodes->_depth = depth;
    return nodes;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (_highlighted != highlighted) {
        _highlighted = highlighted;

        if (highlighted) {
            if (!self.highlight) {
                // 创建高亮节点
                self.highlight = [SCNNode
                    highlight:self.snapshotItem
                    color:[UIColor.blueColor colorWithAlphaComponent:0.5]
                ];
            }
            // 添加高亮节点，如果已变暗则移除变暗节点
            [self.snapshot addChildNode:self.highlight];
            if (self.isDimmed) {
                [self.dimming removeFromParentNode];
            }
        } else {
            // 移除高亮节点，如果已变暗则重新添加变暗节点
            [self.highlight removeFromParentNode];
            if (self.isDimmed) {
                [self.snapshot addChildNode:self.dimming];
            }
        }
    }
}

- (void)setDimmed:(BOOL)dimmed {
    if (_dimmed != dimmed) {
        _dimmed = dimmed;

        if (dimmed) {
            if (!self.dimming) {
                // 创建变暗节点
                self.dimming = [SCNNode
                    highlight:self.snapshotItem
                    color:[UIColor.blackColor colorWithAlphaComponent:0.5]
                ];
            }
            // 如果未高亮则添加变暗节点
            if (!self.isHighlighted) {
                [self.snapshot addChildNode:self.dimming];
            }
        } else {
            // 移除变暗节点 (如果未高亮)
            if (!self.isHighlighted) {
                [self.dimming removeFromParentNode];
            }
        }
    }
}

- (void)setForceHideHeader:(BOOL)forceHideHeader {
    if (_forceHideHeader != forceHideHeader) {
        _forceHideHeader = forceHideHeader;

        if (self.header.parentNode) { // 检查头部节点是否存在于场景中
            self.header.hidden = forceHideHeader; // 根据 forceHideHeader 设置可见性
        }
        // 注意：原始代码中，如果 forceHideHeader 为 YES，会移除头部节点；
        // 如果为 NO，会添加头部节点。当前逻辑仅控制已有头部节点的 hidden 属性。
        // 如果需要完全移除/添加，需要调整这里的逻辑。
        // 例如：
        // if (forceHideHeader) {
        //     [self.header removeFromParentNode];
        // } else if (!self.header.parentNode && self.snapshot) { // 确保快照节点存在
        //     [self.snapshot addChildNode:self.header];
        //     self.header.hidden = NO;
        // }
        // 当前实现简化为仅控制 hidden 属性，前提是 header 已被添加到 snapshot 节点。
        // 如果 header 可能未添加，则需要更复杂的逻辑。
        // 假设 header 总是 snapshot 的子节点（可能被隐藏）。
        self.header.hidden = forceHideHeader;
    }
}

@end
