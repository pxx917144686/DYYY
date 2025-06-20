#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "AwemeHeaders.h"

%hook AWEURLModel
%new
- (NSURL *)getDYYYSrcURLDownload {
    if (!self.originURLList || self.originURLList.count == 0) return nil;
    
    NSURL *bestURL = nil;
    
    for (NSString *url in self.originURLList) {
        if ([url containsString:@"watermark=0"] || 
            [url containsString:@"remove_watermark=1"] || 
            [url containsString:@"noWatermark=1"]) {
            bestURL = [NSURL URLWithString:url];
            break;
        }
    }
    
    if (!bestURL) {
        for (NSString *url in self.originURLList) {
            if ([url containsString:@"video_mp4"] || 
                [url hasSuffix:@".mp4"] || 
                [url hasSuffix:@".mov"] ||
                [url hasSuffix:@".m4v"] ||
                [url hasSuffix:@".avi"] ||
                [url hasSuffix:@".wmv"] ||
                [url hasSuffix:@".flv"] ||
                [url hasSuffix:@".mkv"] ||
                [url hasSuffix:@".webm"] ||
                [url containsString:@"/video/"] ||
                [url containsString:@"type=video"]) {
                bestURL = [NSURL URLWithString:url];
                break;
            }
            
            if ([url hasSuffix:@".jpeg"] || 
                [url hasSuffix:@".jpg"] ||
                [url hasSuffix:@".png"] ||
                [url hasSuffix:@".gif"] ||
                [url hasSuffix:@".webp"] ||
                [url hasSuffix:@".heic"] ||
                [url hasSuffix:@".tiff"] ||
                [url hasSuffix:@".bmp"] ||
                [url containsString:@"/image/"] ||
                [url containsString:@"type=image"]) {
                bestURL = [NSURL URLWithString:url];
                break;
            }
            
            if ([url hasSuffix:@".mp3"] || 
                [url hasSuffix:@".m4a"] ||
                [url hasSuffix:@".wav"] ||
                [url hasSuffix:@".aac"] ||
                [url hasSuffix:@".ogg"] ||
                [url hasSuffix:@".flac"] ||
                [url hasSuffix:@".alac"] ||
                [url hasSuffix:@".aiff"] ||
                [url containsString:@"/audio/"] ||
                [url containsString:@"type=audio"]) {
                bestURL = [NSURL URLWithString:url];
                break;
            }
        }
    }
    
    if (!bestURL) {
        NSString *highestRes = nil;
        int highestValue = 0;
        
        for (NSString *url in self.originURLList) {
            NSArray *resMarkers = @[@"1080p", @"720p", @"4k", @"2k", @"uhd", @"hd", @"high", @"best"];
            for (NSString *marker in resMarkers) {
                if ([url.lowercaseString containsString:marker.lowercaseString]) {
                    int value = 0;
                    if ([marker isEqualToString:@"4k"] || [marker isEqualToString:@"uhd"]) value = 4;
                    else if ([marker isEqualToString:@"2k"]) value = 3;
                    else if ([marker isEqualToString:@"1080p"]) value = 2;
                    else if ([marker isEqualToString:@"720p"] || [marker isEqualToString:@"hd"]) value = 1;
                    else value = 0;
                    
                    if (value > highestValue) {
                        highestValue = value;
                        highestRes = url;
                    }
                    break;
                }
            }
        }
        
        if (highestRes) {
            bestURL = [NSURL URLWithString:highestRes];
        }
    }
    
    if (!bestURL) {
        NSString *highestQuality = nil;
        int highestScore = 0;
        
        for (NSString *url in self.originURLList) {
            NSURLComponents *components = [NSURLComponents componentsWithString:url];
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name.lowercaseString containsString:@"quality"] || 
                    [item.name.lowercaseString containsString:@"definition"] ||
                    [item.name.lowercaseString containsString:@"resolution"]) {
                    NSString *value = item.value.lowercaseString;
                    int score = 0;
                    
                    if ([value containsString:@"high"]) score += 3;
                    if ([value containsString:@"medium"]) score += 2;
                    if ([value containsString:@"low"]) score += 1;
                    
                    if (score > highestScore) {
                        highestScore = score;
                        highestQuality = url;
                    }
                }
            }
        }
        
        if (highestQuality) {
            bestURL = [NSURL URLWithString:highestQuality];
        }
    }
    
	if (!bestURL) {
		NSString *largestFile = nil;
		long long maxSize = 0;
		
		for (NSString *url in self.originURLList) {
			NSURLComponents *components = [NSURLComponents componentsWithString:url];
			for (NSURLQueryItem *item in components.queryItems) {
				if ([item.name.lowercaseString containsString:@"size"] || 
					[item.name.lowercaseString containsString:@"bitrate"] ||
					[item.name.lowercaseString containsString:@"rate"]) {
					long long size = [item.value longLongValue];
					if (size > maxSize) {
						maxSize = size;
						largestFile = url;
					}
				}
			}
		}
		
		if (largestFile) {
			bestURL = [NSURL URLWithString:largestFile];
		}
	}
    
    if (!bestURL && self.originURLList.count > 0) {
        bestURL = [NSURL URLWithString:self.originURLList.lastObject];
    }
    
    if (!bestURL && self.originURLList.count > 0) {
        bestURL = [NSURL URLWithString:self.originURLList.firstObject];
    }
    
    if (bestURL && bestURL.scheme && bestURL.host) {
        return bestURL;
    } else if (self.originURLList.count > 0) {
        return [NSURL URLWithString:self.originURLList.lastObject];
    }
    
    return nil;
}
%end

