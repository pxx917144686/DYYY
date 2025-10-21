//
//  FLEXColorPickerTool.m
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXColorPickerTool.h"

@interface FLEXColorPickerTool()

@property (nonatomic, strong) UIView *magnifierView;
@property (nonatomic, strong) UIView *colorInfoView;
@property (nonatomic, strong) UILabel *colorValueLabel;
@property (nonatomic, strong) UIImageView *capturedImageView;
@property (nonatomic, strong) UIView *colorIndicatorView;

@property (nonatomic, assign) CGPoint currentPoint;
@property (nonatomic, assign) BOOL isMoving;

@end

@implementation FLEXColorPickerTool

+ (instancetype)sharedInstance {
    static FLEXColorPickerTool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FLEXColorPickerTool alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [UIColor clearColor];
        [self setupUI];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)]];
    }
    return self;
}

- (void)setupUI {
    // 创建放大镜视图
    _magnifierView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    _magnifierView.layer.cornerRadius = 50;
    _magnifierView.layer.borderWidth = 2;
    _magnifierView.layer.borderColor = [UIColor whiteColor].CGColor;
    _magnifierView.clipsToBounds = YES;
    [self addSubview:_magnifierView];
    
    // 创建截图视图
    _capturedImageView = [[UIImageView alloc] initWithFrame:_magnifierView.bounds];
    [_magnifierView addSubview:_capturedImageView];
    
    // 创建颜色指示器
    _colorIndicatorView = [[UIView alloc] initWithFrame:CGRectMake(45, 45, 10, 10)];
    _colorIndicatorView.layer.cornerRadius = 5;
    _colorIndicatorView.layer.borderWidth = 1;
    _colorIndicatorView.layer.borderColor = [UIColor whiteColor].CGColor;
    [_magnifierView addSubview:_colorIndicatorView];
    
    // 创建颜色信息视图
    _colorInfoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 80)];
    _colorInfoView.backgroundColor = [UIColor whiteColor];
    _colorInfoView.layer.cornerRadius = 10;
    _colorInfoView.layer.shadowColor = [UIColor blackColor].CGColor;
    _colorInfoView.layer.shadowOffset = CGSizeMake(0, 2);
    _colorInfoView.layer.shadowOpacity = 0.3;
    _colorInfoView.layer.shadowRadius = 3;
    [self addSubview:_colorInfoView];
    
    // 创建颜色值标签
    _colorValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 180, 60)];
    _colorValueLabel.font = [UIFont systemFontOfSize:14];
    _colorValueLabel.numberOfLines = 3;
    _colorValueLabel.textAlignment = NSTextAlignmentCenter;
    [_colorInfoView addSubview:_colorValueLabel];
}

- (void)show {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    [keyWindow addSubview:self];
    
    // 初始位置
    self.currentPoint = CGPointMake(self.center.x, self.center.y);
    [self updateColorAtPoint:self.currentPoint];
}

- (void)hide {
    [self removeFromSuperview];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.isMoving = YES;
        self.currentPoint = point;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.currentPoint = point;
    } else if (gesture.state == UIGestureRecognizerStateEnded || 
               gesture.state == UIGestureRecognizerStateCancelled) {
        self.isMoving = NO;
    }
    
    [self updateColorAtPoint:self.currentPoint];
}

- (void)updateColorAtPoint:(CGPoint)point {
    // 更新放大镜位置
    CGPoint magnifierPosition = CGPointMake(point.x - 50, point.y - 120);
    self.magnifierView.center = magnifierPosition;
    
    // 更新颜色信息视图位置
    CGPoint infoPosition = CGPointMake(point.x, point.y + 100);
    self.colorInfoView.center = infoPosition;
    
    // 捕获屏幕上的颜色
    UIColor *color = [self captureColorAtPoint:point];
    
    // 获取颜色的RGB和HEX值
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    // 更新颜色指示器
    self.colorIndicatorView.backgroundColor = color;
    
    // 更新放大镜内容
    [self updateMagnifierContent:point];
    
    // 更新颜色信息
    NSString *hexString = [self hexStringFromColor:color];
    NSString *rgbString = [NSString stringWithFormat:@"RGB: %.0f, %.0f, %.0f", red * 255, green * 255, blue * 255];
    
    self.colorValueLabel.text = [NSString stringWithFormat:@"%@\n%@", hexString, rgbString];
}

- (UIColor *)captureColorAtPoint:(CGPoint)point {
    // 捕获屏幕上的颜色
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0);
    [self.superview.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // 获取像素颜色
    CGImageRef cgImage = image.CGImage;
    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    CFDataRef pixelData = CGDataProviderCopyData(provider);
    const UInt8 *data = CFDataGetBytePtr(pixelData);
    
    int pixelInfo = ((image.size.width * point.y) + point.x) * 4;
    
    CGFloat red   = data[pixelInfo + 0] / 255.0f;
    CGFloat green = data[pixelInfo + 1] / 255.0f;
    CGFloat blue  = data[pixelInfo + 2] / 255.0f;
    CGFloat alpha = data[pixelInfo + 3] / 255.0f;
    
    CFRelease(pixelData);
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

- (void)updateMagnifierContent:(CGPoint)point {
    // 捕获放大区域的图像
    CGSize captureSize = CGSizeMake(100, 100);
    CGRect captureRect = CGRectMake(point.x - captureSize.width/2, 
                                    point.y - captureSize.height/2,
                                    captureSize.width,
                                    captureSize.height);
    
    UIGraphicsBeginImageContextWithOptions(captureSize, NO, 0);
    [self.superview.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *capturedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // 裁剪图像
    CGImageRef imageRef = CGImageCreateWithImageInRect(capturedImage.CGImage, captureRect);
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    self.capturedImageView.image = croppedImage;
}

- (NSString *)hexStringFromColor:(UIColor *)color {
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    int r = (int)(red * 255);
    int g = (int)(green * 255);
    int b = (int)(blue * 255);
    
    return [NSString stringWithFormat:@"#%02X%02X%02X", r, g, b];
}

@end