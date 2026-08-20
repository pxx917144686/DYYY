#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static inline BOOL DYYYSpoofEnabled() {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    id obj = [d objectForKey:@"DYYYSpoofLiquidGlass"];
    if (!obj) return YES; // 默认开启欺骗，若用户未配置
    return [d boolForKey:@"DYYYSpoofLiquidGlass"];
}

%hook NSProcessInfo

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    if (DYYYSpoofEnabled()) {
        // 让所有版本判断通过（用于启用 iOS26+ 路径）
        return YES;
    }
    return %orig;
}

- (NSOperatingSystemVersion)operatingSystemVersion {
    if (DYYYSpoofEnabled()) {
        NSOperatingSystemVersion v; v.majorVersion = 26; v.minorVersion = 0; v.patchVersion = 0;
        return v;
    }
    return %orig;
}

%end

%hook UIDevice

- (NSString *)systemVersion {
    if (DYYYSpoofEnabled()) {
        return @"26.0";
    }
    return %orig;
}

%end


