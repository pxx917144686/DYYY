#import "DYYYABTestHook.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>

@interface AWEABTestManager : NSObject
@property(retain, nonatomic) NSDictionary *abTestData;
@property(retain, nonatomic) NSMutableDictionary *consistentABTestDic;
@property(copy, nonatomic) NSDictionary *performanceReversalDic;
- (void)setAbTestData:(id)arg1;
- (void)_saveABTestData:(id)arg1;
- (id)abTestData;
+ (id)sharedManager;
@end

BOOL abTestBlockEnabled = NO;
BOOL abTestPatchEnabled = NO;
NSDictionary *gFixedABTestData = nil;
dispatch_once_t onceToken;
BOOL gDataLoaded = NO;
BOOL gFileExists = NO;
static NSDate *lastLoadAttemptTime = nil;
static const NSTimeInterval kMinLoadInterval = 60.0;
BOOL gABTestDataFixed = NO;
static BOOL gIsApplyingFixedData = NO;

// 常量定义（替代 DYYYConstants.h，避免创建新文件）
static NSString *const kDefaultRemoteConfigURL = @"https://github.com/Nathalie-Annis/AWEABTestDataPatch/releases/latest/download/ABTestDataPatch_A.json";
static NSString *const kDYYYRemoteModeString = @"远程模式：启动时自动检查更新";
static NSString *const kDYYYRemoteConfigFlagKey = @"DYYYUseRemoteConfig";
static NSString *const kDYYYRemoteConfigChangedNotification = @"DYYYRemoteConfigStateChanged";
static NSString *const kDYYYTabBarHeightKey = @"DYYYTabBarHeight";
static NSString *const kDYYYABTestTabBarHeightConfigKey = @"hp_tab_bar_custom_height_config";

static NSNumber *DYYYResolveTabBarHeightFromSettings(void) {
	float heightValue = [[NSUserDefaults standardUserDefaults] floatForKey:kDYYYTabBarHeightKey];
	if (heightValue <= 0.0f) {
		return nil;
	}
	return @(heightValue);
}

static NSDictionary *DYYYBuildTabBarHeightConfig(NSDictionary *existingConfig, NSNumber *contentHeight) {
	NSMutableDictionary *config = [NSMutableDictionary dictionary];
	if ([existingConfig isKindOfClass:[NSDictionary class]]) {
		[config addEntriesFromDictionary:existingConfig];
	}

	config[@"content_height"] = contentHeight;
	if (!config[@"custom_safe_area_bottom_offet"]) {
		config[@"custom_safe_area_bottom_offet"] = @0;
	}
	if (!config[@"custom_safe_area_bottom_offset_black_set"]) {
		config[@"custom_safe_area_bottom_offset_black_set"] = @[];
	}
	if (!config[@"custom_tab_bar_height_black_set"]) {
		config[@"custom_tab_bar_height_black_set"] = @[];
	}
	if (!config[@"enabled"]) {
		config[@"enabled"] = @YES;
	}
	if (!config[@"overlap_height"]) {
		config[@"overlap_height"] = @14;
	}

	return [config copy];
}

static NSDictionary *DYYYInjectTabBarHeightConfig(NSDictionary *sourceData, NSNumber *contentHeight) {
	if (!contentHeight) {
		return sourceData;
	}

	NSMutableDictionary *patchedData = [NSMutableDictionary dictionaryWithDictionary:sourceData ?: @{}];
	NSDictionary *existingConfig = nil;
	id existingConfigValue = patchedData[kDYYYABTestTabBarHeightConfigKey];
	if ([existingConfigValue isKindOfClass:[NSDictionary class]]) {
		existingConfig = (NSDictionary *)existingConfigValue;
	}
	patchedData[kDYYYABTestTabBarHeightConfigKey] = DYYYBuildTabBarHeightConfig(existingConfig, contentHeight);

	return [patchedData copy];
}

