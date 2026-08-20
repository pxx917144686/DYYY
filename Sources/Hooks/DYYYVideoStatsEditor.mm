//
//  DYYYVideoStatsEditor.m
//  DYYY
//
//  自定义视频数据编辑视图控制器（纯 UI）。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYSocialStatsShared.h"

@implementation DYYYVideoEditViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentValues = [NSMutableDictionary dictionary];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置半透明背景
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    
    // 创建卡片容器
    UIView *cardView = [[UIView alloc] init];
    cardView.backgroundColor = [UIColor systemBackgroundColor];
    cardView.layer.cornerRadius = 20;
    cardView.clipsToBounds = YES;
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.alpha = 0; // 初始透明，用于动画
    cardView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8); // 初始缩小，用于动画
    cardView.tag = 100;
    [self.view addSubview:cardView];
    
    // 卡片尺寸和位置约束
    [NSLayoutConstraint activateConstraints:@[
        [cardView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [cardView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [cardView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.85],
        [cardView.heightAnchor constraintEqualToConstant:500]
    ]];
    
    // 添加标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"自定义视频数据";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:titleLabel];
    
    // 添加分割线
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [UIColor systemGray3Color];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:divider];
    
    // 创建表单容器
    UIStackView *formContainer = [[UIStackView alloc] init];
    formContainer.axis = UILayoutConstraintAxisVertical;
    formContainer.spacing = 18;
    formContainer.distribution = UIStackViewDistributionFill;
    formContainer.alignment = UIStackViewAlignmentFill;
    formContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:formContainer];
    
    // 添加各项输入控件
    NSArray *itemTitles = @[@"点赞数", @"评论数", @"收藏数", @"分享数"];
    NSArray *itemIcons = @[@"heart.fill", @"bubble.left.fill", @"bookmark.fill", @"arrowshape.turn.up.right.fill"];
    NSArray *itemColors = @[
        [UIColor systemRedColor],
        [UIColor systemBlueColor], 
        [UIColor systemGreenColor], 
        [UIColor systemOrangeColor]
    ];
    NSArray *itemKeys = @[
        DYYY_VIDEO_LIKES_KEY,
        DYYY_VIDEO_COMMENTS_KEY,
        DYYY_VIDEO_COLLECTS_KEY,
        DYYY_VIDEO_SHARES_KEY
    ];
    
    for (int i = 0; i < itemTitles.count; i++) {
        [self addInputRow:formContainer 
                    title:itemTitles[i] 
                     icon:itemIcons[i] 
                    color:itemColors[i] 
                      tag:200 + i 
                      key:itemKeys[i]];
    }
    
    // 添加按钮容器
    UIStackView *buttonContainer = [[UIStackView alloc] init];
    buttonContainer.axis = UILayoutConstraintAxisHorizontal;
    buttonContainer.spacing = 12;
    buttonContainer.distribution = UIStackViewDistributionFillEqually;
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:buttonContainer];
    
    // 创建取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor systemGray5Color];
    cancelButton.layer.cornerRadius = 12;
    [cancelButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelAction) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addArrangedSubview:cancelButton];
    
    // 创建确认按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveButton setTitle:@"确定" forState:UIControlStateNormal];
    saveButton.backgroundColor = [UIColor systemBlueColor];
    saveButton.layer.cornerRadius = 12;
    [saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveAction) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addArrangedSubview:saveButton];
    
    // 为所有按钮设置高度
    for (UIButton *button in buttonContainer.arrangedSubviews) {
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button.heightAnchor constraintEqualToConstant:50].active = YES;
    }
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题约束
        [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        
        // 分割线约束
        [divider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:15],
        [divider.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:0],
        [divider.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:0],
        [divider.heightAnchor constraintEqualToConstant:0.5],
        
        // 表单约束
        [formContainer.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:20],
        [formContainer.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [formContainer.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        
        // 按钮容器约束
        [buttonContainer.topAnchor constraintEqualToAnchor:formContainer.bottomAnchor constant:25],
        [buttonContainer.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [buttonContainer.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        [buttonContainer.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-25],
    ]];
    
    // 加载现有数据
    [self loadExistingData];
    
    // 添加轻点背景关闭弹窗的手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                          initWithTarget:self 
                                          action:@selector(handleBackgroundTap:)];
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];
    
    // 注册键盘通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)addInputRow:(UIStackView *)container title:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color tag:(NSInteger)tag key:(NSString *)key {
    // 创建容器
    UIView *rowView = [[UIView alloc] init];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;
    [rowView.heightAnchor constraintEqualToConstant:65].active = YES;
    [container addArrangedSubview:rowView];
    
    // 创建图标 (在左侧)
    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:iconName];
    } else {
        // 兼容iOS 13以下版本的替代图标
        iconView.image = [UIImage imageNamed:iconName];
    }
    iconView.tintColor = color;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [rowView addSubview:iconView];
    
    // 创建标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [rowView addSubview:titleLabel];
    
    // 创建数值预览标签
    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.tag = tag + 100; // 预览标签tag = 输入框tag + 100
    valueLabel.textColor = color;
    [rowView addSubview:valueLabel];
    
    // 创建输入框
    UITextField *textField = [[UITextField alloc] init];
    textField.placeholder = @"输入数值";
    textField.keyboardType = UIKeyboardTypeNumberPad;
    textField.textAlignment = NSTextAlignmentCenter;
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.tag = tag;
    textField.delegate = self;
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    [textField addTarget:self action:@selector(textFieldValueChanged:) forControlEvents:UIControlEventEditingChanged];
    [rowView addSubview:textField];
    
    // 创建滑块
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 0;
    slider.maximumValue = 10000000; // 千万级上限
    slider.minimumTrackTintColor = color;
    slider.tag = tag + 200; // 滑块tag = 输入框tag + 200
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [rowView addSubview:slider];
    
    // 保存关联的键
    objc_setAssociatedObject(textField, "keyName", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, "keyName", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 图标约束
        [iconView.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:2],
        [iconView.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:8],
        [iconView.widthAnchor constraintEqualToConstant:22],
        [iconView.heightAnchor constraintEqualToConstant:22],
        
        // 标题约束
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:8],
        [titleLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        
        // 数值预览标签约束
        [valueLabel.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor],
        [valueLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:10],
        
        // 输入框约束
        [textField.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:8],
        [textField.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor],
        [textField.widthAnchor constraintEqualToConstant:100],
        [textField.heightAnchor constraintEqualToConstant:35],
        
        // 滑块约束
        [slider.leadingAnchor constraintEqualToAnchor:textField.trailingAnchor constant:10],
        [slider.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor],
        [slider.centerYAnchor constraintEqualToAnchor:textField.centerYAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIView *cardView = [self.view viewWithTag:100];
    
    // 设置卡片的初始状态为缩小并透明
    cardView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8);
    cardView.alpha = 0;
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    
    // 执行弹出动画
    [UIView animateWithDuration:0.3 
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        cardView.transform = CGAffineTransformIdentity;
        cardView.alpha = 1;
        self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    } completion:nil];
}

