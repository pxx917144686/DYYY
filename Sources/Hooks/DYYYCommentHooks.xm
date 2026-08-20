#import "DYYYHookShared.h"

%hook AWECommentInputBackgroundView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideComment")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWEDanmakuContentLabel
- (void)setTextColor:(UIColor *)textColor {
	if (DYYYCachedBool(@"DYYYEnableDanmuColor")) {
		NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];

		if ([danmuColor.lowercaseString isEqualToString:@"random"] || [danmuColor.lowercaseString isEqualToString:@"#random"]) {
			textColor = [UIColor colorWithRed:(arc4random_uniform(256)) / 255.0
						    green:(arc4random_uniform(256)) / 255.0
						     blue:(arc4random_uniform(256)) / 255.0
						    alpha:CGColorGetAlpha(textColor.CGColor)];
			self.layer.shadowOffset = CGSizeZero;
			self.layer.shadowOpacity = 0.0;
		} else if ([danmuColor hasPrefix:@"#"]) {
			textColor = [self colorFromHexString:danmuColor baseColor:textColor];
			self.layer.shadowOffset = CGSizeZero;
			self.layer.shadowOpacity = 0.0;
		} else {
			textColor = [self colorFromHexString:@"#FFFFFF" baseColor:textColor];
		}
	}

	%orig(textColor);
}

%new
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor {
	if ([hexString hasPrefix:@"#"]) {
		hexString = [hexString substringFromIndex:1];
	}
	if ([hexString length] != 6) {
		return [baseColor colorWithAlphaComponent:1];
	}
	unsigned int red, green, blue;
	[[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
	[[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
	[[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];

	if (red < 128 && green < 128 && blue < 128) {
		return [UIColor whiteColor];
	}

	return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:CGColorGetAlpha(baseColor.CGColor)];
}
%end

%hook AWEDanmakuItemTextInfo
- (void)setDanmakuTextColor:(id)arg1 {

	if (DYYYCachedBool(@"DYYYEnableDanmuColor")) {
		NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];

		if ([danmuColor.lowercaseString isEqualToString:@"random"] || [danmuColor.lowercaseString isEqualToString:@"#random"]) {
			arg1 = [UIColor colorWithRed:(arc4random_uniform(256)) / 255.0 green:(arc4random_uniform(256)) / 255.0 blue:(arc4random_uniform(256)) / 255.0 alpha:1.0];
		} else if ([danmuColor hasPrefix:@"#"]) {
			arg1 = [self colorFromHexStringForTextInfo:danmuColor];
		} else {
			arg1 = [self colorFromHexStringForTextInfo:@"#FFFFFF"];
		}
	}

	%orig(arg1);
}

%new
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString {
	if ([hexString hasPrefix:@"#"]) {
		hexString = [hexString substringFromIndex:1];
	}
	if ([hexString length] != 6) {
		return [UIColor whiteColor];
	}
	unsigned int red, green, blue;
	[[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
	[[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
	[[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];

	if (red < 128 && green < 128 && blue < 128) {
		return [UIColor whiteColor];
	}

	return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:1.0];
}
%end

%hook AWEPlayDanmakuInputContainView

- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideDanmuButton")) {
		self.hidden = YES;
	}
}

%end

%hook AWEShowPlayletCommentHeaderView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}
}

%end

%hook AWECommentSearchAnchorView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}
}

%end

%hook AWECommentGuideLunaAnchorView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		[self setHidden:YES];
	}

	if (DYYYCachedBool(@"DYYYMusicCopyText")) {
		UILabel *label = nil;
		if ([self respondsToSelector:@selector(preTitleLabel)]) {
			label = [self valueForKey:@"preTitleLabel"];
		}
		if (label && [label isKindOfClass:[UILabel class]]) {
			label.text = @"";
		}
	}
}

