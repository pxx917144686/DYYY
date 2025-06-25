#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "AwemeHeaders.h"

@interface AWEFeedProgressSlider () <UIColorPickerViewControllerDelegate>
@end

%hook AWEFeedProgressSlider

- (id)initWithFrame:(CGRect)frame {
    id result = %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(handleSettingChanged:)
                                                name:@"DYYYSettingChanged"
                                              object:nil];
    return result;
}

%new
- (void)handleSettingChanged:(NSNotification *)notification {
    static NSTimeInterval lastUpdateTime = 0;
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    // 限制更新频率为最多每0.5秒一次
    if (currentTime - lastUpdateTime < 0.5) return;
    lastUpdateTime = currentTime;
    
    @try {
        NSDictionary *userInfo = notification.userInfo;
        if (!userInfo) return;
        
        NSString *key = userInfo[@"key"];
        if (!key) return;
        
        if ([key isEqualToString:@"DYYYHideVideoProgress"] || 
            [key isEqualToString:@"DYYYisShowScheduleDisplay"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNeedsLayout];
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 处理设置更改异常: %@", exception);
    }
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYSettingChanged" object:nil];
    %orig;
}

- (void)layoutSubviews {
    %orig;
    [self applyCustomProgressStyle];
}

%new
- (void)applyCustomProgressStyle {
    UIView *parentView = self.superview;
    if (!parentView) return;
    
    @try {
        NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
        
        UILabel *leftLabel = [parentView viewWithTag:10001]; 
        UILabel *rightLabel = [parentView viewWithTag:10002];
        
        CGRect originalFrame = self.frame;
        CGFloat sliderCenterY = CGRectGetMidY(originalFrame);
        CGFloat labelHeight = 15.0;
        
        if (leftLabel || rightLabel) {
            if (leftLabel) {
                leftLabel.center = CGPointMake(leftLabel.center.x, sliderCenterY);
            }
            if (rightLabel) {
                rightLabel.center = CGPointMake(rightLabel.center.x, sliderCenterY);
            }
        }
        
        if ([scheduleStyle isEqualToString:@"进度条两侧左右"] && leftLabel && rightLabel) {
            CGFloat padding = 8.0;
            CGFloat sliderX = CGRectGetMaxX(leftLabel.frame) + padding;
            CGFloat sliderWidth = CGRectGetMinX(rightLabel.frame) - padding - sliderX;
            if (sliderWidth > 30) {
                self.frame = CGRectMake(sliderX, originalFrame.origin.y, sliderWidth, originalFrame.size.height);
            }
        }
    } @catch (NSException *exception) {
    }
}

- (void)setAlpha:(CGFloat)alpha {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideVideoProgress"]) {
            %orig(0);
        } else {
            %orig(1.0);
        }
    } else {
        %orig;
    }
}

static CGFloat leftLabelLeftMargin = -1;
static CGFloat rightLabelRightMargin = -1;

