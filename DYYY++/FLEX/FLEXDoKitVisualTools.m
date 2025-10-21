#import "FLEXDoKitVisualTools.h"

@interface FLEXDoKitVisualTools ()
@property (nonatomic, strong) UIWindow *colorPickerWindow;
@property (nonatomic, strong) UIView *rulerView;
@property (nonatomic, strong) UIView *borderOverlayView;
@property (nonatomic, strong) UIView *layoutBoundsView;
@property (nonatomic, assign) BOOL isColorPickerActive;
@property (nonatomic, assign) BOOL isRulerVisible;
@property (nonatomic, assign) BOOL areBordersVisible;
@property (nonatomic, assign) BOOL areLayoutBoundsVisible;
@end

@implementation FLEXDoKitVisualTools

+ (instancetype)sharedInstance {
    static FLEXDoKitVisualTools *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - 颜色吸管

- (void)startColorPicker {
    if (self.isColorPickerActive) return;
    
    self.isColorPickerActive = YES;
    
    // 创建全屏覆盖窗口
    self.colorPickerWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.colorPickerWindow.windowLevel = UIWindowLevelAlert + 100;
    self.colorPickerWindow.backgroundColor = [UIColor clearColor];
    self.colorPickerWindow.hidden = NO;
    
    // 添加手势识别
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                         initWithTarget:self 
                                         action:@selector(handleColorPickerTap:)];
    [self.colorPickerWindow addGestureRecognizer:tapGesture];
    
    // 显示提示
    [self showColorPickerHUD];
}

- (void)stopColorPicker {
    self.isColorPickerActive = NO;
    self.colorPickerWindow.hidden = YES;
    self.colorPickerWindow = nil;
}

- (void)handleColorPickerTap:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.colorPickerWindow];
    UIColor *color = [self getColorAtPoint:location];
    
    [self showColorInfo:color atPoint:location];
}

- (UIColor *)getColorAtPoint:(CGPoint)point {
    // 获取屏幕截图
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 0);
    [[UIApplication sharedApplication].keyWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // 获取像素颜色
    CGImageRef imageRef = screenshot.CGImage;
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    
    if (point.x < 0 || point.x >= width || point.y < 0 || point.y >= height) {
        return [UIColor blackColor];
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = malloc(4);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * 1;
    NSUInteger bitsPerComponent = 8;
    
    CGContextRef context = CGBitmapContextCreate(rawData, 1, 1, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(-point.x, -point.y, width, height), imageRef);
    CGContextRelease(context);
    
    CGFloat red = rawData[0] / 255.0;
    CGFloat green = rawData[1] / 255.0;
    CGFloat blue = rawData[2] / 255.0;
    CGFloat alpha = rawData[3] / 255.0;
    
    free(rawData);
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

- (void)showColorInfo:(UIColor *)color atPoint:(CGPoint)point {
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    NSString *hexColor = [NSString stringWithFormat:@"#%02X%02X%02X", 
                         (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"颜色信息" 
                                                                   message:[NSString stringWithFormat:@"RGB: (%.0f, %.0f, %.0f)\nHex: %@", red*255, green*255, blue*255, hexColor]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = hexColor;
    }];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self stopColorPicker];
    }];
    
    [alert addAction:copyAction];
    [alert addAction:closeAction];
    
    UIViewController *topViewController = [self topViewController];
    [topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showColorPickerHUD {
    // 显示使用提示
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"点击屏幕获取颜色\n双击退出";
    hintLabel.numberOfLines = 2;
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    hintLabel.textColor = [UIColor whiteColor];
    hintLabel.layer.cornerRadius = 8;
    hintLabel.clipsToBounds = YES;
    hintLabel.frame = CGRectMake(0, 0, 200, 60);
    hintLabel.center = CGPointMake(self.colorPickerWindow.bounds.size.width / 2, 100);
    
    [self.colorPickerWindow addSubview:hintLabel];
    
    // 添加双击手势退出
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] 
                                        initWithTarget:self 
                                        action:@selector(stopColorPicker)];
    doubleTap.numberOfTapsRequired = 2;
    [self.colorPickerWindow addGestureRecognizer:doubleTap];
}

