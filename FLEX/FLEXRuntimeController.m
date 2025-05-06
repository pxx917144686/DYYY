// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeController.m
//  FLEX
//
//  由 Tanner 创建于 3/23/17.
//  版权所有 © 2017 Tanner Bennett。保留所有权利。
//

#import "FLEXRuntimeController.h"
#import "FLEXRuntimeClient.h"
#import "FLEXMethod.h"

@interface FLEXRuntimeController ()
@property (nonatomic, readonly) NSCache *bundlePathsCache;
@property (nonatomic, readonly) NSCache *bundleNamesCache;
@property (nonatomic, readonly) NSCache *classNamesCache;
@property (nonatomic, readonly) NSCache *methodsCache;
@end

@implementation FLEXRuntimeController

#pragma mark 初始化

static FLEXRuntimeController *controller = nil;
+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [self new];
    });

    return controller;
}

- (id)init {
    self = [super init];
    if (self) {
        _bundlePathsCache = [NSCache new];
        _bundleNamesCache = [NSCache new];
        _classNamesCache  = [NSCache new];
        _methodsCache     = [NSCache new];
    }

    return self;
}

#pragma mark 公开方法

+ (NSArray *)dataForKeyPath:(FLEXRuntimeKeyPath *)keyPath {
    if (keyPath.bundleKey) {
        if (keyPath.classKey) {
            if (keyPath.methodKey) {
                return [[self shared] methodsForKeyPath:keyPath];
            } else {
                return [[self shared] classesForKeyPath:keyPath];
            }
        } else {
            return [[self shared] bundleNamesForToken:keyPath.bundleKey];
        }
    } else {
        return @[];
    }
}

+ (NSArray<NSArray<FLEXMethod *> *> *)methodsForToken:(FLEXSearchToken *)token
                         instance:(NSNumber *)inst
                        inClasses:(NSArray<NSString*> *)classes {
    return [FLEXRuntimeClient.runtime
        methodsForToken:token
        instance:inst
        inClasses:classes
    ];
}

+ (NSMutableArray<NSString *> *)classesForKeyPath:(FLEXRuntimeKeyPath *)keyPath {
    return [[self shared] classesForKeyPath:keyPath];
}

+ (NSString *)shortBundleNameForClass:(NSString *)name {
    const char *imageName = class_getImageName(NSClassFromString(name));
    if (!imageName) {
        return @"(未指定)";
    }
    
    return [FLEXRuntimeClient.runtime shortNameForImageName:@(imageName)];
}

+ (NSString *)imagePathWithShortName:(NSString *)suffix {
    return [FLEXRuntimeClient.runtime imageNameForShortName:suffix];
}

+ (NSArray *)allBundleNames {
    return FLEXRuntimeClient.runtime.imageDisplayNames;
}

#pragma mark 私有方法

- (NSMutableArray *)bundlePathsForToken:(FLEXSearchToken *)token {
    // 仅当没有通配符时才缓存
    BOOL shouldCache = token == TBWildcardOptionsNone;

    if (shouldCache) {
        NSMutableArray<NSString*> *cached = [self.bundlePathsCache objectForKey:token];
        if (cached) {
            return cached;
        }

        NSMutableArray<NSString*> *bundles = [FLEXRuntimeClient.runtime bundlePathsForToken:token];
        [self.bundlePathsCache setObject:bundles forKey:token];
        return bundles;
    }
    else {
        return [FLEXRuntimeClient.runtime bundlePathsForToken:token];
    }
}

- (NSMutableArray<NSString *> *)bundleNamesForToken:(FLEXSearchToken *)token {
    // 仅当没有通配符时才缓存
    BOOL shouldCache = token == TBWildcardOptionsNone;

    if (shouldCache) {
        NSMutableArray<NSString*> *cached = [self.bundleNamesCache objectForKey:token];
        if (cached) {
            return cached;
        }

        NSMutableArray<NSString*> *bundles = [FLEXRuntimeClient.runtime bundleNamesForToken:token];
        [self.bundleNamesCache setObject:bundles forKey:token];
        return bundles;
    }
    else {
        return [FLEXRuntimeClient.runtime bundleNamesForToken:token];
    }
}

- (NSMutableArray<NSString *> *)classesForKeyPath:(FLEXRuntimeKeyPath *)keyPath {
    FLEXSearchToken *classToken = keyPath.classKey;
    FLEXSearchToken *bundleToken = keyPath.bundleKey;
    
    // 仅当没有通配符时才缓存
    BOOL shouldCache = bundleToken.options == 0 && classToken.options == 0;
    NSString *key = nil;

    if (shouldCache) {
        key = [@[bundleToken.description, classToken.description] componentsJoinedByString:@"+"];
        NSMutableArray<NSString *> *cached = [self.classNamesCache objectForKey:key];
        if (cached) {
            return cached;
        }
    }

    NSMutableArray<NSString *> *bundles = [self bundlePathsForToken:bundleToken];
    NSMutableArray<NSString *> *classes = [FLEXRuntimeClient.runtime
        classesForToken:classToken inBundles:bundles
    ];

    if (shouldCache) {
        [self.classNamesCache setObject:classes forKey:key];
    }

    return classes;
}

- (NSArray<NSMutableArray<FLEXMethod *> *> *)methodsForKeyPath:(FLEXRuntimeKeyPath *)keyPath {
    // 仅当没有通配符时才缓存，但无论如何都检查缓存，因为我懒
    NSArray<NSMutableArray *> *cached = [self.methodsCache objectForKey:keyPath];
    if (cached) {
        return cached;
    }

    NSArray<NSString *> *classes = [self classesForKeyPath:keyPath];
    NSArray<NSMutableArray<FLEXMethod *> *> *methodLists = [FLEXRuntimeClient.runtime
        methodsForToken:keyPath.methodKey
        instance:keyPath.instanceMethods
        inClasses:classes
    ];

    for (NSMutableArray<FLEXMethod *> *methods in methodLists) {
        [methods sortUsingComparator:^NSComparisonResult(FLEXMethod *m1, FLEXMethod *m2) {
            return [m1.description caseInsensitiveCompare:m2.description];
        }];
    }

    // 仅当没有通配符时才缓存，否则缓存可能会变得非常大
    if (keyPath.bundleKey.isAbsolute &&
        keyPath.classKey.isAbsolute) {
        [self.methodsCache setObject:methodLists forKey:keyPath];
    }

    return methodLists;
}

@end
