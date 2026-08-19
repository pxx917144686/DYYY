//
//  DYYYSpeedHooks.xm
//  DYYY
//
//  倍速 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

%hook AWEAwemePlayVideoViewController

- (void)setIsAutoPlay:(BOOL)arg0 {
    %orig(arg0);
    DYYYApplyPreparedPlaybackSpeedToPlayer(self);
}

%end

%hook AWEPlayInteractionSpeedController

static CGFloat currentLongPressSpeed = 0;
static CGFloat initialTouchX = 0;
static BOOL isGestureActive = NO;

- (CGFloat)longPressFastSpeedValue {
    float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");
    if (longPressSpeed == 0) {
        longPressSpeed = 2.0;
    }
    return longPressSpeed;
}

- (void)changeSpeed:(double)speed {
    float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");

    if (isGestureActive && currentLongPressSpeed > 0) {
        %orig(currentLongPressSpeed);
        return;
    }

    if (speed == 2.0 && longPressSpeed != 0 && longPressSpeed != 2.0) {
        %orig(longPressSpeed);
        return;
    }

    if (speed <= 1.0 && dyyyLongPressLockedSpeedActive) {
        DYYYEndLockedLongPressSpeedAndRestoreIfNeeded();
    }

    %orig(speed);
}

- (void)handleLongPressFastSpeed:(UILongPressGestureRecognizer *)gesture {
    BOOL enableSpeedGesture = DYYYGetBool(@"DYYYEnableLongPressSpeedGesture");
    CGPoint location = [gesture locationInView:gesture.view];
    static CGFloat initialTouchY = 0;
    BOOL isBeginning = gesture.state == UIGestureRecognizerStateBegan;
    BOOL isEnding = gesture.state == UIGestureRecognizerStateEnded ||
                    gesture.state == UIGestureRecognizerStateCancelled ||
                    gesture.state == UIGestureRecognizerStateFailed;

    if (isBeginning) {
        dyyyLongPressFastSpeedActive = YES;
        dyyyLongPressLockedSpeedActive = NO;
    } else if (isEnding) {
        isGestureActive = NO;
        currentLongPressSpeed = 0;
        initialTouchY = 0;
        dyyyLongPressFastSpeedActive = NO;
    }

    %orig;

    if (isEnding) {
        DYYYScheduleConfiguredPlaybackSpeedRestore();
    }

    if (!enableSpeedGesture) {
        return;
    }

    if (isBeginning) {
        initialTouchY = location.y;
        isGestureActive = YES;

        float longPressSpeed = DYYYGetFloat(@"DYYYLongPressSpeed");
        if (longPressSpeed == 0) {
            longPressSpeed = 2.0;
        }
        currentLongPressSpeed = longPressSpeed;
    }
    else if (gesture.state == UIGestureRecognizerStateChanged && isGestureActive) {
        CGFloat deltaY = location.y - initialTouchY;
        CGFloat threshold = 10.0;

        if (fabs(deltaY) > threshold) {
            CGFloat speedChange;
            speedChange = (deltaY > 0) ? 0.25 : -0.25;

            CGFloat newSpeed = currentLongPressSpeed + speedChange;
            newSpeed = MAX(0.5, MIN(3.0, newSpeed));

            if (newSpeed != currentLongPressSpeed) {
                currentLongPressSpeed = newSpeed;
                initialTouchY = location.y;
                [self changeSpeed:currentLongPressSpeed];
            }
        }
    }
}

- (void)handleLongPressLockedSpeedBegan {
    dyyyLongPressFastSpeedActive = YES;
    dyyyLongPressLockedSpeedActive = NO;
    %orig;
}

- (void)handleLongPressLockedDoubleSpeedChanged:(id)arg1 gesture:(UIGestureRecognizer *)gesture {
    dyyyLongPressFastSpeedActive = YES;
    dyyyLongPressLockedSpeedActive = NO;
    %orig(arg1, gesture);
}

- (void)handleLongPressLockedDoubleSpeedEnded:(id)arg1 gesture:(UIGestureRecognizer *)gesture {
    %orig(arg1, gesture);
    dyyyLongPressFastSpeedActive = NO;
    dyyyLongPressLockedSpeedActive = YES;
}

- (void)longPressSpeedControlDidChangeSpeed:(double)speed {
    %orig(speed);
    if (speed <= 1.0 && dyyyLongPressLockedSpeedActive) {
        DYYYEndLockedLongPressSpeedAndRestoreIfNeeded();
    }
}
%end

%ctor {
    // 初始化本文件的未分组 hook
    %init;
}
