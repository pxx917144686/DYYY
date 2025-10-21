#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"

%hook AWEAwemeModel

- (id)initWithDictionary:(id)arg1 error:(id *)arg2 {
	id orig = %orig;

	BOOL noAds = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"];
	BOOL skipLive = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"];
    BOOL skipHotSpot = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipHotSpot"];
    BOOL skipAllLive = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSkipAllLive"];
	BOOL filterHDR = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYFilterFeedHDR"];

	BOOL shouldFilterAds = noAds && (self.hotSpotLynxCardModel || self.isAds);
	BOOL shouldFilterRec = skipLive && (self.liveReason != nil);
    BOOL shouldFilterHotSpot = skipHotSpot && self.hotSpotLynxCardModel;
    BOOL shouldFilterAllLive = NO;

	BOOL shouldFilterLowLikes = NO;
	BOOL shouldFilterKeywords = NO;
	BOOL shouldFilterTime = NO;
    BOOL shouldFilterUser = NO;
    BOOL shouldFilterHDR = NO;
    BOOL shouldFilterProp = NO;

    // 获取用户设置的需要过滤的关键词（兼容大小写键名）
    NSString *filterKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterKeywords"];
	NSArray *keywordsList = nil;

	if (filterKeywords.length > 0) {
		keywordsList = [filterKeywords componentsSeparatedByString:@","];
	}

    // 获取需要过滤的用户列表（兼容大小写键名）
    NSString *filterUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"] ?: [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterUsers"];

	// 检查是否需要过滤特定用户
	if (self.shareRecExtra && filterUsers.length > 0 && self.author) {
		NSArray *usersList = [filterUsers componentsSeparatedByString:@","];
		NSString *currentShortID = self.author.shortID;
		NSString *currentNickname = self.author.nickname;

		if (currentShortID.length > 0) {
			for (NSString *userInfo in usersList) {
				// 解析"昵称-id"格式
				NSArray *components = [userInfo componentsSeparatedByString:@"-"];
				if (components.count >= 2) {
					NSString *userId = [components lastObject];
					NSString *userNickname = [[components subarrayWithRange:NSMakeRange(0, components.count - 1)] componentsJoinedByString:@"-"];

					if ([userId isEqualToString:currentShortID]) {
						shouldFilterUser = YES;
						break;
					}
				}
			}
		}
	}

	NSInteger filterLowLikesThreshold = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYfilterLowLikes"];

	// 只有当shareRecExtra不为空时才过滤点赞量低的视频和关键词
	if (self.shareRecExtra && ![self.shareRecExtra isEqual:@""]) {
		// 过滤低点赞量视频
		if (filterLowLikesThreshold > 0) {
			AWESearchAwemeExtraModel *searchExtraModel = [self searchExtraModel];
			if (!searchExtraModel) {
				AWEAwemeStatisticsModel *statistics = self.statistics;
				if (statistics && statistics.diggCount) {
					shouldFilterLowLikes = statistics.diggCount.integerValue < filterLowLikesThreshold;
				}
			}
		}

		// 过滤包含特定关键词的视频
		if (keywordsList.count > 0) {
			// 检查视频标题
			if (self.itemTitle.length > 0) {
				for (NSString *keyword in keywordsList) {
					NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if (trimmedKeyword.length > 0 && [self.itemTitle containsString:trimmedKeyword]) {
						shouldFilterKeywords = YES;
						break;
					}
				}
			}

			// 如果标题中没有关键词，检查标签(textExtras)
			if (!shouldFilterKeywords && self.textExtras.count > 0) {
				for (AWEAwemeTextExtraModel *textExtra in self.textExtras) {
					NSString *hashtagName = textExtra.hashtagName;
					if (hashtagName.length > 0) {
						for (NSString *keyword in keywordsList) {
							NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
							if (trimmedKeyword.length > 0 && [hashtagName containsString:trimmedKeyword]) {
								shouldFilterKeywords = YES;
								break;
							}
						}
						if (shouldFilterKeywords)
							break;
					}
				}
			}
		}

        // 过滤视频发布时间（兼容大小写键名）
        long long currentTimestamp = (long long)[[NSDate date] timeIntervalSince1970];
        NSNumber *daysNumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfiltertimelimit"] ?: [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterTimeLimit"];
        NSInteger daysThreshold = [daysNumber respondsToSelector:@selector(integerValue)] ? [daysNumber integerValue] : 0;
		if (daysThreshold > 0) {
			NSTimeInterval videoTimestamp = [self.createTime doubleValue];
			if (videoTimestamp > 0) {
				NSTimeInterval threshold = daysThreshold * 86400.0;
				NSTimeInterval current = (NSTimeInterval)currentTimestamp;
				NSTimeInterval timeDifference = current - videoTimestamp;
				shouldFilterTime = (timeDifference > threshold);
			}
		}
	}

	// 检查是否为HDR视频
	if (filterHDR && self.video && self.video.bitrateModels) {
		for (id bitrateModel in self.video.bitrateModels) {
			NSNumber *hdrType = [bitrateModel valueForKey:@"hdrType"];
			NSNumber *hdrBit = [bitrateModel valueForKey:@"hdrBit"];
			// 如果hdrType=1且hdrBit=10，则视为HDR视频
			if (hdrType && [hdrType integerValue] == 1 && hdrBit && [hdrBit integerValue] == 10) {
				shouldFilterHDR = YES;
				break;
			}
		}
	}

	// 过滤包含指定拍同款（道具）的视频：读取 DYYYFilterProp，匹配 propName
	NSString *filterProp = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterProp"];
	if (filterProp.length > 0) {
		NSArray *propKeywordsList = [filterProp componentsSeparatedByString:@","];
		if (propKeywordsList.count > 0) {
			id propGuideV2 = [self valueForKey:@"propGuideV2"]; // 运行时访问
			NSString *propName = nil;
			@try {
				propName = [propGuideV2 valueForKey:@"propName"];
			} @catch (__unused NSException *e) {}
			if (propName.length > 0) {
				for (NSString *propKeyword in propKeywordsList) {
					NSString *trimmedKeyword = [propKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if (trimmedKeyword.length > 0 && [propName containsString:trimmedKeyword]) {
						shouldFilterProp = YES;
						break;
					}
				}
			}
		}
	}

	// 过滤全部直播：当 videoFeedTag == "直播中" 时触发
	if (skipAllLive) {
		NSString *videoFeedTag = nil;
		@try {
			videoFeedTag = [self valueForKey:@"videoFeedTag"];
		} @catch (__unused NSException *e) {}
		if ([videoFeedTag isKindOfClass:[NSString class]] && [videoFeedTag isEqualToString:@"直播中"]) {
			shouldFilterAllLive = YES;
		}
	}

	return (shouldFilterAds || shouldFilterRec || shouldFilterAllLive || shouldFilterHotSpot || shouldFilterLowLikes || shouldFilterKeywords || shouldFilterTime || shouldFilterUser || shouldFilterHDR || shouldFilterProp) ? nil : orig;
}