static void DYYYApplyTabBarHeightToCurrentABTestDataIfNeeded(void) {
	NSNumber *contentHeight = DYYYResolveTabBarHeightFromSettings();
	if (!contentHeight) {
		return;
	}

	AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
	if (!manager) {
		return;
	}

	NSDictionary *currentData = [manager abTestData];
	if (currentData && ![currentData isKindOfClass:[NSDictionary class]]) {
		return;
	}

	NSDictionary *patchedData = DYYYInjectTabBarHeightConfig(currentData ?: @{}, contentHeight);
	if (currentData && [currentData isEqualToDictionary:patchedData]) {
		return;
	}

	gIsApplyingFixedData = YES;
	[manager setAbTestData:patchedData];
	gIsApplyingFixedData = NO;
	NSLog(@"[DYYY] 已通过 ABTest 注入底栏高度: %@", contentHeight);
}

static BOOL DYYYIsRemoteMode(void) {
	NSString *savedMode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYABTestModeString"];
	if (savedMode) {
		return [savedMode isEqualToString:kDYYYRemoteModeString] || [[savedMode lowercaseString] isEqualToString:@"remote"];
	}
	return NO;
}

void ensureABTestDataLoaded(void) {
	if (gDataLoaded)
		return;

	dispatch_once(&onceToken, ^{
	  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	  NSString *documentsDirectory = [paths firstObject];

	  NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
	  NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];

	  NSFileManager *fileManager = [NSFileManager defaultManager];
	  if (![fileManager fileExistsAtPath:dyyyFolderPath]) {
		  NSError *error = nil;
		  [fileManager createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
		  if (error) {
			  NSLog(@"[DYYY] 创建DYYY目录失败: %@", error.localizedDescription);
		  }
	  }

	  // 检查文件是否存在
	  if (![fileManager fileExistsAtPath:jsonFilePath]) {
		  gFileExists = NO;
		  gDataLoaded = YES;
		  return;
	  }

	  NSError *error = nil;
	  NSData *jsonData = [NSData dataWithContentsOfFile:jsonFilePath options:0 error:&error];

	  if (jsonData) {
		  NSDictionary *loadedData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
		  if (loadedData && !error) {
			  // 成功加载数据，保存到全局变量
			  gFixedABTestData = [loadedData copy];
			  gFileExists = YES;
			  gDataLoaded = YES;
			  return;
		  }
	  }
	  gFileExists = NO;
	  gDataLoaded = YES;
	});
}

// 优化防止频繁加载
NSDictionary *loadFixedABTestData(void) {
	if (gDataLoaded) {
		return gFileExists ? gFixedABTestData : nil;
	}

	NSDate *now = [NSDate date];
	if (lastLoadAttemptTime && [now timeIntervalSinceDate:lastLoadAttemptTime] < kMinLoadInterval) {
		return gFileExists ? gFixedABTestData : nil;
	}

	lastLoadAttemptTime = now;

	ensureABTestDataLoaded();
	return gFileExists ? gFixedABTestData : nil;
}

static NSDictionary *fixedABTestData(void) {
	if (!abTestBlockEnabled) {
		return nil;
	}

	if (!gDataLoaded) {
		ensureABTestDataLoaded();
	}

	return gFileExists ? gFixedABTestData : nil;
}

// 获取当前ABTest数据
NSDictionary *getCurrentABTestData(void) {
	if (abTestBlockEnabled) {
		if (!gDataLoaded) {
			ensureABTestDataLoaded();
		}
		if (!gFileExists) {
			AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
			return manager ? [manager abTestData] : nil;
		}
		return gFixedABTestData;
	}

	AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
	if (!manager) {
		return nil;
	}

	NSDictionary *currentData = [manager abTestData];
	return currentData;
}

