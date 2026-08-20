#import "DYYYHookShared.h"

%hook AWEFeedTabJumpGuideView

- (void)layoutSubviews {
	%orig;
	[self removeFromSuperview];
}

%end

%hook AWEMarkView

- (void)layoutSubviews {
	%orig;

	UIViewController *vc = [DYYYUtils findViewControllerFromView:self];

	if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
		if (self.markLabel) {
			self.markLabel.textColor = [UIColor whiteColor];
		}
	}

	if (DYYYCachedBool(@"DYYYHideLocation")) {
		self.hidden = YES;
		return;
	}
}

%end

%hook BDASplashControllerView
+ (id)alloc {
	BOOL noAds = DYYYCachedBool(@"DYYYNoAds");
	if (noAds) {
		return nil;
	}
	return %orig;
}
%end

%hook AWELandscapeFeedEntryView

- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYisHiddenEntry")) {
		[self removeFromSuperview];
		return;
	}

	if (self.superview) {
		[self.superview bringSubviewToFront:self];
	}
}

%end

%hook AFDCancelMuteAwemeView
- (void)layoutSubviews {
	%orig;

	UIView *superview = self.superview;

	if ([superview isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) {
		if (DYYYCachedBool(@"DYYYHideCancelMute")) {
			self.hidden = YES;
		}
	}
}
%end

%hook AWEECommerceEntryView

- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideHisShop")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

%hook AWEPOIEntryAnchorView

- (void)p_addViews {
	// 检查用户偏好设置
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		// 直接跳过视图添加流程
		return;
	}
	// 执行原始方法
	%orig;
}

- (void)setIconUrls:(id)arg1 defaultImage:(id)arg2 {
	// 根据需求选择是否拦截资源加载
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		%orig(nil, nil);
		return;
	}
	// 正常传递参数
	%orig(arg1, arg2);
}

- (void)setContentSize:(CGSize)arg1 {
	// 可选：动态调整尺寸计算逻辑
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		// 计算不包含评论视图的尺寸
		CGSize newSize = CGSizeMake(arg1.width, arg1.height - 44); // 示例减法
		%orig(newSize);
		return;
	}
	// 保持原有尺寸计算
	%orig(arg1);
}

%end

%hook AWETemplateTagsCommonView

- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideTemplateTags")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

%hook AWEPostWorkViewController
- (BOOL)isDouGuideTipViewShow {
	BOOL r = %orig;
	NSLog(@"Original value: %@", @(r));
	if (DYYYCachedBool(@"DYYYHideChallengeStickers")) {
		NSLog(@"Force return YES");
		return YES;
	}
	return r;
}
%end

%hook AFDSkylightCellBubble
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYisHiddenAvatarBubble")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEIMMessageTabOptPushBannerView

- (instancetype)initWithFrame:(CGRect)frame {
	if (DYYYCachedBool(@"DYYYHidePushBanner")) {
		return %orig(CGRectMake(frame.origin.x, frame.origin.y, 0, 0));
	}
	return %orig;
}

%end

%hook AWEFeedAnchorContainerView

- (BOOL)isHidden {
	BOOL origHidden = %orig;
	BOOL hideSamestyle = DYYYCachedBool(@"DYYYHideFeedAnchorContainer");
	return origHidden || hideSamestyle;
}

- (void)setHidden:(BOOL)hidden {
	BOOL forceHide = DYYYCachedBool(@"DYYYHideFeedAnchorContainer");
	%orig(forceHide ? YES : hidden);
}

%end

