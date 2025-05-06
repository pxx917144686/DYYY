// 遇到问题联系中文翻译作者：pxx917144686
//
//  SceneKit+Snapshot.m
//  FLEX
//
//  由 Tanner Bennett 创建于 1/8/20.
//

#import "SceneKit+Snapshot.h"
#import "FHSSnapshotNodes.h"

/// 选择此值是为了应用此偏移量以避免
/// 相同 z 位置节点之间的 z-fighting（闪烁），但该值又足够小
/// 使得它们在视觉上看起来在同一平面上。
CGFloat const kFHSSmallZOffset = 0.05;
CGFloat const kHeaderVerticalInset = 8.0;

#pragma mark SCNGeometry
@interface SCNGeometry (SnapshotPrivate)
@end
@implementation SCNGeometry (SnapshotPrivate)

- (void)addDoubleSidedMaterialWithDiffuseContents:(id)contents {
    SCNMaterial *material = [SCNMaterial new];
    material.doubleSided = YES;
    material.diffuse.contents = contents;
    [self insertMaterial:material atIndex:0];
}

@end

#pragma mark SCNNode
@implementation SCNNode (Snapshot)

- (SCNNode *)nearestAncestorSnapshot {
    SCNNode *node = self;

    while (!node.name && node) {
        node = node.parentNode;
    }

    return node;
}

+ (instancetype)shapeNodeWithSize:(CGSize)size materialDiffuse:(id)contents offsetZ:(BOOL)offsetZ {
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(
        0, 0, size.width, size.height
    )];
    SCNShape *shape = [SCNShape shapeWithPath:path materialDiffuse:contents];
    SCNNode *node = [SCNNode nodeWithGeometry:shape];
    
    if (offsetZ) {
        node.position = SCNVector3Make(0, 0, kFHSSmallZOffset);
    }
    return node;
}

+ (instancetype)highlight:(FHSViewSnapshot *)view color:(UIColor *)color {
    return [self shapeNodeWithSize:view.frame.size materialDiffuse:color offsetZ:YES];
}

+ (instancetype)snapshot:(FHSViewSnapshot *)view {
    id image = view.snapshotImage;
    return [self shapeNodeWithSize:view.frame.size materialDiffuse:image offsetZ:NO];
}

+ (instancetype)lineFrom:(SCNVector3)v1 to:(SCNVector3)v2 color:(UIColor *)lineColor {
    SCNVector3 vertices[2] = { v1, v2 };
    int32_t _indices[2] = { 0, 1 };
    NSData *indices = [NSData dataWithBytes:_indices length:sizeof(_indices)];
    
    SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithVertices:vertices count:2];
    SCNGeometryElement *element = [SCNGeometryElement
        geometryElementWithData:indices
        primitiveType:SCNGeometryPrimitiveTypeLine
        primitiveCount:2
        bytesPerIndex:sizeof(int32_t)
    ];

    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[source] elements:@[element]];
    [geometry addDoubleSidedMaterialWithDiffuseContents:lineColor];
    return [SCNNode nodeWithGeometry:geometry];
}

- (instancetype)borderWithColor:(UIColor *)color {
    struct { SCNVector3 min, max; } bb;
    [self getBoundingBoxMin:&bb.min max:&bb.max];

    SCNVector3 topLeft = SCNVector3Make(bb.min.x, bb.max.y, kFHSSmallZOffset);
    SCNVector3 bottomLeft = SCNVector3Make(bb.min.x, bb.min.y, kFHSSmallZOffset);
    SCNVector3 topRight = SCNVector3Make(bb.max.x, bb.max.y, kFHSSmallZOffset);
    SCNVector3 bottomRight = SCNVector3Make(bb.max.x, bb.min.y, kFHSSmallZOffset);

    SCNNode *top = [SCNNode lineFrom:topLeft to:topRight color:color];
    SCNNode *left = [SCNNode lineFrom:bottomLeft to:topLeft color:color];
    SCNNode *bottom = [SCNNode lineFrom:bottomLeft to:bottomRight color:color];
    SCNNode *right = [SCNNode lineFrom:bottomRight to:topRight color:color];

    SCNNode *border = [SCNNode new];
    [border addChildNode:top];
    [border addChildNode:left];
    [border addChildNode:bottom];
    [border addChildNode:right];

    return border;
}

+ (instancetype)header:(FHSViewSnapshot *)view {
    SCNText *text = [SCNText labelGeometry:view.title font:[UIFont boldSystemFontOfSize:13.0]];
    SCNNode *textNode = [SCNNode nodeWithGeometry:text];

    struct { SCNVector3 min, max; } bb;
    [textNode getBoundingBoxMin:&bb.min max:&bb.max];
    CGFloat textWidth = bb.max.x - bb.min.x;
    CGFloat textHeight = bb.max.y - bb.min.y;

    CGFloat snapshotWidth = view.frame.size.width;
    CGFloat headerWidth = MAX(snapshotWidth, textWidth);
    CGRect frame = CGRectMake(0, 0, headerWidth, textHeight + (kHeaderVerticalInset * 2));
    SCNNode *headerNode = [SCNNode nodeWithGeometry:[SCNShape
        nameHeader:view.headerColor frame:frame corners:8
    ]];
    [headerNode addChildNode:textNode];

    textNode.position = SCNVector3Make(
        (frame.size.width / 2.f) - (textWidth / 2.f),
        (frame.size.height / 2.f) - (textHeight / 2.f),
        kFHSSmallZOffset
    );
    headerNode.position = SCNVector3Make(
       (snapshotWidth / 2.f) - (headerWidth / 2.f),
       view.frame.size.height,
       kFHSSmallZOffset
    );

    return headerNode;
}