// 从网络检查并下载最新配置
void checkForRemoteConfigUpdate(BOOL notify) {
	NSString *urlString = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYRemoteConfigURL"];
	if (urlString.length == 0) {
		urlString = kDefaultRemoteConfigURL;
	}
	NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
	NSString *scheme = components.scheme.lowercaseString;
	BOOL invalidURL = NO;
	if (!components || components.host.length == 0 || !scheme || ![scheme isEqualToString:@"https"]) {
		invalidURL = YES;
	}
	NSURL *url = components.URL;
	if (invalidURL || !url) {
		if (notify) {
			dispatch_async(dispatch_get_main_queue(), ^{
			  [DYYYUtils showToast:@"配置地址无效"];
			});
		}
		return;
	}
	NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
	                                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
	                                                           BOOL updated = NO;
	                                                           NSError *validationError = nil;
	                                                           if (data && !error) {
	                                                               id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&validationError];
	                                                               if (validationError || ![jsonObject isKindOfClass:[NSDictionary class]]) {
	                                                                   if (!validationError) {
	                                                                       validationError = [NSError errorWithDomain:@"com.dyyy.remoteconfig" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"配置格式错误"}];
	                                                                   }
	                                                               } else {
	                                                                   NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	                                                                   NSString *documentsDirectory = [paths firstObject];
	                                                                   NSString *dyyyFolderPath = [documentsDirectory stringByAppendingPathComponent:@"DYYY"];
	                                                                   NSString *jsonFilePath = [dyyyFolderPath stringByAppendingPathComponent:@"abtest_data_fixed.json"];
	                                                                   [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
	                                                                   NSData *existingData = [NSData dataWithContentsOfFile:jsonFilePath];
	                                                                   if (!existingData || ![existingData isEqualToData:data]) {
	                                                                       [data writeToFile:jsonFilePath atomically:YES];
	                                                                       updated = YES;
	                                                                   }
	                                                                   if (DYYYIsRemoteMode()) {
	                                                                       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kDYYYRemoteConfigFlagKey];
	                                                                       [[NSNotificationCenter defaultCenter] postNotificationName:kDYYYRemoteConfigChangedNotification object:nil];
	                                                                   }
	                                                               }
	                                                           }
	                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                             if (error || !data) {
                                                                 if (notify) {
                                                                     [DYYYUtils showToast:@"配置更新失败"];
                                                                 }
                                                             } else if (validationError) {
                                                                 if (notify) {
                                                                     [DYYYUtils showToast:@"配置解析失败"];
                                                                 }
                                                             } else if (updated) {
                                                                 if (notify) {
                                                                     [DYYYUtils showToast:@"配置已更新"];
                                                                 }
                                                                 // 重新加载本地配置
                                                                 gFixedABTestData = nil;
                                                                 gFileExists = NO;
                                                                 gDataLoaded = NO;
                                                                 onceToken = 0;
                                                                 ensureABTestDataLoaded();
                                                                 // 应用到 manager
                                                                 AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
                                                                 if (manager && gFixedABTestData) {
                                                                     if (abTestPatchEnabled) {
                                                                         // 覆写(合并)模式
                                                                         NSDictionary *currentData = [manager abTestData];
                                                                         NSMutableDictionary *mergedData = [NSMutableDictionary dictionaryWithDictionary:currentData ?: @{}];
                                                                         [mergedData addEntriesFromDictionary:gFixedABTestData];
                                                                         gIsApplyingFixedData = YES;
                                                                         [manager setAbTestData:[mergedData copy]];
                                                                         gIsApplyingFixedData = NO;
                                                                     } else if (abTestBlockEnabled) {
                                                                         gIsApplyingFixedData = YES;
                                                                         [manager setAbTestData:gFixedABTestData];
                                                                         gIsApplyingFixedData = NO;
                                                                     }
                                                                     gABTestDataFixed = YES;
                                                                 }
                                                             } else {
                                                                 if (notify) {
                                                                     [DYYYUtils showToast:@"已是最新配置"];
                                                                 }
                                                             }
                                                           });
	                                                       }];
	[task resume];
}

%hook AWEABTestManager

