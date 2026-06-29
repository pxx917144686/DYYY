//
//  SceneKit+Snapshot.m
//  FLEX
//
//  Created by Tanner Bennett on 1/8/20.
//

#import "SceneKit+Snapshot.h"
#import "FHSSnapshotNodes.h"

/// 选择这个值是为了避免在相同z位置的节点之间发生z轴冲突，
/// 但又足够小以至于它们在视觉上看起来处于同一平面。
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
    // 这些应该出现在列表中，但不在3D视图中。
    if (view.hidden || CGSizeEqualToSize(view.frame.size, CGSizeZero)) {
        return nil;
    }

    // 创建一个节点，其内容是元素的快照
    SCNNode *node = [self snapshot:view];
    node.name = view.view.identifier;

    // 开始构建节点树
    FHSSnapshotNodes *nodes = [FHSSnapshotNodes snapshot:view depth:depth];
    nodes.snapshot = node;

    // 必须将节点添加到根节点
    // 以便下面的坐标空间计算正常工作
    [rootNode addChildNode:node];
    node.position = ({
        // 翻转y坐标，因为SceneKit使用的是
        // UIKit坐标系统的翻转版本
        CGRect pframe = parent ? parent.frame : CGRectZero;
        CGFloat y = parent ? pframe.size.height - CGRectGetMaxY(view.frame) : 0;

        // 为了简化层之间z轴间距的计算，我们使
        // 每个快照节点成为根的直接子节点，而不是将节点
        // 嵌入到它们的父节点中，与UI元素结构相同。
        // 有了这种扁平的层次结构，z位置可以
        // 通过简单地将间距乘以深度来计算每个节点。
        //
        // 这里引用的`parentSnapshotNode`实际上不是`node`的实际父节点，
        // 它是对应于UI元素父级的节点。
        // 它用于将帧坐标从相对于父级的边界
        // 转换为相对于根节点的坐标。
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

        // 与兄弟节点相交的子节点在
        // 前面兄弟节点的上层单独渲染
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