#pragma mark - 对齐标尺

- (void)showRuler {
    if (self.isRulerVisible) return;
    
    self.isRulerVisible = YES;
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    self.rulerView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    self.rulerView.backgroundColor = [UIColor clearColor];
    self.rulerView.userInteractionEnabled = NO;
    
    // 添加水平和垂直标尺线
    [self addRulerLines];
    
    [keyWindow addSubview:self.rulerView];
}

- (void)hideRuler {
    self.isRulerVisible = NO;
    [self.rulerView removeFromSuperview];
    self.rulerView = nil;
}

- (void)addRulerLines {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    // 垂直线（每10点一条）
    for (int x = 0; x <= screenWidth; x += 10) {
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(x, 0, 1, screenHeight)];
        line.backgroundColor = (x % 50 == 0) ? [UIColor redColor] : [[UIColor redColor] colorWithAlphaComponent:0.3];
        [self.rulerView addSubview:line];
    }
    
    // 水平线（每10点一条）
    for (int y = 0; y <= screenHeight; y += 10) {
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, y, screenWidth, 1)];
        line.backgroundColor = (y % 50 == 0) ? [UIColor redColor] : [[UIColor redColor] colorWithAlphaComponent:0.3];
        [self.rulerView addSubview:line];
    }
}

#pragma mark - 视图边框

- (void)showViewBorders {
    if (self.areBordersVisible) return;
    
    self.areBordersVisible = YES;
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    self.borderOverlayView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    self.borderOverlayView.backgroundColor = [UIColor clearColor];
    self.borderOverlayView.userInteractionEnabled = NO;
    
    [self addViewBordersRecursively:keyWindow];
    
    [keyWindow addSubview:self.borderOverlayView];
}

- (void)hideViewBorders {
    self.areBordersVisible = NO;
    [self.borderOverlayView removeFromSuperview];
    self.borderOverlayView = nil;
}

- (void)addViewBordersRecursively:(UIView *)view {
    if (view == self.borderOverlayView) return;
    
    // 添加边框
    UIView *borderView = [[UIView alloc] initWithFrame:view.frame];
    borderView.layer.borderWidth = 1;
    borderView.layer.borderColor = [UIColor redColor].CGColor;
    borderView.backgroundColor = [UIColor clearColor];
    
    // 转换坐标系
    CGRect convertedFrame = [view.superview convertRect:view.frame toView:[UIApplication sharedApplication].keyWindow];
    borderView.frame = convertedFrame;
    
    [self.borderOverlayView addSubview:borderView];
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        [self addViewBordersRecursively:subview];
    }
}

#pragma mark - 布局边界

- (void)showLayoutBounds {
    if (self.areLayoutBoundsVisible) return;
    
    self.areLayoutBoundsVisible = YES;
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    self.layoutBoundsView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    self.layoutBoundsView.backgroundColor = [UIColor clearColor];
    self.layoutBoundsView.userInteractionEnabled = NO;
    
    [self addLayoutBoundsRecursively:keyWindow];
    
    [keyWindow addSubview:self.layoutBoundsView];
}

- (void)hideLayoutBounds {
    self.areLayoutBoundsVisible = NO;
    [self.layoutBoundsView removeFromSuperview];
    self.layoutBoundsView = nil;
}

- (void)addLayoutBoundsRecursively:(UIView *)view {
    if (view == self.layoutBoundsView) return;
    
    // 显示约束边界
    UIView *boundsView = [[UIView alloc] initWithFrame:view.bounds];
    boundsView.layer.borderWidth = 2;
    boundsView.layer.borderColor = [UIColor blueColor].CGColor;
    boundsView.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.1];
    
    CGRect convertedFrame = [view.superview convertRect:view.frame toView:[UIApplication sharedApplication].keyWindow];
    boundsView.frame = convertedFrame;
    
    [self.layoutBoundsView addSubview:boundsView];
    
    // 递归处理子视图
    for (UIView *subview in view.subviews) {
        [self addLayoutBoundsRecursively:subview];
    }
}

#pragma mark - 辅助方法

- (UIViewController *)topViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

@end