#import "DYYYHookShared.h"

%hook LOTAnimationView
- (void)layoutSubviews {
    %orig;

    // 检查是否需要隐藏加号
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLOTAnimationView"]) {
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

%hook UITextInputTraits
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        %orig(UIKeyboardAppearanceDark);
    }else {
        %orig;
    }
}
%end

%hook UILabel

- (void)setText:(NSString *)text {
    if (DYYYCachedBool(@"DYYYisDarkKeyBoard")) {
        if ([text hasPrefix:@"善语"] || [text hasPrefix:@"友爱评论"] || [text hasPrefix:@"回复"]) {
            self.textColor = [UIColor colorWithRed:125/255.0 green:125/255.0 blue:125/255.0 alpha:0.6];
        }
    }
    %orig;
}

- (void)layoutSubviews {
	%orig;

	BOOL hideRightLabel = DYYYCachedBool(@"DYYYHideRightLable");
	if (!hideRightLabel)
		return;

	NSString *accessibilityLabel = self.accessibilityLabel;
	if (!accessibilityLabel || accessibilityLabel.length == 0)
		return;

	NSString *trimmedLabel = [accessibilityLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	BOOL shouldHide = NO;

	if ([trimmedLabel hasSuffix:@"人共创"]) {
		NSString *prefix = [trimmedLabel substringToIndex:trimmedLabel.length - 3];
		NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
		shouldHide = ([prefix rangeOfCharacterFromSet:nonDigits].location == NSNotFound);
	}

	if (!shouldHide) {
		shouldHide = [trimmedLabel isEqualToString:@"章节要点"] || [trimmedLabel isEqualToString:@"图集"];
	}

	if (shouldHide) {
		self.hidden = YES;

		// 找到父视图是否为 UIStackView
		UIView *superview = self.superview;
		if ([superview isKindOfClass:[UIStackView class]]) {
			UIStackView *stackView = (UIStackView *)superview;
			// 刷新 UIStackView 的布局
			[stackView layoutIfNeeded];
		}
	}
}

%end

%hook UIButton

- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    NSString *label = self.accessibilityLabel;
    if ([label isEqualToString:@"表情"] || [label isEqualToString:@"at"] || [label isEqualToString:@"图片"] || [label isEqualToString:@"键盘"]) {
        if (DYYYCachedBool(@"DYYYisDarkKeyBoard")) {
            
            UIImage *whiteImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            
            self.tintColor = [UIColor whiteColor];
            
            %orig(whiteImage, state);
        }else {
            %orig(image, state);
        }
    } else {
        %orig(image, state);
    }
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    %orig;
    
    if ([title isEqualToString:@"加入挑战"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (DYYYCachedBool(@"DYYYHideChallengeStickers")) {
                UIResponder *responder = self;
                BOOL isInPlayInteractionViewController = NO;

                while ((responder = [responder nextResponder])) {
                    if ([responder isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                        isInPlayInteractionViewController = YES;
                        break;
                    }
                }

                if (isInPlayInteractionViewController) {
                    UIView *parentView = self.superview;
                    if (parentView) {
                        UIView *grandParentView = parentView.superview;
                        if (grandParentView) {
                            grandParentView.hidden = YES;
                        } else {
                            parentView.hidden = YES;
                        }
                    } else {
                        self.hidden = YES;
                    }
                }
            }
        });
    }
}

- (void)layoutSubviews {
	%orig;

	NSString *accessibilityLabel = self.accessibilityLabel;

	if ([accessibilityLabel isEqualToString:@"拍照搜同款"] || [accessibilityLabel isEqualToString:@"扫一扫"]) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideScancode"]) {
			[self removeFromSuperview];
			return;
		}
	}
	
	if ([accessibilityLabel isEqualToString:@"返回"]) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideBack"]) {
			UIView *parent = self.superview;
			if ([parent isKindOfClass:%c(AWEBaseElementView)]) {
				[self removeFromSuperview];
			}
			return;
		}
	}
}

%end

%hook UIImageView
- (void)layoutSubviews {
	%orig;
	if (DYYYCachedBool(@"DYYYHideCommentDiscover")) {
		if (!self.accessibilityLabel) {
			UIView *parentView = self.superview;

			if (parentView && [parentView class] == [UIView class] && [parentView.accessibilityLabel isEqualToString:@"搜索"]) {
				self.hidden = YES;
			}

			else if (parentView && [NSStringFromClass([parentView class]) isEqualToString:@"AWESearchEntryHalfScreenElement"] && [parentView.accessibilityLabel isEqualToString:@"搜索"]) {
				self.hidden = YES;
			}
		}
	}
}
%end

// 隐藏双栏入口

%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    // 处理日期时间格式子开关的互斥性
    if ([defaultName hasPrefix:@"DYYYDateTimeFormat_"] && value) {
        NSArray *formatKeys = @[
            @"DYYYDateTimeFormat_YMDHM",
            @"DYYYDateTimeFormat_MDHM", 
            @"DYYYDateTimeFormat_HMS",
            @"DYYYDateTimeFormat_HM",
            @"DYYYDateTimeFormat_YMD"
        ];
        
        // 关闭其他格式开关
        for (NSString *key in formatKeys) {
            if (![key isEqualToString:defaultName]) {
                %orig(NO, key);
            }
        }
        
        // 设置相应的格式到原始的格式键
        NSDictionary *formatMapping = @{
            @"DYYYDateTimeFormat_YMDHM": @"yyyy-MM-dd HH:mm",
            @"DYYYDateTimeFormat_MDHM": @"MM-dd HH:mm",
            @"DYYYDateTimeFormat_HMS": @"HH:mm:ss",
            @"DYYYDateTimeFormat_HM": @"HH:mm",
            @"DYYYDateTimeFormat_YMD": @"yyyy-MM-dd"
        };
        
        NSString *format = formatMapping[defaultName];
        if (format) {
            [self setObject:format forKey:@"DYYYDateTimeFormat"];
        }
    }
    
    %orig;
    DYYYConfigCacheInvalidate();
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    %orig;
    DYYYConfigCacheInvalidate();
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    %orig;
    DYYYConfigCacheInvalidate();
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName {
    %orig;
    DYYYConfigCacheInvalidate();
}

- (void)removeObjectForKey:(NSString *)defaultName {
    %orig;
    // 设置页"重置/清除"走 removeObjectForKey，同样需失效配置缓存
    DYYYConfigCacheInvalidate();
}

%end

