// 作用:签名验证绕过
// of pxx917144686
/**

DYYYBundleHook.xm
├── 全局配置和工具函数
├── 核心层：Bundle ID获取拦截
│   ├── NSBundle Hook
│   └── 主Bundle处理
├── 网络层：仅拦截Bundle ID相关请求
│   └── NSURLRequest (仅Bundle ID相关)
└── 动态修改机制
    ├── 缓存系统
    ├── 定时器轮换
    └── 清理机制

*/

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

// 全局配置
static NSString * const kOriginalBundleId = @"com.ss.iphone.ugc.Aweme";
static NSString * const kOriginalBundleIdBeta = @"com.ss.iphone.ugc.Aweme.beta";
static NSString * const kOriginalBundleIdInternal = @"com.ss.iphone.ugc.Aweme.internal";

// 多种绕过标识符（随机选择）
static NSArray *bypassIdentifiers = nil;

// 初始化绕过标识符数组
__attribute__((constructor))
static void initializeBypassIdentifiers() {
    bypassIdentifiers = @[
        @"😊", @"😎", @"🤔", @"😉", @"😋", @"😍", @"🥰", @"😘",
        @"😗", @"😙", @"😚", @"🙂", @"🤗", @"🤩", @"🤨", @"🧐",
        @"🤓", @"😇", @"🥳", @"😌", @"😊", @"😏", @"😒", @"🙃"
    ];
}

// 获取随机绕过标识符
static NSString* getRandomBypassIdentifier() {
    if (!bypassIdentifiers) {
        initializeBypassIdentifiers();
    }
    NSUInteger randomIndex = arc4random_uniform((uint32_t)bypassIdentifiers.count);
    return bypassIdentifiers[randomIndex];
}

// 检查是否是抖音Bundle ID
static BOOL isAwemeBundleId(NSString *bundleId) {
    return [bundleId isEqualToString:kOriginalBundleId] ||
           [bundleId isEqualToString:kOriginalBundleIdBeta] ||
           [bundleId isEqualToString:kOriginalBundleIdInternal];
}

// 生成修改后的Bundle ID
static NSString* generateModifiedBundleId(NSString *originalId) {
    if (!isAwemeBundleId(originalId)) {
        return originalId;
    }
    
    // 使用多种策略
    NSString *bypassChar = getRandomBypassIdentifier();
    return [originalId stringByAppendingString:bypassChar];
}

// 缓存机制，避免重复计算
static NSMutableDictionary *bundleIdCache = nil;

__attribute__((constructor))
static void initializeCache() {
    bundleIdCache = [[NSMutableDictionary alloc] init];
}

// 优化的Bundle ID生成函数
static NSString* optimizedGenerateModifiedBundleId(NSString *originalId) {
    if (!isAwemeBundleId(originalId)) {
        return originalId;
    }
    
    // 检查缓存
    NSString *cachedId = bundleIdCache[originalId];
    if (cachedId) {
        return cachedId;
    }
    
    // 生成新的修改后的ID
    NSString *modifiedId = generateModifiedBundleId(originalId);
    
    // 缓存结果（限制缓存大小）
    if (bundleIdCache.count < 100) {
        bundleIdCache[originalId] = modifiedId;
    }
    
    return modifiedId;
}

// ========== Bundle ID获取拦截 ==========

%hook NSBundle

// Hook bundleIdentifier方法，返回修改后的标识符
- (NSString *)bundleIdentifier {
    NSString *originalIdentifier = %orig;
    
    // 使用优化的检查函数
    if (isAwemeBundleId(originalIdentifier)) {
        NSString *modifiedIdentifier = optimizedGenerateModifiedBundleId(originalIdentifier);
        return modifiedIdentifier;
    }
    
    return originalIdentifier;
}

// Hook infoDictionary方法，确保Info.plist中的标识符也被修改
- (NSDictionary *)infoDictionary {
    NSDictionary *originalInfo = %orig;
    
    if (originalInfo) {
        NSMutableDictionary *modifiedInfo = [originalInfo mutableCopy];
        NSString *bundleId = modifiedInfo[@"CFBundleIdentifier"];
        
        // 使用优化的检查函数
        if (isAwemeBundleId(bundleId)) {
            NSString *modifiedBundleId = optimizedGenerateModifiedBundleId(bundleId);
            modifiedInfo[@"CFBundleIdentifier"] = modifiedBundleId;
            
            return [modifiedInfo copy];
        }
    }
    
    return originalInfo;
}

%end

// Hook NSBundle的类方法，确保所有获取Bundle Identifier的地方都被修改
%hook NSBundle

+ (NSBundle *)mainBundle {
    NSBundle *mainBundle = %orig;
    
    // 对主Bundle进行额外处理
    if (mainBundle) {
        NSString *bundleId = [mainBundle bundleIdentifier];
        if ([bundleId containsString:@"com.ss.iphone.ugc.Aweme"] && ![bundleId containsString:@"😊"]) {
            // 主Bundle已经被Hook处理
        }
    }
    
    return mainBundle;
}

%end

// ========== 网络层：仅拦截Bundle ID相关请求 ==========

// Hook NSURLRequest - 仅处理明确的Bundle ID相关请求
%hook NSURLRequest

- (NSURL *)URL {
    NSURL *originalURL = %orig;
    
    if (originalURL) {
        NSString *urlString = [originalURL absoluteString];
        
        // 只处理明确的Bundle ID相关URL，避免影响业务功能
        if ([urlString containsString:@"bundle_id"] || 
            [urlString containsString:@"bundleId"] ||
            [urlString containsString:@"bundle_identifier"]) {
            
            // 检查URL中是否包含原始Bundle ID
            if ([urlString containsString:kOriginalBundleId]) {
                NSString *modifiedUrlString = [urlString stringByReplacingOccurrencesOfString:kOriginalBundleId 
                                                                                     withString:optimizedGenerateModifiedBundleId(kOriginalBundleId)];
                return [NSURL URLWithString:modifiedUrlString];
            }
        }
    }
    
    return originalURL;
}

%end

// Hook NSMutableURLRequest - 仅处理Bundle ID相关的HTTP头部
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // 只拦截明确的Bundle ID相关头部字段
    if ([field.lowercaseString isEqualToString:@"x-bundle-id"] || 
        [field.lowercaseString isEqualToString:@"bundle-identifier"] ||
        [field.lowercaseString isEqualToString:@"app-bundle-id"]) {
        if (value && isAwemeBundleId(value)) {
            value = optimizedGenerateModifiedBundleId(value);
        }
    }
    %orig(value, field);
}

%end

// ========== 动态修改机制 ==========

// 动态标识符轮换
static NSTimer *bundleIdRotationTimer = nil;

__attribute__((constructor))
static void startOptimizedBundleIdRotation() {
    // 每60秒更换一次绕过标识符（减少频率）
    bundleIdRotationTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                             repeats:YES
                                                               block:^(NSTimer * _Nonnull timer) {
        // 清空缓存并重新初始化
        [bundleIdCache removeAllObjects];
        initializeBypassIdentifiers();
    }];
}

__attribute__((destructor))
static void stopBundleIdRotation() {
    if (bundleIdRotationTimer) {
        [bundleIdRotationTimer invalidate];
        bundleIdRotationTimer = nil;
    }
    bundleIdCache = nil;
}