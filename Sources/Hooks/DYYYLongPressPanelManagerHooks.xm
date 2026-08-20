//
//  DYYYLongPressPanelHooks.xm
//  DYYY
//
//  长按面板现代风开关 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

static BOOL DYYYModernLongPressPanelEnabled(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = @"DYYYisEnableModern";
    return [defaults objectForKey:key] ? [defaults boolForKey:key] : YES;
}

%group needDelay
%hook AWELongPressPanelManager
- (BOOL)shouldShowModernLongPressPanel {
    return DYYYModernLongPressPanelEnabled();
}
%end

%hook AWELongPressPanelDataManager
+ (BOOL)enableModernLongPressPanelConfigWithSceneIdentifier:(id)arg1 {
    return DYYYModernLongPressPanelEnabled();
}
%end

%hook AWELongPressPanelABSettings
+ (NSUInteger)modernLongPressPanelStyleMode {
    return DYYYModernLongPressPanelEnabled() ? 1 : 0;
}
%end

%hook AWEModernLongPressPanelUIConfig
+ (NSUInteger)modernLongPressPanelStyleMode {
    return DYYYModernLongPressPanelEnabled() ? 1 : 0;
}
%end
%end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        %init(needDelay);
    });
}
