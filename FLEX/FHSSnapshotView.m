// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSSnapshotView.m
//  FLEX
//
//  Created by Tanner Bennett on 1/7/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FHSSnapshotView.h"
#import "FHSSnapshotNodes.h"
#import "SceneKit+Snapshot.h"
#import "FLEXColor.h"

@interface FHSSnapshotView ()
@property (nonatomic, readonly) SCNView *sceneView;
@property (nonatomic) NSString *currentSummary;

/// 通过快照 ID 映射节点
@property (nonatomic) NSDictionary<NSString *, FHSSnapshotNodes *> *nodesMap;
@property (nonatomic) NSInteger maxDepth;

@property (nonatomic) FHSSnapshotNodes *highlightedNodes;
@property (nonatomic, getter=wantsHideHeaders) BOOL hideHeaders;
@property (nonatomic, getter=wantsHideBorders) BOOL hideBorders;
@property (nonatomic) BOOL suppressSelectionEvents;

@property (nonatomic, readonly) BOOL mustHideHeaders;
@end

@implementation FHSSnapshotView

#pragma mark - 初始化

+ (instancetype)delegate:(id<FHSSnapshotViewDelegate>)delegate {
    FHSSnapshotView *view = [self new];
    view.delegate = delegate;
    return view;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self initSpacingSlider];
        [self initDepthSlider];
        [self initSceneView]; // 必须最后调用；调用 setMaxDepth
//        self.hideHeaders = YES; // 默认隐藏头部

            // 自身视图设置
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // 场景视图设置
        self.sceneView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(handleTap:)
        ]];
    }

    return self;
}

- (void)initSceneView {
    _sceneView = [SCNView new];
    self.sceneView.allowsCameraControl = YES; // 允许相机控制

    [self addSubview:self.sceneView];
}

- (void)initSpacingSlider {
    _spacingSlider = [UISlider new];
    self.spacingSlider.minimumValue = 0;
    self.spacingSlider.maximumValue = 100;
    self.spacingSlider.continuous = YES; // 连续更新
    [self.spacingSlider
        addTarget:self
        action:@selector(spacingSliderDidChange:)
        forControlEvents:UIControlEventValueChanged
    ];

    self.spacingSlider.value = 50; // 默认间距值
}

- (void)initDepthSlider {
    _depthSlider = [FHSRangeSlider new];
    [self.depthSlider
        addTarget:self
        action:@selector(depthSliderDidChange:)
        forControlEvents:UIControlEventValueChanged
    ];
}


#pragma mark - 公共方法

- (void)setSelectedView:(FHSViewSnapshot *)view {
    // 在 selectSnapshot: 中设置实例变量
    [self selectSnapshot:view ? self.nodesMap[view.view.identifier] : nil];
}

- (void)setSnapshots:(NSArray<FHSViewSnapshot *> *)snapshots {
    _snapshots = snapshots;

    // 创建新场景（可能会丢弃旧场景）
    SCNScene *scene = [SCNScene new];
    scene.background.contents = FLEXColor.primaryBackgroundColor; // 设置背景色
    self.sceneView.scene = scene;

    NSInteger depth = 0;
    NSMutableDictionary *nodesMap = [NSMutableDictionary new];

    // 将每个根快照添加到根场景节点，并增加深度
    SCNNode *root = scene.rootNode;
    for (FHSViewSnapshot *snapshot in self.snapshots) {
        [SCNNode
            snapshot:snapshot
            parent:nil
            parentNode:nil
            root:root
            depth:&depth
            nodesMap:nodesMap
            hideHeaders:_hideHeaders
        ];
    }

    self.maxDepth = depth;
    self.nodesMap = nodesMap;
}

- (void)setHeaderExclusions:(NSArray<Class> *)headerExclusions {
    _headerExclusions = headerExclusions;

    if (headerExclusions.count) {
        for (FHSSnapshotNodes *nodes in self.nodesMap.allValues) {
            // 如果视图类在排除列表中，则强制隐藏其头部
            if ([headerExclusions containsObject:nodes.snapshotItem.view.view.class]) {
                nodes.forceHideHeader = YES;
            } else {
                nodes.forceHideHeader = NO;
            }
        }
    }
}

- (void)emphasizeViews:(NSArray<UIView *> *)emphasizedViews {
    if (emphasizedViews.count) {
        [self emphasizeViews:emphasizedViews inSnapshots:self.snapshots];
        [self setNeedsLayout]; // 需要重新布局
    }
}

- (void)emphasizeViews:(NSArray<UIView *> *)emphasizedViews inSnapshots:(NSArray<FHSViewSnapshot *> *)snapshots {
    for (FHSViewSnapshot *snapshot in snapshots) {
        FHSSnapshotNodes *nodes = self.nodesMap[snapshot.view.identifier];
        // 如果视图不在强调列表中，则将其变暗
        nodes.dimmed = ![emphasizedViews containsObject:snapshot.view.view];
        // 递归处理子视图
        [self emphasizeViews:emphasizedViews inSnapshots:snapshot.children];
    }
}

- (void)toggleShowHeaders {
    self.hideHeaders = !self.hideHeaders; // 切换头部显示状态
}

- (void)toggleShowBorders {
    self.hideBorders = !self.hideBorders; // 切换边框显示状态
}