// 加载现有数据
- (void)loadExistingData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *keys = @[
        DYYY_VIDEO_LIKES_KEY,
        DYYY_VIDEO_COMMENTS_KEY,
        DYYY_VIDEO_COLLECTS_KEY,
        DYYY_VIDEO_SHARES_KEY
    ];
    
    for (int i = 0; i < keys.count; i++) {
        NSString *key = keys[i];
        NSString *value = [defaults objectForKey:key];
        
        if (value) {
            [_currentValues setObject:value forKey:key];
            
            // 更新UI
            UITextField *textField = [self.view viewWithTag:200 + i];
            UILabel *valueLabel = [self.view viewWithTag:300 + i];
            UISlider *slider = [self.view viewWithTag:400 + i];
            
            textField.text = value;
            valueLabel.text = [self formatNumberString:value];
            
            // 设置滑块值，但不超过滑块最大值
            float sliderValue = [value floatValue];
            if (sliderValue > slider.maximumValue) {
                sliderValue = slider.maximumValue;
            }
            slider.value = sliderValue;
        }
    }
}

// 处理滑块值变化
- (void)sliderValueChanged:(UISlider *)slider {
    NSInteger correspondingTextFieldTag = slider.tag - 200;
    NSInteger correspondingValueLabelTag = slider.tag - 100;
    
    UITextField *textField = [self.view viewWithTag:correspondingTextFieldTag];
    UILabel *valueLabel = [self.view viewWithTag:correspondingValueLabelTag];
    
    // 四舍五入滑块值
    NSInteger intValue = roundf(slider.value);
    NSString *stringValue = [NSString stringWithFormat:@"%ld", (long)intValue];
    
    // 更新输入框和预览标签
    textField.text = stringValue;
    valueLabel.text = [self formatNumberString:stringValue];
    
    // 保存当前值到临时字典
    NSString *key = objc_getAssociatedObject(slider, "keyName");
    if (key) {
        [_currentValues setObject:stringValue forKey:key];
    }
    
    // 添加轻微振动反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

// 处理输入框值变化
- (void)textFieldValueChanged:(UITextField *)textField {
    NSInteger correspondingSliderTag = textField.tag + 200;
    NSInteger correspondingValueLabelTag = textField.tag + 100;
    
    UISlider *slider = [self.view viewWithTag:correspondingSliderTag];
    UILabel *valueLabel = [self.view viewWithTag:correspondingValueLabelTag];
    
    // 获取输入文本并转换为数字
    NSString *text = textField.text;
    float floatValue = [text floatValue];
    
    // 限制在滑块范围内
    if (floatValue > slider.maximumValue) {
        floatValue = slider.maximumValue;
    }
    
    // 更新滑块和预览标签
    slider.value = floatValue;
    valueLabel.text = [self formatNumberString:text];
    
    // 保存当前值到临时字典
    NSString *key = objc_getAssociatedObject(textField, "keyName");
    if (key) {
        [_currentValues setObject:text forKey:key];
    }
}

// 格式化数字字符串（添加千位分隔符）
- (NSString *)formatNumberString:(NSString *)numberString {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.groupingSeparator = @",";
    formatter.groupingSize = 3;
    
    NSNumber *number = @([numberString longLongValue]);
    return [formatter stringFromNumber:number];
}

// 取消按钮动作
- (void)cancelAction {
    [self dismissWithAnimation:YES completion:nil];
}

// 保存按钮动作
- (void)saveAction {
    // 保存数据到UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    for (NSString *key in _currentValues) {
        NSString *value = _currentValues[key];
        if (value.length > 0) {
            [defaults setObject:value forKey:key];
        } else {
            [defaults removeObjectForKey:key];
        }
    }
    
    // 启用视频数据自定义
    [defaults setBool:YES forKey:DYYY_VIDEO_STATS_ENABLED_KEY];
    [defaults synchronize];
    
    // 重新加载数据并更新界面
    loadCustomSocialStats();
    syncVideoStatsFromSettings();
    
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYVideoStatsChanged" 
                                                      object:nil 
                                                    userInfo:@{
        @"action": @"update",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    }];
    
    // 添加成功振动反馈
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
    }
    
    // 关闭弹窗
    [self dismissWithAnimation:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIViewController *topVC = [DYYYManager getActiveTopController];
            if (topVC) {
                // 强制刷新当前视图
                DYYYEnumerateSubviews(topVC.view, ^(UIView *view) {
                    if ([view isKindOfClass:NSClassFromString(@"AWEFeedVideoButton")] ||
                        [view isKindOfClass:NSClassFromString(@"AWEFeedTableCell")] || 
                        [view isKindOfClass:NSClassFromString(@"AWEFeedViewCell")]) {
                        [view setNeedsLayout];
                        [view layoutIfNeeded];
                        
                        // 用动画强制刷新
                        [UIView animateWithDuration:0.1 animations:^{
                            [view setNeedsDisplay];
                        }];
                    }
                });
                
                // 尝试调用刷新方法
                if ([topVC respondsToSelector:@selector(reloadData)]) {
                    [topVC performSelector:@selector(reloadData)];
                }
            }
        });
    }];
}

