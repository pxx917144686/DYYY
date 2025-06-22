#define DYYYFilterSettingsView_DEFINED
#define DYYYBottomAlertView_DEFINED
#define DYYYUtils_DEFINED

#import "DYYYSettingViewController.h"
#import "DYYYManager.h"
#import "DYYYFilterSettingsView.h"
#import "DYYYFloatSpeedButton.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import "DYYYBottomAlertView.h"
#import "DYYYUtils.h"

@interface UISwitch (DYYY_FuturisticEffects)
- (void)applyFuturisticEffects;
- (void)updateFuturisticEffectsWithState:(BOOL)isOn animated:(BOOL)animated;
@end

extern NSDictionary *dyyySettings;

static BOOL gFileExists = NO;
static BOOL gDataLoaded = NO;
static NSDictionary *gFixedABTestData = nil;
static dispatch_once_t onceToken;

// 添加图片选择器代理
@interface DYYYImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) void (^completionBlock)(NSDictionary *info);
@end

// 添加备份选择器代理
@interface DYYYBackupPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) NSString *tempFilePath;
@property (nonatomic, copy) void (^completionBlock)(NSURL *url);
@end

#ifndef AWESettingBaseViewController_DEFINED
#define AWESettingBaseViewController_DEFINED
@interface AWESettingBaseViewController (DYYY_Addition)
@end
#endif

@class AWESettingItemModel;

@implementation DYYYIconOptionsDialogView

- (instancetype)initWithTitle:(NSString *)title previewImage:(UIImage *)previewImage {
    self = [super init];
    if (self) {
        // 基本设置
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        
        // 创建内容视图
        UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(50, 200, self.bounds.size.width - 100, 300)];
        contentView.backgroundColor = [UIColor systemBackgroundColor];
        contentView.layer.cornerRadius = 15;
        contentView.clipsToBounds = YES;
        
        // 标题标签
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, contentView.bounds.size.width - 40, 30)];
        titleLabel.text = title;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [contentView addSubview:titleLabel];
        
        // 预览图片视图
        if (previewImage) {
            UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:CGRectMake((contentView.bounds.size.width - 100) / 2, 60, 100, 100)];
            previewImageView.image = previewImage;
            previewImageView.contentMode = UIViewContentModeScaleAspectFit;
            previewImageView.layer.cornerRadius = 10;
            previewImageView.clipsToBounds = YES;
            [contentView addSubview:previewImageView];
        }
        
        // 按钮容器
        UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 180, contentView.bounds.size.width - 40, 80)];
        
        // 清除按钮
        UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
        clearButton.frame = CGRectMake(0, 0, (buttonContainer.bounds.size.width - 10) / 2, 35);
        [clearButton setTitle:@"清除" forState:UIControlStateNormal];
        clearButton.backgroundColor = [UIColor systemRedColor];
        [clearButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        clearButton.layer.cornerRadius = 8;
        [clearButton addTarget:self action:@selector(clearButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [buttonContainer addSubview:clearButton];
        
        // 选择按钮
        UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
        selectButton.frame = CGRectMake((buttonContainer.bounds.size.width + 10) / 2, 0, (buttonContainer.bounds.size.width - 10) / 2, 35);
        [selectButton setTitle:@"选择" forState:UIControlStateNormal];
        selectButton.backgroundColor = [UIColor systemBlueColor];
        [selectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        selectButton.layer.cornerRadius = 8;
        [selectButton addTarget:self action:@selector(selectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [buttonContainer addSubview:selectButton];
        
        // 取消按钮
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelButton.frame = CGRectMake(0, 45, buttonContainer.bounds.size.width, 35);
        [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        cancelButton.backgroundColor = [UIColor systemGrayColor];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        cancelButton.layer.cornerRadius = 8;
        [cancelButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [buttonContainer addSubview:cancelButton];
        
        [contentView addSubview:buttonContainer];
        [self addSubview:contentView];
    }
    return self;
}

- (void)show {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self];
    
    self.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
    }];
}

- (void)clearButtonTapped {
    [self dismiss];
    if (self.onClear) {
        self.onClear();
    }
}

- (void)selectButtonTapped {
    [self dismiss];
    if (self.onSelect) {
        self.onSelect();
    }
}

- (void)cancelButtonTapped {
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

// 实现备份选择器代理
@implementation DYYYBackupPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        if (self.completionBlock) {
            self.completionBlock(urls.firstObject);
        }
        
        // 清理临时文件
        if (self.tempFilePath) {
            [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // 清理临时文件
    if (self.tempFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
    }
}

@end

@implementation UISwitch (DYYY_FuturisticEffects)

- (void)applyFuturisticEffects {
    // 确保只应用一次效果
    if ([objc_getAssociatedObject(self, "DYYY_hasAppliedEffects") boolValue]) {
        return;
    }
    
    objc_setAssociatedObject(self, "DYYY_hasAppliedEffects", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 配置主容器视图和效果
    self.clipsToBounds = NO;
    
    // 1. 创建高光描边层 - 增大边框宽度和阴影
    CALayer *glowBorderLayer = [CALayer layer];
    glowBorderLayer.frame = CGRectInset(self.bounds, -4, -4); // 增大边框宽度
    glowBorderLayer.cornerRadius = self.bounds.size.height / 2 + 4;
    glowBorderLayer.shadowColor = self.isOn ? [UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:1.0].CGColor : [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
    glowBorderLayer.shadowOffset = CGSizeMake(0, 0);
    glowBorderLayer.shadowOpacity = self.isOn ? 0.8 : 0.3; // 默认立即显示阴影
    glowBorderLayer.shadowRadius = 5.0; // 增大阴影半径
    glowBorderLayer.masksToBounds = NO;
    
    // 2. 创建玻璃效果覆盖层 - 增加透明度使效果更明显
    UIVisualEffectView *glassEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    glassEffectView.frame = self.bounds;
    glassEffectView.clipsToBounds = YES;
    glassEffectView.layer.cornerRadius = self.bounds.size.height / 2;
    glassEffectView.alpha = 0.18; // 增加透明度
    glassEffectView.userInteractionEnabled = NO;
    
    // 3. 创建液体动画层
    CALayer *liquidLayer = [CALayer layer];
    liquidLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    liquidLayer.masksToBounds = YES;
    liquidLayer.cornerRadius = self.bounds.size.height / 2;
    liquidLayer.opacity = 0.0;
    
    // 创建液体渐变
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = liquidLayer.bounds;
    gradientLayer.cornerRadius = liquidLayer.cornerRadius;
    
    // 设置渐变颜色基于开关状态 - 使用更明亮的颜色
    UIColor *liquidColor = self.isOn ? 
        [UIColor colorWithRed:20/255.0 green:142/255.0 blue:255/255.0 alpha:0.8] : // 更亮的蓝色
        [UIColor colorWithWhite:0.85 alpha:0.8]; // 更亮的灰色
    UIColor *transparentColor = [liquidColor colorWithAlphaComponent:0.0];
    
    gradientLayer.colors = @[(id)liquidColor.CGColor, (id)transparentColor.CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1.0, 0.5);
    
    [liquidLayer addSublayer:gradientLayer];
    
    // 存储这些层以便后续更新
    objc_setAssociatedObject(self, "DYYY_glowBorderLayer", glowBorderLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "DYYY_glassEffectView", glassEffectView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "DYYY_liquidLayer", liquidLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "DYYY_gradientLayer", gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 层级顺序很重要：高光层在底部，玻璃效果在最上层
    [self.layer insertSublayer:glowBorderLayer atIndex:0]; // 高光层放在底部
    [self.layer addSublayer:liquidLayer]; // 液体层在中间
    [self addSubview:glassEffectView]; // 玻璃效果在最上层
    
    // 初始更新效果
    [self updateFuturisticEffectsWithState:self.isOn animated:NO];
    
    // 确保监听状态变化
    [self removeTarget:self action:@selector(futuristicSwitchValueChanged) forControlEvents:UIControlEventValueChanged];
    [self addTarget:self action:@selector(futuristicSwitchValueChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)futuristicSwitchValueChanged {
    [self updateFuturisticEffectsWithState:self.isOn animated:YES];
}

- (void)updateFuturisticEffectsWithState:(BOOL)isOn animated:(BOOL)animated {
    CALayer *glowBorderLayer = objc_getAssociatedObject(self, "DYYY_glowBorderLayer");
    CALayer *liquidLayer = objc_getAssociatedObject(self, "DYYY_liquidLayer");
    CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, "DYYY_gradientLayer");
    
    // 准备动画
    NSTimeInterval animDuration = animated ? 0.35 : 0.0;
    
    // 1. 更新高光边框颜色和不透明度
    UIColor *glowColor = isOn ? [UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:1.0] : [UIColor colorWithWhite:0.8 alpha:1.0];
    CGFloat glowOpacity = isOn ? 0.8 : 0.3;
    
    if (animated) {
        // 高光边框动画
        CABasicAnimation *shadowColorAnimation = [CABasicAnimation animationWithKeyPath:@"shadowColor"];
        shadowColorAnimation.toValue = (__bridge id)glowColor.CGColor;
        shadowColorAnimation.duration = animDuration;
        [glowBorderLayer addAnimation:shadowColorAnimation forKey:@"shadowColor"];
        
        CABasicAnimation *shadowOpacityAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        shadowOpacityAnimation.toValue = @(glowOpacity);
        shadowOpacityAnimation.duration = animDuration;
        [glowBorderLayer addAnimation:shadowOpacityAnimation forKey:@"shadowOpacity"];
    }
    
    glowBorderLayer.shadowColor = glowColor.CGColor;
    glowBorderLayer.shadowOpacity = glowOpacity;
    
    // 2. 触发液体动画效果
    if (animated) {
        // 设置液体颜色
        UIColor *liquidColor = isOn ? [UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:0.7] : [UIColor colorWithWhite:0.8 alpha:0.7];
        UIColor *transparentColor = [liquidColor colorWithAlphaComponent:0.0];
        
        // 更新渐变颜色
        gradientLayer.colors = @[(id)liquidColor.CGColor, (id)transparentColor.CGColor];
        
        // 液体波动动画
        [CATransaction begin];
        [CATransaction setAnimationDuration:animDuration];
        
        // 显示液体层
        liquidLayer.opacity = 1.0;
        
        // 液体流动动画
        CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position.x"];
        positionAnimation.fromValue = @(isOn ? -self.bounds.size.width : self.bounds.size.width * 2);
        positionAnimation.toValue = @(isOn ? self.bounds.size.width * 2 : -self.bounds.size.width);
        positionAnimation.duration = animDuration * 1.5;
        positionAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        
        [CATransaction setCompletionBlock:^{
            // 完成后隐藏液体层
            [UIView animateWithDuration:0.2 animations:^{
                liquidLayer.opacity = 0.0;
            }];
        }];
        
        [liquidLayer addAnimation:positionAnimation forKey:@"liquidFlow"];
        [CATransaction commit];
        
        // 添加脉冲效果
        CAKeyframeAnimation *pulseAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        pulseAnimation.values = @[@1.0, @1.03, @1.0];
        pulseAnimation.keyTimes = @[@0, @0.5, @1.0];
        pulseAnimation.duration = animDuration;
        pulseAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                          [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        [self.layer addAnimation:pulseAnimation forKey:@"pulse"];
    }
}

@end

@implementation DYYYImagePickerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    if (self.completionBlock) {
        self.completionBlock(info);
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

// DYYYSettingItem类
@interface DYYYSettingItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, strong) NSString *placeholder;

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type placeholder:(NSString *)placeholder;

@end

@implementation DYYYSettingItem
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type {
    return [self itemWithTitle:title key:key type:type placeholder:nil];
}

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type placeholder:(NSString *)placeholder {
    DYYYSettingItem *item = [[DYYYSettingItem alloc] init];
    item.title = title;
    item.key = key;
    item.type = type;
    item.placeholder = placeholder;
    return item;
}

@end

// 获取顶层视图控制器
UIViewController *topView(void) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                window = windowScene.windows.firstObject;
                break;
            }
        }
    } else {
        window = [UIApplication sharedApplication].keyWindow;
    }
    
    UIViewController *rootViewController = window.rootViewController;
    UIViewController *topVC = rootViewController;
    
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)topVC;
        topVC = nav.topViewController;
    }
    
    return topVC;
}

// 显示图标选项弹窗
static void showIconOptionsDialog(NSString *title, UIImage *previewImage, NSString *saveFilename, void (^onClear)(void), void (^onSelect)(void)) {
    DYYYIconOptionsDialogView *optionsDialog = [[DYYYIconOptionsDialogView alloc] initWithTitle:title previewImage:previewImage];
    optionsDialog.onClear = onClear;
    optionsDialog.onSelect = onSelect;
    [optionsDialog show];
}

// 加载固定ABTest数据
void loadFixedABTestData(void) {
    static NSDate *lastLoadAttemptTime = nil;
    static const NSTimeInterval kMinLoadInterval = 60.0;
    
    NSDate *now = [NSDate date];
    if (lastLoadAttemptTime && [now timeIntervalSinceDate:lastLoadAttemptTime] < kMinLoadInterval) {
        return;
    }
    lastLoadAttemptTime = now;

    __block NSString *documentsDirectory = nil;
    __block NSString *dyyyFolderPath = nil;
    __block NSString *jsonFilePath = nil;
    __block NSFileManager *fileManager = nil;
    __block NSError *error = nil;
    
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        documentsDirectory = [paths firstObject];
        
        dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
        jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];
        
        fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:dyyyFolderPath]) {
            error = nil;
            [fileManager createDirectoryAtPath:dyyyFolderPath 
                  withIntermediateDirectories:YES 
                                   attributes:nil 
                                        error:&error];
            if (error) {
                NSLog(@"[DYYY] 创建DYYY目录失败: %@", error.localizedDescription);
            }
        }
        
        // 检查文件是否存在
        if (![fileManager fileExistsAtPath:jsonFilePath]) {
            gFileExists = NO;
            gDataLoaded = YES;
            return;
        }
        
        error = nil;
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonFilePath options:0 error:&error];
        
        if (jsonData) {
            NSDictionary *loadedData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if (loadedData && !error) {
                // 成功加载数据，保存到全局变量
                gFixedABTestData = [loadedData copy];
                gFileExists = YES;
                gDataLoaded = YES;
                return;
            }
        }
        gFileExists = NO;
        gDataLoaded = YES;
    });
}

// 获取当前ABTest数据
NSDictionary *getCurrentABTestData(void) {
    // 这里需要从抖音的ABTest管理器获取数据
    // 简化实现，仅通过反射获取，实际需要根据抖音内部机制调整
    Class AWEABTestManagerClass = NSClassFromString(@"AWEABTestManager");
    if (!AWEABTestManagerClass) {
        return nil;
    }
    
    id manager = [AWEABTestManagerClass performSelector:@selector(sharedManager)];
    if (!manager) {
        return nil;
    }
    
    SEL abTestDataSelector = NSSelectorFromString(@"abTestData");
    if (![manager respondsToSelector:abTestDataSelector]) {
        return nil;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSDictionary *currentData = [manager performSelector:abTestDataSelector];
    #pragma clang diagnostic pop
    
    return currentData;
}

static AWESettingItemModel *createIconCustomizationItem(NSString *identifier, NSString *title, NSString *svgIconName, NSString *saveFilename) {
    AWESettingItemModel *item = [[NSClassFromString(@"AWESettingItemModel") alloc] init];
    item.identifier = identifier;
    item.title = title;

    // 检查图片是否存在，使用saveFilename
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
    NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
    item.detail = fileExists ? @"已设置" : @"默认";

    item.type = 0;
    item.svgIconImageName = svgIconName; // 使用传入的SVG图标名称
    item.cellType = 26;
    item.colorStyle = 0;
    item.isEnable = YES;
    item.cellTappedBlock = ^{
        // 创建文件夹（如果不存在）
        if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
        }

        UIViewController *topVC = topView();

        // 加载预览图片(如果存在)
        UIImage *previewImage = nil;
        if (fileExists) {
            previewImage = [UIImage imageWithContentsOfFile:imagePath];
        }

        // 显示选项对话框 - 使用saveFilename作为参数传递
        showIconOptionsDialog(
            title, previewImage, saveFilename,
            ^{
                // 清除按钮回调
                if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
                    NSError *error = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:imagePath error:&error];
                    if (!error) {
                        item.detail = @"默认";

                        UIViewController *topVC = topView();
                        AWESettingBaseViewController *settingsVC = nil;
                        UITableView *tableView = nil;

                        UIView *firstLevelView = [topVC.view.subviews firstObject];
                        UIView *secondLevelView = [firstLevelView.subviews firstObject];
                        UIView *thirdLevelView = [secondLevelView.subviews firstObject];

                        UIResponder *responder = thirdLevelView;
                        while (responder) {
                            if ([responder isKindOfClass:NSClassFromString(@"AWESettingBaseViewController")]) {
                                settingsVC = (AWESettingBaseViewController *)responder;
                                break;
                            }
                            responder = [responder nextResponder];
                        }

                        if (settingsVC) {
                            for (UIView *subview in settingsVC.view.subviews) {
                                if ([subview isKindOfClass:[UITableView class]]) {
                                    tableView = (UITableView *)subview;
                                    break;
                                }
                            }

                            if (tableView) {
                                [tableView reloadData];
                            }
                        }
                    }
                }
            },
            ^{
                // 选择按钮回调 - 打开图片选择器
                UIImagePickerController *picker = [[UIImagePickerController alloc] init];
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                picker.allowsEditing = NO;
                picker.mediaTypes = @[ @"public.image" ];

                // 创建并设置代理
                DYYYImagePickerDelegate *pickerDelegate = [[DYYYImagePickerDelegate alloc] init];
                pickerDelegate.completionBlock = ^(NSDictionary *info) {
                    // 1. 正确声明变量，作用域在块内
                    NSURL *originalImageURL = info[UIImagePickerControllerImageURL];
                    if (!originalImageURL) {
                        originalImageURL = info[UIImagePickerControllerReferenceURL];
                    }

                    // 2. 确保变量在非nil时使用
                    if (originalImageURL) {
                        // 路径构建
                        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                        NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
                        NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];

                        // 获取原始数据
                        NSData *imageData = [NSData dataWithContentsOfURL:originalImageURL];

                        // GIF检测（带类型转换）
                        const char *bytes = (const char *)imageData.bytes;
                        BOOL isGIF = (imageData.length >= 6 && (memcmp(bytes, "GIF87a", 6) == 0 || memcmp(bytes, "GIF89a", 6) == 0));

                        // 保存逻辑
                        if (isGIF) {
                            [imageData writeToFile:imagePath atomically:YES];
                        } else {
                            UIImage *selectedImage = [UIImage imageWithData:imageData];
                            imageData = UIImagePNGRepresentation(selectedImage);
                            [imageData writeToFile:imagePath atomically:YES];
                        }

                        // 文件存在时更新UI（在同一个块内）
                        if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
                            item.detail = @"已设置";
                            dispatch_async(dispatch_get_main_queue(), ^{
                                UIViewController *topVC = topView();
                                AWESettingBaseViewController *settingsVC = nil;
                                UITableView *tableView = nil;

                                UIView *firstLevelView = [topVC.view.subviews firstObject];
                                UIView *secondLevelView = [firstLevelView.subviews firstObject];
                                UIView *thirdLevelView = [secondLevelView.subviews firstObject];

                                UIResponder *responder = thirdLevelView;
                                while (responder) {
                                    if ([responder isKindOfClass:NSClassFromString(@"AWESettingBaseViewController")]) {
                                        settingsVC = (AWESettingBaseViewController *)responder;
                                        break;
                                    }
                                    responder = [responder nextResponder];
                                }

                                if (settingsVC) {
                                    for (UIView *subview in settingsVC.view.subviews) {
                                        if ([subview isKindOfClass:[UITableView class]]) {
                                            tableView = (UITableView *)subview;
                                            break;
                                        }
                                    }

                                    if (tableView) {
                                        [tableView reloadData];
                                    }
                                }
                            });
                        }
                    }
                };

                static char kDYYYPickerDelegateKey;
                picker.delegate = pickerDelegate;
                objc_setAssociatedObject(picker, &kDYYYPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [topVC presentViewController:picker animated:YES completion:nil];
            });
    };

    return item;
}

