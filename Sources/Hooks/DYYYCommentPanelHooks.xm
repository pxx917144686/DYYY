//
//  DYYYCommentPanelHooks.xm
//  DYYY
//
//  评论面板与评论长按菜单 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

%group CommentHeaderGeneralGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView
- (void)layoutSubviews {
	%orig;  // 调用原始方法

	// 检查是否启用隐藏评论视图的功能
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		[(UIView *)self setHidden:YES];  // 将视图设置为隐藏状态（需要类型转换）
	}
}
%end
%end

// Swift 类组 - 评论面板商品视图
%group CommentHeaderGoodsGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView
- (void)layoutSubviews {
	%orig;  // 调用原始方法

	// 检查是否启用隐藏评论视图的功能
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		[(UIView *)self setHidden:YES];  // 将视图设置为隐藏状态（需要类型转换）
	}
}
%end
%end

// Swift 类组 - 评论面板模板锚点视图
%group CommentHeaderTemplateGroup
%hook AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView
- (void)layoutSubviews {
	%orig;  // 调用原始方法

	// 检查是否启用隐藏评论视图的功能
	if (DYYYCachedBool(@"DYYYHideCommentViews")) {
		[(UIView *)self setHidden:YES];  // 将视图设置为隐藏状态（需要类型转换）
	}
}
%end
%end

/**
 * 针对评论面板底部提示容器视图控制器。
 * 当用户设置中的"DYYYHideCommentTips"选项被启用时，它会隐藏评论提示视图。
 */
%group CommentBottomTipsVCGroup
%hook AWECommentPanelListSwiftImpl_CommentBottomTipsContainerViewController
- (void)viewWillAppear:(BOOL)animated {
	%orig(animated);
	if (DYYYCachedBool(@"DYYYHideCommentTips")) {
		((UIViewController *)self).view.hidden = YES;
	}
}
%end
%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement

static BOOL isDownloadFlied = NO;

-(BOOL)elementShouldShow{
    BOOL DYYYFourceDownloadEmotion = DYYYCachedBool(@"DYYYFourceDownloadEmotion");
    if(DYYYFourceDownloadEmotion){
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if(!selectdComment){
            AWECommentLongPressPanelParam *params = [commentPageContext params];
            selectdComment = [params selectdComment];
        }
        // 表情包
        AWEIMStickerModel *sticker = [selectdComment sticker];
        if(sticker){
            AWEURLModel *staticURLModel = [sticker staticURLModel];
            NSArray *originURLList = [staticURLModel originURLList];
            if (originURLList.count > 0) {
                return YES;
            }
        }
        // 评论区语音
        AWECommentAudioModel *audio = [selectdComment audioModel];
        if (audio && audio.content) {
            return YES;
        }
        // 评论区图片
        NSArray *imageList = nil;
        if ([selectdComment respondsToSelector:@selector(imageList)]) {
            imageList = [selectdComment imageList];
        }
        if (imageList && imageList.count > 0) {
            return YES;
        }
    }
    return %orig;
}