- (void)p_didClickSong {
	if (DYYYCachedBool(@"DYYYMusicCopyText")) {
		// 通过 KVC 拿到内部的 songButton
		UIButton *btn = nil;
		if ([self respondsToSelector:@selector(songButton)]) {
			btn = (UIButton *)[self valueForKey:@"songButton"];
		}

		// 获取歌曲名并复制到剪贴板
		if (btn && [btn isKindOfClass:[UIButton class]]) {
			NSString *song = btn.currentTitle;
			if (song.length) {
				[UIPasteboard generalPasteboard].string = song;
				[DYYYToast showSuccessToastWithMessage:@"歌曲名已复制"];
			}
		}
	} else {
		%orig;
	}
}

%end

%hook AWEFeedStickerContainerView

- (BOOL)isHidden {
	BOOL origHidden = %orig;
	BOOL hideRecommend = DYYYCachedBool(@"DYYYHideChallengeStickers");
	return origHidden || hideRecommend;
}

- (void)setHidden:(BOOL)hidden {
	BOOL forceHide = DYYYCachedBool(@"DYYYHideChallengeStickers");
	%orig(forceHide ? YES : hidden);
}

%end

%hook ACCStickerContainerView
- (void)layoutSubviews {
	// 类型安全检查 + 隐藏逻辑
	if (DYYYCachedBool(@"DYYYHideInteractionSearch")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES; // 隐藏更彻底
		return;
	}
	%orig;
}
%end

%hook AWECommentMiniEmoticonPanelView

- (void)layoutSubviews {
    %orig;
    if (DYYYCachedBool(@"DYYYisDarkKeyBoard")) {
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UICollectionView class]]) {
                subview.backgroundColor = [UIColor colorWithRed:115/255.0 green:115/255.0 blue:115/255.0 alpha:1.0];
            }
        }
    }
}
%end

%hook AWECommentPublishGuidanceView

- (void)layoutSubviews {
    %orig;
    if (DYYYCachedBool(@"DYYYisDarkKeyBoard")) {
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UICollectionView class]]) {
                subview.backgroundColor = [UIColor colorWithRed:115/255.0 green:115/255.0 blue:115/255.0 alpha:1.0];
            }
        }
    }
}
%end

%hook AWEIMFeedVideoQuickReplayInputViewController

- (void)viewDidLayoutSubviews {
    %orig;

    if (DYYYCachedBool(@"DYYYHideReply")) {
        [self.view removeFromSuperview];
    }
}

%end

%hook ACCGestureResponsibleStickerView
- (void)layoutSubviews {
	%orig;

	if (DYYYCachedBool(@"DYYYHideChallengeStickers")) {
		[self removeFromSuperview];
		return;
	}
}
%end

%hook AWETextViewInternal

- (void)drawRect:(CGRect)rect {
    %orig(rect);
    if (DYYYCachedBool(@"DYYYisDarkKeyBoard")) {
        
        self.textColor = [UIColor whiteColor];
    }
}

- (double)lineSpacing {
    double r = %orig;
    if (DYYYCachedBool(@"DYYYisDarkKeyBoard")) {
        
        self.textColor = [UIColor whiteColor];
    }
    return r;
}

%end

%hook AWEIMInputActionBarInteractor

- (void)p_setupUI {
	if (DYYYCachedBool(@"DYYYHideGroupInputActionBar")) {
		if ([self respondsToSelector:@selector(removeFromSuperview)]) {
			[self removeFromSuperview];
		}
		self.hidden = YES;
		return;
	}
	%orig;
}
%end

%hook AWECommentMediaDownloadConfigLivePhoto

bool commentLivePhotoNotWaterMark = DYYYCachedBool(@"DYYYCommentLivePhotoNotWaterMark");

- (bool)needClientWaterMark {
	return commentLivePhotoNotWaterMark ? 0 : %orig;
}

- (bool)needClientEndWaterMark {
	return commentLivePhotoNotWaterMark ? 0 : %orig;
}

