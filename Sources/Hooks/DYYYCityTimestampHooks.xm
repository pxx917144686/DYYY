//
//  DYYYCityTimestampHooks.xm
//  DYYY
//
//  视频时间戳与自定义属地 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

@interface AWEPlayInteractionTimestampElement (DYYYCitySelectorProtocol) <CitySelectorDelegate>
- (void)showCitySelector;
- (void)showDateTimeFormatSelector;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)citySelectorDidSelect:(NSString *)provinceCode 
                 provinceName:(NSString *)provinceName 
                     cityCode:(NSString *)cityCode 
                     cityName:(NSString *)cityName 
                 districtCode:(NSString *)districtCode 
                 districtName:(NSString *)districtName;
@end

%hook AWEPlayInteractionTimestampElement

static CLLocationManager *locationManager = nil;

+ (void)initialize {
    if (!locationManager) {
        locationManager = [[CLLocationManager alloc] init];
        [locationManager requestWhenInUseAuthorization];
    }
    // 设置默认 NSUserDefaults 值
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"DYYYisEnableArea": @YES,
        @"DYYYShowDateTime": @YES,
        @"DYYYisEnableAreaProvince": @YES,
        @"DYYYisEnableAreaCity": @YES,
        @"DYYYisEnableAreaDistrict": @YES,
        @"DYYYisEnableAreaStreet": @YES,
        @"DYYYDateTimeFormat_YMDHM": @YES // 默认启用年-月-日 时:分格式
    }];
}