-(void)elementTapped{
    BOOL DYYYFourceDownloadEmotion = DYYYCachedBool(@"DYYYFourceDownloadEmotion");
    if(DYYYFourceDownloadEmotion){
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        AWECommentLongPressPanelParam *params = [commentPageContext params];
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if(!selectdComment){
            selectdComment = [params selectdComment];
        }

        // 判断保存类型(表情包/语音/图片)
        AWEIMStickerModel *sticker = [selectdComment sticker];
        AWEURLModel *stickerURLModel = sticker ? [sticker staticURLModel] : nil;
        NSArray *stickerURLList = stickerURLModel ? [stickerURLModel originURLList] : nil;
        BOOL hasSticker = (stickerURLList.count > 0);

        AWECommentAudioModel *audio = [selectdComment audioModel];
        BOOL hasAudio = (audio && audio.content);

        NSArray *imageList = nil;
        if ([selectdComment respondsToSelector:@selector(imageList)]) {
            imageList = [selectdComment imageList];
        }
        BOOL hasImages = (imageList && imageList.count > 0);

        // 表情包保存
        if (hasSticker) {
            NSString *urlString = @"";
            if(isDownloadFlied){
                urlString = stickerURLList[stickerURLList.count-1];
                isDownloadFlied = NO;
            }else{
                urlString = stickerURLList[0];
            }

            NSURL *heifURL = [NSURL URLWithString:urlString];
			[DYYYManager downloadMedia:heifURL mediaType:MediaTypeHeic completion:^(BOOL success){
				if (success) {
					[DYYYManager showToast:@"表情包已保存到相册"];
				} else if (stickerURLList.count > 1) {
                    isDownloadFlied = YES;
                }
			}];
            return;
        }

        // 评论区语音下载/分享
        if (hasAudio) {
            NSString *audioContent = audio.content;
            NSString *userName = @"未知用户";
            AWEUserModel *author = [selectdComment author];
            if (author && [author respondsToSelector:@selector(nickname)]) {
                NSString *nickname = [author performSelector:@selector(nickname)];
                if (nickname && nickname.length > 0) {
                    userName = nickname;
                }
            }
            [DYYYManager downloadAndShareCommentAudio:audioContent
                                            userName:userName
                                          createTime:[selectdComment createTime]];
            return;
        }

        // 评论区图片批量保存
        if (hasImages) {
            // is_pic_inflow = 1: 点开具体图片后长按 -> 只保存当前图片
            // is_pic_inflow = 0: 直接在评论区长按 -> 保存全部图片
            NSDictionary *extraParams = [params extraParams];
            BOOL isPicInflow = NO;
            if (extraParams && [extraParams isKindOfClass:[NSDictionary class]]) {
                id isPicInflowValue = extraParams[@"is_pic_inflow"];
                if (isPicInflowValue) {
                    isPicInflow = [isPicInflowValue integerValue] == 1;
                }
            }

            NSInteger currentIndex = -1; // -1 表示保存全部

            if (isPicInflow) {
                UIViewController *topVC = [DYYYUtils topView];
                Class ivarClass = NSClassFromString(@"AWECommentMediaFeedSwfitImpl.CommentMediaFeedCellViewController");
                Class targetClass = NSClassFromString(@"AWECommentMediaFeedSwfitImpl.CommentMediaFeedCommonImageCellViewController");
                if (ivarClass && targetClass && topVC) {
                    Ivar multiIndexIvar = class_getInstanceVariable(ivarClass, "currentIndexInMultiImageList");
                    if (multiIndexIvar) {
                        UIViewController *cellVC = [DYYYUtils findViewControllerOfClass:targetClass inViewController:topVC];
                        if (cellVC) {
                            ptrdiff_t offset = ivar_getOffset(multiIndexIvar);
                            NSInteger *ptr = (NSInteger *)((char *)(__bridge void *)cellVC + offset);
                            currentIndex = *ptr;
                        }
                    }
                }
            }

            NSString *hint = (currentIndex >= 0) ? @"正在保存当前图片..." :
                [NSString stringWithFormat:@"正在保存 %lu 张图片...", (unsigned long)imageList.count];
            [DYYYUtils showToast:hint];

            [DYYYManager saveCommentImages:imageList
                             currentIndex:currentIndex
                               completion:^(NSInteger successCount, NSInteger livePhotoCount, NSInteger failedCount) {
                NSMutableString *message = [NSMutableString stringWithFormat:@"成功保存 %ld 张", (long)successCount];
                if (livePhotoCount > 0) {
                    [message appendFormat:@"\n(含 %ld 张实况照片)", (long)livePhotoCount];
                }
                if (failedCount > 0) {
                    [message appendFormat:@"\n失败 %ld 张", (long)failedCount];
                }
                [DYYYUtils showToast:message];
            }];
            return;
        }
    }
    %orig;
}
%end

%group EnableStickerSaveMenu
// 创建全局变量，用于存储当前长按的表情视图
static __weak YYAnimatedImageView *targetStickerView = nil;

%hook _TtCV28AWECommentPanelListSwiftImpl6NEWAPI27CommentCellStickerComponent

// 拦截长按手势处理方法
- (void)handleLongPressWithGes:(UILongPressGestureRecognizer *)gesture {
	// 当手势开始时，保存被长按的表情视图引用
	if (gesture.state == UIGestureRecognizerStateBegan) {
		if ([gesture.view isKindOfClass:%c(YYAnimatedImageView)]) {
			targetStickerView = (YYAnimatedImageView *)gesture.view;
			NSLog(@"DYYY 长按表情：%@", targetStickerView);
		} else {
			targetStickerView = nil;
		}
	}

	%orig; // 执行原始方法
}

%end

%hook UIMenu