%hook AWEPlayerPlayControlHandler

%property (nonatomic, strong) AVAudioUnitEQ *audioEQ;
%property (nonatomic, strong) AVAudioUnitReverb *reverb;
%property (nonatomic, assign) BOOL noiseFilterEnabled;
%property (nonatomic, strong) UIButton *qualityButton;
%property (nonatomic, strong) NSArray *availableQualities;
%property (nonatomic, assign) NSInteger currentQualityIndex;

- (void)setupAVPlayerItem:(AVPlayerItem *)item {
	%orig;
	
	// 在视频准备完成时，获取所有可用清晰度
	id videoModel = [self valueForKey:@"videoModel"];
	if (!videoModel) return;
	
	// 获取视频URL模型
	AWEURLModel *urlModel = [videoModel valueForKey:@"videoURLModel"];
	if (!urlModel || !urlModel.originURLList || urlModel.originURLList.count == 0) return;
	
	// 解析可用的清晰度选项
	[self parseAvailableQualities:urlModel];
	
	// 添加清晰度选择按钮
	[self addQualityButton];
	
	// 应用用户设置的默认清晰度
	[self applyDefaultQuality:item];
}

%new
- (void)parseAvailableQualities:(AWEURLModel *)urlModel {
	// 方法实现保持不变
	NSMutableArray *qualities = [NSMutableArray array];
	NSArray *urls = urlModel.originURLList;
	
	// 检查是否有原画清晰度
	for (NSString *url in urls) {
		if ([url containsString:@"original"] || [url containsString:@"source"]) {
			[qualities addObject:@{
				@"title": @"原画",
				@"url": url,
				@"type": @"original"
			}];
			break;
		}
	}
	
	// 检查是否有1080P清晰度
	for (NSString *url in urls) {
		if ([url containsString:@"1080"] || [url containsString:@"FHD"]) {
			[qualities addObject:@{
				@"title": @"1080P",
				@"url": url,
				@"type": @"1080p"
			}];
			break;
		}
	}
	
	// 检查是否有720P清晰度
	for (NSString *url in urls) {
		if ([url containsString:@"720"] || [url containsString:@"HD"]) {
			[qualities addObject:@{
				@"title": @"720P",
				@"url": url,
				@"type": @"720p"
			}];
			break;
		}
	}
	
	// 检查是否有540P清晰度
	for (NSString *url in urls) {
		if ([url containsString:@"540"] || [url containsString:@"SD"]) {
			[qualities addObject:@{
				@"title": @"540P",
				@"url": url,
				@"type": @"540p"
			}];
			break;
		}
	}
	
	// 如果没有找到任何清晰度选项，至少添加一个默认的
	if (qualities.count == 0 && urls.count > 0) {
		[qualities addObject:@{
			@"title": @"默认",
			@"url": urls.firstObject,
			@"type": @"default"
		}];
	}
	
	self.availableQualities = qualities;
	self.currentQualityIndex = 0; // 默认选择第一个（最高清晰度）
}