@interface DYYYSettingViewController ()
@end

@implementation DYYYSettingViewController
- (void)setupCleanupOptions {
    Class AWESettingItemModelClass = NSClassFromString(@"AWESettingItemModel");
    AWESettingItemModel *cleanCacheItem = [[AWESettingItemModelClass alloc] init];
    cleanCacheItem.identifier = @"DYYYCleanCache";
    cleanCacheItem.title = @"清理缓存";
    cleanCacheItem.detail = @"";
    cleanCacheItem.type = 0;
    cleanCacheItem.svgIconImageName = @"ic_broom_outlined";
    cleanCacheItem.cellType = 26;
    cleanCacheItem.colorStyle = 0;
    cleanCacheItem.isEnable = YES;
    
    // 绑定点击事件
    cleanCacheItem.cellTappedBlock = ^{
        // 处理清理缓存逻辑
        [self handleCleanCache];
    };
}

- (void)handleCleanCache {
    // DYYYBottomAlertView 调用，使用正确的方法名和参数顺序
    [DYYYBottomAlertView showAlertWithTitle:@"清理缓存"
                               message:@"确定要清理缓存吗？\n这将删除临时文件和缓存"
                         cancelButtonText:@"取消"
                         confirmButtonText:@"确定"
                         cancelAction:nil
                         confirmAction:^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSUInteger totalSize = 0;

        // 临时目录
        NSString *tempDir = NSTemporaryDirectory();

        // Library目录下的缓存目录
        NSArray<NSString *> *customDirs = @[@"Caches", @"BDByteCast", @"kitelog"];
        NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;

        NSMutableArray<NSString *> *allPaths = [NSMutableArray arrayWithObject:tempDir];
        for (NSString *sub in customDirs) {
            NSString *fullPath = [libraryDir stringByAppendingPathComponent:sub];
            if ([fileManager fileExistsAtPath:fullPath]) {
                [allPaths addObject:fullPath];
            }
        }

        // 遍历所有目录并清理
        for (NSString *basePath in allPaths) {
            totalSize += [DYYYUtils clearDirectoryContents:basePath];
        }

        float sizeInMB = totalSize / 1024.0 / 1024.0;
        NSString *toastMsg = [NSString stringWithFormat:@"已清理 %.2f MB 的缓存", sizeInMB];
        [DYYYManager showToast:toastMsg];
    }];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DYYY设置";
    self.expandedSections = [NSMutableSet set];
    self.isSearching = NO;
    self.isKVOAdded = NO;
    
    // 隐藏顶部指示器条
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect = nil;
        appearance.shadowColor = nil;
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    // 初始化触觉反馈生成器
    self.feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self.feedbackGenerator prepare];
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backButtonTapped:)];
    self.navigationItem.leftBarButtonItem = backItem;
    
    [self setupAppearance];
    [self setupBackgroundColorView];
    [self setupAvatarView];
    [self setupSearchBar];
    [self setupTableView];
    [self setupSettingItems];
    [self setupSectionTitles];
    [self setupFooterLabel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBackgroundColorChanged) name:@"DYYYBackgroundColorChanged" object:nil];
    
    // 设置链接解析的默认值
    NSString *interfaceDownload = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (interfaceDownload == nil || [interfaceDownload stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@"https://api.qsy.ink/api/douyin?key=DYYY&url=" forKey:@"DYYYInterfaceDownload"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 初始化热更新数据
    loadFixedABTestData();

    [self ensureCustomAlbumSizeDefault];
}

- (void)ensureCustomAlbumSizeDefault {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL large = [defaults objectForKey:@"DYYYCustomAlbumSizeLarge"] ? [defaults boolForKey:@"DYYYCustomAlbumSizeLarge"] : NO;
    BOOL medium = [defaults objectForKey:@"DYYYCustomAlbumSizeMedium"] ? [defaults boolForKey:@"DYYYCustomAlbumSizeMedium"] : NO;
    BOOL small = [defaults objectForKey:@"DYYYCustomAlbumSizeSmall"] ? [defaults boolForKey:@"DYYYCustomAlbumSizeSmall"] : NO;

    // 如果都没设置过，默认“中”为YES，其它NO
    if (!large && !medium && !small) {
        [defaults setBool:NO forKey:@"DYYYCustomAlbumSizeLarge"];
        [defaults setBool:YES forKey:@"DYYYCustomAlbumSizeMedium"];
        [defaults setBool:NO forKey:@"DYYYCustomAlbumSizeSmall"];
        [defaults synchronize];
    } else {
        // 保证互斥：如果有多个为YES，只保留第一个为YES
        NSArray *keys = @[@"DYYYCustomAlbumSizeLarge", @"DYYYCustomAlbumSizeMedium", @"DYYYCustomAlbumSizeSmall"];
        NSMutableArray *onKeys = [NSMutableArray array];
        for (NSString *key in keys) {
            if ([defaults boolForKey:key]) {
                [onKeys addObject:key];
            }
        }
        if (onKeys.count > 1) {
            // 只保留第一个为YES，其它设为NO
            for (NSInteger i = 1; i < onKeys.count; i++) {
                [defaults setBool:NO forKey:onKeys[i]];
            }
            [defaults synchronize];
        }
    }
}

- (void)backButtonTapped:(id)sender {
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.isSearching = NO;
    self.searchBar.text = @"";
    self.filteredSections = nil;
    self.filteredSectionTitles = nil;
    [self.expandedSections removeAllObjects];
    
    if (self.tableView && [self.tableView numberOfSections] > 0) {
        @try {
            [self.tableView reloadData];
        } @catch (NSException *exception) {
        }
    }
    
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.isKVOAdded && self.tableView) {
        @try {
            [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
            self.isKVOAdded = NO;
        } @catch (NSException *exception) {
        }
    }
}

#pragma mark - Setup Methods

- (void)setupAppearance {
    if (self.navigationController) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
        self.navigationController.navigationBar.translucent = YES;
        self.navigationController.navigationBar.backgroundColor = [UIColor clearColor];
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
    }
}

- (void)setupBackgroundColorView {
    self.backgroundColorView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.backgroundColorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *savedColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor whiteColor]; // 默认白色
    self.backgroundColorView.backgroundColor = savedColor;
    [self.view insertSubview:self.backgroundColorView atIndex:0];
}

- (void)setupAvatarView {
    self.avatarContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 160)];
    self.avatarContainerView.backgroundColor = [UIColor clearColor];
    
    self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 100) / 2, 20, 100, 100)];
    self.avatarImageView.layer.cornerRadius = 50;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.backgroundColor = [UIColor systemGray4Color];
    
    NSString *avatarPath = [self avatarImagePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarPath]) {
        self.avatarImageView.image = [UIImage imageWithContentsOfFile:avatarPath];
    } else {
        self.avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
        self.avatarImageView.tintColor = [UIColor systemGrayColor];
    }
    
    [self.avatarContainerView addSubview:self.avatarImageView];
    
    self.avatarTapLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, 30)];
    NSString *customTapText = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYAvatarTapText"];
    self.avatarTapLabel.text = customTapText.length > 0 ? customTapText : @"pxx917144686";
    self.avatarTapLabel.textAlignment = NSTextAlignmentCenter;
    self.avatarTapLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    self.avatarTapLabel.textColor = [UIColor systemBlueColor];
    [self.avatarContainerView addSubview:self.avatarTapLabel];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)];
    self.avatarImageView.userInteractionEnabled = YES;
    [self.avatarImageView addGestureRecognizer:tapGesture];
}

- (void)setupSearchBar {
    // 创建一个容器视图来承载搜索栏和阴影效果
    // 减小搜索框高度，增加上边距使位置更合理
    UIView *searchContainer = [[UIView alloc] initWithFrame:CGRectMake(24, 165, self.view.bounds.size.width - 48, 40)];
    searchContainer.backgroundColor = [UIColor clearColor];
    searchContainer.tag = 1001;
    
    // 创建内层阴影容器（减小高度）
    UIView *innerShadowContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, searchContainer.frame.size.width, 36)];
    // 减小圆角，使按钮看起来更紧凑
    innerShadowContainer.layer.cornerRadius = 18;
    innerShadowContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    innerShadowContainer.layer.masksToBounds = NO;
    
    // 保持较小且锐利的环绕阴影
    innerShadowContainer.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.1].CGColor;
    innerShadowContainer.layer.shadowOffset = CGSizeMake(0, 1);
    innerShadowContainer.layer.shadowOpacity = 0.8;
    innerShadowContainer.layer.shadowRadius = 1.0;
    
    // 创建外层阴影容器
    UIView *outerShadowContainer = [[UIView alloc] initWithFrame:innerShadowContainer.frame];
    outerShadowContainer.layer.cornerRadius = 18;
    outerShadowContainer.backgroundColor = [UIColor clearColor];
    outerShadowContainer.layer.masksToBounds = NO;
    
    // 减小阴影效果，使整体更轻量
    outerShadowContainer.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
    outerShadowContainer.layer.shadowOffset = CGSizeMake(0, 2);
    outerShadowContainer.layer.shadowOpacity = 0.5;
    outerShadowContainer.layer.shadowRadius = 4;
    
    // 按照层次结构添加视图
    [searchContainer addSubview:outerShadowContainer];
    [searchContainer addSubview:innerShadowContainer];
    
    // 创建并配置搜索栏（减小尺寸）
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, innerShadowContainer.frame.size.width, 34)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索设置";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [UIColor clearColor];
    
    // 优化搜索框内部文本
    self.searchBar.searchTextField.backgroundColor = [UIColor clearColor];
    self.searchBar.searchTextField.font = [UIFont systemFontOfSize:14]; // 减小字体大小
    self.searchBar.searchTextField.textColor = [UIColor darkTextColor];
    
    // 调整内阴影效果
    UIView *textFieldContainer = self.searchBar.searchTextField.superview;
    textFieldContainer.layer.shadowColor = [UIColor colorWithWhite:0.8 alpha:0.4].CGColor;
    textFieldContainer.layer.shadowOffset = CGSizeMake(0, 1);
    textFieldContainer.layer.shadowOpacity = 0.3;
    textFieldContainer.layer.shadowRadius = 0.5;
    
    // 调整搜索图标位置，更紧凑
    UIOffset iconOffset = UIOffsetMake(20, 0);
    [self.searchBar setPositionAdjustment:iconOffset forSearchBarIcon:UISearchBarIconSearch];
    
    // 添加搜索栏到内层容器
    [innerShadowContainer addSubview:self.searchBar];
    
    // 保留水波纹效果
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(searchBarTapped:)];
    [innerShadowContainer addGestureRecognizer:tapGesture];
    
    // 将完整的搜索容器添加到表头视图
    [self.tableView.tableHeaderView addSubview:searchContainer];
    
    // 减小tableHeaderView的高度，使搜索区域更紧凑
    CGRect headerFrame = self.tableView.tableHeaderView.frame;
    headerFrame.size.height = 60; // 减小高度
    self.tableView.tableHeaderView.frame = headerFrame;
}

// 添加搜索栏点击触觉反馈
- (void)searchBarTapped:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        // 执行水波纹动画
        CGPoint tapPoint = [gesture locationInView:gesture.view];
        [self addRippleEffectAtPoint:tapPoint inView:gesture.view];
        
        // 触发触觉反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 激活搜索栏
        [self.searchBar becomeFirstResponder];
    }
}

// 添加水波纹效果
- (void)addRippleEffectAtPoint:(CGPoint)point inView:(UIView *)view {
    // 创建波纹层
    CAShapeLayer *rippleLayer = [CAShapeLayer layer];
    rippleLayer.position = point;
    
    // 设置波纹路径
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:CGPointZero 
                                                             radius:10 
                                                         startAngle:0 
                                                           endAngle:2*M_PI 
                                                          clockwise:YES];
    rippleLayer.path = circlePath.CGPath;
    
    // 设置波纹外观
    rippleLayer.fillColor = [UIColor colorWithWhite:0.9 alpha:0.3].CGColor;
    rippleLayer.opacity = 1.0;
    
    // 添加到视图
    [view.layer addSublayer:rippleLayer];
    
    // 创建扩散动画
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @1.0;
    scaleAnimation.toValue = @15.0;
    
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @1.0;
    opacityAnimation.toValue = @0.0;
    
    // 组合动画
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = @[scaleAnimation, opacityAnimation];
    animationGroup.duration = 0.8;
    animationGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    // 完成后移除波纹层
    animationGroup.removedOnCompletion = YES;
    animationGroup.fillMode = kCAFillModeForwards;
    
    [rippleLayer addAnimation:animationGroup forKey:@"rippleEffect"];
    
    // 延时删除图层
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [rippleLayer removeFromSuperlayer];
    });
}

// 根据主题动态调整搜索栏颜色
- (void)handleBackgroundColorChanged {
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *savedColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor whiteColor];
    self.backgroundColorView.backgroundColor = savedColor;
    
    // 更新搜索栏背景色
    // 提取背景颜色的亮度
    CGFloat brightness = 0;
    [savedColor getWhite:&brightness alpha:NULL];
    
    // 根据背景亮度调整搜索栏色调
    UIView *searchContainer = [self.tableView.tableHeaderView viewWithTag:1001];
    if (!searchContainer) {
        return;
    }
    
    for (UIView *subview in searchContainer.subviews) {
        if (subview.layer.cornerRadius == 22) {
            if (brightness < 0.5) {
                // 深色背景下使用深色搜索栏
                subview.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
                self.searchBar.searchTextField.textColor = [UIColor whiteColor];
                self.searchBar.searchTextField.attributedPlaceholder = [[NSAttributedString alloc] 
                    initWithString:@"搜索设置" 
                    attributes:@{NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
            } else {
                // 浅色背景下使用浅色搜索栏
                subview.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
                self.searchBar.searchTextField.textColor = [UIColor darkTextColor];
                self.searchBar.searchTextField.attributedPlaceholder = [[NSAttributedString alloc] 
                    initWithString:@"搜索设置" 
                    attributes:@{NSForegroundColorAttributeName: [UIColor grayColor]}];
            }
        }
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    // 调整section头部间距，减小或移除这个设置
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 2; // 减小组头部之间的垂直距离
    }
    
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 204)];
    [self.tableView.tableHeaderView addSubview:self.avatarContainerView];
    [self.tableView.tableHeaderView addSubview:self.searchBar];
    self.searchBar.frame = CGRectMake(0, 160, self.view.bounds.size.width, 44);
    [self.view addSubview:self.tableView];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:longPress];
}

