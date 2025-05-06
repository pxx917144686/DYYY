// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXScopeCarousel.m
//  FLEX
//
//  由 Tanner Bennett 创建于 7/17/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXScopeCarousel.h"
#import "FLEXCarouselCell.h"
#import "FLEXColor.h"
#import "FLEXMacros.h"
#import "UIView+FLEX_Layout.h"

const CGFloat kCarouselItemSpacing = 0;
NSString * const kCarouselCellReuseIdentifier = @"kCarouselCellReuseIdentifier";

@interface FLEXScopeCarousel () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, readonly) UICollectionView *collectionView;
@property (nonatomic, readonly) FLEXCarouselCell *sizingCell;

@property (nonatomic, readonly) id dynamicTypeObserver;
@property (nonatomic, readonly) NSMutableArray *dynamicTypeHandlers;

@property (nonatomic) BOOL constraintsInstalled;
@end

@implementation FLEXScopeCarousel

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = FLEXColor.primaryBackgroundColor;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.translatesAutoresizingMaskIntoConstraints = YES;
        _dynamicTypeHandlers = [NSMutableArray new];
        
        CGSize itemSize = CGSizeZero;
        if (@available(iOS 10.0, *)) {
            itemSize = UICollectionViewFlowLayoutAutomaticSize;
        }

        // 集合视图布局
        UICollectionViewFlowLayout *layout = ({
            UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
            layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
            layout.sectionInset = UIEdgeInsetsZero;
            layout.minimumLineSpacing = kCarouselItemSpacing;
            layout.itemSize = itemSize;
            layout.estimatedItemSize = itemSize;
            layout;
        });

        // 集合视图
        _collectionView = ({
            UICollectionView *cv = [[UICollectionView alloc]
                initWithFrame:CGRectZero
                collectionViewLayout:layout
            ];
            cv.showsHorizontalScrollIndicator = NO;
            cv.backgroundColor = UIColor.clearColor;
            cv.delegate = self;
            cv.dataSource = self;
            [cv registerClass:[FLEXCarouselCell class] forCellWithReuseIdentifier:kCarouselCellReuseIdentifier];

            [self addSubview:cv];
            cv;
        });


        // 尺寸调整单元格
        _sizingCell = [FLEXCarouselCell new];
        self.sizingCell.title = @"NSObject";

        // 动态类型
        weakify(self);
        _dynamicTypeObserver = [NSNotificationCenter.defaultCenter
            addObserverForName:UIContentSizeCategoryDidChangeNotification
            object:nil queue:nil usingBlock:^(NSNotification *note) { strongify(self)
                [self.collectionView setNeedsLayout];
                [self setNeedsUpdateConstraints];

                // 通知观察者
                for (void (^block)(FLEXScopeCarousel *) in self.dynamicTypeHandlers) {
                    block(self);
                }
            }
        ];
    }

    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self.dynamicTypeObserver];
}

#pragma mark - 重写

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    CGFloat width = 1.f / UIScreen.mainScreen.scale;

    // 绘制发际线
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, FLEXColor.hairlineColor.CGColor);
    CGContextSetLineWidth(context, width);
    CGContextMoveToPoint(context, 0, rect.size.height - width);
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height - width);
    CGContextStrokePath(context);
}

+ (BOOL)requiresConstraintBasedLayout {
    return YES;
}

- (void)updateConstraints {
    if (!self.constraintsInstalled) {
        self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.collectionView flex_pinEdgesToSuperview];
        
        self.constraintsInstalled = YES;
    }
    
    [super updateConstraints];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(
        UIViewNoIntrinsicMetric,
        [self.sizingCell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height
    );
}

#pragma mark - 公开

- (void)setItems:(NSArray<NSString *> *)items {
    NSParameterAssert(items.count);

    _items = items.copy;

    // 刷新列表，初始选择第一项
    [self.collectionView reloadData];
    self.selectedIndex = 0;
}

- (void)setSelectedIndex:(NSInteger)idx {
    NSParameterAssert(idx < self.items.count);

    _selectedIndex = idx;
    NSIndexPath *path = [NSIndexPath indexPathForItem:idx inSection:0];
    [self.collectionView selectItemAtIndexPath:path
                                      animated:YES
                                scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
    [self collectionView:self.collectionView didSelectItemAtIndexPath:path];
}

- (void)registerBlockForDynamicTypeChanges:(void (^)(FLEXScopeCarousel *))handler {
    [self.dynamicTypeHandlers addObject:handler];
}

#pragma mark - UICollectionView

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
//    if (@available(iOS 10.0, *)) {
//        return UICollectionViewFlowLayoutAutomaticSize;
//    }
    
    self.sizingCell.title = self.items[indexPath.item];
    return [self.sizingCell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    FLEXCarouselCell *cell = (id)[collectionView dequeueReusableCellWithReuseIdentifier:kCarouselCellReuseIdentifier
                                                                           forIndexPath:indexPath];
    cell.title = self.items[indexPath.row];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    _selectedIndex = indexPath.item; // 以防 self.selectedIndex 未触发此调用

    if (self.selectedIndexChangedAction) {
        self.selectedIndexChangedAction(indexPath.row);
    }

    // TODO: 动态选择滚动位置。非常宽的项目应该
    // 获取“左对齐”，而较小的项目根本不应滚动，除非
    // 它们仅部分显示在屏幕上，在这种情况下，它们
    // 应该获取“水平居中”以将它们显示在屏幕上。
    // 目前，所有内容都向左滚动，因为这具有类似的效果。
    [collectionView scrollToItemAtIndexPath:indexPath
                           atScrollPosition:UICollectionViewScrollPositionLeft
                                   animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