%new
- (void)addQualityButton {
	// 方法实现保持不变
	UIViewController *parentVC = nil;
	
	// 获取父视图控制器
	id currentResponder = self;
	while ((currentResponder = [currentResponder nextResponder])) {
		if ([currentResponder isKindOfClass:[UIViewController class]]) {
			parentVC = (UIViewController *)currentResponder;
			break;
		}
	}
	
	if (!parentVC || !parentVC.view) return;
	
	// 移除已有按钮
	if (self.qualityButton) {
		[self.qualityButton removeFromSuperview];
		self.qualityButton = nil;
	}
	
	// 创建清晰度切换按钮
	UIButton *qualityButton = [UIButton buttonWithType:UIButtonTypeCustom];
	qualityButton.frame = CGRectMake(parentVC.view.frame.size.width - 90, 210, 70, 30);
	qualityButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
	qualityButton.layer.cornerRadius = 15;
	
	// 获取当前清晰度文本
	NSString *qualityText = @"清晰度";
	if (self.availableQualities.count > 0 && self.currentQualityIndex < self.availableQualities.count) {
		qualityText = self.availableQualities[self.currentQualityIndex][@"title"];
	}
	
	[qualityButton setTitle:qualityText forState:UIControlStateNormal];
	[qualityButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	qualityButton.titleLabel.font = [UIFont systemFontOfSize:13];
	[qualityButton addTarget:self action:@selector(showQualityOptions) forControlEvents:UIControlEventTouchUpInside];
	qualityButton.tag = 9877;
	
	[parentVC.view addSubview:qualityButton];
	self.qualityButton = qualityButton;
}

%new
- (void)applyDefaultQuality:(AVPlayerItem *)item {
	// 方法实现保持不变
	// 检查是否启用了自动清晰度选择
	BOOL enableHighestQuality = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableVideoHighestQuality"];
	
	if (self.availableQualities.count == 0) return;
	
	// 获取默认清晰度设置
	BOOL defaultBest = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDefaultQualityBest"];
	BOOL defaultOriginal = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDefaultQualityOriginal"];
	BOOL default1080p = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDefaultQuality1080p"];
	BOOL default720p = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDefaultQuality720p"];
	
	// 如果启用了"最高清晰度"选项或"默认最佳"选项
	if (enableHighestQuality || defaultBest) {
		[self switchToQuality:0]; // 选择第一个（最高）清晰度
		return;
	}
	
	// 如果指定了原画
	if (defaultOriginal) {
		for (int i = 0; i < self.availableQualities.count; i++) {
			NSDictionary *quality = self.availableQualities[i];
			NSString *type = quality[@"type"];
			if ([type isEqualToString:@"original"]) {
				[self switchToQuality:i];
				return;
			}
		}
	}
	
	// 如果指定了1080p
	if (default1080p) {
		for (int i = 0; i < self.availableQualities.count; i++) {
			NSDictionary *quality = self.availableQualities[i];
			NSString *type = quality[@"type"];
			if ([type isEqualToString:@"1080p"]) {
				[self switchToQuality:i];
				return;
			}
		}
	}
	
	// 如果指定了720p
	if (default720p) {
		for (int i = 0; i < self.availableQualities.count; i++) {
			NSDictionary *quality = self.availableQualities[i];
			NSString *type = quality[@"type"];
			if ([type isEqualToString:@"720p"]) {
				[self switchToQuality:i];
				return;
			}
		}
	}
	
	// 如果没有匹配的默认选项或没有找到指定的清晰度，使用最高可用清晰度
	[self switchToQuality:0];
}

%new
- (void)showQualityOptions {
	// 方法实现保持不变
	if (!self.availableQualities || self.availableQualities.count == 0) return;
	
	UIViewController *parentVC = nil;
	
	// 获取父视图控制器
	id currentResponder = self;
	while ((currentResponder = [currentResponder nextResponder])) {
		if ([currentResponder isKindOfClass:[UIViewController class]]) {
			parentVC = (UIViewController *)currentResponder;
			break;
		}
	}
	
	if (!parentVC) return;
	
	// 创建警告控制器作为清晰度选择菜单
	UIAlertController *alertController = [UIAlertController 
										 alertControllerWithTitle:@"选择清晰度"
										 message:nil
										 preferredStyle:UIAlertControllerStyleActionSheet];
	
	// 添加每个清晰度选项
	for (int i = 0; i < self.availableQualities.count; i++) {
		NSDictionary *quality = self.availableQualities[i];
		NSString *title = quality[@"title"];
		
		if (i == self.currentQualityIndex) {
			title = [NSString stringWithFormat:@"✓ %@", title];
		}
		
		UIAlertAction *action = [UIAlertAction 
							   actionWithTitle:title
							   style:UIAlertActionStyleDefault
							   handler:^(UIAlertAction * _Nonnull action) {
			[self switchToQuality:i];
		}];
		
		[alertController addAction:action];
	}
	
	// 添加取消按钮
	UIAlertAction *cancelAction = [UIAlertAction 
								  actionWithTitle:@"取消"
								  style:UIAlertActionStyleCancel
								  handler:nil];
	[alertController addAction:cancelAction];
	
	// 在iPad上设置弹出源
	if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		alertController.popoverPresentationController.sourceView = self.qualityButton;
		alertController.popoverPresentationController.sourceRect = self.qualityButton.bounds;
	}
	
	// 显示菜单
	[parentVC presentViewController:alertController animated:YES completion:nil];
}