- (id)timestampLabel {
	UILabel *label = %orig;
	
	// 准备第一行显示日期时间
	NSString *firstLine = @"";
	NSString *secondLine = @"";
	
	// 处理时间和日期显示
	if (DYYYCachedBool(@"DYYYShowDateTime")) {
		static NSDateFormatter *formatter = nil;
		static dispatch_once_t formatterOnce;
		dispatch_once(&formatterOnce, ^{
			formatter = [[NSDateFormatter alloc] init];
		});
		
		// 根据子开关决定日期格式
		NSString *dateFormat = @"yyyy-MM-dd HH:mm"; // 默认格式
		
		if (DYYYCachedBool(@"DYYYDateTimeFormat_YMDHM")) {
			dateFormat = @"yyyy-MM-dd HH:mm";
		} else if (DYYYCachedBool(@"DYYYDateTimeFormat_MDHM")) {
			dateFormat = @"MM-dd HH:mm";
		} else if (DYYYCachedBool(@"DYYYDateTimeFormat_HMS")) {
			dateFormat = @"HH:mm:ss";
		} else if (DYYYCachedBool(@"DYYYDateTimeFormat_HM")) {
			dateFormat = @"HH:mm";
		} else if (DYYYCachedBool(@"DYYYDateTimeFormat_YMD")) {
			dateFormat = @"yyyy-MM-dd";
		} else {
			// 检查是否有旧的格式设置
			NSString *oldFormat = DYYYCachedString(@"DYYYDateTimeFormat");
			if (oldFormat && oldFormat.length > 0) {
				dateFormat = oldFormat;
			}
		}
		
		formatter.dateFormat = dateFormat;
		
		// 使用视频发布时间而不是当前时间
		NSDate *creationDate = nil;
		NSNumber *createTimeStamp = [self.model valueForKey:@"createTime"];
		if (createTimeStamp) {
			// 时间戳转换为日期
			creationDate = [NSDate dateWithTimeIntervalSince1970:[createTimeStamp doubleValue]];
		} else {
			// 回退到原始标签文本中可能包含的时间信息
			NSString *originalText = label.text;
			if (originalText && originalText.length > 0) {
				firstLine = originalText;
			} else {
				creationDate = [NSDate date]; // 作为最后的回退选项
			}
		}
		
		if (creationDate) {
			firstLine = [formatter stringFromDate:creationDate];
		}
	}
	
	// 处理自定义属地，放在第二行 - 添加安全检查
	if (DYYYCachedBool(@"DYYYisEnableArea")) {
		NSString *cityCode = self.model.cityCode;
		NSString *customCityCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCustomCityCode"];
		
		// 检查是否使用自定义属地
		if (DYYYCachedBool(@"DYYYEnableCustomArea") && customCityCode) {
			cityCode = customCityCode;
		}
		
		// 添加安全检查 - 确保cityCode不为nil且不为空字符串
		if (cityCode && cityCode.length > 0) {
			DYYYCityManager *cityManager = [DYYYCityManager sharedInstance];
			// 确保cityManager有效
			if (cityManager && [cityManager respondsToSelector:@selector(generateRandomFourLevelAddressForCityCode:)]) {
				NSString *locationPrefix = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLocationPrefix"] ?: @"IP属地:";
				NSMutableString *location = [NSMutableString stringWithString:locationPrefix];
				
				@try {
					// 使用@try-@catch块捕获可能的异常
					NSString *fourLevelAddress = [cityManager generateRandomFourLevelAddressForCityCode:cityCode];
					
					if (fourLevelAddress && fourLevelAddress.length > 0) {
						[location appendString:fourLevelAddress];
					} else {
						[location appendString:@"未知地区"];
					}
				} @catch (NSException *exception) {
					// 捕获任何异常，防止崩溃
					NSLog(@"DYYY异常: %@", exception);
					[location appendString:@"未知地区"];
				}
				
				// 设置第二行文本
				if (location.length > locationPrefix.length) {
					secondLine = location;
				}
			}
		}
	}
	
	// 如果有两行内容，设置为多行显示
	if (secondLine.length > 0) {
		label.numberOfLines = 2;
		label.textAlignment = NSTextAlignmentLeft;
		label.lineBreakMode = NSLineBreakByWordWrapping;
		
		// 组合成两行文本
		label.text = [NSString stringWithFormat:@"%@\n%@", firstLine, secondLine];
		
		// 动态调整标签大小
		CGSize textSize = [label.text boundingRectWithSize:CGSizeMake(label.frame.size.width, CGFLOAT_MAX)
												  options:NSStringDrawingUsesLineFragmentOrigin
											   attributes:@{NSFontAttributeName: label.font}
												  context:nil].size;
		CGRect frame = label.frame;
		frame.size.height = textSize.height + 10;
		label.frame = frame;
		
		// 设置段落样式
		NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
		paragraphStyle.alignment = NSTextAlignmentLeft;
		paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
		
		NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:label.text];
		[attributedText addAttribute:NSParagraphStyleAttributeName 
							  value:paragraphStyle 
							  range:NSMakeRange(0, label.text.length)];
		
		label.attributedText = attributedText;
	} else {
		label.numberOfLines = 1;
		label.text = firstLine;
		label.textAlignment = NSTextAlignmentLeft;
	}
	
	// 设置标签颜色
	NSString *labelColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLabelColor"];
	if (labelColor.length > 0) {
		label.textColor = [DYYYManager colorWithHexString:labelColor];
	}
	
	// 添加长按手势
	if (!objc_getAssociatedObject(label, "hasLongPressGesture")) {
		UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] 
												 initWithTarget:self 
												 action:@selector(handleLongPress:)];
		[label addGestureRecognizer:longPress];
		label.userInteractionEnabled = YES;
		objc_setAssociatedObject(label, "hasLongPressGesture", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return label;
}

// 显示城市选择器
%new
- (void)showCitySelector {
    NSString *savedCityCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYCustomCityCode"];
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (topVC) {
        [[DYYYCityManager sharedInstance] showCitySelectorInViewController:topVC 
                                                             delegate:(id<CitySelectorDelegate>)self
                                                 initialSelectedCode:savedCityCode];
    } else {
        [DYYYManager showToast:@"无法打开选择器：找不到顶层视图控制器"];
    }
}