- (void)setupSettingItems {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *sections = @[
            // 第一部分 - 基本设置
            @[
                [DYYYSettingItem itemWithTitle:@"启用弹幕改色" key:@"DYYYEnableDanmuColor" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"自定弹幕颜色" key:@"DYYYdanmuColor" type:DYYYSettingItemTypeTextField placeholder:@"十六进制"],
                [DYYYSettingItem itemWithTitle:@"显示进度时长" key:@"DYYYisShowScheduleDisplay" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"进度纵轴位置" key:@"DYYYTimelineVerticalPosition" type:DYYYSettingItemTypeTextField placeholder:@"-12.5"],
                [DYYYSettingItem itemWithTitle:@"时间进度位置" key:@"DYYYScheduleStyle" type:DYYYSettingItemTypeCustomPicker placeholder:@"点击选择"],
                [DYYYSettingItem itemWithTitle:@"进度标签颜色" key:@"DYYYProgressLabelColor" type:DYYYSettingItemTypeTextField placeholder:@"十六进制"],
                [DYYYSettingItem itemWithTitle:@"隐藏视频进度" key:@"DYYYHideVideoProgress" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"推荐过滤直播" key:@"DYYYisSkipLive" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"推荐过滤热点" key:@"DYYYisSkipHotSpot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"推荐过滤低赞" key:@"DYYYfilterLowLikes" type:DYYYSettingItemTypeTextField placeholder:@"填0关闭"],
                [DYYYSettingItem itemWithTitle:@"推荐过滤文案" key:@"DYYYfilterKeywords" type:DYYYSettingItemTypeTextField placeholder:@"不填关闭"],
                [DYYYSettingItem itemWithTitle:@"推荐视频时限" key:@"DYYYfiltertimelimit" type:DYYYSettingItemTypeTextField placeholder:@"填0关闭，单位为天"],
                [DYYYSettingItem itemWithTitle:@"首页全屏+透明" key:@"DYYYisEnableFullScreen" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"去除App内更新" key:@"DYYYNoUpdates" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"去青少年弹窗" key:@"DYYYHideteenmode" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区毛玻璃" key:@"DYYYisEnableCommentBlur" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"毛玻璃透明度" key:@"DYYYCommentBlurTransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"通知玻璃效果" key:@"DYYYEnableNotificationTransparency" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"通知圆角半径" key:@"DYYYNotificationCornerRadius" type:DYYYSettingItemTypeTextField placeholder:@"默认12"],
                [DYYYSettingItem itemWithTitle:@"时间标签颜色" key:@"DYYYLabelColor" type:DYYYSettingItemTypeTextField placeholder:@"十六进制"],
                [DYYYSettingItem itemWithTitle:@"隐藏系统顶栏" key:@"DYYYisHideStatusbar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"关注二次确认" key:@"DYYYfollowTips" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"收藏二次确认" key:@"DYYYcollectTips" type:DYYYSettingItemTypeSwitch]
            ],
            
            // 第二部分 - 界面设置
            @[
                [DYYYSettingItem itemWithTitle:@"设置顶栏文字透明" key:@"DYYYtopbartransparent" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"设置全局透明" key:@"DYYYGlobalTransparency" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"首页头像透明" key:@"DYYYAvatarViewTransparency" type:DYYYSettingItemTypeTextField placeholder:@"0-1小数"],
                [DYYYSettingItem itemWithTitle:@"右侧栏缩放度" key:@"DYYYElementScale" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"昵称文案缩放" key:@"DYYYNicknameScale" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"昵称下移距离" key:@"DYYYNicknameVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"文案下移距离" key:@"DYYYDescriptionVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"属地下移距离" key:@"DYYYIPLabelVerticalOffset" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置首页标题" key:@"DYYYIndexTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置朋友标题" key:@"DYYYFriendsTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置消息标题" key:@"DYYYMsgTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置我的标题" key:@"DYYYSelfTitle" type:DYYYSettingItemTypeTextField placeholder:@"不填默认"],
                [DYYYSettingItem itemWithTitle:@"设置顶栏横幅" key:@"DYYYModifyTopTabText" type:DYYYSettingItemTypeTextField placeholder:@"格式:原标题=新标题"]
            ],
            
            // 第三部分 - 隐藏设置
            @[
                [DYYYSettingItem itemWithTitle:@"隐藏全屏观看" key:@"DYYYisHiddenEntry" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏商城" key:@"DYYYHideShopButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏消息" key:@"DYYYHideMessageButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏朋友" key:@"DYYYHideFriendsButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏加号" key:@"DYYYisHiddenJia" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏红点" key:@"DYYYisHiddenBottomDot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底栏背景" key:@"DYYYisHiddenBottomBg" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏侧栏红点" key:@"DYYYisHiddenSidebarDot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏发作品框" key:@"DYYYHidePostView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像加号" key:@"DYYYHideLOTAnimationView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏点赞数值" key:@"DYYYHideLikeLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论数值" key:@"DYYYHideCommentLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏收藏数值" key:@"DYYYHideCollectLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享数值" key:@"DYYYHideShareLabel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏点赞按钮" key:@"DYYYHideLikeButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论按钮" key:@"DYYYHideCommentButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏收藏按钮" key:@"DYYYHideCollectButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像按钮" key:@"DYYYHideAvatarButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏音乐按钮" key:@"DYYYHideMusicButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享按钮" key:@"DYYYHideShareButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频定位" key:@"DYYYHideLocation" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏右上搜索" key:@"DYYYHideDiscover" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏相关搜索" key:@"DYYYHideInteractionSearch" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏进入直播" key:@"DYYYHideEnterLive" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论视图" key:@"DYYYHideCommentViews" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏通知提示" key:@"DYYYHidePushBanner" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像列表" key:@"DYYYisHiddenAvatarList" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏头像气泡" key:@"DYYYisHiddenAvatarBubble" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏左侧边栏" key:@"DYYYisHiddenLeftSideBar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏吃喝玩乐" key:@"DYYYHideNearbyCapsuleView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏弹幕按钮" key:@"DYYYHideDanmuButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏取消静音" key:@"DYYYHideCancelMute" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏去汽水听" key:@"DYYYHideQuqishuiting" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏共创头像" key:@"DYYYHideGongChuang" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏热点提示" key:@"DYYYHideHotspot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏推荐提示" key:@"DYYYHideRecommendTips" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享提示" key:@"DYYYHideShareContentView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏作者声明" key:@"DYYYHideAntiAddictedNotice" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底部相关" key:@"DYYYHideBottomRelated" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏拍摄同款" key:@"DYYYHideFeedAnchorContainer" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏挑战贴纸" key:@"DYYYHideChallengeStickers" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏校园提示" key:@"DYYYHideTemplateTags" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏作者店铺" key:@"DYYYHideHisShop" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏关注直播" key:@"DYYYHideConcernCapsuleView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏顶栏横线" key:@"DYYYHidentopbarprompt" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频合集" key:@"DYYYHideTemplateVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏短剧合集" key:@"DYYYHideTemplatePlaylet" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏动图标签" key:@"DYYYHideLiveGIF" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏笔记标签" key:@"DYYYHideItemTag" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏底部话题" key:@"DYYYHideTemplateGroup" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏相机定位" key:@"DYYYHideCameraLocation" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频滑条" key:@"DYYYHideStoryProgressSlide" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏图片滑条" key:@"DYYYHideDotsIndicator" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏分享私信" key:@"DYYYHidePrivateMessages" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏昵称右侧" key:@"DYYYHideRightLable" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏群聊商店" key:@"DYYYHideGroupShop" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播胶囊" key:@"DYYYHideLiveCapsuleView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏关注顶端" key:@"DYYYHidenLiveView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏同城顶端" key:@"DYYYHideMenuView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏群直播中" key:@"DYYYGroupLiving" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏群工具栏" key:@"DYYYHideGroupInputActionBar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播广场" key:@"DYYYHideLivePlayground" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏礼物展馆" key:@"DYYYHideGiftPavilion" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏顶栏红点" key:@"DYYYHideTopBarBadge" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏退出清屏" key:@"DYYYHideLiveRoomClear" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏投屏按钮" key:@"DYYYHideLiveRoomMirroring" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播发现" key:@"DYYYHideLiveDiscovery" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播点歌" key:@"DYYYHideKTVSongIndicator" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏流量提醒" key:@"DYYYHideCellularAlert" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"聊天评论透明" key:@"DYYYHideChatCommentBg" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论背景" key:@"DYYYHideComment" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏返回按钮" key:@"DYYYHideBack" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏回复框" key:@"DYYYHideReply" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏搜索气泡" key:@"DYYYHideSearchBubble" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏章节进度条" key:@"DYYYHideChapterProgress" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播间设置" key:@"DYYYHideLiveRoomClose" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播间横屏" key:@"DYYYHideLiveRoomFullscreen" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播商品信息" key:@"DYYYHideLiveGoodsMsg" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏直播点赞动画" key:@"DYYYHideLiveLikeAnimation" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏激励红包挂件" key:@"DYYYHidePendantGroup" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏双栏入口" key:@"DYYYHideDoubleColumnEntry" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏上次看到提示" key:@"DYYYHidePopover" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏视频搜索长框" key:@"DYYYHideSearchEntrance" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏朋友关注按钮" key:@"DYYYHideFamiliar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏添加朋友" key:@"DYYYHideButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏拍照搜同款扫一扫" key:@"DYYYHideScancode" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏搜索指示条" key:@"DYYYHideSearchEntranceIndicator" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论搜索" key:@"DYYYHideCommentDiscover" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论提示" key:@"DYYYHideCommentTips" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏关注提示视图" key:@"DYYYHideFollowPromptView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏我的按钮" key:@"DYYYHideMyButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏暂停关键词" key:@"DYYYHidePauseVideoRelatedWord" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏搜索引导提示框" key:@"DYYYHideGuideTipView" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏顶栏引导提示" key:@"DYYYHideFeedTabJumpGuide" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏大家都在搜" key:@"DYYYHideWords" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏观看历史搜索" key:@"DYYYHideDiscoverFeedEntry" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏短剧免费去看" key:@"DYYYHideShowPlayletComment" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论音乐" key:@"DYYYHideCommentMusicAnchor" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏评论定位" key:@"DYYYHidePOIEntryAnchor" type:DYYYSettingItemTypeSwitch]
            ],
            
            // 第四部分 - 移除设置
            @[
                [DYYYSettingItem itemWithTitle:@"移除推荐" key:@"DYYYHideHotContainer" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除关注" key:@"DYYYHideFollow" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除精选" key:@"DYYYHideMediumVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除商城" key:@"DYYYHideMall" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除朋友" key:@"DYYYHideFriend" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除同城" key:@"DYYYHideNearby" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除团购" key:@"DYYYHideGroupon" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除直播" key:@"DYYYHideTabLive" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除热点" key:@"DYYYHidePadHot" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除经验" key:@"DYYYHideHangout" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"移除短剧" key:@"DYYYHideTemplatePlaylet" type:DYYYSettingItemTypeSwitch]
            ],
            
            // 第五部分 - 增强功能
            @[
                [DYYYSettingItem itemWithTitle:@"启用新版玻璃面板" key:@"DYYYisEnableModern" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用保存他人头像" key:@"DYYYEnableSaveAvatar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"禁用点击首页刷新" key:@"DYYYDisableHomeRefresh" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"禁用双击视频点赞" key:@"DYYYDouble" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-双击触发" key:@"DYYYEnableDoubleOpenComment" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论文本复制" key:@"DYYYCommentCopyText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-长按复制文本" key:@"DYYYEnableCommentCopyText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-保存动态图" key:@"DYYYCommentLivePhotoNotWaterMark" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-保存图片" key:@"DYYYCommentNotWaterMark" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"评论区-保存表情包" key:@"DYYYFourceDownloadEmotion" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"表情预览保存" key:@"DYYYForceDownloadPreviewEmotion" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"私信表情保存" key:@"DYYYForceDownloadIMEmotion" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"视频-显示日期时间" key:@"DYYYShowDateTime" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -年-月-日 时:分" key:@"DYYYDateTimeFormat_YMDHM" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -月-日 时:分" key:@"DYYYDateTimeFormat_MDHM" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -时:分:秒" key:@"DYYYDateTimeFormat_HMS" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -时:分" key:@"DYYYDateTimeFormat_HM" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -年-月-日" key:@"DYYYDateTimeFormat_YMD" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"属地前缀" key:@"DYYYLocationPrefix" type:DYYYSettingItemTypeTextField placeholder:@"可以自定义修改 "],
                [DYYYSettingItem itemWithTitle:@"时间属地显示-开关" key:@"DYYYisEnableArea" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -省级" key:@"DYYYisEnableAreaProvince" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -城市" key:@"DYYYisEnableAreaCity" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -市区或县城" key:@"DYYYisEnableAreaDistrict" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -街道或小区" key:@"DYYYisEnableAreaStreet" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"链接解析API" key:@"DYYYInterfaceDownload" type:DYYYSettingItemTypeTextField placeholder:@"不设置，默认"],
                [DYYYSettingItem itemWithTitle:@"弹出-清晰度选项" key:@"DYYYShowAllVideoQuality" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"拦截广告（开屏、信息流、启动视频）"  key:@"DYYYNoAds" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"头像文本-修改" key:@"DYYYAvatarTapText" type:DYYYSettingItemTypeTextField placeholder:@"可以自定义修改"],
                [DYYYSettingItem itemWithTitle:@"菜单背景颜色" key:@"DYYYBackgroundColor" type:DYYYSettingItemTypeColorPicker],
                [DYYYSettingItem itemWithTitle:@"默认倍速（如果没有倍数设置）" key:@"DYYYDefaultSpeed" type:DYYYSettingItemTypeSpeedPicker placeholder:@"点击选择"],
                [DYYYSettingItem itemWithTitle:@"倍速按钮功能-开关" key:@"DYYYEnableFloatSpeedButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速数值（强制倍数）" key:@"DYYYSpeedSettings" type:DYYYSettingItemTypeTextField placeholder:@"英文逗号分隔"],
                [DYYYSettingItem itemWithTitle:@"下一个视频会自动恢复默认倍速" key:@"DYYYAutoRestoreSpeed" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速按钮显示后缀" key:@"DYYYSpeedButtonShowX" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"倍速按钮大小" key:@"DYYYSpeedButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"默认40"],
                [DYYYSettingItem itemWithTitle:@"视频清屏隐藏-开关" key:@"DYYYEnableFloatClearButton" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -按钮大" key:@"DYYYCustomAlbumSizeLarge" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -按钮中" key:@"DYYYCustomAlbumSizeMedium" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -按钮小" key:@"DYYYCustomAlbumSizeSmall" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -按钮自定义" key:@"DYYYEnableFloatClearButtonSize" type:DYYYSettingItemTypeTextField placeholder:@"默认40"],
                [DYYYSettingItem itemWithTitle:@"图标更换-开关" key:@"DYYYEnableCustomAlbum" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -本地相册" key:@"DYYYCustomAlbumImage" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"  -清屏隐藏弹幕" key:@"DYYYHideDanmaku" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -清屏移除进度" key:@"DYYYEnabshijianjindu" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -清屏隐藏进度" key:@"DYYYHideTimeProgress" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -清屏隐藏滑条" key:@"DYYYHideSlider" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -清屏隐藏底栏" key:@"DYYYHideTabBar" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -清屏隐藏倍速" key:@"DYYYHideSpeed" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"长按功能-开关" key:@"DYYYLongPressDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -保存视频" key:@"DYYYLongPressSaveVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -分享音频" key:@"DYYYLongPressSaveAudio" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -启用FLEX" key:@"DYYYEnableFLEX" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -保存当前图片" key:@"DYYYLongPressSaveCurrentImage" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -保存所有图片" key:@"DYYYLongPressSaveAllImages" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制链接" key:@"DYYYLongPressCopyLink" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -接口解析" key:@"DYYYLongPressApiDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -过滤用户" key:@"DYYYLongPressFilterUser" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -过滤文案" key:@"DYYYLongPressFilterTitle" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -定时关闭" key:@"DYYYLongPressTimerClose" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -制作视频" key:@"DYYYLongPressCreateVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-转发日常" key:@"DYYYHideDaily" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-推荐" key:@"DYYYHideRecommend" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-不感兴趣" key:@"DYYYHideNotInterested" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-举报" key:@"DYYYHideReport" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-倍速" key:@"DYYYHideSpeed" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-清屏播放" key:@"DYYYHideClearScreen" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-缓存视频" key:@"DYYYHideFavorite" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-稍后再看" key:@"DYYYHideLater" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-投屏" key:@"DYYYHideCast" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-PC打开" key:@"DYYYHideOpenInPC" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-弹幕" key:@"DYYYHideSubtitle" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-自动连播" key:@"DYYYHideAutoPlay" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-识别图片" key:@"DYYYHideSearchImage" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-听抖音" key:@"DYYYHideListenDouyin" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-后台播放" key:@"DYYYHideBackgroundPlay" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-双列入口" key:@"DYYYHideBiserial" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"隐藏长按-定时关闭" key:@"DYYYHideTimerclose" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"长按面板-复制功能" key:@"DYYYCopyText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制原文本" key:@"DYYYCopyOriginalText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制分享链接" key:@"DYYYCopyShareLink" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"双击操作-开关" key:@"DYYYEnableDoubleOpenAlertController" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -保存视频/图片/实况动图" key:@"DYYYDoubleTapDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -音频弹出分享" key:@"DYYYDoubleTapDownloadAudio" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -复制文案" key:@"DYYYDoubleTapCopyDesc" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -打开评论" key:@"DYYYDoubleTapComment" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -点赞视频" key:@"DYYYDoubleTapLike" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -分享视频" key:@"DYYYDoubleTapshowSharePanel" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -长按面板" key:@"DYYYDoubleTapshowDislikeOnVideo" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -接口解析" key:@"DYYYDoubleInterfaceDownload" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"默认最高画质" key:@"DYYYEnableVideoHighestQuality" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"视频降噪增强" key:@"DYYYEnableNoiseFilter" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"默认清晰度-最高" key:@"DYYYDefaultQualityBest" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"默认清晰度-原画" key:@"DYYYDefaultQualityOriginal" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"默认清晰度-1080P" key:@"DYYYDefaultQuality1080p" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"默认清晰度-720P" key:@"DYYYDefaultQuality720p" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"直播视频-最高画质" key:@"DYYYEnableLiveHighestQuality" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"禁用直播PCDN功能" key:@"DYYYDisableLivePCDN" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"自动勾选原图" key:@"DYYYisAutoSelectOriginalPhoto" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"视频降噪-人声增强" key:@"DYYYEnableNoiseFilter" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"无痕模式" key:@"DYYYEnableIncognitoMode" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"主页-自定义总开关" key:@"DYYYEnableSocialStatsCustom" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -粉丝数量" key:@"DYYYCustomFollowers" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -获赞数量" key:@"DYYYCustomLikes" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -关注数量" key:@"DYYYCustomFollowing" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -互关数量" key:@"DYYYCustomMutual" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"视频-自定义总开关" key:@"DYYYEnableVideoStatsCustom" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"  -点赞数量" key:@"DYYYVideoCustomLikes" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -评论数量" key:@"DYYYVideoCustomComments" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -收藏数量" key:@"DYYYVideoCustomCollects" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"  -分享数量" key:@"DYYYVideoCustomShares" type:DYYYSettingItemTypeTextField placeholder:@"填写数字"],
                [DYYYSettingItem itemWithTitle:@"强制自动播放（不能关闭）" key:@"DYYYisEnableAutoPlay" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用深色键盘" key:@"DYYYisDarkKeyBoard" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"长按-复制视频文案" key:@"DYYYLongPressCopyTextEnabled" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用音乐文本复制" key:@"DYYYMusicCopyText" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"简化侧边栏" key:@"DYYYStreamlinethesidebar" type:DYYYSettingItemTypeSwitch]
            ],

            // 第六部分 - 图标自定义功能
            @[
                [DYYYSettingItem itemWithTitle:@"未点赞图标" key:@"DYYYIconLikeBefore" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"已点赞图标" key:@"DYYYIconLikeAfter" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"评论的图标" key:@"DYYYIconComment" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"未收藏图标" key:@"DYYYIconUnfavorite" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"已收藏图标" key:@"DYYYIconFavorite" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"],
                [DYYYSettingItem itemWithTitle:@"分享的图标" key:@"DYYYIconShare" type:DYYYSettingItemTypeTextField placeholder:@"点击选择图片"]
            ],
            
            // 第七部分 - 清理功能
            @[
                [DYYYSettingItem itemWithTitle:@"清除设置" key:@"DYYYCleanSettings" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"清理缓存" key:@"DYYYCleanCache" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"备份设置" key:@"DYYYBackupSettings" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"恢复设置" key:@"DYYYRestoreSettings" type:DYYYSettingItemTypeSwitch]
            ],
            
            // 第八部分 - 热更新功能
            @[
                [DYYYSettingItem itemWithTitle:@"禁用下发配置" key:@"DYYYABTestBlockEnabled" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"启用补丁模式" key:@"DYYYABTestPatchEnabled" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"保存当前配置" key:@"SaveCurrentABTestData" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"本地选择配置" key:@"LoadABTestConfigFile" type:DYYYSettingItemTypeSwitch],
                [DYYYSettingItem itemWithTitle:@"删除本地配置" key:@"DeleteABTestConfigFile" type:DYYYSettingItemTypeSwitch]
            ]
        ];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.settingSections = sections;
            self.filteredSections = sections;
            self.filteredSectionTitles = [self.sectionTitles mutableCopy];
            if (self.tableView) {
                [self.tableView reloadData];
            }
            
            // 设置备份功能
            [self setupBackupFunctions];
        });
    });
}

- (void)setupBackupFunctions {
    // 确保表格已经加载
    if (!self.tableView) return;
    
    // 找到备份设置项并添加点击事件
    for (NSInteger section = 0; section < self.settingSections.count; section++) {
        NSArray<DYYYSettingItem *> *items = self.settingSections[section];
        for (NSInteger row = 0; row < items.count; row++) {
            DYYYSettingItem *item = items[row];
            
            if ([item.key isEqualToString:@"DYYYBackupSettings"]) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                
                if (cell) {
                    // 移除现有的开关
                    if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                        [cell.accessoryView removeFromSuperview];
                    }
                    
                    // 创建新的按钮
                    UIButton *backupButton = [UIButton buttonWithType:UIButtonTypeSystem];
                    [backupButton setTitle:@"备份" forState:UIControlStateNormal];
                    backupButton.frame = CGRectMake(0, 0, 60, 30);
                    backupButton.layer.cornerRadius = 8;
                    backupButton.backgroundColor = [UIColor systemBlueColor];
                    [backupButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    [backupButton addTarget:self action:@selector(backupSettings) forControlEvents:UIControlEventTouchUpInside];
                    cell.accessoryView = backupButton;
                }
            }
            else if ([item.key isEqualToString:@"DYYYRestoreSettings"]) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                
                if (cell) {
                    // 移除现有的开关
                    if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                        [cell.accessoryView removeFromSuperview];
                    }
                    
                    // 创建新的按钮
                    UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
                    [restoreButton setTitle:@"恢复" forState:UIControlStateNormal];
                    restoreButton.frame = CGRectMake(0, 0, 60, 30);
                    restoreButton.layer.cornerRadius = 8;
                    restoreButton.backgroundColor = [UIColor systemBlueColor];
                    [restoreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    [restoreButton addTarget:self action:@selector(restoreSettings) forControlEvents:UIControlEventTouchUpInside];
                    cell.accessoryView = restoreButton;
                }
            }
        }
    }
}

