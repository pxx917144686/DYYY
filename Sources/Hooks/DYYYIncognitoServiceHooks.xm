//
//  DYYYIncognitoServiceHooks.xm
//  DYYY
//
//  无痕模式与服务拦截 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

static NSMutableDictionary *incognitoStateDict = nil;
static dispatch_once_t incognitoStateDictOnceToken;

static void ensureIncognitoStateDictInitialized(void) {
    dispatch_once(&incognitoStateDictOnceToken, ^{
        if (!incognitoStateDict) {
            incognitoStateDict = [NSMutableDictionary dictionary];
        }
    });
}

%hook AWETabViewController

%property (nonatomic, assign) BOOL isIncognitoModeActive;

- (void)viewDidLoad {
    %orig;
    
    // 初始化无痕模式状态
    ensureIncognitoStateDictInitialized();
    
    // 检查是否启用无痕模式
    BOOL enableIncognito = DYYYCachedBool(@"DYYYEnableIncognitoMode");
    
    // 同步设置无痕模式状态
    self.isIncognitoModeActive = enableIncognito;
    @synchronized(incognitoStateDict) {
        [incognitoStateDict setObject:@(enableIncognito) forKey:@"isIncognitoActive"];
    }
    
    // 如果启用了无痕模式，显示提示
    if (enableIncognito) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [DYYYManager showToast:@"无痕浏览模式已启用，浏览记录不会被保存"];
        });
    }
}

%end

static BOOL isIncognitoModeActive() {
    // 直接检查用户默认设置
    return DYYYCachedBool(@"DYYYEnableIncognitoMode");
}

%hook AWEHistoryService

- (void)addAwemeToHistory:(id)arg1 {
    if (isIncognitoModeActive()) {
        // 无痕模式下不记录历史
        return;
    }
    %orig;
}

%end

// 拦截搜索历史记录
%hook AWESearchHistoryStorage

- (void)saveSearchKeyword:(id)arg1 {
    if (isIncognitoModeActive()) {
        // 无痕模式下不记录搜索历史
        return;
    }
    %orig;
}

%end

// 拦截点赞行为
%hook AWELikeServiceManager

- (void)likeAweme:(id)arg1 completion:(id)arg2 {
    if (isIncognitoModeActive()) {
        // 无痕模式下显示提示，不执行点赞
        [DYYYManager showToast:@"无痕模式下，点赞操作不会被记录"];
        
        // 调用回调避免UI卡住
        if (arg2 && [arg2 isKindOfClass:NSClassFromString(@"NSBlock")]) {
            void (^completionBlock)(BOOL, NSError *) = arg2;
            completionBlock(YES, nil);
        }
        return;
    }
    %orig;
}

%end

// 拦截收藏行为
%hook AWEFavoriteServiceManager

- (void)favoriteAweme:(id)arg1 completion:(id)arg2 {
    if (isIncognitoModeActive()) {
        // 无痕模式下显示提示，不执行收藏
        [DYYYManager showToast:@"无痕模式下，收藏操作不会被记录"];
        
        // 调用回调避免UI卡住
        if (arg2 && [arg2 isKindOfClass:NSClassFromString(@"NSBlock")]) {
            void (^completionBlock)(BOOL, NSError *) = arg2;
            completionBlock(YES, nil);
        }
        return;
    }
    %orig;
}

%end

// 拦截评论行为
%hook AWECommentService

- (void)postComment:(id)arg1 completion:(id)arg2 {
    if (isIncognitoModeActive()) {
        // 无痕模式下显示提示，不执行评论
        [DYYYManager showToast:@"无痕模式下，评论操作不会被记录"];
        
        // 调用回调避免UI卡住
        if (arg2 && [arg2 isKindOfClass:NSClassFromString(@"NSBlock")]) {
            void (^completionBlock)(id, NSError *) = arg2;
            NSError *error = [NSError errorWithDomain:@"com.dyyy.incognito" code:999 userInfo:@{NSLocalizedDescriptionKey: @"无痕模式已阻止此操作"}];
            completionBlock(nil, error);
        }
        return;
    }
    %orig;
}

%end

// 拦截关注行为
%hook AWEUserServiceManager

- (void)followUser:(id)arg1 completion:(id)arg2 {
    if (isIncognitoModeActive()) {
        // 无痕模式下显示提示，不执行关注
        [DYYYManager showToast:@"无痕模式下，关注操作不会被记录"];
        
        // 调用回调避免UI卡住
        if (arg2 && [arg2 isKindOfClass:NSClassFromString(@"NSBlock")]) {
            void (^completionBlock)(id, NSError *) = arg2;
            NSError *error = [NSError errorWithDomain:@"com.dyyy.incognito" code:999 userInfo:@{NSLocalizedDescriptionKey: @"无痕模式已阻止此操作"}];
            completionBlock(nil, error);
        }
        return;
    }
    %orig;
}

%end

%ctor {
    // 初始化无痕模式状态字典
    ensureIncognitoStateDictInitialized();
    @synchronized(incognitoStateDict) {
        [incognitoStateDict setObject:@(NO) forKey:@"isIncognitoActive"];
    }

    // 检查初始状态
    BOOL initialState = DYYYCachedBool(@"DYYYEnableIncognitoMode");
    @synchronized(incognitoStateDict) {
        [incognitoStateDict setObject:@(initialState) forKey:@"isIncognitoActive"];
    }

    %init;
}
