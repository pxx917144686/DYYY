#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXLookinDisplayItem : NSObject

@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) CALayer *layer;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, assign) BOOL isExpandable;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL inNoPreviewHierarchy;
@property (nonatomic, assign) BOOL representedForSystemClass;
@property (nonatomic, strong) NSArray<FLEXLookinDisplayItem *> *children;

// 搜索和匹配
- (BOOL)isMatchedWithSearchString:(NSString *)string;

// 层次遍历
- (void)enumerateSelfAndAncestors:(void (^)(FLEXLookinDisplayItem *item, BOOL *stop))block;
- (void)enumerateSelfAndChildren:(void (^)(FLEXLookinDisplayItem *item))block;

// Frame计算
- (BOOL)hasValidFrameToRoot;
- (CGRect)calculateFrameToRoot;

// 预览能力
- (BOOL)hasPreviewBoxAbility;
- (UIImage *)appropriateScreenshot;

@end

NS_ASSUME_NONNULL_END