- (void)backupSettings {
    // 获取所有以DYYY开头的NSUserDefaults键值
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    NSMutableDictionary *dyyySettings = [NSMutableDictionary dictionary];

    for (NSString *key in allDefaults.allKeys) {
        if ([key hasPrefix:@"DYYY"]) {
            dyyySettings[key] = [defaults objectForKey:key];
        }
    }

    // 备份图标文件
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

    NSArray *iconFileNames = @[ @"like_before.png", @"like_after.png", @"comment.png", @"unfavorite.png", @"favorite.png", @"share.png", @"qingping.gif" ];

    NSMutableDictionary *iconBase64Dict = [NSMutableDictionary dictionary];

    for (NSString *iconFileName in iconFileNames) {
        NSString *iconPath = [dyyyFolderPath stringByAppendingPathComponent:iconFileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:iconPath]) {
            // 读取图片数据并转换为Base64
            NSData *imageData = [NSData dataWithContentsOfFile:iconPath];
            if (imageData) {
                NSString *base64String = [imageData base64EncodedStringWithOptions:0];
                iconBase64Dict[iconFileName] = base64String;
            }
        }
    }

    // 将图标Base64数据添加到备份设置中
    if (iconBase64Dict.count > 0) {
        dyyySettings[@"DYYYIconsBase64"] = iconBase64Dict;
    }

    // 转换为JSON数据
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dyyySettings options:NSJSONWritingPrettyPrinted error:&error];

    if (error) {
        [DYYYManager showToast:@"备份失败：无法序列化设置数据"];
        return;
    }

    // 确保目录存在
    if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *backupFileName = [NSString stringWithFormat:@"DYYY_Backup_%@.json", timestamp];
    NSString *tempDir = NSTemporaryDirectory();
    NSString *tempFilePath = [tempDir stringByAppendingPathComponent:backupFileName];

    BOOL success = [jsonData writeToFile:tempFilePath atomically:YES];

    if (!success) {
        [DYYYManager showToast:@"备份失败：无法创建临时文件"];
        return;
    }

    // 创建文档选择器让用户选择保存位置
    NSURL *tempFileURL = [NSURL fileURLWithPath:tempFilePath];
    
    // 使用正确的模式和文档类型
    UIDocumentPickerViewController *documentPicker;
    if (@available(iOS 11.0, *)) {
        documentPicker = [[UIDocumentPickerViewController alloc] initWithURLs:@[tempFileURL] inMode:UIDocumentPickerModeExportToService];
    } else {
        documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:tempFileURL inMode:UIDocumentPickerModeExportToService];
    }

    // 强引用代理对象
    self.backupPickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
    self.backupPickerDelegate.tempFilePath = tempFilePath;
    self.backupPickerDelegate.completionBlock = ^(NSURL *url) {
        // 备份成功
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYManager showToast:@"备份成功"];
        });
    };

    // 使用实例变量而非关联对象
    documentPicker.delegate = self.backupPickerDelegate;

    // iPad上的展示方式
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        documentPicker.popoverPresentationController.sourceView = self.view;
        documentPicker.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                           self.view.bounds.size.height / 2, 
                                                                           0, 0);
    }

    // 修复：安全地呈现视图控制器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:documentPicker animated:YES completion:nil];
    });
}

- (void)restoreSettings {
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json", @"public.text"] inMode:UIDocumentPickerModeImport];
    documentPicker.allowsMultipleSelection = NO;

    // 强引用代理对象
    self.restorePickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
    self.restorePickerDelegate.completionBlock = ^(NSURL *url) {
        if (!url) {
            [DYYYManager showToast:@"未选择备份文件"];
            return;
        }
        
        NSData *jsonData = [NSData dataWithContentsOfURL:url];
        if (!jsonData) {
            [DYYYManager showToast:@"无法读取备份文件"];
            return;
        }

        NSError *jsonError;
        NSDictionary *dyyySettings = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
        if (jsonError || ![dyyySettings isKindOfClass:[NSDictionary class]]) {
            [DYYYManager showToast:@"备份文件格式错误"];
            return;
        }

        // 恢复图标文件
        NSDictionary *iconBase64Dict = dyyySettings[@"DYYYIconsBase64"];
        if (iconBase64Dict && [iconBase64Dict isKindOfClass:[NSDictionary class]]) {
            NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];

            // 确保DYYY文件夹存在
            if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
            }

            // 从Base64还原图标文件
            for (NSString *iconFileName in iconBase64Dict) {
                NSString *base64String = iconBase64Dict[iconFileName];
                if ([base64String isKindOfClass:[NSString class]]) {
                    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
                    if (imageData) {
                        NSString *iconPath = [dyyyFolderPath stringByAppendingPathComponent:iconFileName];
                        [imageData writeToFile:iconPath atomically:YES];
                    }
                }
            }

            NSMutableDictionary *cleanSettings = [dyyySettings mutableCopy];
            [cleanSettings removeObjectForKey:@"DYYYIconsBase64"];
            dyyySettings = cleanSettings;
        }

        // 恢复设置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in dyyySettings) {
            [defaults setObject:dyyySettings[key] forKey:key];
        }
        [defaults synchronize];

        // 在主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYManager showToast:@"设置已恢复，请重启应用以应用所有更改"];
            
            // 刷新设置界面
            [self.tableView reloadData];
        });
    };

    documentPicker.delegate = self.restorePickerDelegate;

    // iPad上的展示方式
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        documentPicker.popoverPresentationController.sourceView = self.view;
        documentPicker.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                           self.view.bounds.size.height / 2, 
                                                                           0, 0);
    }

    // 安全地呈现视图控制器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:documentPicker animated:YES completion:nil];
    });
}

- (void)setupFooterLabel {
    // 创建一个容器视图，用于包含文本和按钮
    UIView *footerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    
    // 创建文本标签
    self.footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 40)];
    self.footerLabel.text = @"Developer By @huamidev\nVersion: 2.1-7++ (修改2025-06-01)";
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    self.footerLabel.font = [UIFont systemFontOfSize:14];
    self.footerLabel.textColor = [UIColor secondaryLabelColor];
    self.footerLabel.numberOfLines = 2;
    [footerContainer addSubview:self.footerLabel];
    
    // 创建"看看源代码"按钮 - 增强动画效果
    UIButton *sourceCodeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sourceCodeButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 50, 200, 40);
    sourceCodeButton.layer.cornerRadius = 20;
    sourceCodeButton.clipsToBounds = YES;
    sourceCodeButton.tag = 101;
    
    // 创建渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = CGRectMake(0, 0, 200, 40);
    gradientLayer.cornerRadius = 20;
    gradientLayer.colors = @[(id)[UIColor systemBlueColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0.5);
    gradientLayer.endPoint = CGPointMake(1, 0.5);
    [sourceCodeButton.layer insertSublayer:gradientLayer atIndex:0];
    
    // 添加动画效果
    CABasicAnimation *gradientAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
    gradientAnimation.fromValue = @[(id)[UIColor systemBlueColor].CGColor, (id)[UIColor systemPurpleColor].CGColor];
    gradientAnimation.toValue = @[(id)[UIColor systemPurpleColor].CGColor, (id)[UIColor systemBlueColor].CGColor];
    gradientAnimation.duration = 3.0;
    gradientAnimation.autoreverses = YES;
    gradientAnimation.repeatCount = HUGE_VALF;
    [gradientLayer addAnimation:gradientAnimation forKey:@"gradientAnimation"];
    
    [sourceCodeButton setTitle:@"👉 看看源代码！" forState:UIControlStateNormal];
    [sourceCodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sourceCodeButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    
    // 添加阴影效果
    sourceCodeButton.layer.shadowColor = [UIColor blackColor].CGColor;
    sourceCodeButton.layer.shadowOffset = CGSizeMake(0, 2);
    sourceCodeButton.layer.shadowRadius = 4;
    sourceCodeButton.layer.shadowOpacity = 0.3;
    
    [sourceCodeButton addTarget:self action:@selector(showSourceCodePopup) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加按下效果
    [sourceCodeButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [sourceCodeButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    
    [footerContainer addSubview:sourceCodeButton];
    
    // 设置容器为表格底部视图
    self.tableView.tableFooterView = footerContainer;
}

- (void)setupSectionTitles {
    self.sectionTitles = [NSMutableArray arrayWithObjects:
                          @"基本设置",
                          @"界面设置",
                          @"隐藏设置",
                          @"移除设置",
                          @"增强功能",
                          @"图标",
                          @"清理&备份",
                          @"热更新",
                          nil];
}

#pragma mark - Avatar Handling

- (void)avatarTapped:(UITapGestureRecognizer *)gesture {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusAuthorized) {
                UIImagePickerController *picker = [[UIImagePickerController alloc] init];
                picker.delegate = self;
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                picker.allowsEditing = YES;
                [self presentViewController:picker animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法访问相册"
                                                                               message:@"请在设置中允许访问相册"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *selectedImage = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (!selectedImage) {
        [DYYYManager showToast:@"无法获取所选图片"];
        return;
    }
    
    BOOL isCustomAlbumPicker = [objc_getAssociatedObject(picker, "isCustomAlbumPicker") boolValue];
    if (isCustomAlbumPicker) {
        NSString *customAlbumImagePath = [self saveCustomAlbumImage:selectedImage];
        if (customAlbumImagePath) {
            [[NSUserDefaults standardUserDefaults] setObject:customAlbumImagePath forKey:@"DYYYCustomAlbumImagePath"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [DYYYManager showToast:@"自定义相册图片已设置"];
            [self.tableView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
        } else {
            [DYYYManager showToast:@"保存自定义相册图片失败"];
        }
    } else {
        NSString *avatarPath = [self avatarImagePath];
        NSData *imageData = UIImageJPEGRepresentation(selectedImage, 0.8);
        [imageData writeToFile:avatarPath atomically:YES];
        self.avatarImageView.image = selectedImage;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)avatarImagePath {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documentsPath stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
}

- (NSString *)saveCustomAlbumImage:(UIImage *)image {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolder = [documentsPath stringByAppendingPathComponent:@"DYYY"];
    
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolder 
                              withIntermediateDirectories:YES 
                                               attributes:nil 
                                                    error:&error];
    if (error) {
        return nil;
    }
    
    NSString *imagePath = [dyyyFolder stringByAppendingPathComponent:@"custom_album_image.png"];
    NSData *imageData = UIImagePNGRepresentation(image);
    if ([imageData writeToFile:imagePath atomically:YES]) {
        return imagePath;
    }
    
    return nil;
}

#pragma mark - Color Picker

- (void)showColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
        UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
        picker.selectedColor = currentColor;
        picker.delegate = (id)self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择背景颜色"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray<NSDictionary *> *colors = @[
            @{@"name": @"粉红", @"color": [UIColor systemRedColor]},
            @{@"name": @"蓝色", @"color": [UIColor systemBlueColor]},
            @{@"name": @"绿色", @"color": [UIColor systemGreenColor]},
            @{@"name": @"黄色", @"color": [UIColor systemYellowColor]},
            @{@"name": @"紫色", @"color": [UIColor systemPurpleColor]},
            @{@"name": @"橙色", @"color": [UIColor systemOrangeColor]},
            @{@"name": @"粉色", @"color": [UIColor systemPinkColor]},
            @{@"name": @"灰色", @"color": [UIColor systemGrayColor]},
            @{@"name": @"白色", @"color": [UIColor whiteColor]},
            @{@"name": @"黑色", @"color": [UIColor blackColor]}
        ];
        for (NSDictionary *colorInfo in colors) {
            NSString *name = colorInfo[@"name"];
            UIColor *color = colorInfo[@"color"];
            UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                self.backgroundColorView.backgroundColor = color;
                NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
                [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                for (NSInteger section = 0; section < self.settingSections.count; section++) {
                    NSArray *items = self.settingSections[section];
                    for (NSInteger row = 0; row < items.count; row++) {
                        DYYYSettingItem *item = items[row];
                        if (item.type == DYYYSettingItemTypeColorPicker) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                            if (self.tableView) {
                                [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                            }
                            break;
                        }
                    }
                }
            }];
            UIImage *colorImage = [self imageWithColor:color size:CGSizeMake(20, 20)];
            [action setValue:colorImage forKey:@"image"];
            [alert addAction:action];
        }
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = self.tableView.bounds;
        }
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 支持 UIColorPickerViewController 回调
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    UIColor *color = viewController.selectedColor;
    self.backgroundColorView.backgroundColor = color;
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // 通知弹窗刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYBackgroundColorChanged" object:nil];
    for (NSInteger section = 0; section < self.settingSections.count; section++) {
        NSArray *items = self.settingSections[section];
        for (NSInteger row = 0; row < items.count; row++) {
            DYYYSettingItem *item = items[row];
            if (item.type == DYYYSettingItemTypeColorPicker) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                if (self.tableView) {
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                }
                break;
            }
        }
    }
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    [self colorPickerViewControllerDidSelectColor:viewController];
}
#endif

- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [color setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, size.width - 2, size.height - 2)];
    path.lineWidth = 1.0;
    [path fill];
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        self.filteredSections = nil;
        self.filteredSectionTitles = nil;
    } else {
        self.isSearching = YES;
        [self filterContentForSearchText:searchText];
    }
    
    [self.tableView reloadData];
}