// 拦截设置 ABTest 数据的方法
- (void)setAbTestData:(id)arg1 {
	if (abTestBlockEnabled && !gIsApplyingFixedData && arg1 != gFixedABTestData) {
		return;
	}
	id finalData = arg1;
	NSNumber *contentHeight = DYYYResolveTabBarHeightFromSettings();
	if (contentHeight && (!arg1 || [arg1 isKindOfClass:[NSDictionary class]])) {
		finalData = DYYYInjectTabBarHeightConfig(arg1 ?: @{}, contentHeight);
	}
	%orig(finalData);
}

// 拦截增量数据更新
- (void)incrementalUpdateData:(id)arg1 unchangedKeyList:(id)arg2 {
	if (abTestBlockEnabled) {
		return;
	}
	%orig;
}

// 拦截网络获取配置方法
- (void)fetchConfigurationWithRetry:(BOOL)arg1 completion:(id)arg2 {
	if (abTestBlockEnabled) {
		if (arg2 && [arg2 isKindOfClass:%c(NSBlock)]) {
			dispatch_async(dispatch_get_main_queue(), ^{
			  ((void (^)(id))arg2)(nil);
			});
		}
		return;
	}
	%orig;
}

- (void)fetchConfiguration:(id)arg1 {
	if (abTestBlockEnabled) {
		return;
	}
	%orig;
}

// 拦截重写ABTest数据的方法
- (void)overrideABTestData:(id)arg1 needCleanCache:(BOOL)arg2 {
	if (abTestBlockEnabled) {
		return;
	}
	%orig;
}

// 拦截一致性ABTest值获取方法
- (id)getValueOfConsistentABTestWithKey:(id)arg1 {
    if (gABTestDataFixed) {
        return %orig;
    }

    if ((abTestBlockEnabled || abTestPatchEnabled) && arg1) {
        if (!gDataLoaded) {
            ensureABTestDataLoaded();
        }
        if (!gFileExists) {
            return %orig; 
        }
        NSString *key = (NSString *)arg1;
        id localValue = [gFixedABTestData objectForKey:key];
        
        if (localValue) {
            return localValue;
        }

        if (abTestPatchEnabled) {
            return %orig;
        }

        return nil;
    }
 
    return %orig;
}

%end

%ctor {
    %init;
    abTestBlockEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYABTestBlockEnabled"];
    abTestPatchEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYABTestPatchEnabled"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ensureABTestDataLoaded();
        AWEABTestManager *manager = [%c(AWEABTestManager) sharedManager];
        if (manager && gFixedABTestData && abTestBlockEnabled && !abTestPatchEnabled) {
            [manager setAbTestData:gFixedABTestData];

            if ([manager respondsToSelector:@selector(_saveABTestData:)]) {
                [manager _saveABTestData:gFixedABTestData];
            }

            gABTestDataFixed = YES;
        } else if (manager && gFixedABTestData && abTestPatchEnabled) {
            // 覆写(合并)模式：将本地配置合并进现有 abTestData
            NSDictionary *currentData = [manager abTestData];
            NSMutableDictionary *mergedData = [NSMutableDictionary dictionaryWithDictionary:currentData ?: @{}];
            [mergedData addEntriesFromDictionary:gFixedABTestData];
            NSDictionary *dataToApply = [mergedData copy];

            gIsApplyingFixedData = YES;
            [manager setAbTestData:dataToApply];
            if ([manager respondsToSelector:@selector(_saveABTestData:)]) {
                [manager _saveABTestData:dataToApply];
            }
            gIsApplyingFixedData = NO;
            gABTestDataFixed = YES;
        } else {
            NSLog(@"[DYYY] 无法设置ABTest数据: manager=%@, data=%@, 模式=%@",
                manager,
                gFixedABTestData ? @"已加载" : @"未加载",
                abTestPatchEnabled ? @"补丁模式" : (abTestBlockEnabled ? @"完全替换模式" : @"未启用"));
        }

        // 注入底栏高度到当前 ABTest 数据
        DYYYApplyTabBarHeightToCurrentABTestDataIfNeeded();

        // 远程模式：启动时检查配置更新
        if (DYYYIsRemoteMode()) {
            checkForRemoteConfigUpdate(NO);
        }
    });
}