%new
- (void)switchToQuality:(NSInteger)index {
	// 方法实现保持不变
	if (index < 0 || index >= self.availableQualities.count) return;
	
	// 获取播放器对象
	id playerObject = [self valueForKey:@"player"];
	if (!playerObject || ![playerObject isKindOfClass:[AVPlayer class]]) return;
	
	AVPlayer *player = (AVPlayer *)playerObject;
	AVPlayerItem *currentItem = player.currentItem;
	if (!currentItem) return;
	
	// 保存当前播放位置
	CMTime currentTime = currentItem.currentTime;
	BOOL wasPlaying = player.rate > 0;
	
	// 获取选择的清晰度URL
	NSString *urlString = self.availableQualities[index][@"url"];
	NSURL *url = [NSURL URLWithString:urlString];
	if (!url) return;
	
	// 创建新的AVPlayerItem并替换
	AVPlayerItem *newItem = [AVPlayerItem playerItemWithURL:url];
	if (!newItem) return;
	
	// 替换播放项
	[player replaceCurrentItemWithPlayerItem:newItem];
	
	// 恢复播放位置
	[newItem seekToTime:currentTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
	
	// 如果之前在播放，继续播放
	if (wasPlaying) {
		[player play];
	}
	
	// 更新当前选中的清晰度索引
	self.currentQualityIndex = index;
	
	// 更新按钮标题
	if (self.qualityButton) {
		NSString *qualityText = self.availableQualities[index][@"title"];
		[self.qualityButton setTitle:qualityText forState:UIControlStateNormal];
	}
	
	// 显示提示
	NSString *qualityName = self.availableQualities[index][@"title"];
	[DYYYManager showToast:[NSString stringWithFormat:@"已切换到%@清晰度", qualityName]];
}

%new
- (void)setupNoiseFilter {
	AVPlayer *player = [self valueForKey:@"player"];
	if (!player) return;
	
	// 如果已启用过滤器，直接返回
	if (self.noiseFilterEnabled) return;
	
	// 获取音频节点配置
	AVAudioSession *session = [AVAudioSession sharedInstance];
	NSError *error = nil;
	
	// 设置音频会话类型
	[session setCategory:AVAudioSessionCategoryPlayback error:&error];
	if (error) {
		NSLog(@"设置音频会话类型失败: %@", error);
		return;
	}
	
	// 初始化音频节点
	if (!self.audioEQ) {
		// 创建EQ单元处理器
		AVAudioUnitEQ *eq = [[AVAudioUnitEQ alloc] initWithNumberOfBands:10];
		
		// 设置EQ音频处理参数
		AVAudioUnitEQFilterParameters *lowPassFilter = [eq.bands objectAtIndex:0];
		lowPassFilter.filterType = AVAudioUnitEQFilterTypeLowPass;
		lowPassFilter.frequency = 5000.0; // 设置低通滤波器频率，过滤高频噪音
		lowPassFilter.bypass = NO;
		lowPassFilter.gain = 0.0;
		
		AVAudioUnitEQFilterParameters *highPassFilter = [eq.bands objectAtIndex:1];
		highPassFilter.filterType = AVAudioUnitEQFilterTypeHighPass;
		highPassFilter.frequency = 85.0; // 设置高通滤波器频率，去除低频噪音
		highPassFilter.bypass = NO;
		highPassFilter.gain = 0.0;
		
		// 增强人声频段
		for (int i = 2; i < 7; i++) {
			AVAudioUnitEQFilterParameters *band = [eq.bands objectAtIndex:i];
			band.filterType = AVAudioUnitEQFilterTypeParametric;
			band.frequency = 500.0 + (i - 2) * 500.0; // 人声主要集中在500Hz-3000Hz
			band.bandwidth = 100.0;
			band.gain = 3.0; // 增强人声
			band.bypass = NO;
		}
		
		self.audioEQ = eq;
	}
	
	if (!self.reverb) {
		// 创建混响单元处理器
		AVAudioUnitReverb *reverb = [[AVAudioUnitReverb alloc] init];
		reverb.wetDryMix = 10.0; // 混响量很小，只是为了增加一点空间感
		self.reverb = reverb;
	}
	
	// 添加控制按钮
	[self addNoiseFilterButton];
	
	self.noiseFilterEnabled = YES;
}

%new
- (void)addNoiseFilterButton {
	UIViewController *parentVC = nil;
	
	// 使用id类型避免类型转换问题
	id currentResponder = self;
	while ((currentResponder = [currentResponder nextResponder])) {
		if ([currentResponder isKindOfClass:[UIViewController class]]) {
			parentVC = (UIViewController *)currentResponder;
			break;
		}
	}
	
	if (!parentVC || !parentVC.view) return;
	
	// 检查按钮是否已存在
	if ([parentVC.view viewWithTag:9876]) return;
	
	UIButton *filterButton = [UIButton buttonWithType:UIButtonTypeCustom];
	filterButton.frame = CGRectMake(parentVC.view.frame.size.width - 90, 160, 70, 30);
	filterButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
	filterButton.layer.cornerRadius = 15;
	[filterButton setTitle:@"降噪" forState:UIControlStateNormal];
	[filterButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	filterButton.titleLabel.font = [UIFont systemFontOfSize:13];
	[filterButton addTarget:self action:@selector(toggleNoiseFilter) forControlEvents:UIControlEventTouchUpInside];
	filterButton.tag = 9876;
	
	[parentVC.view addSubview:filterButton];
}

%new
- (void)toggleNoiseFilter {
	AVPlayer *player = [self valueForKey:@"player"];
	if (!player) return;
	
	// 切换噪声过滤状态
	BOOL isActive = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoiseFilterActive"];
	[[NSUserDefaults standardUserDefaults] setBool:isActive forKey:@"DYYYNoiseFilterActive"];
	
	// 保存当前播放位置
	CMTime currentTime = player.currentTime;
	
	// 应用或移除音频处理
	if (isActive) {
		// 应用音频增强
		AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
		AVMutableAudioMixInputParameters *inputParams = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:player.currentItem.asset.tracks.firstObject];
		// 改为简单设置音量保持原始值
		inputParams.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmSpectral;
		
		audioMix.inputParameters = @[inputParams];
		player.currentItem.audioMix = audioMix;
		
		[DYYYManager showToast:@"已启用噪音过滤"];
	} else {
		// 移除音频处理
		player.currentItem.audioMix = nil;
		[DYYYManager showToast:@"已关闭噪音过滤"];
	}
	
	// 恢复播放位置
	[player seekToTime:currentTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)play {
	%orig;
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableNoiseFilter"]) {
		[self setupNoiseFilter];
	}
}

%end

// 默认视频流最高画质
%hook AWEVideoModel

- (AWEURLModel *)playURL {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableVideoHighestQuality"]) {
        return %orig;
    }

    // 获取比特率模型数组
    NSArray *bitrateModels = [self bitrateModels];
    if (!bitrateModels || bitrateModels.count == 0) {
        return %orig;
    }

    // 查找比特率最高的模型
    id highestBitrateModel = nil;
    NSInteger highestBitrate = 0;

    for (id model in bitrateModels) {
        NSInteger bitrate = 0;
        BOOL validModel = NO;

        if ([model isKindOfClass:NSClassFromString(@"AWEVideoBSModel")]) {
            // 使用 valueForKey 替代直接调用方法
            id bitrateValue = [model valueForKey:@"bitrate"];
            if (bitrateValue && [bitrateValue respondsToSelector:@selector(integerValue)]) {
                bitrate = [bitrateValue integerValue];
                validModel = YES;
            }
        }

        if (validModel && bitrate > highestBitrate) {
            highestBitrate = bitrate;
            highestBitrateModel = model;
        }
    }

    // 如果找到了最高比特率模型，获取其播放地址
    if (highestBitrateModel) {
        id playAddr = [highestBitrateModel valueForKey:@"playAddr"];
        if (playAddr && [playAddr isKindOfClass:%c(AWEURLModel)]) {
            return playAddr;
        }
    }

    return %orig;
}