- (void)filterContentForSearchText:(NSString *)searchText {
    NSMutableArray *filteredSections = [NSMutableArray array];
    NSMutableArray *filteredTitles = [NSMutableArray array];
    
    for (NSInteger i = 0; i < self.settingSections.count; i++) {
        NSArray *section = self.settingSections[i];
        NSMutableArray *filteredSection = [NSMutableArray array];
        
        for (DYYYSettingItem *item in section) {
            // 搜索标题或key
            if ([item.title.lowercaseString containsString:searchText.lowercaseString] ||
                [item.key.lowercaseString containsString:searchText.lowercaseString]) {
                [filteredSection addObject:item];
            }
        }
        
        if (filteredSection.count > 0) {
            [filteredSections addObject:filteredSection];
            [filteredTitles addObject:self.sectionTitles[i]];
        }
    }
    
    self.filteredSections = filteredSections;
    self.filteredSectionTitles = filteredTitles;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isSearching ? self.filteredSections.count : self.settingSections.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    // 确保头部视图高度与返回的高度一致(35)
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 45)];
    headerView.backgroundColor = [UIColor clearColor];
    
    // 修正头部按钮的宽度和位置，使其居中且宽度适当
    UIButton *headerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    // 设置按钮水平居中，并设置合适的宽度
    CGFloat buttonWidth = tableView.bounds.size.width - 55;
    CGFloat buttonX = (tableView.bounds.size.width - buttonWidth) / 5; // 计算使按钮水平居中的X坐标
    headerButton.frame = CGRectMake(buttonX, 2, buttonWidth, 41);
    
    // 使用系统背景色并添加圆角
    headerButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9]; // 半透明白色背景
    headerButton.layer.cornerRadius = 10;
    headerButton.layer.masksToBounds = YES; // 确保内容不超出圆角范围
    
    // 设置标题按钮属性
    headerButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    headerButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [headerButton setTitle:self.isSearching ? self.filteredSectionTitles[section] : self.sectionTitles[section] forState:UIControlStateNormal];
    [headerButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
    headerButton.tag = section;
    [headerButton addTarget:self action:@selector(headerTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // 添加左侧图标 - 使用iPhone原生界面大小
    UIImageView *leftIconImageView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        NSString *iconName = [self iconNameForSection:section];
        UIColor *iconColor = [self iconColorForSection:section];
        
        // 使用更大的图标尺寸，模仿iPhone原生设置界面
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        UIImage *iconImage = [[UIImage systemImageNamed:iconName] imageWithConfiguration:config];
        leftIconImageView.image = iconImage;
        leftIconImageView.tintColor = iconColor;
    } else {
        leftIconImageView.image = [UIImage systemImageNamed:@"gear"];
        leftIconImageView.tintColor = [UIColor systemBlueColor];
    }
    
    // 设置左侧图标位置 - 调整为更大的尺寸和位置
    CGFloat leftIconMargin = 15;
    CGFloat iconSize = 24; // 增大图标尺寸，模仿原生界面
    CGFloat iconY = (41 - iconSize) / 2; // 垂直居中
    leftIconImageView.frame = CGRectMake(leftIconMargin, iconY, iconSize, iconSize);
    leftIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    // 调整标题按钮的内容边距，为左侧图标留出空间
    headerButton.contentEdgeInsets = UIEdgeInsetsMake(0, leftIconMargin + iconSize + 10, 0, 35); // 左边距 = 图标左边距 + 图标宽度 + 间距
    
    // 添加右侧箭头指示器
    UIImageView *arrowImageView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        UIImage *arrowImage = [UIImage systemImageNamed:[self.expandedSections containsObject:@(section)] ? @"chevron.down" : @"chevron.right"];
        
        // 箭头也使用更大的尺寸
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        arrowImage = [arrowImage imageWithConfiguration:config];
        arrowImageView.image = arrowImage;
        arrowImageView.tintColor = [UIColor systemGrayColor];
    } else {
        arrowImageView.image = [UIImage systemImageNamed:[self.expandedSections containsObject:@(section)] ? @"chevron.down" : @"chevron.right"];
        arrowImageView.tintColor = [UIColor systemGrayColor];
    }
    
    // 调整箭头位置到右侧 - 使用更大的尺寸
    CGFloat arrowRightMargin = 15;
    CGFloat arrowSize = 18; // 增大箭头尺寸
    CGFloat arrowY = (41 - arrowSize) / 2; // 垂直居中
    arrowImageView.frame = CGRectMake(buttonWidth - arrowSize - arrowRightMargin, arrowY, arrowSize, arrowSize);
    arrowImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    arrowImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    arrowImageView.layer.shadowOffset = CGSizeMake(0, 1);
    arrowImageView.layer.shadowOpacity = 0.2;
    arrowImageView.layer.shadowRadius = 1.5;
    arrowImageView.tag = 100;
    
    [headerView addSubview:headerButton];
    [headerButton addSubview:leftIconImageView];
    [headerButton addSubview:arrowImageView];
    
    return headerView;
}

- (NSString *)iconNameForSection:(NSInteger)section {
    NSArray *iconNames = @[
        @"slider.horizontal.3",        // 基本设置 - 更直观的控制面板图标
        @"paintpalette.fill",          // 界面设置 - 调色板更符合界面定制
        @"eye.slash.circle.fill",      // 隐藏设置 - 圆形版本更现代
        @"minus.circle.fill",          // 移除设置 - 减号更准确表达移除
        @"wand.and.stars",             // 增强功能 - 魔法棒表示增强/优化
        @"app.badge.fill",             // 图标 - 应用徽章更贴切图标定制
        @"archivebox.fill",            // 清理&备份 - 归档盒子更专业
        @"arrow.clockwise.icloud.fill" // 热更新 - 云端更新图标更准确
    ];
    
    // 获取搜索时的原始分组索引
    NSInteger originalSection = section;
    if (self.isSearching && section < self.filteredSectionTitles.count) {
        NSString *sectionTitle = self.filteredSectionTitles[section];
        originalSection = [self.sectionTitles indexOfObject:sectionTitle];
        if (originalSection == NSNotFound) {
            originalSection = section;
        }
    }
    
    if (originalSection < iconNames.count) {
        return iconNames[originalSection];
    }
    return @"slider.horizontal.3";
}

