//
//  FLEXRulerTool.m
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXRulerTool.h"

@interface FLEXRulerTool ()

@property (nonatomic, strong) UIView *horizontalLine;
@property (nonatomic, strong) UIView *verticalLine;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) CGPoint currentPoint;
@property (nonatomic, assign) BOOL isDrawing;

@end

@implementation FLEXRulerTool

+ (instancetype)sharedInstance {
    static FLEXRulerTool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FLEXRulerTool alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.1];
        [self setupUI];
        [self setupGestures];
    }
    return self;
}

- (void)setupUI {
    // 水平线
    self.horizontalLine = [[UIView alloc] init];
    self.horizontalLine.backgroundColor = [UIColor redColor];
    [self addSubview:self.horizontalLine];
    
    // 垂直线
    self.verticalLine = [[UIView alloc] init];
    self.verticalLine.backgroundColor = [UIColor redColor];
    [self addSubview:self.verticalLine];
    
    // 信息标签
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.backgroundColor = [UIColor whiteColor];
    self.infoLabel.textColor = [UIColor blackColor];
    self.infoLabel.font = [UIFont systemFontOfSize:12];
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.layer.cornerRadius = 5;
    self.infoLabel.layer.masksToBounds = YES;
    self.infoLabel.frame = CGRectMake(0, 0, 120, 40);
    [self addSubview:self.infoLabel];
    
    self.horizontalLine.hidden = YES;
    self.verticalLine.hidden = YES;
    self.infoLabel.hidden = YES;
}

- (void)setupGestures {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self addGestureRecognizer:tapGesture];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    [self addGestureRecognizer:panGesture];
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self];
    
    if (self.isDrawing) {
        // 重置
        self.isDrawing = NO;
        self.horizontalLine.hidden = YES;
        self.verticalLine.hidden = YES;
        self.infoLabel.hidden = YES;
    } else {
        // 开始新的测量
        self.isDrawing = YES;
        self.startPoint = point;
        self.currentPoint = point;
        
        [self updateRulerWithStartPoint:self.startPoint endPoint:self.currentPoint];
        
        self.horizontalLine.hidden = NO;
        self.verticalLine.hidden = NO;
        self.infoLabel.hidden = NO;
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    if (!self.isDrawing) {
        return;
    }
    
    if (gesture.state == UIGestureRecognizerStateChanged || 
        gesture.state == UIGestureRecognizerStateEnded) {
        self.currentPoint = [gesture locationInView:self];
        [self updateRulerWithStartPoint:self.startPoint endPoint:self.currentPoint];
    }
}

- (void)updateRulerWithStartPoint:(CGPoint)start endPoint:(CGPoint)end {
    // 更新水平线
    CGFloat horizontalHeight = 1.0;
    self.horizontalLine.frame = CGRectMake(
        MIN(start.x, end.x),
        start.y - horizontalHeight / 2,
        fabs(end.x - start.x),
        horizontalHeight
    );
    
    // 更新垂直线
    CGFloat verticalWidth = 1.0;
    self.verticalLine.frame = CGRectMake(
        end.x - verticalWidth / 2,
        MIN(start.y, end.y),
        verticalWidth,
        fabs(end.y - start.y)
    );
    
    // 计算水平和垂直距离
    CGFloat horizontalDistance = fabs(end.x - start.x);
    CGFloat verticalDistance = fabs(end.y - start.y);
    
    // 更新信息标签
    self.infoLabel.text = [NSString stringWithFormat:@"宽: %.1f\n高: %.1f", horizontalDistance, verticalDistance];
    
    // 将标签放在适当的位置
    CGPoint labelCenter = CGPointMake(
        (start.x + end.x) / 2,
        MIN(start.y, end.y) - 30
    );
    
    // 确保标签不超出屏幕边界
    CGFloat labelHalfWidth = self.infoLabel.frame.size.width / 2;
    CGFloat labelHalfHeight = self.infoLabel.frame.size.height / 2;
    
    if (labelCenter.x - labelHalfWidth < 0) {
        labelCenter.x = labelHalfWidth;
    } else if (labelCenter.x + labelHalfWidth > self.frame.size.width) {
        labelCenter.x = self.frame.size.width - labelHalfWidth;
    }
    
    if (labelCenter.y - labelHalfHeight < 0) {
        labelCenter.y = labelHalfHeight;
    } else if (labelCenter.y + labelHalfHeight > self.frame.size.height) {
        labelCenter.y = self.frame.size.height - labelHalfHeight;
    }
    
    self.infoLabel.center = labelCenter;
}

- (void)show {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    [keyWindow addSubview:self];
    
    self.isDrawing = NO;
    self.horizontalLine.hidden = YES;
    self.verticalLine.hidden = YES;
    self.infoLabel.hidden = YES;
}

- (void)hide {
    [self removeFromSuperview];
}

@end