- (void)hideView:(FHSViewSnapshot *)view {
    NSParameterAssert(view); // 确保视图不为空
    FHSSnapshotNodes *nodes = self.nodesMap[view.view.identifier];
    [nodes.snapshot removeFromParentNode]; // 从父节点移除快照
}

#pragma mark - 辅助方法

- (BOOL)mustHideHeaders {
    // 当间距滑块的值小于或等于最小 Z 偏移量时，必须隐藏头部
    return self.spacingSlider.value <= kFHSSmallZOffset;
}

- (void)setMaxDepth:(NSInteger)maxDepth {
    _maxDepth = maxDepth;

    // 设置深度滑块的允许范围和当前值
    self.depthSlider.allowedMinValue = 0;
    self.depthSlider.allowedMaxValue = maxDepth;
    self.depthSlider.maxValue = maxDepth;
    self.depthSlider.minValue = 0;
}

- (void)setHideHeaders:(BOOL)hideHeaders {
    if (_hideHeaders != hideHeaders) {
        _hideHeaders = hideHeaders;

        // 如果不是必须隐藏头部的情况
        if (!self.mustHideHeaders) {
            if (hideHeaders) {
                [self hideHeaders]; // 隐藏所有头部
            } else {
                [self unhideHeaders]; // 显示所有头部（除非被强制隐藏）
            }
        }
    }
}

- (void)setHideBorders:(BOOL)hideBorders {
    if (_hideBorders != hideBorders) {
        _hideBorders = hideBorders;

        // 更新所有节点的边框可见性
        for (FHSSnapshotNodes *nodes in self.nodesMap.allValues) {
            nodes.border.hidden = hideBorders;
        }
    }
}

- (FHSSnapshotNodes *)nodesAtPoint:(CGPoint)point {
    // 在指定点进行命中测试
    NSArray<SCNHitTestResult *> *results = [self.sceneView hitTest:point options:nil];
    for (SCNHitTestResult *result in results) {
        // 找到最近的祖先快照节点
        SCNNode *nearestSnapshot = result.node.nearestAncestorSnapshot;
        if (nearestSnapshot) {
            // 返回对应的节点对象
            return self.nodesMap[nearestSnapshot.name];
        }
    }

    return nil; // 未找到节点
}

- (void)selectSnapshot:(FHSSnapshotNodes *)selected {
    // 如果取消选择且当前有选中的视图，通知代理
    if (!selected && self.selectedView) {
        [self.delegate didDeselectView:self.selectedView];
    }

    _selectedView = selected.snapshotItem; // 更新当前选中的视图快照

    // 情况：选择了当前已选中的节点
    if (selected == self.highlightedNodes) {
        return; // 无需操作
    }

    // 如果没有高亮节点，则取消高亮（安全操作）
    self.highlightedNodes.highlighted = NO;
    self.highlightedNodes = nil;

    // 如果 selected 不为 nil，表示点击了某个节点，而不是背景
    if (selected) {
        selected.highlighted = YES; // 高亮新选中的节点
        // TODO: 在这里更新描述文本
        self.highlightedNodes = selected; // 更新高亮节点引用
    }

    // 通知代理选择了新视图
    [self.delegate didSelectView:selected.snapshotItem];

    [self setNeedsLayout]; // 需要重新布局
}

- (void)hideHeaders {
    // 隐藏所有节点的头部
    for (FHSSnapshotNodes *nodes in self.nodesMap.allValues) {
        nodes.header.hidden = YES;
    }
}

- (void)unhideHeaders {
    // 显示所有节点的头部，除非被强制隐藏
    for (FHSSnapshotNodes *nodes in self.nodesMap.allValues) {
        if (!nodes.forceHideHeader) {
            nodes.header.hidden = NO;
        }
    }
}


#pragma mark - 事件处理

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        // 获取点击位置并选择对应的节点
        CGPoint tap = [gesture locationInView:self.sceneView];
        [self selectSnapshot:[self nodesAtPoint:tap]];
    }
}

- (void)spacingSliderDidChange:(UISlider *)slider {
    // TODO: 处理平铺时隐藏头部的逻辑

    // 更新所有节点的 Z 轴位置
    for (FHSSnapshotNodes *nodes in self.nodesMap.allValues) {
        nodes.snapshot.position = ({
            SCNVector3 pos = nodes.snapshot.position;
            // Z 位置 = (滑块值 或 最小偏移量) * 深度
            pos.z = MAX(slider.value, kFHSSmallZOffset) * nodes.depth;
            pos;
        });

        // 如果用户没有主动要求隐藏头部
        if (!self.wantsHideHeaders) {
            // 根据间距决定是否必须隐藏头部
            if (self.mustHideHeaders) {
                [self hideHeaders];
            } else {
                [self unhideHeaders];
            }
        }
    }
}

- (void)depthSliderDidChange:(FHSRangeSlider *)slider {
    CGFloat min = slider.minValue, max = slider.maxValue;
    // 根据深度范围更新节点的可见性
    for (FHSSnapshotNodes *nodes in self.nodesMap.allValues) {
        CGFloat depth = nodes.depth;
        nodes.snapshot.hidden = depth < min || max < depth; // 隐藏范围之外的节点
    }
}

@end