%hook AWEFeedUnfollowFamiliarFollowAndDislikeView
- (void)showUnfollowFamiliarView {
	if (DYYYCachedBool(@"DYYYHideFamiliar")) {
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEFamiliarNavView
- (void)layoutSubviews {

	if (DYYYCachedBool(@"DYYYHideFamiliar")) {
		self.hidden = YES;
	}

	%orig;
}
%end

%hook AWEAntiAddictedNoticeBarView
- (void)layoutSubviews {
	%orig;

	// 获取 tipsLabel 属性
	UILabel *tipsLabel = [self valueForKey:@"tipsLabel"];

	if (tipsLabel && [tipsLabel isKindOfClass:%c(UILabel)]) {
		NSString *labelText = tipsLabel.text;

		if (labelText) {
			// 明确判断是合集还是作者声明
			if ([labelText containsString:@"合集"]) {
				// 如果是合集，只检查合集的开关
				if (DYYYCachedBool(@"DYYYHideTemplateVideo")) {
					[self removeFromSuperview];
				} else if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
					self.backgroundColor = [UIColor clearColor];
				}
			} else {
				// 如果不是合集（即作者声明），只检查声明的开关
				if (DYYYCachedBool(@"DYYYHideAntiAddictedNotice")) {
					[self removeFromSuperview];
				}
			}
		}
	}
}
- (void)setBackgroundColor:(UIColor *)backgroundColor {
	// 禁用背景色设置
	if (DYYYCachedBool(@"DYYYHideGradient")) {
		%orig(UIColor.clearColor);
	} else {
		%orig(backgroundColor);
	}
}
%end

%hook AWEFeedRelatedSearchTipView
- (void)layoutSubviews {
	if (DYYYCachedBool(@"DYYYHideBottomRelated")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEAwemeModel

- (void)live_callInitWithDictyCategoryMethod:(id)arg1 {
    if (self.currentAweme && [self.currentAweme isLive] && DYYYCachedBool(@"DYYYisSkipLive")) {
        return;
    }
    %orig;
}

+ (id)liveStreamURLJSONTransformer {
    return DYYYCachedBool(@"DYYYisSkipLive") ? nil : %orig;
}

+ (id)relatedLiveJSONTransformer {
    return DYYYCachedBool(@"DYYYisSkipLive") ? nil : %orig;
}

+ (id)rawModelFromLiveRoomModel:(id)arg1 {
    return DYYYCachedBool(@"DYYYisSkipLive") ? nil : %orig;
}

+ (id)aweLiveRoom_subModelPropertyKey {
    return DYYYCachedBool(@"DYYYisSkipLive") ? nil : %orig;
}

%new
- (BOOL)contentFilter {
	BOOL noAds = DYYYCachedBool(@"DYYYNoAds");
	BOOL skipLive = DYYYCachedBool(@"DYYYisSkipLive");
	BOOL skipHotSpot = DYYYCachedBool(@"DYYYisSkipHotSpot");
	BOOL skipPhoto = DYYYCachedBool(@"DYYYSkipPhoto");
	BOOL skipPhotoText = DYYYCachedBool(@"DYYYSkipPhotoText");
	BOOL skipMusic = DYYYCachedBool(@"DYYYSkipMusic");
	BOOL skipAIInteraction = DYYYCachedBool(@"DYYYSkipAIInteraction");

	// P2-4：广告检测改用 DYYYUtils 统一判定，覆盖 checkIsAd/isHardAd/isAds 等明确广告标记
	BOOL shouldFilterAds = noAds && [DYYYUtils isAdvertisementAwemeModel:self];

	// P2-5：直播过滤改用 cellRoom != nil 或 videoFeedTag 判定，避免误杀带 liveReason 占位的非直播作品
	BOOL isLive = (self.cellRoom != nil) || [self.videoFeedTag isEqualToString:@"直播中"];
	BOOL shouldFilterRec = skipLive && isLive;

	BOOL shouldFilterHotSpot = skipHotSpot && self.hotSpotLynxCardModel;

	BOOL isRecommendFeed = [self.referString isEqualToString:@"homepage_hot"];
	BOOL shouldFilterPhoto = skipPhoto && (self.awemeType == 68) && isRecommendFeed;
	BOOL shouldFilterPhotoText = skipPhotoText && self.isNewTextMode && isRecommendFeed;
	BOOL shouldFilterMusic = skipMusic && (self.musicCard != nil) && isRecommendFeed;
	BOOL shouldFilterAIInteraction = skipAIInteraction && (self.awemeType == 162) && isRecommendFeed;

	BOOL shouldFilterLowLikes = NO;
	BOOL shouldFilterKeywords = NO;
	BOOL shouldFilterTime = NO;
	BOOL shouldFilterProp = NO;
	BOOL shouldFilterUser = NO;

	// 获取用户设置的需要过滤的关键词（预编译缓存）
	NSArray *keywordsList = DYYYCachedKeywordList(@"DYYYfilterKeywords");

	// 过滤包含指定拍同款的视频（预编译缓存）
	NSArray *propKeywordsList = DYYYCachedKeywordList(@"DYYYFilterProp");

	// 获取需要过滤的用户列表
	NSString *filterUsers = DYYYCachedString(@"DYYYFilterUsers");
	NSArray *usersList = DYYYCachedKeywordList(@"DYYYFilterUsers");

	NSInteger filterLowLikesThreshold = DYYYCachedInteger(@"DYYYfilterLowLikes");

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
					if ([self.itemTitle containsString:keyword]) {
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
							if ([hashtagName containsString:keyword]) {
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

		// 过滤视频发布时间
		long long currentTimestamp = (long long)[[NSDate date] timeIntervalSince1970];
		NSInteger daysThreshold = DYYYCachedInteger(@"DYYYfiltertimelimit");
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

	// 按用户 ID/昵称过滤（解析"昵称-id"格式）
	if (isRecommendFeed && filterUsers.length > 0 && self.author) {
		NSString *currentShortID = self.author.shortID;

		if (currentShortID.length > 0) {
			for (NSString *userInfo in usersList) {
				NSArray *components = [userInfo componentsSeparatedByString:@"-"];
				if (components.count >= 2) {
					NSString *userId = [components lastObject];
					if ([userId isEqualToString:currentShortID]) {
						shouldFilterUser = YES;
						break;
					}
				}
			}
		}
	}

	// 仅在推荐页过滤拍同款道具
	if (isRecommendFeed && propKeywordsList.count > 0 && self.propGuideV2) {
		NSString *propName = self.propGuideV2.propName;
		if (propName.length > 0) {
			for (NSString *propKeyword in propKeywordsList) {
				if ([propName containsString:propKeyword]) {
					shouldFilterProp = YES;
					break;
				}
			}
		}
	}

	return shouldFilterAds || shouldFilterRec || shouldFilterHotSpot || shouldFilterLowLikes || shouldFilterKeywords || shouldFilterTime ||
	       shouldFilterPhoto || shouldFilterPhotoText || shouldFilterMusic || shouldFilterAIInteraction || shouldFilterProp || shouldFilterUser;
}

- (id)initWithDictionary:(id)arg1 error:(id *)arg2 {
	id orig = %orig;
	return [self contentFilter] ? nil : orig;
}

- (id)init {
	id orig = %orig;
	return [self contentFilter] ? nil : orig;
}

- (bool)preventDownload {
	if (DYYYCachedBool(@"DYYYNoAds")) {
		return NO;
	} else {
		return %orig;
	}
}

- (void)setAdLinkType:(long long)arg1 {
	if (DYYYCachedBool(@"DYYYNoAds")) {
		arg1 = 0;
	} else {
	}

	%orig;
}


%end

%hook AWEMixVideoDetailPlayListDataController

- (void)setDataSource:(id)dataSource {
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    %orig(filtered);
}

%end

%hook AWEHotListDataController

- (id)transferAwemeListIfNeededWithArray:(id)arg1 isInitFetch:(BOOL)arg2 {
    NSArray *orig = %orig;
    if (![orig isKindOfClass:[NSArray class]] || orig.count == 0) {
        return orig;
    }

    // --- 配置读取 ---
    NSInteger daysThreshold = DYYYGetInteger(@"DYYYfiltertimelimit");
    BOOL skipLive = DYYYGetBool(@"DYYYisSkipLive");
    NSInteger minLikesThreshold = DYYYGetInteger(@"DYYYfilterLowLikes");
    BOOL skipPhotoText = DYYYGetBool(@"DYYYSkipPhotoText");
    BOOL skipPhoto = DYYYGetBool(@"DYYYSkipPhoto");
    BOOL skipMusic = DYYYGetBool(@"DYYYSkipMusic");
    BOOL noAds = DYYYGetBool(@"DYYYNoAds");

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval thresholdInSeconds = MAX(daysThreshold, 0) * 86400.0;

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:orig.count];

    for (id obj in orig) {
        if (![obj isKindOfClass:%c(AWEAwemeModel)]) {
            [filtered addObject:obj];
            continue;
        }

        AWEAwemeModel *m = (AWEAwemeModel *)obj;

        // 1. 广告过滤：合集、搜索内流、分页追加等旁路也会进入此共享转换。
        if (noAds && [DYYYUtils isAdvertisementAwemeModel:m]) {
            continue;
        }

        // 2. 直播过滤逻辑 (仅依赖 cellRoom / videoFeedTag)
        if (skipLive &&
            [m respondsToSelector:@selector(cellRoom)] && m.cellRoom != nil) {
            continue;
        }
        if (skipLive &&
            [m respondsToSelector:@selector(videoFeedTag)] &&
            [m.videoFeedTag isEqualToString:@"直播中"]) {
            continue;
        }

        // 2.1 图文模式过滤逻辑（推荐页）
        if (skipPhotoText &&
            [m respondsToSelector:@selector(isNewTextMode)] &&
            m.isNewTextMode &&
            [m respondsToSelector:@selector(referString)] &&
            [m.referString isEqualToString:@"homepage_hot"]) {
            continue;
        }

        // 2.2 图集过滤逻辑（推荐页）
        if (skipPhoto &&
            [m respondsToSelector:@selector(awemeType)] &&
            m.awemeType == 68 &&
            [m respondsToSelector:@selector(referString)] &&
            [m.referString isEqualToString:@"homepage_hot"]) {
            continue;
        }

        // 2.3 音乐过滤逻辑（推荐页）
        if (skipMusic &&
            [m respondsToSelector:@selector(referString)] &&
            [m.referString isEqualToString:@"homepage_hot"] &&
            [m respondsToSelector:@selector(musicCard)] &&
            m.musicCard) {
            continue;
        }

        // 3. 时间限制过滤
        if (daysThreshold > 0 && [m respondsToSelector:@selector(createTime)]) {
            NSTimeInterval vTs = [m.createTime doubleValue];
            if (vTs > 1e12) {
                vTs /= 1000.0; // 毫秒转秒
            }

            if (vTs > 0 && (now - vTs) > thresholdInSeconds) {
                continue;
            }
        }

        // 4. 低赞过滤：字段缺失时放行；能解析到数值时严格按阈值过滤。
        if (minLikesThreshold > 0) {
            AWEAwemeStatisticsModel *statistics = nil;
            if ([m respondsToSelector:@selector(statistics)]) {
                statistics = m.statistics;
            }
            NSNumber *diggCount = statistics.diggCount;
            if (diggCount && diggCount.integerValue < minLikesThreshold) {
                continue;
            }
        }

        [filtered addObject:obj];
    }

    return [filtered copy];
}

%end

%hook TTAdSplashModel

+ (id)alloc {
	if (DYYYGetBool(@"DYYYNoAds")) {
		return nil;  // 直接返回 nil，阻止对象创建
	}
	return %orig;
}

%end

%hook AWEOriginalAdModel
- (instancetype)init {
	BOOL noAds = DYYYGetBool(@"DYYYNoAds");
	if (noAds) {
		return nil;  // 阻止创建，直接返回 nil
	}
	return %orig;
}

- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
	BOOL noAds = DYYYGetBool(@"DYYYNoAds");
	if (noAds) {
		return nil;  // 阻止创建，直接返回 nil
	}
	return %orig;
}
%end

%hook BDXWebView
- (void)layoutSubviews {
	%orig;

	BOOL enabled = DYYYCachedBool(@"DYYYHideGiftPavilion");
	if (!enabled)
		return;

	NSString *title = [self valueForKey:@"title"];

	if ([title containsString:@"任务Banner"] || [title containsString:@"活动Banner"]) {
		[self removeFromSuperview];
	}
}
%end

%hook AWEVideoTypeTagView

- (void)setupUI {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideLiveGIF"])
		%orig;
}
%end

%hook AWEMusicCoverButton

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"音乐详情"]) {
        if (DYYYCachedBool(@"DYYYHideMusicButton")) {
            [self removeFromSuperview];
            return;
        }
    }
}