- (void)setLimitUpperActionArea:(BOOL)arg1 {
    %orig;

    BOOL isShowSchedule = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"];

    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *parentView = self.superview;
        if (!parentView) return;

        [[parentView viewWithTag:10001] removeFromSuperview];
        [[parentView viewWithTag:10002] removeFromSuperview];

        if (isShowSchedule) {
            NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
            BOOL showRemainingTime = [scheduleStyle isEqualToString:@"进度条右侧剩余"];
            BOOL showCompleteTime = [scheduleStyle isEqualToString:@"进度条右侧完整"];
            BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"进度条左侧剩余"];
            BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"进度条左侧完整"];
            BOOL showBothSides = [scheduleStyle isEqualToString:@"进度条两侧左右"];

            NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];
            UIColor *labelColor = [UIColor whiteColor];
            if (labelColorHex && labelColorHex.length > 0) {
                SEL colorSelector = NSSelectorFromString(@"colorWithHexString:");
                Class dyyyManagerClass = NSClassFromString(@"DYYYManager");
                if (dyyyManagerClass && [dyyyManagerClass respondsToSelector:colorSelector]) {
                    labelColor = [dyyyManagerClass performSelector:colorSelector withObject:labelColorHex];
                }
            }

            NSString *durationFormatted = @"00:00";
            @try {
                if (self.progressSliderDelegate && self.progressSliderDelegate.model) {
                    durationFormatted = [self.progressSliderDelegate formatTimeFromSeconds:floor(self.progressSliderDelegate.model.videoDuration / 1000)];
                }
            } @catch (NSException *exception) {
            }

            CGRect sliderFrame = self.frame;
            CGFloat sliderCenterY = CGRectGetMidY(sliderFrame);

            CGFloat verticalOffset = -12.5;
            NSString *offsetValueString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimelineVerticalPosition"];
            if (offsetValueString.length > 0) {
                CGFloat configOffset = [offsetValueString floatValue];
                if (configOffset != 0)
                    verticalOffset = configOffset;
            }

            CGFloat labelHeight = 15.0;
            UIFont *labelFont = [UIFont systemFontOfSize:8];
            CGFloat labelY = sliderCenterY - labelHeight / 2.0 + verticalOffset;

            if (showLeftRemainingTime || showLeftCompleteTime || showBothSides) {
                UILabel *leftLabel = [[UILabel alloc] init];
                leftLabel.backgroundColor = [UIColor clearColor];
                leftLabel.textColor = labelColor;
                leftLabel.font = labelFont;
                leftLabel.tag = 10001;

                if (showLeftRemainingTime)
                    leftLabel.text = @"00:00";
                else if (showLeftCompleteTime)
                    leftLabel.text = [NSString stringWithFormat:@"00:00/%@", durationFormatted];
                else
                    leftLabel.text = @"00:00";

                [leftLabel sizeToFit];

                CGFloat leftLabelLeftMargin = MAX(5.0, sliderFrame.origin.x - leftLabel.frame.size.width - 10.0);
                leftLabel.frame = CGRectMake(leftLabelLeftMargin, labelY, leftLabel.frame.size.width, labelHeight);
                [parentView addSubview:leftLabel];
            }

            if (showRemainingTime || showCompleteTime || showBothSides) {
                UILabel *rightLabel = [[UILabel alloc] init];
                rightLabel.backgroundColor = [UIColor clearColor];
                rightLabel.textColor = labelColor;
                rightLabel.font = labelFont;
                rightLabel.tag = 10002;

                if (showRemainingTime)
                    rightLabel.text = @"00:00";
                else if (showCompleteTime)
                    rightLabel.text = [NSString stringWithFormat:@"00:00/%@", durationFormatted];
                else
                    rightLabel.text = durationFormatted;

                [rightLabel sizeToFit];

                CGFloat rightLabelRightMargin = MIN(
                    parentView.bounds.size.width - rightLabel.frame.size.width - 5.0,
                    CGRectGetMaxX(sliderFrame) + 10.0
                );
                rightLabel.frame = CGRectMake(rightLabelRightMargin, labelY, rightLabel.frame.size.width, labelHeight);
                [parentView addSubview:rightLabel];
            }
        }
        [self setNeedsLayout];
    });
}

%end


%hook AWEPlayInteractionProgressController

%new
- (NSString *)formatTimeFromSeconds:(CGFloat)seconds {
    NSInteger hours = (NSInteger)seconds / 3600;
    NSInteger minutes = ((NSInteger)seconds % 3600) / 60;
    NSInteger secs = (NSInteger)seconds % 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)secs];
    } else {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)secs];
    }
}