- (UIColor *)iconColorForSection:(NSInteger)section {
    NSArray *colors = @[
        [UIColor systemBlueColor],      // 基本设置
        [UIColor systemPurpleColor],    // 界面设置  
        [UIColor systemRedColor],       // 隐藏设置
        [UIColor systemOrangeColor],    // 移除设置
        [UIColor systemGreenColor],     // 增强功能
        [UIColor systemPinkColor],      // 图标
        [UIColor systemTealColor],      // 清理&备份
        [UIColor systemIndigoColor]     // 热更新
    ];
    
    // 获取搜索时的原始分组索引
    NSInteger originalSection = section;
    if (self.isSearching && section < self.filteredSectionTitles.count) {
        NSString *sectionTitle = self.filteredSectionTitles[section];
        originalSection = [self.sectionTitles indexOfObject:sectionTitle];
        if (originalSection == NSNotFound) {
            originalSection = section;
        }
    }
    
    if (originalSection < colors.count) {
        return colors[originalSection];
    }
    return [UIColor systemBlueColor];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0; // 使用标准行高
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 35.0; // 保持一致的分组头部高度
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return 0;
    }
    return [self.expandedSections containsObject:@(section)] ? sections[section].count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SettingCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    // 移除旧的重置按钮和其他自定义视图
    for (UIView *view in cell.contentView.subviews) {
        if (view.tag == 555) {
            [view removeFromSuperview];
        }
    }
    
    // 调整文字间距
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 2;  // 行间距
    paragraphStyle.paragraphSpacing = 0;  // 段落间距
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] 
                                         initWithString:item.title 
                                         attributes:@{
                                             NSParagraphStyleAttributeName: paragraphStyle,
                                             NSFontAttributeName: [UIFont systemFontOfSize:16],
                                             NSForegroundColorAttributeName: [UIColor labelColor],
                                             NSKernAttributeName: @(-0.5)  // 字符间距
                                         }];
    
    cell.textLabel.attributedText = attributedText;
    cell.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = nil; // 清空，防止复用时异常
    
    // 特殊处理备份和恢复功能
    if ([item.key isEqualToString:@"DYYYBackupSettings"] || [item.key isEqualToString:@"DYYYRestoreSettings"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    
    // 特殊处理清理功能
    if ([item.key isEqualToString:@"DYYYCleanCache"] || [item.key isEqualToString:@"DYYYCleanSettings"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    
    // 特殊处理热更新功能
    if ([item.key isEqualToString:@"SaveCurrentABTestData"] || 
        [item.key isEqualToString:@"LoadABTestConfigFile"] || 
        [item.key isEqualToString:@"DeleteABTestConfigFile"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    
    // 特殊处理图标自定义功能
    if ([item.key hasPrefix:@"DYYYIcon"]) {
        NSString *saveFilename = nil;
        if ([item.key isEqualToString:@"DYYYIconLikeBefore"]) {
            saveFilename = @"like_before.png";
        } else if ([item.key isEqualToString:@"DYYYIconLikeAfter"]) {
            saveFilename = @"like_after.png";
        } else if ([item.key isEqualToString:@"DYYYIconComment"]) {
            saveFilename = @"comment.png";
        } else if ([item.key isEqualToString:@"DYYYIconUnfavorite"]) {
            saveFilename = @"unfavorite.png";
        } else if ([item.key isEqualToString:@"DYYYIconFavorite"]) {
            saveFilename = @"favorite.png";
        } else if ([item.key isEqualToString:@"DYYYIconShare"]) {
            saveFilename = @"share.png";
        }
        
        if (saveFilename) {
            // 创建一个图标预览按钮
            NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
            NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
            
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
            
            UIButton *iconButton = [UIButton buttonWithType:UIButtonTypeCustom];
            iconButton.frame = CGRectMake(0, 0, 40, 40);
            iconButton.layer.cornerRadius = 20;
            iconButton.clipsToBounds = YES;
            iconButton.layer.borderWidth = 1.0;
            iconButton.layer.borderColor = [UIColor systemGrayColor].CGColor;
            iconButton.backgroundColor = [UIColor systemBackgroundColor];
            
            if (fileExists) {
                // 显示自定义图标
                UIImage *icon = [UIImage imageWithContentsOfFile:imagePath];
                if (icon) {
                    [iconButton setImage:icon forState:UIControlStateNormal];
                    iconButton.contentMode = UIViewContentModeScaleAspectFit;
                } else {
                    // 如果图标加载失败，显示默认设置图标
                    [iconButton setImage:[UIImage systemImageNamed:@"photo"] forState:UIControlStateNormal];
                    [iconButton setTintColor:[UIColor systemBlueColor]];
                }
            } else {
                // 未设置自定义图标，显示选择图标
                [iconButton setImage:[UIImage systemImageNamed:@"plus.circle"] forState:UIControlStateNormal];
                [iconButton setTintColor:[UIColor systemBlueColor]];
            }
            
            // 给按钮添加点击事件，用于打开图标选择器
            [iconButton addTarget:self action:@selector(iconButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            iconButton.tag = indexPath.section * 1000 + indexPath.row;
            
            cell.accessoryView = iconButton;
            return cell;
        }
    }
    
    // 为单元格添加左侧彩色图标
    UIImage *icon = [self iconImageForSettingItem:item];
    if (icon) {
        cell.imageView.image = icon;
        cell.imageView.tintColor = [self colorForSettingItem:item];
    }

    // 微软风格卡片背景
    UIView *card = [cell.contentView viewWithTag:8888];
    if (!card) {
        card = [[UIView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 8, 4)];
        card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        card.layer.cornerRadius = 12;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOpacity = 0.06;
        card.layer.shadowOffset = CGSizeMake(0, 2);
        card.layer.shadowRadius = 4;
        card.tag = 8888;
        [cell.contentView insertSubview:card atIndex:0];
    }
    
    // 创建单元格的配件视图
    UIView *accessoryView = nil;
    
    // 针对scheduleStyle的特殊处理
    if ([item.key isEqualToString:@"DYYYScheduleStyle"]) {
        // 创建显示当前选择的按钮
        UIButton *styleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        styleButton.frame = CGRectMake(0, 0, 120, 30);

        // 获取当前选中的样式
        NSString *currentStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
        BOOL displayEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"];

        if (currentStyle.length == 0) {
            [styleButton setTitle:@"默认" forState:UIControlStateNormal];
        } else {
            NSString *displayValue = currentStyle;
            if ([currentStyle containsString:@"-"]) {
                displayValue = [currentStyle componentsSeparatedByString:@"-"].lastObject;
            }
            [styleButton setTitle:displayValue forState:UIControlStateNormal];
        }

        // 设置按钮状态
        styleButton.enabled = displayEnabled;
        styleButton.alpha = displayEnabled ? 1.0 : 0.5;

        // 添加提示文本
        if (!displayEnabled) {
            cell.detailTextLabel.text = @"需先开启显示进度时长";
            cell.detailTextLabel.textColor = [UIColor systemRedColor];
        } else {
            cell.detailTextLabel.text = nil;
        }

        [styleButton addTarget:self action:@selector(showScheduleStylePicker) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = styleButton;
        return cell;
    }
    
    if (item.type == DYYYSettingItemTypeSwitch) {
        // 开关类型
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        
        // 重要：先设置开关状态，再应用特效
        if ([item.key hasPrefix:@"DYYYisEnableArea"] && 
            ![item.key isEqualToString:@"DYYYisEnableArea"]) {
            BOOL parentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
            switchView.enabled = parentEnabled;
            
            BOOL isAreaSubSwitch = [item.key isEqualToString:@"DYYYisEnableAreaProvince"] ||
                                  [item.key isEqualToString:@"DYYYisEnableAreaCity"] ||
                                  [item.key isEqualToString:@"DYYYisEnableAreaDistrict"] ||
                                  [item.key isEqualToString:@"DYYYisEnableAreaStreet"];
            
            if (isAreaSubSwitch) {
                BOOL anyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaProvince"] ||
                                [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaCity"] ||
                                [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaDistrict"] ||
                                [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAreaStreet"];
                
                if (anyEnabled && parentEnabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:item.key];
                    [switchView setOn:YES];
                } else {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:item.key];
                    [switchView setOn:NO];
                }
            } else {
                BOOL isOn = parentEnabled ? [[NSUserDefaults standardUserDefaults] boolForKey:item.key] : NO;
                [switchView setOn:isOn];
            }
        } else {
            [switchView setOn:[[NSUserDefaults standardUserDefaults] boolForKey:item.key]];
        }
        
        // 立即强制应用特效 - 确保每个开关都有效果
        [switchView applyFuturisticEffects];
        [switchView updateFuturisticEffectsWithState:switchView.isOn animated:NO];
        
        [switchView addTarget:self action:@selector(animatedSwitchToggled:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.section * 1000 + indexPath.row;
        accessoryView = switchView;
    } else if (item.type == DYYYSettingItemTypeTextField) {
        // 文本输入类型
        if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
            NSString *imagePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCustomAlbumImagePath"];
            BOOL fileExists = imagePath && [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
            if (fileExists) {
            // 显示图片预览按钮
            UIButton *previewButton = [UIButton buttonWithType:UIButtonTypeCustom];
            previewButton.frame = CGRectMake(0, 0, 40, 40);
            previewButton.layer.cornerRadius = 8;
            previewButton.clipsToBounds = YES;
            UIImage *img = [UIImage imageWithContentsOfFile:imagePath];
            [previewButton setImage:img forState:UIControlStateNormal];
            [previewButton addTarget:self action:@selector(showImagePickerForCustomAlbum) forControlEvents:UIControlEventTouchUpInside];
            accessoryView = previewButton;
            } else {
            UIButton *chooseButton = [UIButton buttonWithType:UIButtonTypeSystem];
            [chooseButton setTitle:@"选择图片" forState:UIControlStateNormal];
            [chooseButton addTarget:self action:@selector(showImagePickerForCustomAlbum) forControlEvents:UIControlEventTouchUpInside];
            chooseButton.frame = CGRectMake(0, 0, 80, 30);
            accessoryView = chooseButton;
            }
        } else {
            // 关键：加宽文本框宽度，避免被遮挡
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 160, 30)];
            textField.layer.cornerRadius = 8;
            textField.clipsToBounds = YES;
            textField.backgroundColor = [UIColor tertiarySystemFillColor];
            textField.textColor = [UIColor labelColor];
            textField.placeholder = item.placeholder;
            textField.textAlignment = NSTextAlignmentRight;
            textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
            [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingDidEnd];
            textField.tag = indexPath.section * 1000 + indexPath.row;

            accessoryView = textField;

            if ([item.key isEqualToString:@"DYYYAvatarTapText"]) {
                [textField addTarget:self action:@selector(avatarTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            }
        }
    } else if (item.type == DYYYSettingItemTypeSpeedPicker || item.type == DYYYSettingItemTypeColorPicker) {
        // 倍速选择器或颜色选择器类型
        if (item.type == DYYYSettingItemTypeSpeedPicker) {
            UITextField *speedField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
            speedField.text = [NSString stringWithFormat:@"%.2f", [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"]];
            speedField.textColor = [UIColor labelColor];
            speedField.borderStyle = UITextBorderStyleNone;
            speedField.backgroundColor = [UIColor clearColor];
            speedField.textAlignment = NSTextAlignmentRight;
            speedField.enabled = NO;
            speedField.tag = 999;
            accessoryView = speedField;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            // 为菜单背景颜色添加彩色渐变效果
            UIView *colorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
            colorView.layer.cornerRadius = 15;
            colorView.clipsToBounds = YES;
            colorView.layer.borderWidth = 1.0;
            colorView.layer.borderColor = [UIColor whiteColor].CGColor;
            
            // 从 UserDefaults 获取保存的颜色
            NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
            UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
            
            // 创建渐变背景展示当前颜色效果
            CAGradientLayer *gradientLayer = [CAGradientLayer layer];
            gradientLayer.frame = colorView.bounds;
            gradientLayer.cornerRadius = 15;
            
            // 使用当前颜色创建渐变效果
            if ([currentColor isEqual:[UIColor whiteColor]] || [currentColor isEqual:[UIColor systemBackgroundColor]]) {
                // 如果是白色或系统背景色，使用彩虹渐变表示取色器
                gradientLayer.colors = @[
                    (id)[UIColor systemRedColor].CGColor,
                    (id)[UIColor systemOrangeColor].CGColor,
                    (id)[UIColor systemYellowColor].CGColor,
                    (id)[UIColor systemGreenColor].CGColor,
                    (id)[UIColor systemBlueColor].CGColor,
                    (id)[UIColor systemPurpleColor].CGColor
                ];
                gradientLayer.startPoint = CGPointMake(0, 0);
                gradientLayer.endPoint = CGPointMake(1, 1);
            } else {
                // 使用选择的颜色进行渐变
                gradientLayer.colors = @[
                    (id)[currentColor colorWithAlphaComponent:0.7].CGColor,
                    (id)currentColor.CGColor,
                    (id)[currentColor colorWithAlphaComponent:0.9].CGColor
                ];
                gradientLayer.startPoint = CGPointMake(0, 0);
                gradientLayer.endPoint = CGPointMake(1, 1);
            }
            
            [colorView.layer insertSublayer:gradientLayer atIndex:0];
            accessoryView = colorView;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    
    // 设置单元格的配件视图
    if (accessoryView) {
        cell.accessoryView = accessoryView;
    }
    
    return cell;
}

// 添加图标按钮点击处理方法
- (void)iconButtonTapped:(UIButton *)sender {
    NSInteger tag = sender.tag;
    NSInteger section = tag / 1000;
    NSInteger row = tag % 1000;
    
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count || row >= sections[section].count) {
        return;
    }
    
    DYYYSettingItem *item = sections[section][row];
    
    NSString *saveFilename = nil;
    if ([item.key isEqualToString:@"DYYYIconLikeBefore"]) {
        saveFilename = @"like_before.png";
    } else if ([item.key isEqualToString:@"DYYYIconLikeAfter"]) {
        saveFilename = @"like_after.png";
    } else if ([item.key isEqualToString:@"DYYYIconComment"]) {
        saveFilename = @"comment.png";
    } else if ([item.key isEqualToString:@"DYYYIconUnfavorite"]) {
        saveFilename = @"unfavorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconFavorite"]) {
        saveFilename = @"favorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconShare"]) {
        saveFilename = @"share.png";
    }
    
    if (saveFilename) {
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
        NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
        
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
        UIImage *previewImage = fileExists ? [UIImage imageWithContentsOfFile:imagePath] : nil;
        
        // 显示图标选择弹窗
        [self showIconOptionsDialogWithTitle:item.title previewImage:previewImage saveFilename:saveFilename];
    }
}

// 添加热更新功能实现方法
- (void)saveCurrentABTestData {
    NSDictionary *currentData = getCurrentABTestData();
    if (!currentData) {
        [DYYYManager showToast:@"获取ABTest数据失败"];
        return;
    }
    
    // 保存到文档目录
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
    NSString *configPath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_config.json"];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:currentData options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error) {
        [DYYYManager showToast:@"序列化数据失败"];
        return;
    }
    
    // 确保目录存在
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    if ([jsonData writeToFile:configPath atomically:YES]) {
        [DYYYManager showToast:@"ABTest配置已保存"];
    } else {
        [DYYYManager showToast:@"保存失败"];
    }
}

- (void)loadABTestConfigFile {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self.restorePickerDelegate;
    picker.allowsMultipleSelection = NO;
    
    self.restorePickerDelegate.completionBlock = ^(NSURL *url) {
        [self processABTestConfigFile:url];
    };
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)processABTestConfigFile:(NSURL *)url {
    NSError *error;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    
    if (error) {
        [DYYYManager showToast:@"读取文件失败"];
        return;
    }
    
    NSDictionary *configData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error) {
        [DYYYManager showToast:@"解析JSON失败"];
        return;
    }
    
    // 应用ABTest配置
    Class AWEABTestManagerClass = NSClassFromString(@"AWEABTestManager");
    if (AWEABTestManagerClass) {
        id manager = [AWEABTestManagerClass performSelector:@selector(sharedManager)];
        if ([manager respondsToSelector:@selector(setAbTestData:)]) {
            [manager performSelector:@selector(setAbTestData:) withObject:configData];
            [DYYYManager showToast:@"ABTest配置已应用"];
        }
    }
}

- (void)deleteABTestConfigFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
    NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:jsonFilePath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:jsonFilePath error:&error];
        
        if (!error) {
            gFileExists = NO;
            gFixedABTestData = nil;
            [DYYYManager showToast:@"ABTest配置文件已删除"];
        } else {
            [DYYYManager showToast:[NSString stringWithFormat:@"删除配置文件失败: %@", error.localizedDescription]];
        }
    } else {
        [DYYYManager showToast:@"没有找到ABTest配置文件"];
    }
}

// 在 handleABTestBlockEnabled 和 handleABTestPatchEnabled 方法中实现切换功能
- (void)handleABTestBlockEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"DYYYABTestBlockEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DYYYManager showToast:enabled ? @"已启用ABTest拦截" : @"已关闭ABTest拦截"];
}

- (void)handleABTestPatchEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"DYYYABTestPatchEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DYYYManager showToast:enabled ? @"已启用ABTest补丁模式" : @"已关闭ABTest补丁模式"];
}

// 根据设置项返回图标名称
- (UIImage *)iconImageForSettingItem:(DYYYSettingItem *)item {
    NSString *iconName;
    
    // 为新增功能添加图标
    if ([item.key isEqualToString:@"DYYYEnableVideoHighestQuality"]) {
        iconName = @"4k.tv.fill";
    } else if ([item.key isEqualToString:@"DYYYEnableNoiseFilter"]) {
        iconName = @"waveform.path.ecg";
    } else if ([item.key isEqualToString:@"DYYYisEnableAutoPlay"]) {
        iconName = @"play.circle.fill";
    } else if ([item.key isEqualToString:@"DYYYisEnableModern"]) {
        iconName = @"rectangle.3.group.fill";
    } else if ([item.key isEqualToString:@"DYYYEnableSaveAvatar"]) {
        iconName = @"person.crop.circle.badge.plus";
    } else if ([item.key containsString:@"Comment"] && [item.key containsString:@"NotWaterMark"]) {
        iconName = @"bubble.left.and.bubble.right.fill";
    } else if ([item.key isEqualToString:@"DYYYFourceDownloadEmotion"]) {
        iconName = @"face.smiling.inverse";
    } 
    // 为彩色取色器添加特殊处理
    else if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
        iconName = @"paintpalette.fill";
    } 
    // 为侧栏简化功能添加特殊处理
    else if ([item.key isEqualToString:@"DYYYStreamlinethesidebar"]) {
        iconName = @"sidebar.left";
    }
    // 为深色键盘功能添加特殊处理
    else if ([item.key isEqualToString:@"DYYYisDarkKeyBoard"]) {
        iconName = @"keyboard";
    }
    // 其他根据设置项的key选择合适的图标...
    else if ([item.key containsString:@"Danmu"] || [item.key containsString:@"弹幕"]) {
        iconName = @"text.bubble.fill";
    } else if ([item.key containsString:@"Color"] || [item.key containsString:@"颜色"]) {
        iconName = @"paintbrush.fill";
    } else if ([item.key containsString:@"Hide"] || [item.key containsString:@"hidden"]) {
        iconName = @"eye.slash.fill";
    } else if ([item.key containsString:@"Download"] || [item.key containsString:@"下载"]) {
        iconName = @"arrow.down.circle.fill";
    } else if ([item.key containsString:@"Video"] || [item.key containsString:@"视频"]) {
        iconName = @"video.fill";
    } else if ([item.key containsString:@"Audio"] || [item.key containsString:@"音频"]) {
        iconName = @"speaker.wave.2.fill";
    } else if ([item.key containsString:@"Image"] || [item.key containsString:@"图片"]) {
        iconName = @"photo.fill";
    } else if ([item.key containsString:@"Speed"] || [item.key containsString:@"倍速"]) {
        iconName = @"speedometer";
    } else if ([item.key containsString:@"Enable"] || [item.key containsString:@"启用"]) {
        iconName = @"checkmark.circle.fill";
    } else if ([item.key containsString:@"Disable"] || [item.key containsString:@"禁用"]) {
        iconName = @"xmark.circle.fill";
    } else if ([item.key containsString:@"Time"] || [item.key containsString:@"时间"]) {
        iconName = @"clock.fill";
    } else if ([item.key containsString:@"Date"] || [item.key containsString:@"日期"]) {
        iconName = @"calendar";
    } else if ([item.key containsString:@"Button"] || [item.key containsString:@"按钮"]) {
        iconName = @"hand.tap.fill";
    } else if ([item.key containsString:@"Avatar"] || [item.key containsString:@"头像"]) {
        iconName = @"person.crop.circle.fill";
    } else if ([item.key containsString:@"Comment"] || [item.key containsString:@"评论"]) {
        iconName = @"message.fill";
    } else if ([item.key containsString:@"Clean"] || [item.key containsString:@"清理"] || [item.key containsString:@"清屏"]) {
        iconName = @"trash.fill";
    } else if ([item.key containsString:@"Share"] || [item.key containsString:@"分享"]) {
        iconName = @"square.and.arrow.up.fill";
    } else if ([item.key containsString:@"Background"] || [item.key containsString:@"背景"]) {
        iconName = @"rectangle.fill.on.rectangle.fill";
    } else if ([item.key containsString:@"Like"] || [item.key containsString:@"点赞"]) {
        iconName = @"heart.fill";
    } else if ([item.key containsString:@"Notification"] || [item.key containsString:@"通知"]) {
        iconName = @"bell.fill";
    } else if ([item.key containsString:@"Copy"] || [item.key containsString:@"复制"]) {
        iconName = @"doc.on.doc.fill";
    } else if ([item.key containsString:@"Emotion"] || [item.key containsString:@"表情"]) {
        iconName = @"face.smiling.fill";
    } else if ([item.key containsString:@"Text"] || [item.key containsString:@"文本"]) {
        iconName = @"text.alignleft";
    } else if ([item.key containsString:@"Location"] || [item.key containsString:@"位置"] || [item.key containsString:@"属地"]) {
        iconName = @"location.fill";
    } else if ([item.key containsString:@"Area"] || [item.key containsString:@"地区"]) {
        iconName = @"mappin.and.ellipse";
    } else if ([item.key containsString:@"Layout"] || [item.key containsString:@"布局"]) {
        iconName = @"square.grid.2x2.fill";
    } else if ([item.key containsString:@"Transparent"] || [item.key containsString:@"透明"]) {
        iconName = @"square.on.circle.fill";
    } else if ([item.key containsString:@"Live"] || [item.key containsString:@"直播"]) {
        iconName = @"antenna.radiowaves.left.and.right";
    } else if ([item.key containsString:@"Double"] || [item.key containsString:@"双击"]) {
        iconName = @"hand.tap.fill";
    } else if ([item.key containsString:@"Long"] || [item.key containsString:@"长按"]) {
        iconName = @"hand.draw.fill";
    } else if ([item.key containsString:@"ScreenDisplay"] || [item.key containsString:@"全屏"]) {
        iconName = @"rectangle.expand.vertical";
    } else if ([item.key containsString:@"Index"] || [item.key containsString:@"首页"]) {
        iconName = @"house.fill";
    } else if ([item.key containsString:@"Friends"] || [item.key containsString:@"朋友"]) {
        iconName = @"person.2.fill";
    } else if ([item.key containsString:@"Msg"] || [item.key containsString:@"消息"]) {
        iconName = @"envelope.fill";
    } else if ([item.key containsString:@"Self"] || [item.key containsString:@"我的"]) {
        iconName = @"person.crop.square.fill";
    } else if ([item.key containsString:@"NoAds"] || [item.key containsString:@"广告"]) {
        iconName = @"xmark.octagon.fill";
    } else if ([item.key containsString:@"NoUpdates"] || [item.key containsString:@"更新"]) {
        iconName = @"arrow.triangle.2.circlepath";
    } else if ([item.key containsString:@"InterfaceDownload"] || [item.key containsString:@"接口"]) {
        iconName = @"link.circle.fill";
    } else if ([item.key containsString:@"Scale"] || [item.key containsString:@"缩放"]) {
        iconName = @"arrow.up.left.and.down.right.magnifyingglass";
    } else if ([item.key containsString:@"Blur"] || [item.key containsString:@"模糊"] || [item.key containsString:@"玻璃"]) {
        iconName = @"drop.fill";
    } else if ([item.key containsString:@"Shop"] || [item.key containsString:@"商城"]) {
        iconName = @"cart.fill";
    } else if ([item.key containsString:@"Tips"] || [item.key containsString:@"提示"]) {
        iconName = @"exclamationmark.bubble.fill";
    } else if ([item.key containsString:@"Format"] || [item.key containsString:@"格式"]) {
        iconName = @"textformat";
    } else if ([item.key containsString:@"Filter"] || [item.key containsString:@"过滤"]) {
        iconName = @"line.horizontal.3.decrease.circle.fill";
    } else {
        // 默认图标
        iconName = @"gearshape.fill";
    }
    
    UIImage *icon = [UIImage systemImageNamed:iconName];
    if (@available(iOS 15.0, *)) {
        // 为颜色背景特殊处理
        if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
            return [icon imageWithConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[UIColor systemPinkColor]]];
        }
        return [icon imageWithConfiguration:[UIImageSymbolConfiguration configurationWithHierarchicalColor:[self colorForSettingItem:item]]];
    } else {
        return icon;
    }
}

// 根据设置项返回颜色
- (UIColor *)colorForSettingItem:(DYYYSettingItem *)item {
    // 为取色器和特定功能设置特殊颜色
    if ([item.key isEqualToString:@"DYYYBackgroundColor"]) {
        return [UIColor systemPinkColor];
    } else if ([item.key isEqualToString:@"DYYYStreamlinethesidebar"]) {
        return [UIColor systemIndigoColor];
    } else if ([item.key isEqualToString:@"DYYYisDarkKeyBoard"]) {
        return [UIColor systemGrayColor];
    }
    
    // 根据设置项类型返回不同颜色
    if ([item.key containsString:@"Hide"] || [item.key containsString:@"hidden"]) {
        return [UIColor systemRedColor];
    } else if ([item.key containsString:@"Enable"] || [item.key containsString:@"启用"]) {
        return [UIColor systemGreenColor];
    } else if ([item.key containsString:@"Color"] || [item.key containsString:@"颜色"]) {
        return [UIColor systemPurpleColor];
    } else if ([item.key containsString:@"Copy"] || [item.key containsString:@"复制"]) {
        return [UIColor systemTealColor];
    } else if ([item.key containsString:@"Emotion"] || [item.key containsString:@"表情"]) {
        return [UIColor systemYellowColor];
    } else if ([item.key containsString:@"Double"] || [item.key containsString:@"双击"]) {
        return [UIColor systemOrangeColor];
    } else if ([item.key containsString:@"Download"] || [item.key containsString:@"下载"]) {
        return [UIColor systemBlueColor];
    } else if ([item.key containsString:@"Video"] || [item.key containsString:@"视频"]) {
        return [UIColor systemIndigoColor];
    } else if ([item.key containsString:@"Audio"] || [item.key containsString:@"音频"]) {
        return [UIColor systemTealColor];
    } else if ([item.key containsString:@"Speed"] || [item.key containsString:@"倍速"]) {
        return [UIColor systemYellowColor];
    } else if ([item.key containsString:@"Time"] || [item.key containsString:@"时间"]) {
        return [UIColor systemOrangeColor];
    }
    
    // 默认颜色
    return [UIColor systemBlueColor];
}

// 微软风格UISwitch动画，联动卡片
- (void)animatedSwitchToggled:(UISwitch *)sender {
    [sender applyFuturisticEffects];
    [sender updateFuturisticEffectsWithState:sender.isOn animated:YES];
    UITableViewCell *cell = (UITableViewCell *)sender.superview.superview;
    UIView *card = [cell.contentView viewWithTag:8888];
    // 卡片和switch联动弹跳+高光
    [UIView animateWithDuration:0.10 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.90, 0.90);
        sender.alpha = 0.7;
        sender.layer.shadowColor = [UIColor systemBlueColor].CGColor;
        sender.layer.shadowOpacity = 0.18;
        sender.layer.shadowRadius = 8;
        sender.layer.shadowOffset = CGSizeMake(0, 2);
        card.transform = CGAffineTransformMakeScale(0.97, 0.97);
               card.layer.shadowOpacity =0.18;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.7 options:0 animations:^{
            sender.transform = CGAffineTransformIdentity;
            sender.alpha = 1.0;
            sender.layer.shadowOpacity = 0.0;
            card.transform = CGAffineTransformIdentity;
            card.layer.shadowOpacity = 0.06;
        } completion:nil];
    }];
    [self switchToggled:sender];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat cornerRadius = 10.0;
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds
                                                  byRoundingCorners:(indexPath.row == 0 ? (UIRectCornerTopLeft | UIRectCornerTopRight) : 0) |
                                                                   (indexPath.row == [tableView numberOfRowsInSection:indexPath.section] - 1 ? (UIRectCornerBottomLeft | UIRectCornerBottomRight) : 0)
                                                        cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    
    // 添加清理缓存功能处理
    if ([item.key isEqualToString:@"DYYYCleanCache"]) {
        [self handleCleanCache];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加清除设置功能
    if ([item.key isEqualToString:@"DYYYCleanSettings"]) {
        [DYYYBottomAlertView showAlertWithTitle:@"清除抖音设置"
                message:@"确定要清除抖音所有设置吗？\n这将无法恢复，应用会自动退出！"
                cancelButtonText:@"取消"
                confirmButtonText:@"确定"
                cancelAction:nil
                confirmAction:^{
                    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
                    if (paths.count > 0) {
                        NSString *preferencesPath = [paths.firstObject stringByAppendingPathComponent:@"Preferences"];
                        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
                        NSString *plistPath = [preferencesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleIdentifier]];

                        NSError *error = nil;
                        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:&error];

                        if (!error) {
                            [DYYYManager showToast:@"抖音设置已清除，应用即将退出"];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                              exit(0);
                            });
                        } else {
                            [DYYYManager showToast:[NSString stringWithFormat:@"清除失败: %@", error.localizedDescription]];
                        }
                    }
                }];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加备份设置功能处理
    if ([item.key isEqualToString:@"DYYYBackupSettings"]) {
        [self backupSettings];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 添加恢复设置功能处理
    if ([item.key isEqualToString:@"DYYYRestoreSettings"]) {
        [self restoreSettings];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 处理图标自定义项
    if ([item.key hasPrefix:@"DYYYIcon"]) {
        [self handleIconSelection:item];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 热更新功能处理
    if ([item.key isEqualToString:@"SaveCurrentABTestData"]) {
        [self saveCurrentABTestData];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    } else if ([item.key isEqualToString:@"LoadABTestConfigFile"]) {
        [self loadABTestConfigFile];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    } else if ([item.key isEqualToString:@"DeleteABTestConfigFile"]) {
        [self deleteABTestConfigFile];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    if (item.type == DYYYSettingItemTypeCustomPicker && [item.key isEqualToString:@"DYYYScheduleStyle"]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"]) {
            [DYYYManager showToast:@"请先开启\"显示进度时长\"选项"];
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择进度条样式"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray *styles = @[
            @{@"title": @"进度条右侧剩余", @"value": @"进度条右侧剩余"},
            @{@"title": @"进度条右侧完整", @"value": @"进度条右侧完整"},
            @{@"title": @"进度条左侧剩余", @"value": @"进度条左侧剩余"},
            @{@"title": @"进度条左侧完整", @"value": @"进度条左侧完整"},
            @{@"title": @"进度条两侧左右", @"value": @"进度条两侧左右"}
        ];
        for (NSDictionary *style in styles) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:style[@"title"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] setObject:style[@"value"] forKey:@"DYYYScheduleStyle"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [self.tableView reloadData];
            }];
            [alert addAction:action];
        }
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
            alert.popoverPresentationController.sourceView = selectedCell;
            alert.popoverPresentationController.sourceRect = selectedCell.bounds;
        }
        [self presentViewController:alert animated:YES completion:nil];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    if (item.type == DYYYSettingItemTypeSpeedPicker) {
        [self showSpeedPicker];
    } else if (item.type == DYYYSettingItemTypeColorPicker) {
        [self showColorPicker];
    } else if ([item.key isEqualToString:@"DYYYfilterKeywords"]) {
        // 获取当前已保存的关键词
        NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"];
        
        // 创建并显示过滤设置视图
        DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"设置过滤关键词" text:currentKeywords];
        [filterView showWithConfirmBlock:^(NSString *selectedText) {
            [[NSUserDefaults standardUserDefaults] setObject:selectedText forKey:@"DYYYfilterKeywords"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        } cancelBlock:nil];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)handleIconSelection:(DYYYSettingItem *)item {
    NSString *saveFilename = nil;
    
    // 映射图标类型到文件名
    if ([item.key isEqualToString:@"DYYYIconLikeBefore"]) {
        saveFilename = @"like_before.png";
    } else if ([item.key isEqualToString:@"DYYYIconLikeAfter"]) {
        saveFilename = @"like_after.png";
    } else if ([item.key isEqualToString:@"DYYYIconComment"]) {
        saveFilename = @"comment.png";
    } else if ([item.key isEqualToString:@"DYYYIconUnfavorite"]) {
        saveFilename = @"unfavorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconFavorite"]) {
        saveFilename = @"favorite.png";
    } else if ([item.key isEqualToString:@"DYYYIconShare"]) {
        saveFilename = @"share.png";
    }
    
    if (saveFilename) {
        // 获取图标路径
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
        NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
        
        // 检查是否已有自定义图标
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
        UIImage *previewImage = fileExists ? [UIImage imageWithContentsOfFile:imagePath] : nil;
        
        // 显示图标选项对话框
        [self showIconOptionsDialogWithTitle:item.title previewImage:previewImage saveFilename:saveFilename];
    }
}

