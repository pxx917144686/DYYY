// filepath: SceneKit+Snapshot.h
// 遇到问题联系中文翻译作者：pxx917144686
//
//  SceneKit+Snapshot.h
//  FLEX
//
//  由 Tanner Bennett 创建于 1/8/20.
//

#import <SceneKit/SceneKit.h>
#import "FHSViewSnapshot.h"
@class FHSSnapshotNodes;

extern CGFloat const kFHSSmallZOffset;

#pragma mark SCNNode
@interface SCNNode (Snapshot)

/// @return 从此节点开始的最近的祖先快照节点
@property (nonatomic, readonly) SCNNode *nearestAncestorSnapshot;

/// @return 渲染指定快照高亮覆盖层的节点
+ (instancetype)highlight:(FHSViewSnapshot *)view color:(UIColor *)color;
/// @return 渲染快照图像的节点
+ (instancetype)snapshot:(FHSViewSnapshot *)view;
/// @return 在两个顶点之间绘制线条的节点
+ (instancetype)lineFrom:(SCNVector3)v1 to:(SCNVector3)v2 color:(UIColor *)lineColor;

/// @return 可用于在指定节点周围渲染彩色边框的节点
- (instancetype)borderWithColor:(UIColor *)color;
/// @return 在快照节点上方渲染标题的节点
///         如果指定，则使用视图中的标题文本
+ (instancetype)header:(FHSViewSnapshot *)view;

/// @return 一个 SceneKit 节点，用于从指定的快照开始递归渲染 UI 元素的层级结构
+ (instancetype)snapshot:(FHSViewSnapshot *)view
                  parent:(FHSViewSnapshot *)parentView
              parentNode:(SCNNode *)parentNode
                    root:(SCNNode *)rootNode
                   depth:(NSInteger *)depthOut
                nodesMap:(NSMutableDictionary<NSString *, FHSSnapshotNodes *> *)nodesMap
             hideHeaders:(BOOL)hideHeaders;

@end


#pragma mark SCNShape
@interface SCNShape (Snapshot)
/// @return 一个具有给定路径、0 拉伸深度以及在索引 0 处插入了具有给定漫反射内容的双面材质的形状
+ (instancetype)shapeWithPath:(UIBezierPath *)path materialDiffuse:(id)contents;
/// @return 用于渲染快照标题背景的形状
+ (instancetype)nameHeader:(UIColor *)color frame:(CGRect)frame corners:(CGFloat)cornerRadius;

@end


#pragma mark SCNText
@interface SCNText (Snapshot)
/// @return 用于在快照标题内渲染文本的文本几何体
+ (instancetype)labelGeometry:(NSString *)text font:(UIFont *)font;

@end
