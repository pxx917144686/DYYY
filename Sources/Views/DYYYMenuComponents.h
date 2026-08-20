//
//  DYYYMenuComponents.h
//  DYYY
//
//  播放页菜单组件：拖拽按钮、菜单模块与风格构建器（拆分自 AWEPlayInteractionViewController.xm）。
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

// 颜色圆圈图像生成函数
UIImage *createColorCircleImage(UIColor *color, CGSize size);

// 菜单布局样式枚举
typedef NS_ENUM(NSInteger, DYYYMenuStyle) {
    DYYYMenuStyleCard = 0,
    DYYYMenuStyleList = 1
};

// MARK: - 视图模式枚举定义
typedef NS_ENUM(NSInteger, DYYYMenuVisualStyle) {
    DYYYMenuVisualStyleClassic = 0,     // 默认风格
    DYYYMenuVisualStyleNeuomorphic = 1, // 新UI风格
};

// MARK: - 模块配置协议
@protocol DYYYMenuModuleProtocol <NSObject>
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *color;
@property (nonatomic, copy) void (^action)(void);
@end

@interface DYYYDraggableButton : UIButton
@property (nonatomic, assign) NSInteger originalIndex;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) CGPoint originalCenter;
@property (nonatomic, strong, nullable) UIView *dragPreviewView;
@property (nonatomic, assign) BOOL isDragging;
@end

@interface DYYYMenuModule : NSObject <DYYYMenuModuleProtocol>
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *icon;
@property (nonatomic, strong) NSString *color;
@property (nonatomic, copy) void (^action)(void);
+ (instancetype)moduleWithTitle:(NSString *)title icon:(NSString *)icon color:(NSString *)color action:(void(^)(void))action;
@end

@interface DYYYMenuStyleBuilder : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray<DYYYMenuModule *> *modules;
@property (nonatomic, strong) NSMutableArray *moduleViews;
@property (nonatomic, weak) id delegate;

- (instancetype)initWithScrollView:(UIScrollView *)scrollView modules:(NSArray<DYYYMenuModule *> *)modules;
- (void)buildMenuWithAnimation:(BOOL)animated;
- (void)clearExistingViews;

// 子类需要重写的方法
- (UIView *)createModuleViewForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index;
- (CGSize)calculateContentSize;
- (void)animateModuleViews:(NSArray *)views;
@end

@interface DYYYCardStyleBuilder : DYYYMenuStyleBuilder
@end

@interface DYYYListStyleBuilder : DYYYMenuStyleBuilder
@end

@interface DYYYNeuomorphicStyleBuilder : DYYYMenuStyleBuilder
- (UIView *)createNeuomorphicListItemForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index;
@end

@interface DYYYNeuomorphicStyleBuilder (ListViewFix)
- (UIView *)createNeuomorphicListItemForModule:(DYYYMenuModule *)module atIndex:(NSInteger)index;
@end

NS_ASSUME_NONNULL_END