- (id)init {
	id orig = %orig;

	BOOL noAds = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"];
	BOOL skipLive = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"];
	BOOL skipHotSpot = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipHotSpot"];
    BOOL skipAllLive = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSkipAllLive"];
	BOOL filterHDR = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYFilterFeedHDR"];

	BOOL shouldFilterAds = noAds && (self.hotSpotLynxCardModel || self.isAds);
	BOOL shouldFilterRec = skipLive && (self.liveReason != nil);
	BOOL shouldFilterHotSpot = skipHotSpot && self.hotSpotLynxCardModel;
    BOOL shouldFilterAllLive = NO;

	BOOL shouldFilterLowLikes = NO;
	BOOL shouldFilterKeywords = NO;

	BOOL shouldFilterTime = NO;
	BOOL shouldFilterHDR = NO;
    BOOL shouldFilterProp = NO;

	// 获取用户设置的需要过滤的关键词
	NSString *filterKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"];
	NSArray *keywordsList = nil;

	if (filterKeywords.length > 0) {
		keywordsList = [filterKeywords componentsSeparatedByString:@","];
	}

	NSInteger filterLowLikesThreshold = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYfilterLowLikes"];

	// 只有当shareRecExtra不为空时才过滤
	if (self.shareRecExtra && ![self.shareRecExtra isEqual:@""]) {
		// 过滤低点赞量视频
		if (filterLowLikesThreshold > 0) {
			AWESearchAwemeExtraModel *searchExtraModel = [self searchExtraModel];
			if (!searchExtraModel) {
				AWEAwemeStatisticsModel *statistics = self.statistics;
				if (statistics && statistics.diggCount) {
					shouldFilterLowLikes = statistics.diggCount.integerValue < filterLowLikesThreshold;
				}
			}
		}

		// 过滤包含特定关键词的视频
		if (keywordsList.count > 0) {
			// 检查视频标题
			if (self.itemTitle.length > 0) {
				for (NSString *keyword in keywordsList) {
					NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if (trimmedKeyword.length > 0 && [self.itemTitle containsString:trimmedKeyword]) {
						shouldFilterKeywords = YES;
						break;
					}
				}
			}

			// 如果标题中没有关键词，检查标签(textExtras)
			if (!shouldFilterKeywords && self.textExtras.count > 0) {
				for (AWEAwemeTextExtraModel *textExtra in self.textExtras) {
					NSString *hashtagName = textExtra.hashtagName;
					if (hashtagName.length > 0) {
						for (NSString *keyword in keywordsList) {
							NSString *trimmedKeyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
							if (trimmedKeyword.length > 0 && [hashtagName containsString:trimmedKeyword]) {
								shouldFilterKeywords = YES;
								break;
							}
						}
						if (shouldFilterKeywords)
							break;
					}
				}
			}
		}

        // 过滤视频发布时间（兼容大小写键名）
        long long currentTimestamp = (long long)[[NSDate date] timeIntervalSince1970];
        NSNumber *daysNumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfiltertimelimit"] ?: [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterTimeLimit"];
        NSInteger daysThreshold = [daysNumber respondsToSelector:@selector(integerValue)] ? [daysNumber integerValue] : 0;
		if (daysThreshold > 0) {
			NSTimeInterval videoTimestamp = [self.createTime doubleValue];
			if (videoTimestamp > 0) {
				NSTimeInterval threshold = daysThreshold * 86400.0;
				NSTimeInterval current = (NSTimeInterval)currentTimestamp;
				NSTimeInterval timeDifference = current - videoTimestamp;
				shouldFilterTime = (timeDifference > threshold);
			}
		}
	}

	// 检查是否为HDR视频
	if (filterHDR && self.video && self.video.bitrateModels) {
		for (id bitrateModel in self.video.bitrateModels) {
			NSNumber *hdrType = [bitrateModel valueForKey:@"hdrType"];
			NSNumber *hdrBit = [bitrateModel valueForKey:@"hdrBit"];
			// 如果hdrType=1且hdrBit=10，则视为HDR视频
			if (hdrType && [hdrType integerValue] == 1 && hdrBit && [hdrBit integerValue] == 10) {
				shouldFilterHDR = YES;
				break;
			}
		}
	}

    // 过滤包含指定拍同款（道具）的视频：读取 DYYYFilterProp，匹配 propName
    NSString *filterProp = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFilterProp"];
    if (filterProp.length > 0) {
        NSArray *propKeywordsList = [filterProp componentsSeparatedByString:@","];
        if (propKeywordsList.count > 0) {
            id propGuideV2 = [self valueForKey:@"propGuideV2"]; // 运行时访问
            NSString *propName = nil;
            @try {
                propName = [propGuideV2 valueForKey:@"propName"];
            } @catch (__unused NSException *e) {}
            if (propName.length > 0) {
                for (NSString *propKeyword in propKeywordsList) {
                    NSString *trimmedKeyword = [propKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (trimmedKeyword.length > 0 && [propName containsString:trimmedKeyword]) {
                        shouldFilterProp = YES;
                        break;
                    }
                }
            }
        }
    }

    // 过滤全部直播：当 videoFeedTag == "直播中" 时触发
    if (skipAllLive) {
        NSString *videoFeedTag = nil;
        @try {
            videoFeedTag = [self valueForKey:@"videoFeedTag"];
        } @catch (__unused NSException *e) {}
        if ([videoFeedTag isKindOfClass:[NSString class]] && [videoFeedTag isEqualToString:@"直播中"]) {
            shouldFilterAllLive = YES;
        }
    }

    return (shouldFilterAds || shouldFilterRec || shouldFilterAllLive || shouldFilterHotSpot || shouldFilterLowLikes || shouldFilterKeywords || shouldFilterTime || shouldFilterHDR || shouldFilterProp) ? nil : orig;
}

- (bool)preventDownload {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"]) {
		return NO;
	} else {
		return %orig;
	}
}

- (void)setAdLinkType:(long long)arg1 {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"]) {
		arg1 = 0;
	} else {
	}

	%orig;
}

%end

// 拦截开屏广告
%hook BDASplashControllerView
+ (id)alloc {
	BOOL noAds = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"];
	if (noAds) {
		return nil;
	}
	return %orig;
}
%end


// 去除启动视频广告
%hook AWEAwesomeSplashFeedCellOldAccessoryView

- (id)ddExtraView {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"]) {
		return NULL;
	}

	return %orig;
}

%end

// 去广告功能
%hook AwemeAdManager
- (void)showAd {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"])
		return;
	%orig;
}
%end