// 添加这个辅助方法
- (void)showIconOptionsDialogWithTitle:(NSString *)title previewImage:(UIImage *)previewImage saveFilename:(NSString *)saveFilename {
    DYYYIconOptionsDialogView *optionsDialog = [[DYYYIconOptionsDialogView alloc] initWithTitle:title previewImage:previewImage];
    
    // 确保DYYY文件夹存在
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
    NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    __weak typeof(self) weakSelf = self;
    
    // 设置清除按钮回调
    optionsDialog.onClear = ^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:imagePath error:&error];
            if (!error) {
                [DYYYManager showToast:@"已恢复默认图标"];
                [weakSelf.tableView reloadData];
            }
        }
    };
    
    // 设置选择按钮回调
    optionsDialog.onSelect = ^{
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.allowsEditing = NO;
        picker.mediaTypes = @[@"public.image"];
        DYYYImagePickerDelegate *pickerDelegate = [[DYYYImagePickerDelegate alloc] init];
        pickerDelegate.completionBlock = ^(NSDictionary *info) {
            NSURL *imageURL = info[UIImagePickerControllerImageURL];
            if (!imageURL) {
                imageURL = info[UIImagePickerControllerReferenceURL];
            }
            
            if (imageURL) {
                NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
                if (imageData) {
                    // 检测是否为GIF
                    const char *bytes = (const char *)imageData.bytes;
                    BOOL isGIF = (imageData.length >= 6 && (memcmp(bytes, "GIF87a", 6) == 0 || memcmp(bytes, "GIF89a", 6) == 0));
                    
                    if (isGIF) {
                        [imageData writeToFile:imagePath atomically:YES];
                    } else {
                        UIImage *selectedImage = [UIImage imageWithData:imageData];
                        NSData *pngData = UIImagePNGRepresentation(selectedImage);
                        [pngData writeToFile:imagePath atomically:YES];
                    }
                    
                    [DYYYManager showToast:@"图标已设置，重启应用生效"];
                    [weakSelf.tableView reloadData];
                }
            }
        };
        
        static char kDYYYPickerDelegateKey;
        picker.delegate = pickerDelegate;
        objc_setAssociatedObject(picker, &kDYYYPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [weakSelf presentViewController:picker animated:YES completion:nil];
    };
    
    [optionsDialog show];
}

- (void)showSpeedPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择倍速"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *speeds = @[@0.75, @1.0, @1.25, @1.5, @2.0, @2.5, @3.0];
    for (NSNumber *speed in speeds) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%.2f", speed.floatValue]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setFloat:speed.floatValue forKey:@"DYYYDefaultSpeed"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            for (NSInteger section = 0; section < self.settingSections.count; section++) {
                NSArray *items = self.settingSections[section];
                for (NSInteger row = 0; row < items.count; row++) {
                    DYYYSettingItem *item = items[row];
                    if (item.type == DYYYSettingItemTypeSpeedPicker) {
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                        UITextField *speedField = [cell.accessoryView viewWithTag:999];
                        if (speedField) {
                            speedField.text = [NSString stringWithFormat:@"%.2f", speed.floatValue];
                        }
                        break;
                    }
                }
            }
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:[self.tableView indexPathForSelectedRow]];
        alert.popoverPresentationController.sourceView = selectedCell;
        alert.popoverPresentationController.sourceRect = selectedCell.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (void)switchToggled:(UISwitch *)sender {
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;
    NSArray *currentSection = self.isSearching ? self.filteredSections[section] : self.settingSections[section];
    DYYYSettingItem *item = currentSection[row];

    // 保存设置值
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:item.key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // 互斥逻辑：按钮大/中/小只能选一个
    if (([item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
         [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
         [item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"]) && sender.isOn) {
        [self updateMutuallyExclusiveSwitches:section excludingItemKey:item.key];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:item.key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // 只在总开关从关闭变为打开时，自动打开所有子开关
    if ([item.key isEqualToString:@"DYYYEnableFloatClearButton"] && sender.isOn) {
        NSArray<NSString *> *subKeys = @[
            @"DYYYHideDanmaku",
            @"DYYYEnabshijianjindu",
            @"DYYYHideTimeProgress",
            @"DYYYHideSlider",
            @"DYYYHideTabBar",
            @"DYYYHideSpeed"
        ];
        NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
        for (NSUInteger r = 0; r < sectionItems.count; r++) {
            DYYYSettingItem *subItem = sectionItems[r];
            if ([subKeys containsObject:subItem.key]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:subItem.key];
                NSIndexPath *cellPath = [NSIndexPath indexPathForRow:r inSection:section];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
                if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                    UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                    subSwitch.on = YES;
                }
            }
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // 特定功能处理 - 确保菜单开关能控制功能
    if ([item.key isEqualToString:@"DYYYStreamlinethesidebar"]) {
        [DYYYManager showToast:sender.isOn ? @"侧栏简化已启用，重新打开侧栏生效" : @"侧栏简化已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYisDarkKeyBoard"]) {
        [DYYYManager showToast:sender.isOn ? @"深色键盘已启用" : @"深色键盘已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYEnableVideoHighestQuality"]) {
        [DYYYManager showToast:sender.isOn ? @"默认最高画质已启用" : @"默认最高画质已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYEnableNoiseFilter"]) {
        [DYYYManager showToast:sender.isOn ? @"视频降噪增强已启用" : @"视频降噪增强已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYisEnableAutoPlay"]) {
        [DYYYManager showToast:sender.isOn ? @"自动播放已启用，重启应用生效" : @"自动播放已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYisEnableModern"]) {
        [DYYYManager showToast:sender.isOn ? @"现代面板已启用" : @"现代面板已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYEnableSaveAvatar"]) {
        [DYYYManager showToast:sender.isOn ? @"保存头像功能已启用" : @"保存头像功能已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYCommentLivePhotoNotWaterMark"]) {
        [DYYYManager showToast:sender.isOn ? @"评论动图保存已启用" : @"评论动图保存已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYCommentNotWaterMark"]) {
        [DYYYManager showToast:sender.isOn ? @"评论图片保存已启用" : @"评论图片保存已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYFourceDownloadEmotion"]) {
        [DYYYManager showToast:sender.isOn ? @"强制下载表情已启用，重启应用生效" : @"强制下载表情已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYfollowTips"]) {
        [DYYYManager showToast:sender.isOn ? @"关注二次确认已启用" : @"关注二次确认已关闭"];
    }
    else if ([item.key isEqualToString:@"DYYYcollectTips"]) {
        [DYYYManager showToast:sender.isOn ? @"收藏二次确认已启用" : @"收藏二次确认已关闭"];
    }
    // 隐藏功能的处理
    else if ([item.key isEqualToString:@"DYYYHideGuideTipView"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏搜索引导提示框" : @"已显示搜索引导提示框"];
    }
    else if ([item.key isEqualToString:@"DYYYHideFeedTabJumpGuide"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏顶栏引导提示" : @"已显示顶栏引导提示"];
    }
    else if ([item.key isEqualToString:@"DYYYHideWords"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏大家都在搜" : @"已显示大家都在搜"];
    }
    else if ([item.key isEqualToString:@"DYYYHideShowPlayletComment"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏短剧免费去看" : @"已显示短剧免费去看"];
    }
    else if ([item.key isEqualToString:@"DYYYHideCommentMusicAnchor"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏评论音乐" : @"已显示评论音乐"];
    }
    else if ([item.key isEqualToString:@"DYYYHidePOIEntryAnchor"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏评论定位" : @"已显示评论定位"];
    }
    else if ([item.key isEqualToString:@"DYYYHideCommentSearchAnchor"]) {
        [DYYYManager showToast:sender.isOn ? @"已隐藏评论搜索" : @"已显示评论搜索"];
    }
    // ABTest热更新功能
    else if ([item.key isEqualToString:@"DYYYABTestBlockEnabled"]) {
        [self handleABTestBlockEnabled:sender.isOn];
    }
    else if ([item.key isEqualToString:@"DYYYABTestPatchEnabled"]) {
        [self handleABTestPatchEnabled:sender.isOn];
    }

    // 进度时长依赖处理
    if ([item.key isEqualToString:@"DYYYisShowScheduleDisplay"]) {
        // 关闭时，清空样式设置
        if (!sender.isOn) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYScheduleStyle"];
        }
        // 刷新相关cell
        for (NSInteger s = 0; s < self.settingSections.count; s++) {
            NSArray *items = self.settingSections[s];
            for (NSInteger r = 0; r < items.count; r++) {
                DYYYSettingItem *subItem = items[r];
                if ([subItem.key isEqualToString:@"DYYYScheduleStyle"]) {
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
                    [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        }
    }

    // 处理开关依赖关系
    [self updateSwitchDependencies:item.key isEnabled:sender.isOn section:section];

    // 主动发送设置变更通知，确保清屏按钮、隐藏功能、倍速按钮等立即响应
    NSArray *floatButtonKeys = @[
        // 清屏相关
        @"DYYYEnableFloatClearButton",
        @"DYYYEnableFloatClearButtonSize",
        @"DYYYCustomAlbumSizeLarge",
        @"DYYYCustomAlbumSizeMedium",
        @"DYYYCustomAlbumSizeSmall",
        @"DYYYCustomAlbumImagePath",
        @"DYYYEnableCustomAlbum",
        @"DYYYHideTabBar",
        @"DYYYHideDanmaku",
        @"DYYYHideSlider",
        @"DYYYHideChapter",
        // 倍速相关
        @"DYYYEnableFloatSpeedButton",
        @"DYYYSpeedSettings",
        @"DYYYSpeedButtonShowX",
        @"DYYYSpeedButtonSize"
    ];
    if ([floatButtonKeys containsObject:item.key] || [item.key hasPrefix:@"DYYYHide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYSettingChanged"
                                                            object:nil
                                                          userInfo:@{@"key": item.key, @"value": @(sender.isOn)}];
    }

    // 触觉反馈
    [self.feedbackGenerator impactOccurred];
}

// 开关依赖关系处理方法
- (void)updateSwitchDependencies:(NSString *)key isEnabled:(BOOL)enabled section:(NSInteger)section {
    // 处理清屏功能子选项
    if ([key isEqualToString:@"DYYYEnableFloatClearButton"]) {
        [self updateClearButtonSubSwitchesUI:section enabled:enabled];
    }
    // 处理长按功能子选项
    else if ([key isEqualToString:@"DYYYLongPressDownload"]) {
        [self updateLongPressSubSwitchesUI:section enabled:enabled];
    }
    // 处理时间属地显示的子选项
    else if ([key isEqualToString:@"DYYYisEnableArea"]) {
        [self updateAreaSubSwitchesUI:section enabled:enabled];
    }
    // 处理视频显示日期时间的子选项
    else if ([key isEqualToString:@"DYYYShowDateTime"]) {
        [self updateDateTimeFormatSubSwitchesUI:section enabled:enabled];
    }
    // 处理主页自定义总开关
    else if ([key isEqualToString:@"DYYYEnableSocialStatsCustom"]) {
        [self updateSubswitchesForSection:section parentKey:key];
    }
    // 处理视频自定义总开关
    else if ([key isEqualToString:@"DYYYEnableVideoStatsCustom"]) {
        [self updateSubswitchesForSection:section parentKey:key];
    }
}

- (void)updateClearButtonSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<NSString *> *subKeys = @[
        @"DYYYHideDanmaku",
        @"DYYYEnabshijianjindu", 
        @"DYYYHideTimeProgress",
        @"DYYYHideSlider",
        @"DYYYHideTabBar",
        @"DYYYHideSpeed"
    ];
    
    [self updateSubSwitchesInSection:section withKeys:subKeys enabled:enabled];
}

- (void)updateLongPressSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<NSString *> *subKeys = @[
        @"DYYYLongPressSaveVideo",
        @"DYYYLongPressSaveAudio",
        @"DYYYEnableFLEX",
        @"DYYYLongPressSaveCurrentImage",
        @"DYYYLongPressSaveAllImages",
        @"DYYYLongPressCopyLink",
        @"DYYYLongPressApiDownload",
        @"DYYYLongPressFilterUser",
        @"DYYYLongPressFilterTitle",
        @"DYYYLongPressTimerClose",
        @"DYYYLongPressCreateVideo"
    ];
    
    [self updateSubSwitchesInSection:section withKeys:subKeys enabled:enabled];
}

- (void)updateSubSwitchesInSection:(NSInteger)section withKeys:(NSArray<NSString *> *)keys enabled:(BOOL)enabled {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([keys containsObject:item.key]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.enabled = enabled;
                subSwitch.alpha = enabled ? 1.0 : 0.5;
                if (!enabled) {
                    subSwitch.on = NO;
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:item.key];
                }
            }
        }
    }
}

- (void)updateAreaMainSwitchUI:(NSInteger)section {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到主开关
        if ([item.key isEqualToString:@"DYYYisEnableArea"]) {
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *mainSwitch = (UISwitch *)cell.accessoryView;
                BOOL shouldBeOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
                mainSwitch.on = shouldBeOn;
            }
            break;
        }
    }
}

- (void)updateAreaSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到所有子开关
        if ([item.key isEqualToString:@"DYYYisEnableAreaProvince"] || 
            [item.key isEqualToString:@"DYYYisEnableAreaCity"] || 
            [item.key isEqualToString:@"DYYYisEnableAreaDistrict"] || 
            [item.key isEqualToString:@"DYYYisEnableAreaStreet"]) {
            
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = enabled;
            }
        }
    }
}

- (void)updateMutuallyExclusiveSwitches:(NSInteger)section excludingItemKey:(NSString *)excludedKey {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        if (([item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
             [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
             [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"]) &&
            ![item.key isEqualToString:excludedKey]) {
            // UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *cellSwitch = (UISwitch *)cell.accessoryView;
                cellSwitch.on = NO;
            }
            // 数据
            [defaults setBool:NO forKey:item.key];
        }
    }
    [defaults synchronize];
}

- (void)updateAllSubswitchesForSection:(NSInteger)section {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 只处理自定义相册尺寸相关的开关
        if ([item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] || 
            [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] || 
            [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"]) {
            
            // 查找并更新cell的开关状态
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *cellSwitch = (UISwitch *)cell.accessoryView;
                cellSwitch.on = NO;
            }
        }
    }
}

- (void)updateSubswitchesForSection:(NSInteger)section parentKey:(NSString *)parentKey {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    NSArray *keysToUpdate = nil;
    
    if ([parentKey isEqualToString:@"DYYYLongPressDownload"]) {
        keysToUpdate = @[
            @"DYYYLongPressSaveVideo",
            @"DYYYEnableFLEX",
            @"DYYYLongPressSaveCover", 
            @"DYYYLongPressSaveAudio",
            @"DYYYLongPressSaveCurrentImage",
            @"DYYYLongPressSaveAllImages",
            @"DYYYLongPressCopyText",
            @"DYYYLongPressCopyLink",
            @"DYYYLongPressApiDownload", 
            @"DYYYLongPressFilterUser",
            @"DYYYLongPressFilterTitle", 
            @"DYYYLongPressTimerClose",
            @"DYYYLongPressCreateVideo"
        ];
    } else if ([parentKey isEqualToString:@"DYYYCopyText"]) {
        keysToUpdate = @[@"DYYYCopyOriginalText", @"DYYYCopyShareLink"];
    } else if ([parentKey isEqualToString:@"DYYYEnableDoubleOpenAlertController"]) {
        keysToUpdate = @[@"DYYYDoubleTapDownload", @"DYYYEnableImageToVideo", 
                          @"DYYYDoubleTapDownloadAudio", @"DYYYDoubleTapCopyDesc", 
                          @"DYYYDoubleTapComment", @"DYYYDoubleTapLike", 
                          @"DYYYDoubleTapshowSharePanel", @"DYYYDoubleTapshowDislikeOnVideo", 
                          @"DYYYDoubleInterfaceDownload"];
    }
    
    if (!keysToUpdate) return;
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        if ([keysToUpdate containsObject:item.key]) {
            // 查找并更新cell的开关状态
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = NO;
            }
        }
    }
}

- (void)updateDateTimeFormatMainSwitchUI:(NSInteger)section {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到主开关
        if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *mainSwitch = (UISwitch *)cell.accessoryView;
                BOOL shouldBeOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYShowDateTime"];
                mainSwitch.on = shouldBeOn;
            }
            break;
        }
    }
}