- (id)watermarkConfig {
	return commentLivePhotoNotWaterMark ? nil : %orig;
}

%end

%hook AWECommentImageModel
-(id)downloadUrl{
    if (DYYYCachedBool(@"DYYYCommentNotWaterMark")) {
        return self.originUrl;
    }
    return %orig;
}
%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement

- (void)elementTapped {
	if (DYYYCachedBool(@"DYYYCommentCopyText")) {
		AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
		AWECommentModel *selectdComment = [commentPageContext selectdComment];
		if (!selectdComment) {
			AWECommentLongPressPanelParam *params = [commentPageContext params];
			selectdComment = [params selectdComment];
		}
		NSString *descText = [selectdComment content];
		[[UIPasteboard generalPasteboard] setString:descText];
		[DYYYToast showSuccessToastWithMessage:@"评论已复制"];
	}
}
%end

%hook AWEIMEmoticonPreviewV2

// 添加保存按钮
- (void)layoutSubviews {
	%orig;
	static char kHasSaveButtonKey;
	BOOL DYYYForceDownloadPreviewEmotion = DYYYCachedBool(@"DYYYForceDownloadPreviewEmotion");
	if (DYYYForceDownloadPreviewEmotion) {
		if (!objc_getAssociatedObject(self, &kHasSaveButtonKey)) {
			UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
			UIImage *downloadIcon = [UIImage systemImageNamed:@"arrow.down.circle"];
			[saveButton setImage:downloadIcon forState:UIControlStateNormal];
			[saveButton setTintColor:[UIColor whiteColor]];
			saveButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.9 alpha:0.5];

			saveButton.layer.shadowColor = [UIColor blackColor].CGColor;
			saveButton.layer.shadowOffset = CGSizeMake(0, 2);
			saveButton.layer.shadowOpacity = 0.3;
			saveButton.layer.shadowRadius = 3;

			saveButton.translatesAutoresizingMaskIntoConstraints = NO;
			[self addSubview:saveButton];
			CGFloat buttonSize = 24.0;
			saveButton.layer.cornerRadius = buttonSize / 2;

			[NSLayoutConstraint activateConstraints:@[
				[saveButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15], [saveButton.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-10],
				[saveButton.widthAnchor constraintEqualToConstant:buttonSize], [saveButton.heightAnchor constraintEqualToConstant:buttonSize]
			]];

			saveButton.userInteractionEnabled = YES;
			[saveButton addTarget:self action:@selector(dyyy_saveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
			objc_setAssociatedObject(self, &kHasSaveButtonKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	}
}

%new
- (void)dyyy_saveButtonTapped:(UIButton *)sender {
	// 获取表情包URL
	AWEIMEmoticonModel *emoticonModel = self.model;
	if (!emoticonModel) {
		[DYYYManager showToast:@"无法获取表情包信息"];
		return;
	}

	NSString *urlString = nil;

	// 尝试动态URL
	if ([emoticonModel valueForKey:@"animate_url"]) {
		urlString = [emoticonModel valueForKey:@"animate_url"];
	}
	// 如果没有动态URL，则使用静态URL
	else if ([emoticonModel valueForKey:@"static_url"]) {
		urlString = [emoticonModel valueForKey:@"static_url"];
	}
	// 使用animateURLModel获取URL
	else if ([emoticonModel valueForKey:@"animateURLModel"]) {
		AWEURLModel *urlModel = [emoticonModel valueForKey:@"animateURLModel"];
		if (urlModel.originURLList.count > 0) {
			urlString = urlModel.originURLList[0];
		}
	}

	if (!urlString) {
		[DYYYManager showToast:@"无法获取表情包链接"];
		return;
	}

	NSURL *url = [NSURL URLWithString:urlString];
	[DYYYManager downloadMedia:url
			 mediaType:MediaTypeHeic
			completion:^(BOOL success){
			}];
}

%end