// 拦截菜单创建方法，添加"保存到相册"选项
+ (instancetype)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(UIMenuIdentifier)identifier options:(UIMenuOptions)options children:(NSArray<UIMenuElement *> *)children {
	// 检查菜单中是否已有"添加到表情"和"保存到相册"选项
	BOOL hasAddStickerOption = NO;
	BOOL hasSaveLocalOption = NO;

	// 遍历所有菜单项，检查现有选项
	for (UIMenuElement *element in children) {
		NSString *elementTitle = nil;

		if ([element isKindOfClass:%c(UIAction)]) {
			elementTitle = [(UIAction *)element title];
		} else if ([element isKindOfClass:%c(UICommand)]) {
			elementTitle = [(UICommand *)element title];
		}

		if ([elementTitle isEqualToString:@"添加到表情"]) {
			hasAddStickerOption = YES;
		} else if ([elementTitle isEqualToString:@"保存到相册"]) {
			hasSaveLocalOption = YES;
		}
	}

	// 如果有"添加到表情"选项但没有"保存到相册"选项，则添加自定义保存选项
	if (hasAddStickerOption && !hasSaveLocalOption) {
		NSMutableArray *newChildren = [children mutableCopy];

		// 创建"保存到相册"操作
		UIAction *saveAction = [%c(UIAction) actionWithTitle:@"保存到相册"
									 image:nil
									identifier:nil
									   handler:^(__kindof UIAction *_Nonnull action) {
									 if (targetStickerView) {
										 [DYYYManager saveAnimatedSticker:targetStickerView];
									 } else {
										 [DYYYUtils showToast:@"无法获取表情视图"];
									 }
									   }];

		// 将新选项添加到菜单中
		[newChildren addObject:saveAction];
		return %orig(title, image, identifier, options, newChildren);
	}

	return %orig; // 如果不需要修改菜单，则执行原始方法
}

%end
%end

static AWEIMReusableCommonCell *currentCell;

%hook AWEIMCustomMenuComponent
- (void)msg_showMenuForBubbleFrameInScreen:(CGRect)bubbleFrame tapLocationInScreen:(CGPoint)tapLocation menuItemList:(id)menuItems moreEmoticon:(BOOL)moreEmoticon onCell:(id)cell extra:(id)extra {
	if (!DYYYCachedBool(@"DYYYForceDownloadIMEmotion")) {
		%orig(bubbleFrame, tapLocation, menuItems, moreEmoticon, cell, extra);
		return;
	}
	NSArray *originalMenuItems = menuItems;

	NSMutableArray *newMenuItems = [originalMenuItems mutableCopy];
	currentCell = (AWEIMReusableCommonCell *)cell;

	AWEIMCustomMenuModel *newMenuItem1 = [%c(AWEIMCustomMenuModel) new];
	newMenuItem1.title = @"保存表情";
	newMenuItem1.imageName = @"im_emoticon_interactive_tab_new";
	newMenuItem1.willPerformMenuActionSelectorBlock = ^(id arg1) {
	  AWEIMMessageComponentContext *context = (AWEIMMessageComponentContext *)currentCell.currentContext;
	  if ([context.message isKindOfClass:%c(AWEIMGiphyMessage)]) {
		  AWEIMGiphyMessage *giphyMessage = (AWEIMGiphyMessage *)context.message;
		  if (giphyMessage.giphyURL && giphyMessage.giphyURL.originURLList.count > 0) {
			  NSURL *url = [NSURL URLWithString:giphyMessage.giphyURL.originURLList.firstObject];
			  [DYYYManager downloadMedia:url
					   mediaType:MediaTypeHeic
					  completion:^(BOOL success){
					  }];
		  }
	  }
	};
	newMenuItem1.trackerName = @"保存表情";
	AWEIMMessageComponentContext *context = (AWEIMMessageComponentContext *)currentCell.currentContext;
	if ([context.message isKindOfClass:%c(AWEIMGiphyMessage)]) {
		[newMenuItems addObject:newMenuItem1];
	}
	%orig(bubbleFrame, tapLocation, newMenuItems, moreEmoticon, cell, extra);
}

%end

%ctor {
    %init;

    // 动态获取 Swift 类并初始化对应的组
    Class commentHeaderGeneralClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderGeneralView");
    if (commentHeaderGeneralClass) {
        %init(CommentHeaderGeneralGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderGeneralView = commentHeaderGeneralClass);
    }

    Class commentHeaderGoodsClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderGoodsView");
    if (commentHeaderGoodsClass) {
        %init(CommentHeaderGoodsGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderGoodsView = commentHeaderGoodsClass);
    }

    Class commentHeaderTemplateClass = objc_getClass("AWECommentPanelHeaderSwiftImpl.CommentHeaderTemplateAnchorView");
    if (commentHeaderTemplateClass) {
        %init(CommentHeaderTemplateGroup, AWECommentPanelHeaderSwiftImpl_CommentHeaderTemplateAnchorView = commentHeaderTemplateClass);
    }

    Class tipsVCClass = objc_getClass("AWECommentPanelListSwiftImpl.CommentBottomTipsContainerViewController");
    if (tipsVCClass) {
        %init(CommentBottomTipsVCGroup, AWECommentPanelListSwiftImpl_CommentBottomTipsContainerViewController = tipsVCClass);
    }

    // 设置默认启用表情包下载功能
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYForceDownloadEmotion"];

    // 表情保存菜单钩子组
    %init(EnableStickerSaveMenu);
}