- (void)updateDateTimeFormatSubSwitchesUI:(NSInteger)section enabled:(BOOL)enabled {
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到所有子开关
        if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
            // 更新UI
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = enabled;
            }
        }
    }
}

- (void)updateDateTimeFormatExclusiveSwitch:(NSInteger)section currentKey:(NSString *)currentKey {
    NSArray<NSString *> *allFormatKeys = @[@"DYYYDateTimeFormat_YMDHM", 
                                          @"DYYYDateTimeFormat_MDHM", 
                                          @"DYYYDateTimeFormat_HMS", 
                                          @"DYYYDateTimeFormat_HM", 
                                          @"DYYYDateTimeFormat_YMD"];
    
    // 关闭所有其他格式开关
    for (NSString *key in allFormatKeys) {
        if (![key isEqualToString:currentKey]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:key];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
        }
    }
    
    // 更新UI
    NSArray<DYYYSettingItem *> *sectionItems = self.settingSections[section];
    
    for (NSUInteger row = 0; row < sectionItems.count; row++) {
        DYYYSettingItem *item = sectionItems[row];
        
        // 找到相关的子开关
        if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
            NSIndexPath *cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellPath];
            
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *subSwitch = (UISwitch *)cell.accessoryView;
                subSwitch.on = [item.key isEqualToString:currentKey];
            }
        }
    }
}

- (void)textFieldDidChange:(UITextField *)textField {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:textField.tag % 1000 inSection:textField.tag / 1000];
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
        return;
    }
    
    DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
    
    // 添加对链接解析接口的特殊处理
    if ([item.key isEqualToString:@"DYYYInterfaceDownload"]) {
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (text.length == 0) {
            textField.text = @"https://api.qsy.ink/api/douyin?key=DYYY&url=";
            [[NSUserDefaults standardUserDefaults] setObject:@"https://api.qsy.ink/api/douyin?key=DYYY&url=" forKey:item.key];
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
        }
    } 
    // 倍速数值设置的特殊处理
    else if ([item.key isEqualToString:@"DYYYSpeedSettings"]) {
        NSString *speedConfig = textField.text;
        if (speedConfig.length == 0) {
            speedConfig = @"1.0,1.25,1.5,2.0";
            textField.text = speedConfig;
        }
        [[NSUserDefaults standardUserDefaults] setObject:speedConfig forKey:item.key];
        [DYYYManager showToast:@"倍速选项已更新"];
    }
    // 倍速按钮大小的特殊处理
    else if ([item.key isEqualToString:@"DYYYSpeedButtonSize"]) {
        NSString *sizeStr = textField.text;
        if (sizeStr.length == 0 || [sizeStr floatValue] <= 0) {
            sizeStr = @"40";
            textField.text = sizeStr;
        }
        [[NSUserDefaults standardUserDefaults] setObject:sizeStr forKey:item.key];
        [DYYYManager showToast:@"倍速按钮大小已更新"];
    } 
    else {
        [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:item.key];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 在设置值保存后添加：
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYSettingChanged" object:nil userInfo:@{
        @"key": item.key,
        @"value": textField.text ?: [NSNull null]
    }];
    
    // 处理特殊键
    if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
        [self showImagePickerForCustomAlbum];
    }
}

- (void)avatarTextFieldDidChange:(UITextField *)textField {
    self.avatarTapLabel.text = textField.text.length > 0 ? textField.text : @"pxx917144686";
}

- (void)headerTapped:(UIButton *)sender {
    // 触发触觉反馈
    [self.feedbackGenerator impactOccurred];
    [self.feedbackGenerator prepare];
    
    NSInteger section = sender.tag;
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return;
    }
    
    BOOL isCurrentExpanded = [self.expandedSections containsObject:@(section)];
    
    // 获取所有需要更新的行信息 - 在修改expandedSections之前
    NSMutableArray<NSIndexPath *> *allRowsToUpdate = [NSMutableArray array];
    NSMutableArray<NSNumber *> *sectionsToUpdate = [NSMutableArray array];
    
    // 收集当前要点击的section的所有行
    NSArray<NSIndexPath *> *currentSectionRows = [self rowsForSection:section];
    [allRowsToUpdate addObjectsFromArray:currentSectionRows];
    [sectionsToUpdate addObject:@(section)];
    
    // 如果当前section不是展开的，需要收集其他已展开section的所有行
    if (!isCurrentExpanded) {
        for (NSNumber *expandedSection in [self.expandedSections copy]) {
            if (![expandedSection isEqualToNumber:@(section)]) {
                NSArray<NSIndexPath *> *expandedSectionRows = [self rowsForSection:[expandedSection integerValue]];
                [allRowsToUpdate addObjectsFromArray:expandedSectionRows];
                [sectionsToUpdate addObject:expandedSection];
            }
        }
        
        // 清空已展开sections，只保留当前section
        [self.expandedSections removeAllObjects];
        [self.expandedSections addObject:@(section)];
    } else {
        // 当前section已展开，需要将其关闭
        [self.expandedSections removeObject:@(section)];
    }
    
    // 更新所有涉及的section头部箭头
    for (NSNumber *sectionNumber in sectionsToUpdate) {
        NSInteger sectionIndex = [sectionNumber integerValue];
        UIView *headerView = [self.tableView headerViewForSection:sectionIndex];
        UIButton *headerButton = [headerView viewWithTag:sectionIndex];
        UIImageView *arrow = [headerButton viewWithTag:100];
        
        BOOL shouldBeExpanded = [self.expandedSections containsObject:sectionNumber];
        
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
            arrow.image = [[UIImage systemImageNamed:shouldBeExpanded ? @"chevron.down" : @"chevron.right"] imageWithConfiguration:config];
        } else {
            arrow.image = [UIImage systemImageNamed:shouldBeExpanded ? @"chevron.down" : @"chevron.right"];
        }
        
        // 动画过渡效果
        [UIView animateWithDuration:0.3 animations:^{
            arrow.transform = shouldBeExpanded ? CGAffineTransformMakeRotation(M_PI/2) : CGAffineTransformIdentity;
        }];
    }
    
    // 简单方式：直接刷新表格而不是试图追踪单独的行操作
    [self.tableView reloadData];
    
    // 如果展开了某个section，让表格视图滚动到该section的位置
    if (!isCurrentExpanded) {
        NSIndexPath *firstRowPath = [NSIndexPath indexPathForRow:0 inSection:section];
        if ([self.tableView numberOfRowsInSection:section] > 0) {
            [self.tableView scrollToRowAtIndexPath:firstRowPath 
                                  atScrollPosition:UITableViewScrollPositionTop 
                                          animated:YES];
        }
    }
}

// 添加主标题文字间距调整
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UIView class]]) {
        UIButton *headerButton = [view viewWithTag:section];
        if ([headerButton isKindOfClass:[UIButton class]]) {
            // 调整标题文字的属性
            UIColor *textColor;
            if (@available(iOS 13.0, *)) {
                textColor = [UIColor labelColor];
            } else {
                textColor = [UIColor darkTextColor];
            }
            
            NSAttributedString *attributedTitle = [[NSAttributedString alloc] 
                                                 initWithString:headerButton.titleLabel.text 
                                                 attributes:@{
                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:17],
                                                     NSForegroundColorAttributeName: textColor,
                                                     NSKernAttributeName: @(-0.8) // 减小字符间距
                                                 }];
            [headerButton setAttributedTitle:attributedTitle forState:UIControlStateNormal];
        }
    }
}

- (NSArray<NSIndexPath *> *)rowsForSection:(NSInteger)section {
    NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
    if (section >= sections.count) {
        return @[];
    }
    NSInteger rowCount = sections[section].count;
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:rowCount];
    for (NSInteger row = 0; row < rowCount; row++) {
        [rows addObject:[NSIndexPath indexPathForRow:row inSection:section]];
    }
    return rows;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (!indexPath) {
            return;
        }
        
        NSArray<NSArray<DYYYSettingItem *> *> *sections = self.isSearching ? self.filteredSections : self.settingSections;
        if (indexPath.section >= sections.count || indexPath.row >= sections[indexPath.section].count) {
            return;
        }
        
        DYYYSettingItem *item = sections[indexPath.section][indexPath.row];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选项"
                                                                      message:item.title
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
        
        if ([item.key isEqualToString:@"DYYYCustomAlbumImage"]) {
            [alert addAction:[UIAlertAction actionWithTitle:@"从相册选择"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary forCustomAlbum:YES];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"使用相机"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera forCustomAlbum:YES];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认图片"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomAlbumImagePath"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:@"自定义相册图片已设置"];
                [self.tableView reloadData];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
            }]];
        }
        
        // 默认重置选项
        UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"重置"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:item.key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // 特殊处理清屏按钮尺寸重置
            if ([item.key isEqualToString:@"DYYYEnableFloatClearButton"] || 
                [item.key isEqualToString:@"DYYYFloatClearButtonSizePreference"]) {
                [[NSUserDefaults standardUserDefaults] setInteger:DYYYButtonSizeMedium 
                                                           forKey:@"DYYYFloatClearButtonSizePreference"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            // 特殊处理日期时间格式相关设置
            if ([item.key isEqualToString:@"DYYYShowDateTime"]) {
                // 重置主开关也重置所有子开关和格式设置
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                
                // 更新UI中子开关的状态
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [self updateDateTimeFormatSubSwitchesUI:section enabled:NO];
                }
            }
            else if ([item.key hasPrefix:@"DYYYDateTimeFormat_"]) {
                // 重置一个子开关时检查是否有其他子开关启用
                BOOL anyEnabled = NO;
                for (NSString *key in @[@"DYYYDateTimeFormat_YMDHM", @"DYYYDateTimeFormat_MDHM", 
                                        @"DYYYDateTimeFormat_HMS", @"DYYYDateTimeFormat_HM", 
                                        @"DYYYDateTimeFormat_YMD"]) {
                    if (![key isEqualToString:key] && [[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                        anyEnabled = YES;
                        break;
                    }
                }
                
                // 如果所有子开关都关闭，也关闭主开关并清除格式
                if (!anyEnabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
                    for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                        [self updateDateTimeFormatMainSwitchUI:section];
                    }
                }
            }
            
            // 特殊处理时间属地显示开关组
            if ([item.key isEqualToString:@"DYYYisEnableArea"]) {
                // 重置主开关也重置所有子开关
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaProvince"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaCity"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaDistrict"];
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaStreet"];
                
                // 更新UI
                for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                    [self updateAreaSubSwitchesUI:section enabled:NO];
                }
            }
            
            // 针对自定义相册图片和大小，重置后刷新按钮
            if ([item.key isEqualToString:@"DYYYCustomAlbumImagePath"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
                [item.key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
                [item.key isEqualToString:@"DYYYEnableCustomAlbum"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
            }
            
            // 处理头像文本
            if ([item.key isEqualToString:@"DYYYAvatarTapText"]) {
                self.avatarTapLabel.text = @"pxx917144686";
            }
            
            // 刷新UI
            [self.tableView reloadData];
            
            // 显示提示
            [DYYYManager showToast:[NSString stringWithFormat:@"已重置: %@", item.title]];
            NSLog(@"DYYY: Reset %@", item.key);
        }];
        
        // 重置操作到弹出菜单
        [alert addAction:resetAction];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = CGRectMake(point.x, point.y, 1, 1);
        }
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)showImagePickerForCustomAlbum {
    // 检查自定义选择相册图片功能是否启用
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableCustomAlbum"]) {
        [DYYYManager showToast:@"请先开启「自定义选择相册图片」"];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择图片来源" 
                                                                  message:nil 
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"相册" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary forCustomAlbum:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"相机" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self showImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera forCustomAlbum:YES];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认" 
                                             style:UIAlertActionStyleDefault 
                                           handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomAlbumImagePath"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [DYYYManager showToast:@"已恢复默认相册图片"];
        [self.tableView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                             style:UIAlertActionStyleCancel 
                                           handler:nil]];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 
                                                                   self.view.bounds.size.height / 2, 
                                                                   0, 0);
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType forCustomAlbum:(BOOL)isCustomAlbum {
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) {
        [DYYYManager showToast:@"设备不支持该图片来源"];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    picker.allowsEditing = YES;
    
    objc_setAssociatedObject(picker, "isCustomAlbumPicker", isCustomAlbum ? @YES : @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetButtonTapped:(UIButton *)sender {
    NSString *key = sender.accessibilityLabel;
    if (!key) return;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 特殊处理清屏按钮尺寸重置
    if ([key isEqualToString:@"DYYYEnableFloatClearButton"] || 
        [key isEqualToString:@"DYYYFloatClearButtonSizePreference"]) {
        [[NSUserDefaults standardUserDefaults] setInteger:DYYYButtonSizeMedium 
                                                           forKey:@"DYYYFloatClearButtonSizePreference"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 特殊处理日期时间格式相关设置
    if ([key isEqualToString:@"DYYYShowDateTime"]) {
        // 重置主开关也重置所有子开关和格式设置
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMDHM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_MDHM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HMS"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_HM"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYDateTimeFormat_YMD"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
        
        // 更新UI中子开关的状态
        for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
            [self updateDateTimeFormatSubSwitchesUI:section enabled:NO];
        }
    }
    else if ([key hasPrefix:@"DYYYDateTimeFormat_"]) {
        // 重置一个子开关时检查是否有其他子开关启用
        BOOL anyEnabled = NO;
        for (NSString *key in @[@"DYYYDateTimeFormat_YMDHM", @"DYYYDateTimeFormat_MDHM", 
                                @"DYYYDateTimeFormat_HMS", @"DYYYDateTimeFormat_HM", 
                                @"DYYYDateTimeFormat_YMD"]) {
            if (![key isEqualToString:key] && [[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                anyEnabled = YES;
                break;
            }
        }
        
        // 如果所有子开关都关闭，也关闭主开关并清除格式
        if (!anyEnabled) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYShowDateTime"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYDateTimeFormat"];
            for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
                [self updateDateTimeFormatMainSwitchUI:section];
            }
        }
    }
    
    // 特殊处理时间属地显示开关组
    if ([key isEqualToString:@"DYYYisEnableArea"]) {
        // 重置主开关也重置所有子开关
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaProvince"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaCity"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaDistrict"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYisEnableAreaStreet"];
        
        // 更新UI
        for (NSInteger section = 0; section < [self.tableView numberOfSections]; section++) {
            [self updateAreaSubSwitchesUI:section enabled:NO];
        }
    }
    
    // 针对自定义相册图片和大小，重置后刷新按钮
    if ([key isEqualToString:@"DYYYCustomAlbumImagePath"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeSmall"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeMedium"] ||
        [key isEqualToString:@"DYYYCustomAlbumSizeLarge"] ||
        [key isEqualToString:@"DYYYEnableCustomAlbum"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYCustomAlbumSettingChanged" object:nil];
    }
    
    // 处理头像文本
    if ([key isEqualToString:@"DYYYAvatarTapText"]) {
        self.avatarTapLabel.text = @"pxx917144686";
    }
    
    // 刷新UI
    [self.tableView reloadData];
    
    // 显示提示
    [DYYYManager showToast:[NSString stringWithFormat:@"已重置: %@", key]];
}

- (void)showSourceCodePopup {
    NSString *githubURL = @"https://github.com/pxx917144686/DYYY";
    
    // 添加跳转前的动画效果
    CAKeyframeAnimation *pulseAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.values = @[@1.0, @1.08, @1.0];
    pulseAnimation.keyTimes = @[@0, @0.5, @1.0];
    pulseAnimation.duration = 0.5;
    pulseAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                       [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    
    UIButton *sourceCodeButton = (UIButton *)[self.tableView.tableFooterView viewWithTag:101];
    [sourceCodeButton.layer addAnimation:pulseAnimation forKey:@"pulse"];
    
    // 跳转到GitHub页面
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:githubURL] options:@{} completionHandler:nil];
}

#pragma mark - Dealloc

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showScheduleStylePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择进度条样式"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *styles = @[
        @{@"title": @"进度条右侧剩余", @"value": @"进度条右侧剩余"},
        @{@"title": @"进度条右侧完整", @"value": @"进度条右侧完整"},
        @{@"title": @"进度条左侧剩余", @"value": @"进度条左侧剩余"},
        @{@"title": @"进度条左侧完整", @"value": @"进度条左侧完整"},
        @{@"title": @"进度条两侧左右", @"value": @"进度条两侧左右"}
    ];
    
    for (NSDictionary *style in styles) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:style[@"title"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setObject:style[@"value"] forKey:@"DYYYScheduleStyle"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 辅助方法用于显示更简短的样式名称
- (NSString *)getShortNameForStyleValue:(NSString *)styleValue {
    if ([styleValue isEqualToString:@"进度条右侧剩余"]) return @"右侧剩余";
    if ([styleValue isEqualToString:@"进度条右侧完整"]) return @"右侧完整";
    if ([styleValue isEqualToString:@"进度条左侧剩余"]) return @"左侧剩余";
    if ([styleValue isEqualToString:@"进度条左侧完整"]) return @"左侧完整";
    if ([styleValue isEqualToString:@"进度条两侧左右"]) return @"两侧左右";
    return styleValue;
}

@end