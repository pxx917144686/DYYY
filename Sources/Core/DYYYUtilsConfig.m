//
//  DYYYUtilsConfig.m
//  DYYY
//
//  缓存失效、历史特性键迁移、玻璃功能门控。
//  玻璃门控键常量也定义在本文件（DYYYGlassGatedKeySet 依赖它们）。
//

#import "DYYYUtils.h"
#import "DYYYUtilsPrivate.h"

NSString * const DYYYKeyCommentHideBottomBar = @"DYYYHideCommentBottomBar";
NSString * const DYYYKeyCommentMediaCleanBottomBar = @"DYYYCommentMediaCleanBottomBar";
NSString * const DYYYKeyCommentGlass = @"DYYYCommentGlass";
NSString * const DYYYKeyCommentGlassClear = @"DYYYCommentGlassClear";
NSString * const DYYYKeySharePanelGlass = @"DYYYSharePanelGlass";
NSString * const DYYYKeySharePanelGlassClear = @"DYYYSharePanelGlassClear";
NSString * const DYYYKeyInnerNotiGlass = @"DYYYInnerNotiGlass";
NSString * const DYYYKeyInnerNotiGlassClear = @"DYYYInnerNotiGlassClear";
NSString * const DYYYKeyInnerNotiCorner = @"DYYYInnerNotiCorner";
NSString * const DYYYKeyGlassTabBar = @"DYYYGlassTabBar";
NSString * const DYYYKeyGlassTabBarClear = @"DYYYGlassTabBarClear";
NSString * const DYYYKeyAudioVizPosition = @"DYYYAudioVizPosition";
NSString * const DYYYKeyAudioVizStyle = @"DYYYAudioVizStyle";
NSString * const DYYYKeyDetailHideBottomBar = @"DYYYDetailHideBottomBar";

NSSet<NSString *> *DYYYGlassGatedKeySet(void) {
    static NSSet<NSString *> *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithObjects:
               DYYYKeyCommentGlass,
               DYYYKeyCommentGlassClear,
               DYYYKeySharePanelGlass,
               DYYYKeySharePanelGlassClear,
               DYYYKeyInnerNotiGlass,
               DYYYKeyInnerNotiGlassClear,
               DYYYKeyInnerNotiCorner,
               DYYYKeyGlassTabBar,
               DYYYKeyGlassTabBarClear,
               DYYYKeyAudioVizPosition,
               DYYYKeyAudioVizStyle,
               nil];
    });
    return set;
}

BOOL DYYYGlassOSAvailable(void) {
    static BOOL available;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(iOS 26.0, *)) {
            available = YES;
        } else {
            available = NO;
        }
    });
    return available;
}

BOOL DYYYGlassIsGatedKey(NSString *key) {
    return key.length && [DYYYGlassGatedKeySet() containsObject:key];
}

BOOL DYYYPrefBool(NSString *key) {
    if (DYYYGlassIsGatedKey(key) && !DYYYGlassOSAvailable()) return NO;
    return DYYYCachedBool(key);
}

NSInteger DYYYPrefInteger(NSString *key) {
    if (DYYYGlassIsGatedKey(key) && !DYYYGlassOSAvailable()) return 0;
    return DYYYCachedInteger(key);
}

void DYYYConfigCacheInvalidate(void) {
    @synchronized (DYYYConfigCache()) {
        [DYYYConfigCache() removeAllObjects];
    }
    // 关键词预编译缓存与配置缓存联动失效
    @synchronized (DYYYKeywordListCache()) {
        [DYYYKeywordListCache() removeAllObjects];
    }
}

static void DYYYMigrateLegacyFeatureKeys(void) {
    NSDictionary<NSString *, NSString *> *mapping = @{
        @"DYKillerCommentGlass": DYYYKeyCommentGlass,
        @"DYKillerCommentGlassClear": DYYYKeyCommentGlassClear,
        @"DYKillerHideCommentBottomBar": DYYYKeyCommentHideBottomBar,
        @"DYKillerCommentMediaCleanBottomBar": DYYYKeyCommentMediaCleanBottomBar,
        @"DYKillerSharePanelGlass": DYYYKeySharePanelGlass,
        @"DYKillerSharePanelGlassClear": DYYYKeySharePanelGlassClear,
        @"DYKillerInnerNotiGlass": DYYYKeyInnerNotiGlass,
        @"DYKillerInnerNotiGlassClear": DYYYKeyInnerNotiGlassClear,
        @"DYKillerInnerNotiCorner": DYYYKeyInnerNotiCorner,
        @"DYKillerGlassTabBar": DYYYKeyGlassTabBar,
        @"DYKillerGlassTabBarClear": DYYYKeyGlassTabBarClear,
        @"DYKillerAudioVizPosition": DYYYKeyAudioVizPosition,
        @"DYKillerAudioVizStyle": DYYYKeyAudioVizStyle,
        @"DYKillerHideChatVideoBottomBar": DYYYKeyDetailHideBottomBar,
    };

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    for (NSString *oldKey in mapping) {
        id value = [defaults objectForKey:oldKey];
        if (!value) continue;
        NSString *newKey = mapping[oldKey];
        if (![defaults objectForKey:newKey]) {
            [defaults setObject:value forKey:newKey];
        }
        [defaults removeObjectForKey:oldKey];
    }
    [defaults synchronize];
}

__attribute__((constructor))
static void DYYYFeatureSupportCtor(void) {
    DYYYMigrateLegacyFeatureKeys();
}
