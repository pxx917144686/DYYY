#import "FLEXDoKitComponentViewController.h"
#import "FLEXCompatibility.h"  // ✅ 兼容性头文件

@interface FLEXDoKitComponentViewController ()
@property (nonatomic, strong) UIView *overlayWindow;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UIView *highlightView;
@property (nonatomic, assign) BOOL isInspecting;
@end

@implementation FLEXDoKitComponentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"组件检查器";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
}

- (void)setupUI {
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [startButton setTitle:@"开始检查" forState:UIControlStateNormal];
    [startButton setTitle:@"停止检查" forState:UIControlStateSelected];
    startButton.backgroundColor = FLEXSystemBlueColor;
    [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startButton.layer.cornerRadius = 8;
    [startButton addTarget:self action:@selector(toggleInspecting:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *instructionLabel = [[UILabel alloc] init];
    instructionLabel.text = @"开启后点击屏幕任意UI元素查看组件信息";
    instructionLabel.numberOfLines = 0;
    instructionLabel.textAlignment = NSTextAlignmentCenter;
    instructionLabel.font = [UIFont systemFontOfSize:16];
    instructionLabel.textColor = FLEXSystemGrayColor;
    
    // 信息展示区域
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.font = [UIFont fontWithName:@"Courier" size:12];
    self.infoLabel.backgroundColor = FLEXSecondarySystemBackgroundColor;
    self.infoLabel.textColor = FLEXLabelColor;
    self.infoLabel.text = @"点击开始检查后，触摸任意UI元素查看详细信息";
    self.infoLabel.textAlignment = NSTextAlignmentLeft;
    self.infoLabel.layer.cornerRadius = 8;
    self.infoLabel.layer.masksToBounds = YES;
    
    // 添加内边距
    self.infoLabel.layer.borderWidth = 1;
    self.infoLabel.layer.borderColor = FLEXSeparatorColor.CGColor;  // ✅ 使用兼容性宏
    
    // 布局
    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        instructionLabel,
        startButton,
        self.infoLabel
    ]];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 20;
    stackView.alignment = UIStackViewAlignmentFill;
    
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [startButton.heightAnchor constraintEqualToConstant:44],
        [self.infoLabel.heightAnchor constraintGreaterThanOrEqualToConstant:200]
    ]];
}

- (void)toggleInspecting:(UIButton *)sender {
    self.isInspecting = !self.isInspecting;
    sender.selected = self.isInspecting;
    
    if (self.isInspecting) {
        [self startInspecting];
    } else {
        [self stopInspecting];
    }
}

- (void)startInspecting {
    // 创建全屏覆盖视图用于捕获触摸事件
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    // CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;  // 删除这行
    self.overlayWindow = [[UIView alloc] initWithFrame:screenBounds];
    self.overlayWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1];
    self.overlayWindow.userInteractionEnabled = YES;
    
    // 添加点击手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handleTap:)];
    [self.overlayWindow addGestureRecognizer:tapGesture];
    
    // 获取当前应用的关键窗口并添加覆盖层
    UIWindow *keyWindow = [self getKeyWindow];
    if (keyWindow) {
        [keyWindow addSubview:self.overlayWindow];
    }
    
    self.infoLabel.text = @"检查模式已启用\n触摸任意UI元素查看信息";
}

- (void)stopInspecting {
    [self.overlayWindow removeFromSuperview];
    self.overlayWindow = nil;
    
    [self.highlightView removeFromSuperview];
    self.highlightView = nil;
    
    self.infoLabel.text = @"检查模式已关闭";
}

- (UIWindow *)getKeyWindow {
    // iOS 13+ 兼容性处理
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIWindowScene *windowScene in connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        return window;
                    }
                }
            }
        }
        
        // 如果没找到keyWindow，返回第一个window
        for (UIWindowScene *windowScene in connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene.windows.firstObject;
            }
        }
    }
    
    // iOS 12及以下版本的fallback
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.overlayWindow];
    
    // 查找被点击的视图
    UIWindow *keyWindow = [self getKeyWindow];
    UIView *hitView = [keyWindow hitTest:location withEvent:nil];
    
    if (hitView && hitView != self.overlayWindow) {
        [self inspectView:hitView];
        [self highlightView:hitView];
    }
}

- (void)inspectView:(UIView *)view {
    NSMutableString *info = [NSMutableString string];
    
    // 基本信息
    [info appendFormat:@"类名: %@\n", NSStringFromClass([view class])];
    [info appendFormat:@"内存地址: %p\n", view];
    [info appendFormat:@"Frame: %@\n", NSStringFromCGRect(view.frame)];
    [info appendFormat:@"Bounds: %@\n", NSStringFromCGRect(view.bounds)];
    [info appendFormat:@"Hidden: %@\n", view.hidden ? @"YES" : @"NO"];
    [info appendFormat:@"Alpha: %.2f\n", view.alpha];
    [info appendFormat:@"Tag: %ld\n", (long)view.tag];
    
    // 层次信息
    [info appendFormat:@"父视图: %@\n", view.superview ? NSStringFromClass([view.superview class]) : @"无"];
    [info appendFormat:@"子视图数量: %lu\n", (unsigned long)view.subviews.count];
    
    // 特殊属性
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        [info appendFormat:@"文本: %@\n", label.text ?: @"无"];
        [info appendFormat:@"字体: %@\n", label.font.fontName];
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        [info appendFormat:@"标题: %@\n", [button titleForState:UIControlStateNormal] ?: @"无"];
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        [info appendFormat:@"图片: %@\n", imageView.image ? @"有图片" : @"无图片"];
    }
    
    self.infoLabel.text = info;
}

- (void)highlightView:(UIView *)view {
    // 移除之前的高亮
    [self.highlightView removeFromSuperview];
    
    // 创建新的高亮视图
    self.highlightView = [[UIView alloc] initWithFrame:view.frame];
    self.highlightView.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.3];
    self.highlightView.layer.borderWidth = 2;
    self.highlightView.layer.borderColor = [UIColor systemRedColor].CGColor;
    self.highlightView.userInteractionEnabled = NO;
    
    // 添加到父视图中
    if (view.superview) {
        [view.superview addSubview:self.highlightView];
        
        // 2秒后自动移除高亮
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.highlightView removeFromSuperview];
            self.highlightView = nil;
        });
    }
}

@end