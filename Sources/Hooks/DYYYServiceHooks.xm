#import "DYYYHookShared.h"

%hook AWESearchAnchorListModel

- (BOOL)hideWords {
	return DYYYCachedBool(@"DYYYHideCommentViews");
}

- (void)setHideWords:(BOOL)arg1 {
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		%orig(YES);
	} else {
		%orig(arg1);
	}
}

- (void)setScene:(id)arg1 {
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		NSDictionary *customScene = @{@"hideComments" : @YES};
		%orig(customScene);
	} else {
		%orig(arg1);
	}
}
%end

%hook AWEGeneralSearchModel
- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
	id orig = %orig;

	BOOL noAds = DYYYGetBool(@"DYYYNoAds");
	if (!noAds || !orig) {
		return orig;
	}

	if ([DYYYUtils isAdvertisementContainerModel:orig] || [DYYYUtils isAdvertisementRawData:dict]) {
		return nil;
	}

	return orig;
}
%end

%hook AwemeAdManager
- (void)showAd {
	if (DYYYCachedBool(@"DYYYNoAds"))
		return;
	%orig;
}
%end

%hook AWEVersionUpdateManager

- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
	if (DYYYCachedBool(@"DYYYNoUpdates")) {
		if (arg2) {
			void (^completionBlock)(void) = arg2;
			completionBlock();
		}
	} else {
		%orig;
	}
}

- (id)workflow {
	return DYYYCachedBool(@"DYYYNoUpdates") ? nil : %orig;
}

- (id)badgeModule {
	return DYYYCachedBool(@"DYYYNoUpdates") ? nil : %orig;
}

%end

%hook AFDProfileAvatarFunctionManager
- (BOOL)shouldShowSaveAvatarItem {
	BOOL shouldEnable = DYYYCachedBool(@"DYYYEnableSaveAvatar");
	if (shouldEnable) {
		return YES;
	}
	return %orig;
}
%end

%hook AWESettingsViewModel

- (NSArray *)sectionDataArray {
    NSArray *originalSections = %orig;
    
    BOOL sectionExists = NO;
    for (AWESettingSectionModel *section in originalSections) {
        if ([section.sectionHeaderTitle isEqualToString:@"DYYY"]) {
            sectionExists = YES;
            break;
        }
    }
    
    if (!sectionExists) {
        AWESettingItemModel *dyyyItem = [[%c(AWESettingItemModel) alloc] init];
        dyyyItem.identifier = @"DYYY";
        dyyyItem.title = @"DYYY";
        dyyyItem.detail = @"v2.1-7++";
        dyyyItem.type = 0;
        dyyyItem.iconImageName = @"noticesettting_like";
        dyyyItem.cellType = 26;
        dyyyItem.colorStyle = 2;
        dyyyItem.isEnable = YES;
        
        dyyyItem.cellTappedBlock = ^{
            UIViewController *rootViewController = self.controllerDelegate;
            if (!rootViewController) {
                return;
            }
            
            DYYYSettingViewController *settingVC = [[DYYYSettingViewController alloc] init];
            if (rootViewController.navigationController) {
                [rootViewController.navigationController pushViewController:settingVC animated:YES];
            } else {
                UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingVC];
                navController.modalPresentationStyle = UIModalPresentationFullScreen;
                [rootViewController presentViewController:navController animated:YES completion:nil];
            }
        };
        
        AWESettingSectionModel *dyyySection = [[%c(AWESettingSectionModel) alloc] init];
        dyyySection.sectionHeaderTitle = @"DYYY";
        dyyySection.sectionHeaderHeight = 40;
        dyyySection.type = 0;
        dyyySection.itemArray = @[dyyyItem];
        
        NSMutableArray<AWESettingSectionModel *> *newSections = [NSMutableArray arrayWithArray:originalSections];
        [newSections insertObject:dyyySection atIndex:0];
        
        return newSections;
    }
    
    return originalSections;
}

%end

%hook AWEIMPhotoPickerFunctionModel

- (void)setUseShadowIcon:(BOOL)arg1 {
	BOOL enabled = DYYYCachedBool(@"DYYYisAutoSelectOriginalPhoto");
	if (enabled) {
		%orig(YES);
	} else {
		%orig(arg1);
	}
}

- (BOOL)isSelected {
	BOOL enabled = DYYYCachedBool(@"DYYYisAutoSelectOriginalPhoto");
	if (enabled) {
		return YES;
	}
	return %orig;
}

%end

%hook AWEFeedModuleService
- (BOOL)getFeedIphoneAutoPlayState {
    // 检查是否启用自动播放功能
    BOOL enabled = DYYYCachedBool(@"DYYYisEnableAutoPlay");
    if (!enabled) {
        return %orig; // 未启用时保持原来的行为
    }
    return YES; // 启用时强制返回YES
}
%end