+ (instancetype)snapshot:(FHSViewSnapshot *)view
                  parent:(FHSViewSnapshot *)parent
              parentNode:(SCNNode *)parentNode
                    root:(SCNNode *)rootNode
                   depth:(NSInteger *)depthOut
                nodesMap:(NSMutableDictionary<NSString *, FHSSnapshotNodes *> *)nodesMap
             hideHeaders:(BOOL)hideHeaders {
    NSInteger const depth = *depthOut;

    // 忽略不可见的元素。
    // 这些元素应出现在列表中，但不应出现在 3D 视图中。
    if (view.hidden || CGSizeEqualToSize(view.frame.size, CGSizeZero)) {
        return nil;
    }

    // 创建一个节点，其内容是元素的快照
    SCNNode *node = [self snapshot:view];
    node.name = view.view.identifier;

    // 开始构建节点树
    FHSSnapshotNodes *nodes = [FHSSnapshotNodes snapshot:view depth:depth];
    nodes.snapshot = node;

    // 节点必须添加到根节点
    // 以便下面的坐标空间计算能够正常工作
    [rootNode addChildNode:node];
    node.position = ({
        // 翻转 y 坐标，因为 SceneKit 的坐标系
        // 与 UIKit 的坐标系 y 轴相反
        CGRect pframe = parent ? parent.frame : CGRectZero;
        CGFloat y = parent ? pframe.size.height - CGRectGetMaxY(view.frame) : 0;

        // 为了简化计算层之间的 z 轴间距，我们将
        // 每个快照节点都作为根节点的直接子节点，而不是将
        // 节点嵌入其父节点中（与 UI 元素本身的结构相同）。
        // 通过这种扁平化层次结构，只需将间距乘以深度，
        // 即可计算每个节点的 z 位置。
        //
        // 此处引用的 `parentSnapshotNode` 不是 `node` 的实际父节点，
        // 它是对应于 UI 元素父节点的节点。
        // 它用于将相对于父节点边界的帧坐标转换
        // 为相对于根节点的坐标。
        SCNVector3 positionRelativeToParent = SCNVector3Make(view.frame.origin.x, y, 0);
        SCNVector3 positionRelativeToRoot;
        if (parent) {
            positionRelativeToRoot = [rootNode convertPosition:positionRelativeToParent fromNode:parentNode];
        } else {
            positionRelativeToRoot = positionRelativeToParent;
        }
        positionRelativeToRoot.z = 50 * depth;
        positionRelativeToRoot;
    });

    // 创建边框节点
    nodes.border = [node borderWithColor:view.headerColor];
    [node addChildNode:nodes.border];

    // 创建头部节点
    nodes.header = [SCNNode header:view];
    [node addChildNode:nodes.header];
    if (hideHeaders) {
        nodes.header.hidden = YES;
    }

    nodesMap[view.view.identifier] = nodes;

    NSMutableArray<FHSViewSnapshot *> *checkForIntersect = [NSMutableArray new];
    NSInteger maxChildDepth = depth;

    // 递归到子节点；重叠的子节点具有更高的深度
    for (FHSViewSnapshot *child in view.children) {
        NSInteger childDepth = depth + 1;

        // 与同级节点相交的子节点将渲染在
        // 先前同级节点之上的单独图层中
        for (FHSViewSnapshot *sibling in checkForIntersect) {
            if (CGRectIntersectsRect(sibling.frame, child.frame)) {
                childDepth = maxChildDepth + 1;
                break;
            }
        }

        id didMakeNode = [SCNNode
            snapshot:child
            parent:view
            parentNode:node
            root:rootNode
            depth:&childDepth
            nodesMap:nodesMap
            hideHeaders:hideHeaders
        ];
        if (didMakeNode) {
            maxChildDepth = MAX(childDepth, maxChildDepth);
            [checkForIntersect addObject:child];
        }
    }

    *depthOut = maxChildDepth;
    return node;
}

@end


#pragma mark SCNShape
@implementation SCNShape (Snapshot)

+ (instancetype)shapeWithPath:(UIBezierPath *)path materialDiffuse:(id)contents {
    SCNShape *shape = [SCNShape shapeWithPath:path extrusionDepth:0];
    [shape addDoubleSidedMaterialWithDiffuseContents:contents];
    return shape;
}

+ (instancetype)nameHeader:(UIColor *)color frame:(CGRect)frame corners:(CGFloat)radius {
    UIBezierPath *path = [UIBezierPath
        bezierPathWithRoundedRect:frame
        byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight
        cornerRadii:CGSizeMake(radius, radius)
    ];
    return [SCNShape shapeWithPath:path materialDiffuse:color];
}

@end


#pragma mark SCNText
@implementation SCNText (Snapshot)

+ (instancetype)labelGeometry:(NSString *)text font:(UIFont *)font {
    NSParameterAssert(text);

    SCNText *label = [self new];
    label.string = text;
    label.font = font;
    label.alignmentMode = kCAAlignmentCenter;
    label.truncationMode = kCATruncationEnd;

    return label;
}

@end