// 显示日期时间格式选择器 - 保留该方法用于长按菜单
%new
- (void)showDateTimeFormatSelector {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择日期时间格式" 
                                                                  message:@"请选择一种格式（也可在设置中选择）" 
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *formats = @[
        @{@"name": @"年-月-日 时:分", @"format": @"yyyy-MM-dd HH:mm", @"key": @"DYYYDateTimeFormat_YMDHM"},
        @{@"name": @"月-日 时:分", @"format": @"MM-dd HH:mm", @"key": @"DYYYDateTimeFormat_MDHM"},
        @{@"name": @"时:分:秒", @"format": @"HH:mm:ss", @"key": @"DYYYDateTimeFormat_HMS"},
        @{@"name": @"时:分", @"format": @"HH:mm", @"key": @"DYYYDateTimeFormat_HM"},
        @{@"name": @"年-月-日", @"format": @"yyyy-MM-dd", @"key": @"DYYYDateTimeFormat_YMD"}
    ];
    
    for (NSDictionary *formatInfo in formats) {
        [alert addAction:[UIAlertAction actionWithTitle:formatInfo[@"name"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            // 关闭所有格式开关
            for (NSDictionary *format in formats) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:format[@"key"]];
            }
            
            // 打开选中的格式开关
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:formatInfo[@"key"]];
            
            // 保留旧的格式键以保持兼容性
            [[NSUserDefaults standardUserDefaults] setObject:formatInfo[@"format"] forKey:@"DYYYDateTimeFormat"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [DYYYManager showToast:[NSString stringWithFormat:@"已设置日期时间格式: %@", formatInfo[@"name"]]];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIView *sourceView = topVC.view;
        alert.popoverPresentationController.sourceView = sourceView;
        alert.popoverPresentationController.sourceRect = CGRectMake(sourceView.bounds.size.width / 2, 
                                                                   sourceView.bounds.size.height / 2, 
                                                                   0, 0);
    }
    
    [topVC presentViewController:alert animated:YES completion:nil];
}

// 处理城市选择结果
%new
- (void)citySelectorDidSelect:(NSString *)provinceCode 
                 provinceName:(NSString *)provinceName 
                     cityCode:(NSString *)cityCode 
                     cityName:(NSString *)cityName 
                 districtCode:(NSString *)districtCode 
                 districtName:(NSString *)districtName {
    NSString *selectedCode = cityCode ?: provinceCode;
    if (selectedCode) {
        [[NSUserDefaults standardUserDefaults] setObject:selectedCode forKey:@"DYYYCustomCityCode"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYEnableCustomArea"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSString *location = (provinceName.length > 0 && cityName.length > 0) 
            ? [NSString stringWithFormat:@"%@ %@", provinceName, cityName] 
            : (cityName ?: provinceName);
        [DYYYManager showToast:[NSString stringWithFormat:@"已设置属地为: %@", location]];
    }
}

// 处理长按事件
%new
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"时间和属地设置" 
                                                                  message:@"请选择操作" 
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 时间日期选项
    BOOL dateTimeEnabled = DYYYCachedBool(@"DYYYShowDateTime");
    NSString *dateTimeTitle = dateTimeEnabled ? @"关闭日期时间显示" : @"开启日期时间显示";
    
    [alert addAction:[UIAlertAction actionWithTitle:dateTimeTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:!dateTimeEnabled forKey:@"DYYYShowDateTime"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [DYYYManager showToast:dateTimeEnabled ? @"已关闭日期时间显示" : @"已更新设置"];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"设置日期时间格式"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self showDateTimeFormatSelector];
    }]];
    
    // 属地设置选项
    [alert addAction:[UIAlertAction actionWithTitle:@"选择自定义属地"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self showCitySelector];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"使用默认属地" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYEnableCustomArea"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYCustomCityCode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [DYYYManager showToast:@"已恢复默认属地"];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                              style:UIAlertActionStyleCancel 
                                            handler:nil]];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = gesture.view;
        alert.popoverPresentationController.sourceRect = gesture.view.bounds;
    }
    
    UIViewController *topVC = [DYYYManager getActiveTopController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

+ (BOOL)shouldActiveWithData:(id)arg1 context:(id)arg2 {
    return DYYYCachedBool(@"DYYYisEnableArea") ||
           DYYYCachedBool(@"DYYYShowDateTime");
}

%end

%ctor {
    %init;
}