// 带动画消失
- (void)dismissWithAnimation:(BOOL)animated completion:(void(^)(void))completion {
    if (animated) {
        UIView *cardView = [self.view viewWithTag:100];
        
        [UIView animateWithDuration:0.2 animations:^{
            cardView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8);
            cardView.alpha = 0;
            self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        } completion:^(BOOL finished) {
            [self dismissViewControllerAnimated:NO completion:^{
                if (completion) completion();
            }];
        }];
    } else {
        [self dismissViewControllerAnimated:NO completion:completion];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // 只允许输入数字
    NSCharacterSet *nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([string rangeOfCharacterFromSet:nonDigitSet].location != NSNotFound) {
        return NO;
    }
    
    // 限制最大长度为10位数
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText.length > 10) {
        return NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - 键盘处理

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    UIView *cardView = [self.view viewWithTag:100];
    CGRect cardFrame = [cardView convertRect:cardView.bounds toView:self.view];
    
    CGFloat bottomOfCard = cardFrame.origin.y + cardFrame.size.height;
    CGFloat topOfKeyboard = self.view.frame.size.height - keyboardSize.height;
    
    // 如果卡片底部被键盘遮挡
    if (bottomOfCard > topOfKeyboard) {
        CGFloat offsetY = bottomOfCard - topOfKeyboard + 20; // 额外20pt的空间
        
        [UIView animateWithDuration:0.3 animations:^{
            cardView.transform = CGAffineTransformMakeTranslation(0, -offsetY);
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIView *cardView = [self.view viewWithTag:100];
    
    [UIView animateWithDuration:0.3 animations:^{
        cardView.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - 背景点击处理

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *cardView = [self.view viewWithTag:100];
    CGPoint touchPoint = [touch locationInView:self.view];
    return ![cardView pointInside:[self.view convertPoint:touchPoint toView:cardView] withEvent:nil];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gesture {
    [self.view endEditing:YES];
    [self cancelAction];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
