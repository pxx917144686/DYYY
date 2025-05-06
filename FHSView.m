// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSView.m
//  FLEX
//
//  Created by Tanner Bennett on 1/6/20.
//

#import "FHSView.h"
#import "FLEXUtility.h"
#import "NSArray+FLEX.h"

@interface FHSView (Snapshotting)
// 快照视图
+ (UIImage *)_snapshotView:(UIView *)view;
@end

@implementation FHSView

+ (instancetype)forView:(UIView *)view isInScrollView:(BOOL)inScrollView {
    return [[self alloc] initWithView:view isInScrollView:inScrollView];
}

- (id)initWithView:(UIView *)view isInScrollView:(BOOL)inScrollView {
    self = [super init];
    if (self) {
        _view = view;
        _inScrollView = inScrollView;
        _identifier = NSUUID.UUID.UUIDString;

        UIViewController *controller = [FLEXUtility viewControllerForView:view];
        if (controller) {
            _important = YES;
            _title = [NSString stringWithFormat:
                @"%@ (for %@)",
                NSStringFromClass([controller class]),
                NSStringFromClass([view class])
            ];
        } else {
            _title = NSStringFromClass([view class]);
        }
    }

    return self;
}

- (CGRect)frame {
    if (_inScrollView) {
        CGPoint offset = [(UIScrollView *)self.view.superview contentOffset];
        return CGRectOffset(self.view.frame, -offset.x, -offset.y);
    } else {
        return self.view.frame;
    }
}

- (BOOL)hidden {
    return self.view.isHidden;
}

- (UIImage *)snapshotImage {
    return [FHSView _snapshotView:self.view];
}

- (NSArray<FHSView *> *)children {
    BOOL isScrollView = [self.view isKindOfClass:[UIScrollView class]];
    return [self.view.subviews flex_mapped:^id(UIView *subview, NSUInteger idx) {
        return [FHSView forView:subview isInScrollView:isScrollView];
    }];
}

- (NSString *)summary {
    CGRect f = self.frame;
    return [NSString stringWithFormat:
        @"%@ (%.1f, %.1f, %.1f, %.1f)",
        NSStringFromClass([self.view class]),
        f.origin.x, f.origin.y, f.size.width, f.size.height
    ];
}

- (NSString *)description{
    return self.view.description;
}

- (id)ifImportant:(id)importantAttr ifNormal:(id)normalAttr {
    return self.important ? importantAttr : normalAttr;
}

@end

@implementation FHSView (Snapshotting)

+ (UIImage *)drawView:(UIView *)view {
    if (CGRectIsEmpty(view.bounds)) {
        return [UIImage new];
    }

    CGSize size = view.bounds.size;
    CGFloat minUnit = 1.f / UIScreen.mainScreen.scale;

    // 每个绘制的视图宽度或高度都不能为 0
    CGSize minsize = CGSizeMake(MAX(size.width, minUnit), MAX(size.height, minUnit));
    CGRect minBounds = CGRectMake(0, 0, minsize.width, minsize.height);

    UIGraphicsBeginImageContextWithOptions(minsize, NO, 0);
    [view drawViewHierarchyInRect:minBounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

/// 递归隐藏所有可能遮挡给定视图的视图，并将它们收集到给定的数组中。
/// 完成后应取消隐藏所有这些视图。
+ (BOOL)_hideViewsCoveringView:(UIView *)view
                          root:(UIView *)rootView
                   hiddenViews:(NSMutableArray<UIView *> *)hiddenViews {
    // 当我们到达此视图时停止
    if (view == rootView) {
        return YES;
    }

    for (UIView *subview in rootView.subviews.reverseObjectEnumerator.allObjects) {
        if ([self _hideViewsCoveringView:view root:subview hiddenViews:hiddenViews]) {
            return YES;
        }
    }

    if (!rootView.isHidden) {
        rootView.hidden = YES;
        [hiddenViews addObject:rootView];
    }

    return NO;
}

/// 递归隐藏所有可能遮挡给定视图的视图，并将它们收集到给定的数组中。
/// 完成后应取消隐藏所有这些视图。
+ (void)hideViewsCoveringView:(UIView *)view doWhileHidden:(void(^)(void))block {
    NSMutableArray *viewsToUnhide = [NSMutableArray new];
    if ([self _hideViewsCoveringView:view root:view.window hiddenViews:viewsToUnhide]) {
        block();
    }

    for (UIView *v in viewsToUnhide) {
        v.hidden = NO;
    }
}

+ (UIImage *)_snapshotVisualEffectBackdropView:(UIView *)view {
    NSParameterAssert(view.window);

    // UIVisualEffectView 是一个特殊情况，不能像其他视图一样进行快照。
    // 来自 Apple 文档：
    //
    //   许多效果需要托管 UIVisualEffectView 的窗口的支持。
    //   尝试仅对 UIVisualEffectView 进行快照将导致快照不包含效果。
    //   要对包含 UIVisualEffectView 的视图层次结构进行快照，
    //   您必须对包含它的整个 UIWindow 或 UIScreen 进行快照。
    //
    // 为了对此视图进行快照，我们从窗口开始遍历视图层次结构，
    // 并隐藏位于 _UIVisualEffectBackdropView 之上的任何视图，
    // 以便它在窗口的快照中可见。然后我们对窗口进行快照，
    // 并将其裁剪到包含背景视图的部分。这似乎与 Xcode 自己的
    // 视图调试器用于快照视觉效果视图的技术相同。
    __block UIImage *image = nil;
    [self hideViewsCoveringView:view doWhileHidden:^{
        // 对窗口进行快照，因为直接快照 UIVisualEffectView 可能无法正确渲染效果
        UIImage *windowSnapshot = [self drawView:view.window];
        // 计算视图在窗口中的位置和大小
        CGRect cropRect = [view.window convertRect:view.bounds fromView:view];
        // 裁剪窗口快照以获取目标视图的图像
        CGImageRef imageRef = CGImageCreateWithImageInRect(windowSnapshot.CGImage, cropRect);
        if (imageRef) {
            image = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        } else {
            // 如果裁剪失败，尝试直接绘制视图作为后备方案
            image = [self drawView:view];
        }
    }];

    return image ?: [UIImage new]; //确保返回非nil
}

+ (UIImage *)_snapshotView:(UIView *)view {
    UIView *superview = view.superview;
    // 此视图是否在 UIVisualEffectView 内部？
    if ([superview isKindOfClass:[UIVisualEffectView class]]) {
        // 它（可能）是此 UIVisualEffectView 的“背景”视图吗？
        if (superview.subviews.firstObject == view) {
            return [self _snapshotVisualEffectBackdropView:view];
        }
    }

    // 在快照之前隐藏视图的子视图
    NSMutableIndexSet *toUnhide = [NSMutableIndexSet new];
    [view.subviews flex_forEach:^(UIView *v, NSUInteger idx) {
        if (!v.isHidden) {
            v.hidden = YES;
            [toUnhide addIndex:idx];
        }
    }];

    // 快照视图，然后取消隐藏先前未隐藏的视图
    UIImage *snapshot = [self drawView:view];
    for (UIView *v in [view.subviews objectsAtIndexes:toUnhide]) {
        v.hidden = NO;
    }

    return snapshot;
}

@end