- (void)updateProgressSliderWithTime:(CGFloat)arg1 totalDuration:(CGFloat)arg2 {
    %orig;
    
    // 如果功能未启用，直接返回，避免不必要的处理
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"]) {
        return;
    }
    
    // 使用静态变量来缓存上次更新时间和值，避免频繁更新
    static NSTimeInterval lastUpdateTime = 0;
    static CGFloat lastTime = -1;
    
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    // 限制更新频率，除非时间变化明显
    if (currentTime - lastUpdateTime < 0.25 && fabs(lastTime - arg1) < 0.5) {
        return;
    }
    
    lastUpdateTime = currentTime;
    lastTime = arg1;
    
    // 使用弱引用避免潜在的循环引用
    __weak AWEPlayInteractionProgressController *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!weakSelf) return;
            
            AWEFeedProgressSlider *progressSlider = weakSelf.progressSlider;
            if (!progressSlider) {
                return;
            }
            
            UIView *parentView = progressSlider.superview;
            if (!parentView) {
                return;
            }
            
            UILabel *leftLabel = [parentView viewWithTag:10001];
            UILabel *rightLabel = [parentView viewWithTag:10002];
            
            NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];
            UIColor *labelColor = [UIColor whiteColor];
            
            if (labelColorHex && labelColorHex.length > 0) {
                @try {
                    SEL colorSelector = NSSelectorFromString(@"colorWithHexString:");
                    Class dyyyManagerClass = NSClassFromString(@"DYYYManager");
                    if (dyyyManagerClass && [dyyyManagerClass respondsToSelector:colorSelector]) {
                        labelColor = [dyyyManagerClass performSelector:colorSelector withObject:labelColorHex];
                    }
                } @catch (NSException *exception) {
                }
            }
            
            NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
            BOOL showRemainingTime = [scheduleStyle isEqualToString:@"进度条右侧剩余"];
            BOOL showCompleteTime = [scheduleStyle isEqualToString:@"进度条右侧完整"];
            BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"进度条左侧剩余"];
            BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"进度条左侧完整"];
            BOOL showBothSides = [scheduleStyle isEqualToString:@"进度条两侧左右"];
            
            if (arg1 >= 0 && leftLabel != nil) {
                NSString *newLeftText = @"";
                if (showLeftRemainingTime) {
                    CGFloat remainingTime = arg2 - arg1;
                    if (remainingTime < 0)
                        remainingTime = 0;
                    newLeftText = [weakSelf formatTimeFromSeconds:remainingTime];
                } else if (showLeftCompleteTime) {
                    newLeftText = [NSString stringWithFormat:@"%@/%@", [weakSelf formatTimeFromSeconds:arg1], [weakSelf formatTimeFromSeconds:arg2]];
                } else {
                    newLeftText = [weakSelf formatTimeFromSeconds:arg1];
                }

                if (![leftLabel.text isEqualToString:newLeftText]) {
                    leftLabel.text = newLeftText;
                    [leftLabel sizeToFit];
                    CGRect leftFrame = leftLabel.frame;
                    leftFrame.size.height = 15.0;
                    leftLabel.frame = leftFrame;
                }
                leftLabel.textColor = labelColor;
            }

            if (arg2 > 0 && rightLabel != nil) {
                NSString *newRightText = @"";
                if (showRemainingTime) {
                    CGFloat remainingTime = arg2 - arg1;
                    if (remainingTime < 0)
                        remainingTime = 0;
                    newRightText = [weakSelf formatTimeFromSeconds:remainingTime];
                } else if (showCompleteTime) {
                    newRightText = [NSString stringWithFormat:@"%@/%@", [weakSelf formatTimeFromSeconds:arg1], [weakSelf formatTimeFromSeconds:arg2]];
                } else {
                    newRightText = [weakSelf formatTimeFromSeconds:arg2];
                }

                if (![rightLabel.text isEqualToString:newRightText]) {
                    rightLabel.text = newRightText;
                    [rightLabel sizeToFit];
                    CGRect rightFrame = rightLabel.frame;
                    rightFrame.size.height = 15.0;
                    rightLabel.frame = rightFrame;
                }
                rightLabel.textColor = labelColor;
            }
        } @catch (NSException *exception) {
            NSLog(@"[DYYY] 更新进度异常: %@", exception);
        }
    });
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    BOOL hideVideoProgress = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideVideoProgress"];
    BOOL showScheduleDisplay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"];
    if (hideVideoProgress && showScheduleDisplay && !hidden) {
        self.alpha = 0;
    }
}

%end

%hook AWEFakeProgressSliderView
- (void)layoutSubviews {
    %orig;
    [self applyCustomProgressStyle];
}

%new
- (void)applyCustomProgressStyle {
    NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];

    if ([scheduleStyle isEqualToString:@"进度条两侧左右"]) {
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class] && 
                subview.tag != 10001 && subview.tag != 10002) {
                subview.hidden = YES;
            }
        }
    }
}
%end