- (NSArray *)bitrateModels {

    NSArray *originalModels = %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableVideoHighestQuality"]) {
        return originalModels;
    }

    if (originalModels.count == 0) {
        return originalModels;
    }

    // 查找比特率最高的模型
    id highestBitrateModel = nil;
    NSInteger highestBitrate = 0;

    for (id model in originalModels) {

        NSInteger bitrate = 0;
        BOOL validModel = NO;

        if ([model isKindOfClass:NSClassFromString(@"AWEVideoBSModel")]) {
            // 使用 valueForKey 替代直接调用方法
            id bitrateValue = [model valueForKey:@"bitrate"];
            if (bitrateValue && [bitrateValue respondsToSelector:@selector(integerValue)]) {
                bitrate = [bitrateValue integerValue];
                validModel = YES;
            }
        }

        if (validModel) {
            if (bitrate > highestBitrate) {
                highestBitrate = bitrate;
                highestBitrateModel = model;
            }
        }
    }

    if (highestBitrateModel) {
        return @[ highestBitrateModel ];
    }

    return originalModels;
}

%end


%ctor {
	// 设置默认清晰度选项的初始值
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:@"DYYYDefaultQualityBest"]) {
		[defaults setBool:YES forKey:@"DYYYDefaultQualityBest"];
	}
	if (![defaults objectForKey:@"DYYYDefaultQualityOriginal"]) {
		[defaults setBool:NO forKey:@"DYYYDefaultQualityOriginal"];
	}
	if (![defaults objectForKey:@"DYYYDefaultQuality1080p"]) {
		[defaults setBool:NO forKey:@"DYYYDefaultQuality1080p"];
	}
	if (![defaults objectForKey:@"DYYYDefaultQuality720p"]) {
		[defaults setBool:NO forKey:@"DYYYDefaultQuality720p"];
	}
	[defaults synchronize];
	
	%init;
}