%end

%hook AWEGradientView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideGradient")) {
		UIView *parent = self.superview;
		if ([parent.accessibilityLabel isEqualToString:@"暂停，按钮"] || [parent.accessibilityLabel isEqualToString:@"播放，按钮"] ||
		    [parent.accessibilityLabel isEqualToString:@"“切换视角，按钮"]) {
			[self removeFromSuperview];
		}
		return;
	}
}
%end

%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideHotSearch")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEHotSpotBlurView
- (void)layoutSubviews {
	%orig;

	// 如果用户启用了隐藏渐变效果的设置，则移除此视图
	if (DYYYCachedBool(@"DYYYHideGradient")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEAdAvatarView
- (void)layoutSubviews {
    %orig;

    // 检查是否需要隐藏头像
    if (DYYYCachedBool(@"DYYYHideAvatarButton")) {
        [self removeFromSuperview];
        return;
    }

    // 应用透明度设置
    NSString *transparencyValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYAvatarViewTransparency"];
    if (transparencyValue && transparencyValue.length > 0) {
        CGFloat alphaValue = [transparencyValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            self.alpha = alphaValue;
        }
    }
}
%end

%hook AWENearbySkyLightCapsuleView
- (void)layoutSubviews {
	if (DYYYCachedBool(@"DYYYHideNearbyCapsuleView")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEFeedChannelManager

- (void)reloadChannelWithChannelModels:(id)arg1 currentChannelIDList:(id)arg2 reloadType:(id)arg3 selectedChannelID:(id)arg4 {
    NSArray *channelModels = arg1;
    NSMutableArray *newChannelModels = [NSMutableArray array];
    NSArray *currentChannelIDList = arg2;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray *newCurrentChannelIDList = [NSMutableArray arrayWithArray:currentChannelIDList];
    
    for (AWEHPTopTabItemModel *tabItemModel in channelModels) {
        NSString *channelID = tabItemModel.channelID;
        
        if ([channelID isEqualToString:@"homepage_hot_container"]) {
            [newChannelModels addObject:tabItemModel];
            continue;
        }
        
        BOOL isHideChannel = NO;
        if ([channelID isEqualToString:@"homepage_follow"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideFollow"];
        } else if ([channelID isEqualToString:@"homepage_mediumvideo"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideMediumVideo"];
        } else if ([channelID isEqualToString:@"homepage_mall"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideMall"];
        } else if ([channelID isEqualToString:@"homepage_nearby"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideNearby"];
        } else if ([channelID isEqualToString:@"homepage_groupon"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideGroupon"];
        } else if ([channelID isEqualToString:@"homepage_tablive"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideTabLive"];
        } else if ([channelID isEqualToString:@"homepage_pad_hot"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHidePadHot"];
        } else if ([channelID isEqualToString:@"homepage_hangout"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideHangout"];
        } else if ([channelID isEqualToString:@"homepage_familiar"]) {
            isHideChannel = [defaults boolForKey:@"DYYYHideFriend"];
        }
        
        if (!isHideChannel) {
            [newChannelModels addObject:tabItemModel];
        } else {
            [newCurrentChannelIDList removeObject:channelID];
        }
    }
    
    %orig(newChannelModels, newCurrentChannelIDList, arg3, arg4);
}

%end

%hook AWEFeedRootViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYCachedBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEFeedRootViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

%hook AWEAwemeDetailTableViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYCachedBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEAwemeDetailTableViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

%hook AWEAwemeHotSpotTableViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYCachedBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		return %orig;
	}
}
%end

%hook AWEFullPageFeedNewContainerViewController
- (BOOL)prefersStatusBarHidden {
	if (DYYYCachedBool(@"DYYYisHideStatusbar")) {
		return YES;
	} else {
		if (class_getInstanceMethod([self class], @selector(prefersStatusBarHidden)) !=
		    class_getInstanceMethod([%c(AWEFullPageFeedNewContainerViewController) class], @selector(prefersStatusBarHidden))) {
			return %orig;
		}
		return NO;
	}
}
%end

%hook AWEIMFansGroupTopDynamicDomainTemplateView
- (void)layoutSubviews {
	if (DYYYCachedBool(@"DYYYHideGroupShop")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEFeedTemplateAnchorView

- (void)layoutSubviews {
	%orig;

	BOOL hideFeedAnchor = DYYYCachedBool(@"DYYYHideFeedAnchorContainer");
	BOOL hideLocation = DYYYCachedBool(@"DYYYHideLocation");

	if (!hideFeedAnchor && !hideLocation)
		return;

	AWECodeGenCommonAnchorBasicInfoModel *anchorInfo = [self valueForKey:@"templateAnchorInfo"];
	if (!anchorInfo || ![anchorInfo respondsToSelector:@selector(name)])
		return;

	NSString *name = [anchorInfo valueForKey:@"name"];
	BOOL isPoi = [name isEqualToString:@"poi_poi"];

	if ((hideFeedAnchor && !isPoi) || (hideLocation && isPoi)) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		}
	}
}

%end

%hook AWEUIAlertView
- (void)show {
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYHideteenmode"])
		%orig;
}
%end

%hook AWETeenModeAlertView
- (BOOL)show {
	if (DYYYCachedBool(@"DYYYHideteenmode")) {
		return NO;
	}
	return %orig;
}
%end

%hook AWETeenModeSimpleAlertView
- (BOOL)show {
	if (DYYYCachedBool(@"DYYYHideteenmode")) {
		return NO;
	}
	return %orig;
}
%end

%hook AWEUserTabListModel

- (NSInteger)profileLandingTab {
	if (DYYYCachedBool(@"DYYYDefaultEnterWorks")) {
		return 0;
	} else {
		return %orig;
	}
}

%end

%hook AWEIMFeedBottomQuickEmojiInputBar

- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideChatCommentBg")) {
		UIView *parentView = self.superview;
		while (parentView) {
			if ([NSStringFromClass([parentView class]) isEqualToString:@"UIView"]) {
				dispatch_async(dispatch_get_main_queue(), ^{
				  parentView.backgroundColor = [UIColor clearColor];
				  parentView.layer.backgroundColor = [UIColor clearColor].CGColor;
				  parentView.opaque = NO;
				});
				break;
			}
			parentView = parentView.superview;
		}
	}
}

%end

%hook AWELuckyCatBannerView
- (id)initWithFrame:(CGRect)frame {
	return nil;
}

- (id)init {
	return nil;
}
%end

%hook DUXPopover
- (void)layoutSubviews {
	%orig;

	if (!DYYYCachedBool(@"DYYYHidePopover")) {
		return;
	}

	id rawContent = nil;
	@try {
		rawContent = [self valueForKey:@"content"];
	} @catch (__unused NSException *e) {
		return;
	}

	NSString *text = [rawContent isKindOfClass:NSString.class] ? (NSString *)rawContent : [rawContent description];

	if ([text containsString:@"上次看到"]) {
		[self removeFromSuperview];
	}
}
%end

%hook AWETemplateCommonView
- (void)layoutSubviews {
	if (DYYYCachedBool(@"DYYYHideCameraLocation")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWETemplatePlayletView

- (void)layoutSubviews {

	if (DYYYCachedBool(@"DYYYHideTemplatePlaylet")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AFDNewFastReplyView

- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHidePrivateMessages")) {
		UIView *parentView = self.superview;
		if (parentView) {
			parentView.hidden = YES;
		} else {
			self.hidden = YES;
		}
	}
}

%end

%hook AWENewHotSpotBottomBarView
- (void)layoutSubviews {
	if (DYYYCachedBool(@"DYYYHideHotspot")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWEAwemeMusicInfoView

- (void)layoutSubviews {
    %orig;

    if (DYYYCachedBool(@"DYYYHideQuqishuiting")) {
        // 找到父视图并隐藏
        UIView *parentView = self.superview;
        if (parentView) {
            parentView.hidden = YES;
        } else {
            self.hidden = YES;
        }
    }
}

%end

%hook AWEFeedPauseRelatedWordComponent

// 拦截更新视图的方法，如果启用了隐藏设置则返回nil
- (id)updateViewWithModel:(id)arg0 {
	if (DYYYCachedBool(@"DYYYHidePauseVideoRelatedWord")) {
		return nil; // 用户选择隐藏暂停关键词，返回nil阻止显示
	}
	return %orig;
}

// 拦截获取暂停内容的方法，控制是否显示暂停时的内容
- (id)pauseContentWithModel:(id)arg0 {
	if (DYYYCachedBool(@"DYYYHidePauseVideoRelatedWord")) {
		return nil; // 用户选择隐藏暂停关键词，返回nil阻止显示
	}
	return %orig;
}

// 拦截获取推荐词的方法，控制是否返回推荐关键词
- (id)recommendsWords {
	if (DYYYCachedBool(@"DYYYHidePauseVideoRelatedWord")) {
		return nil; // 用户选择隐藏暂停关键词，返回nil阻止显示
	}
	return %orig;
}

// 设置UI组件，如果启用了隐藏设置则隐藏相关视图
- (void)setupUI {
	%orig; // 先执行原始方法
	if (DYYYCachedBool(@"DYYYHidePauseVideoRelatedWord")) {
		if ([self respondsToSelector:@selector(relatedView)]) {
			UIView *relatedView = self.relatedView;
			if (relatedView && [relatedView isKindOfClass:[UIView class]]) {
				relatedView.hidden = YES; // 隐藏相关词视图
			}
		}
		
		UIView *relatedView = [self valueForKey:@"relatedView"];
		if (relatedView && [relatedView isKindOfClass:[UIView class]]) {
			relatedView.hidden = YES; // 隐藏相关词视图
		}
	}
}

%end

%hook AWETemplateHotspotView

- (void)layoutSubviews {
    %orig;

    if (DYYYCachedBool(@"DYYYHideHotspot")) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWEUserNameLabel

- (void)layoutSubviews {
	%orig;

	self.transform = CGAffineTransformIdentity;

	// 添加垂直偏移支持
	NSString *verticalOffsetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameVerticalOffset"];
	CGFloat verticalOffset = 0;
	if (verticalOffsetValue.length > 0) {
		verticalOffset = [verticalOffsetValue floatValue];
	}

	UIView *parentView = self.superview;
	UIView *grandParentView = nil;

	if (parentView) {
		grandParentView = parentView.superview;
	}

	// 检查祖父视图是否为 AWEBaseElementView 类型
	if (grandParentView && [grandParentView.superview isKindOfClass:%c(AWEBaseElementView)]) {
		CGRect scaledFrame = grandParentView.frame;
		CGFloat translationX = -scaledFrame.origin.x;

		CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(translationX, verticalOffset);
		grandParentView.transform = translationTransform;
	}
}

%end

%hook AWEFeedVideoButton

- (void)setImage:(id)arg1 {
	static NSCache *iconCache = nil;
	static NSDictionary *iconMapping = nil;
	static NSString *dyyyFolderPath = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		iconCache = [[NSCache alloc] init];
		iconMapping = @{
			@"icon_home_like_after" : @"like_after.png",
			@"icon_home_like_before" : @"like_before.png",
			@"icon_home_comment" : @"comment.png",
			@"icon_home_unfavorite" : @"unfavorite.png",
			@"icon_home_favorite" : @"favorite.png",
			@"iconHomeShareRight" : @"share.png"
		};
		dyyyFolderPath = [DYYYPaths iconsDir];
		// 目录创建移出热路径，仅首次执行一次
		[[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
	});

	NSString *nameString = nil;

	if ([self respondsToSelector:@selector(imageNameString)]) {
		nameString = [self performSelector:@selector(imageNameString)];
	}

	if (!nameString) {
		%orig;
		return;
	}

	NSString *customFileName = nil;
	if ([nameString containsString:@"_comment"]) {
		customFileName = @"comment.png";
	} else if ([nameString containsString:@"_like"]) {
		customFileName = @"like_before.png";
	} else if ([nameString containsString:@"_collect"]) {
		customFileName = @"unfavorite.png";
	} else if ([nameString containsString:@"_share"]) {
		customFileName = @"share.png";
	}

	for (NSString *prefix in iconMapping.allKeys) {
		if ([nameString hasPrefix:prefix]) {
			customFileName = iconMapping[prefix];
			break;
		}
	}

	if (customFileName) {
		// 优先命中内存缓存，避免每次设图都做磁盘 IO + 主线程重采样
		UIImage *cachedImage = [iconCache objectForKey:customFileName];
		if (cachedImage) {
			%orig(cachedImage);
			return;
		}

		NSString *customImagePath = [dyyyFolderPath stringByAppendingPathComponent:customFileName];

		if ([[NSFileManager defaultManager] fileExistsAtPath:customImagePath]) {
			UIImage *customImage = [UIImage imageWithContentsOfFile:customImagePath];
			if (customImage) {
				CGFloat targetWidth = 44.0;
				CGFloat targetHeight = 44.0;
				CGSize originalSize = customImage.size;

				CGFloat scale = MIN(targetWidth / originalSize.width, targetHeight / originalSize.height);
				CGFloat newWidth = originalSize.width * scale;
				CGFloat newHeight = originalSize.height * scale;

				UIGraphicsBeginImageContextWithOptions(CGSizeMake(newWidth, newHeight), NO, 0.0);
				[customImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
				UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
				UIGraphicsEndImageContext();

				if (resizedImage) {
					[iconCache setObject:resizedImage forKey:customFileName];
					%orig(resizedImage);
					return;
				}
			}
		}
	}

	%orig;
}

- (id)touchUpInsideBlock {
	id r = %orig;

	// 只有收藏按钮才显示确认弹窗
	if (DYYYCachedBool(@"DYYYcollectTips") && [self.accessibilityLabel isEqualToString:@"收藏"]) {

		// 复制并强持有原始 block，避免在异步确认期间被释放
		void (^storedBlock)(void) = nil;
		if (r && [r isKindOfClass:NSClassFromString(@"NSBlock")]) {
			storedBlock = [((void (^)(void))r) copy];
		}
		// 使用关联对象绑定到按钮实例，确认后再清理
		objc_setAssociatedObject(self, @selector(touchUpInsideBlock), storedBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		dispatch_async(dispatch_get_main_queue(), ^{
			[DYYYBottomAlertView showAlertWithTitle:@"收藏确认"
						  message:@"是否确认/取消收藏？"
					     cancelAction:nil
					    confirmAction:^{
							void (^blockToCall)(void) = objc_getAssociatedObject(self, @selector(touchUpInsideBlock));
							if (blockToCall) {
								blockToCall();
							}
							// 执行后清理关联，释放强引用
							objc_setAssociatedObject(self, @selector(touchUpInsideBlock), nil, OBJC_ASSOCIATION_ASSIGN);
					    }];
		});

		return nil; // 阻止原始 block 立即执行
	}

	return r;
}

- (void)layoutSubviews {
	%orig;

	NSString *accessibilityLabel = self.accessibilityLabel;

	if ([accessibilityLabel isEqualToString:@"点赞"]) {
		if (DYYYCachedBool(@"DYYYHideLikeButton")) {
			[self removeFromSuperview];
			return;
		}

		// 隐藏点赞数值标签
		if (DYYYCachedBool(@"DYYYHideLikeLabel")) {
			for (UIView *subview in self.subviews) {
				if ([subview isKindOfClass:[UILabel class]]) {
					subview.hidden = YES;
				}
			}
		}
	} else if ([accessibilityLabel isEqualToString:@"评论"]) {
		if (DYYYCachedBool(@"DYYYHideCommentButton")) {
			[self removeFromSuperview];
			return;
		}

		// 隐藏评论数值标签
		if (DYYYCachedBool(@"DYYYHideCommentLabel")) {
			for (UIView *subview in self.subviews) {
				if ([subview isKindOfClass:[UILabel class]]) {
					subview.hidden = YES;
				}
			}
		}
	} else if ([accessibilityLabel isEqualToString:@"分享"]) {
		if (DYYYCachedBool(@"DYYYHideShareButton")) {
			[self removeFromSuperview];
			return;
		}

		// 隐藏分享数值标签
		if (DYYYCachedBool(@"DYYYHideShareLabel")) {
			for (UIView *subview in self.subviews) {
				if ([subview isKindOfClass:[UILabel class]]) {
					subview.hidden = YES;
				}
			}
		}
	} else if ([accessibilityLabel isEqualToString:@"收藏"]) {
		if (DYYYCachedBool(@"DYYYHideCollectButton")) {
			[self removeFromSuperview];
			return;
		}

		// 隐藏收藏数值标签
		if (DYYYCachedBool(@"DYYYHideCollectLabel")) {
			for (UIView *subview in self.subviews) {
				if ([subview isKindOfClass:[UILabel class]]) {
					subview.hidden = YES;
				}
			}
		}
	}
}

%end

%hook AWEAwesomeSplashFeedCellOldAccessoryView

// 在方法入口处添加控制逻辑
- (id)ddExtraView {
	// 检查用户是否启用了无广告模式
	if (DYYYCachedBool(@"DYYYNoAds")) {
		return NULL; // 返回空视图
	}

	// 正常模式调用原始方法
	return %orig;
}

%end

%hook AWEConcernSkylightCapsuleView
- (void)setHidden:(BOOL)hidden {
	if (DYYYCachedBool(@"DYYYHideConcernCapsuleView")) {
		[self removeFromSuperview];
		return;
	}

	%orig(hidden);
}
%end

%hook AWEFeedMultiTabSelectedContainerView

- (void)setHidden:(BOOL)hidden {
	BOOL forceHide = DYYYCachedBool(@"DYYYHidentopbarprompt");

	if (forceHide) {
		%orig(YES);
	} else {
		%orig(hidden);
	}
}

%end

%hook AWEProfileMixItemCollectionViewCell
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHidePostView")) {
		if ([self.accessibilityLabel isEqualToString:@"私密作品"]) {
			[self removeFromSuperview];
		}
	}
}
%end

%hook AWEProfileMixCollectionViewCell
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHidePostView")) {
		self.hidden = YES;
	}
}
%end

%hook AWENearbyFullScreenViewModel

- (void)setShowSkyLight:(id)arg1 {
	if (DYYYCachedBool(@"DYYYHideMenuView")) {
		arg1 = nil;
	}
	%orig(arg1);
}

- (void)setHaveSkyLight:(id)arg1 {
	if (DYYYCachedBool(@"DYYYHideMenuView")) {
		arg1 = nil;
	}
	%orig(arg1);
}

%end

%hook AWEProfileTaskCardStyleListCollectionViewCell
- (BOOL)shouldShowPublishGuide {
	// 检查是否启用了隐藏作品视图的设置
	if (DYYYCachedBool(@"DYYYHidePostView")) {
		return NO;  // 返回NO以隐藏发布引导提示
	}
	return %orig;  // 返回原始实现结果
}
%end

%hook AWEProfileRichEmptyView

- (void)setTitle:(id)title {
	// 如果启用了隐藏作品视图的设置，则跳过设置标题
	if (DYYYCachedBool(@"DYYYHidePostView")) {
		return;  // 直接返回，不设置标题
	}
	%orig(title);  // 调用原始实现设置标题
}

- (void)setDetail:(id)detail {
	// 如果启用了隐藏作品视图的设置，则跳过设置详情文本
	if (DYYYCachedBool(@"DYYYHidePostView")) {
		return;  // 直接返回，不设置详情文本
	}
	%orig(detail);  // 调用原始实现设置详情文本
}
%end

%hook AWECorrelationItemTag

- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideItemTag")) {
		self.frame = CGRectMake(0, 0, 0, 0);
		self.hidden = YES;
	}
}

%end

%hook AWEAwemeDetailContainerPlayControlConfig
- (BOOL)enableUserProfilePostAutoPlay {
    // 检查是否启用自动播放功能
    BOOL enabled = DYYYCachedBool(@"DYYYisEnableAutoPlay");
    if (!enabled) {
        return %orig; // 未启用时保持原来的行为
    }
    return YES; // 启用时强制返回YES
}
%end

%hook AWEFeedIPhoneAutoPlayManager
- (BOOL)isAutoPlayOpen {
    BOOL enabled = DYYYCachedBool(@"DYYYisEnableAutoPlay");
    if (enabled) {
        return YES;
    }
    return %orig;
}

- (BOOL)getFeedIphoneAutoPlayState {
    // 检查是否启用自动播放功能
    BOOL enabled = DYYYCachedBool(@"DYYYisEnableAutoPlay");
    if (!enabled) {
        return %orig; // 未启用时保持原来的行为
    }
    return YES; // 启用时强制返回YES
}

%end

%hook AFDViewedBottomView
- (void)layoutSubviews {
    %orig;

    // 启用全屏模式时将底部视图设为透明
    if (DYYYCachedBool(@"DYYYisEnableFullScreen")) {
        // 将 self 强制转换为 UIView 来访问 backgroundColor 属性
        ((UIView *)self).backgroundColor = [UIColor clearColor];
        
        // 通过 KVC 安全地访问 effectView 属性，转换为 NSObject
        @try {
            UIView *effectView = [(NSObject *)self valueForKey:@"effectView"];
            if (effectView && [effectView isKindOfClass:[UIView class]]) {
                effectView.hidden = YES;
            }
        } @catch (NSException *exception) {
            // 如果没有 effectView 属性，忽略错误
            NSLog(@"AFDViewedBottomView 没有 effectView 属性或访问失败: %@", exception.reason);
        }
    }
}
%end
