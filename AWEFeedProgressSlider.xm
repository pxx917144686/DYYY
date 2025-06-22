#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"

@interface AWEFeedProgressSlider () <UIColorPickerViewControllerDelegate>
@end

%hook AWEFeedProgressSlider

- (void)layoutSubviews {
	%orig;
	[self applyCustomProgressStyle];
}

%new
- (void)applyCustomProgressStyle {
    NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
    UIView *parentView = self.superview;
    if (!parentView) return;

    CGRect sliderFrame = self.frame;
    UILabel *leftLabel = [parentView viewWithTag:10001];
    UILabel *rightLabel = [parentView viewWithTag:10002];
    CGFloat labelHeight = 15.0;
    CGFloat sliderCenterY = CGRectGetMidY(sliderFrame);

    if ([scheduleStyle isEqualToString:@"进度条两侧左右"]) {
        if (leftLabel && rightLabel) {
            CGFloat labelY = sliderCenterY - labelHeight / 2.0;
            leftLabel.center = CGPointMake(leftLabel.center.x, labelY + labelHeight/2.0);
            rightLabel.center = CGPointMake(rightLabel.center.x, labelY + labelHeight/2.0);

            CGFloat padding = 5.0;
            CGFloat sliderX = CGRectGetMaxX(leftLabel.frame) + padding;
            CGFloat sliderWidth = CGRectGetMinX(rightLabel.frame) - padding - sliderX;
            if (sliderWidth < 0) sliderWidth = 0;
            self.frame = CGRectMake(sliderX, sliderFrame.origin.y, sliderWidth, sliderFrame.size.height);
        } else {
            CGFloat fallbackWidthPercent = 0.80;
            CGFloat parentWidth = parentView.bounds.size.width;
            CGFloat fallbackWidth = parentWidth * fallbackWidthPercent;
            CGFloat fallbackX = (parentWidth - fallbackWidth) / 2.0;
            self.frame = CGRectMake(fallbackX, sliderFrame.origin.y, fallbackWidth, sliderFrame.size.height);
        }
    } else if ([scheduleStyle isEqualToString:@"进度条右侧剩余"] || [scheduleStyle isEqualToString:@"进度条右侧完整"]) {
        if (rightLabel) {
            CGFloat labelY = sliderCenterY - labelHeight / 2.0;
            rightLabel.center = CGPointMake(rightLabel.center.x, labelY + labelHeight/2.0);
            CGFloat padding = 5.0;
            CGFloat sliderX = sliderFrame.origin.x;
            CGFloat sliderWidth = CGRectGetMinX(rightLabel.frame) - padding - sliderX;
            if (sliderWidth < 0) sliderWidth = 0;
            self.frame = CGRectMake(sliderX, sliderFrame.origin.y, sliderWidth, sliderFrame.size.height);
        }
    } else if ([scheduleStyle isEqualToString:@"进度条左侧剩余"] || [scheduleStyle isEqualToString:@"进度条左侧完整"]) {
        if (leftLabel) {
            CGFloat labelY = sliderCenterY - labelHeight / 2.0;
            leftLabel.center = CGPointMake(leftLabel.center.x, labelY + labelHeight/2.0);
            CGFloat padding = 5.0;
            CGFloat sliderX = CGRectGetMaxX(leftLabel.frame) + padding;
            CGFloat sliderWidth = CGRectGetMaxX(sliderFrame) - sliderX;
            if (sliderWidth < 0) sliderWidth = 0;
            self.frame = CGRectMake(sliderX, sliderFrame.origin.y, sliderWidth, sliderFrame.size.height);
        }
    } else {
        CGFloat fallbackWidthPercent = 0.80;
        CGFloat parentWidth = parentView.bounds.size.width;
        CGFloat fallbackWidth = parentWidth * fallbackWidthPercent;
        CGFloat fallbackX = (parentWidth - fallbackWidth) / 2.0;
        self.frame = CGRectMake(fallbackX, sliderFrame.origin.y, fallbackWidth, sliderFrame.size.height);
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

    NSString *durationFormatted = [self.progressSliderDelegate formatTimeFromSeconds:floor(self.progressSliderDelegate.model.videoDuration / 1000)];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowScheduleDisplay"]) {
        UIView *parentView = self.superview;
        if (!parentView) return;

        [[parentView viewWithTag:10001] removeFromSuperview];
        [[parentView viewWithTag:10002] removeFromSuperview];

        CGRect sliderFrame = self.frame;
        CGFloat sliderCenterY = CGRectGetMidY(sliderFrame);

        CGFloat verticalOffset = -12.5;
        NSString *offsetValueString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimelineVerticalPosition"];
        if (offsetValueString.length > 0) {
            CGFloat configOffset = [offsetValueString floatValue];
            if (configOffset != 0)
                verticalOffset = configOffset;
        }

        NSString *scheduleStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYScheduleStyle"];
        BOOL showRemainingTime = [scheduleStyle isEqualToString:@"进度条右侧剩余"];
        BOOL showCompleteTime = [scheduleStyle isEqualToString:@"进度条右侧完整"];
        BOOL showLeftRemainingTime = [scheduleStyle isEqualToString:@"进度条左侧剩余"];
        BOOL showLeftCompleteTime = [scheduleStyle isEqualToString:@"进度条左侧完整"];

        NSString *labelColorHex = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYProgressLabelColor"];
        UIColor *labelColor = [UIColor whiteColor];
        if (labelColorHex && labelColorHex.length > 0) {
            SEL colorSelector = NSSelectorFromString(@"colorWithHexString:");
            Class dyyyManagerClass = NSClassFromString(@"DYYYManager");
            if (dyyyManagerClass && [dyyyManagerClass respondsToSelector:colorSelector]) {
                labelColor = [dyyyManagerClass performSelector:colorSelector withObject:labelColorHex];
            }
        }

        CGFloat labelHeight = 15.0;
        UIFont *labelFont = [UIFont systemFontOfSize:8];

        CGFloat labelY = sliderCenterY - labelHeight / 2.0 + verticalOffset;

        if (!showRemainingTime && !showCompleteTime) {
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

            // 动态计算 left margin
            CGFloat leftLabelLeftMargin = sliderFrame.origin.x - leftLabel.frame.size.width - 5.0;
            if (leftLabelLeftMargin < 0) leftLabelLeftMargin = 0;

            leftLabel.frame = CGRectMake(leftLabelLeftMargin, labelY, leftLabel.frame.size.width, labelHeight);
            [parentView addSubview:leftLabel];
        }

        if (!showLeftRemainingTime && !showLeftCompleteTime) {
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

            // 动态计算 right margin
            CGFloat rightLabelRightMargin = CGRectGetMaxX(sliderFrame) + 5.0;
            if (rightLabelRightMargin + rightLabel.frame.size.width > parentView.bounds.size.width)
                rightLabelRightMargin = parentView.bounds.size.width - rightLabel.frame.size.width;

            rightLabel.frame = CGRectMake(rightLabelRightMargin, labelY, rightLabel.frame.size.width, labelHeight);
            [parentView addSubview:rightLabel];
        }

        [self setNeedsLayout];
    } else {
        UIView *parentView = self.superview;
        if (parentView) {
            [[parentView viewWithTag:10001] removeFromSuperview];
            [[parentView viewWithTag:10002] removeFromSuperview];
        }
        [self setNeedsLayout];
    }
}

%end