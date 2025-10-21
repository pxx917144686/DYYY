#import "DYYYSettingsHelper.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYImagePickerDelegate.h"
#import "DYYYUtils.h"

#import "DYYYAboutDialogView.h"
#import "DYYYCustomInputView.h"
#import "DYYYIconOptionsDialogView.h"

@implementation DYYYSettingsHelper

// 获取正确的 NSUserDefaults 实例
+ (NSUserDefaults *)getCorrectUserDefaults {
    static NSUserDefaults *correctDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 获取当前应用的 Bundle ID
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        
        // 如果是抖音应用，使用抖音的 NSUserDefaults 域
        if ([bundleId containsString:@"com.ss.iphone.ugc.Aweme"] || 
            [bundleId isEqualToString:@"com.ss.iphone.ugc.Aweme"] ||
            [bundleId isEqualToString:@"com.ss.iphone.ugc.aweme.lite"] ||
            [bundleId isEqualToString:@"com.ss.iphone.ugc.Aweme.beta"] ||
            [bundleId isEqualToString:@"com.ss.iphone.ugc.Aweme.internal"]) {
            
            // 尝试使用主要的抖音 Bundle ID
            correctDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ss.iphone.ugc.Aweme"];
            
            // 如果失败，回退到标准 NSUserDefaults
            if (!correctDefaults) {
                correctDefaults = [NSUserDefaults standardUserDefaults];
            }
        } else {
            // 非抖音应用，使用标准 NSUserDefaults
            correctDefaults = [NSUserDefaults standardUserDefaults];
        }
    });
    
    return correctDefaults;
}

// 获取用户默认设置
+ (bool)getUserDefaults:(NSString *)key {
    return [[self getCorrectUserDefaults] boolForKey:key];
}

// 设置用户默认设置
+ (void)setUserDefaults:(id)object forKey:(NSString *)key {
    NSUserDefaults *defaults = [self getCorrectUserDefaults];
    [defaults setObject:object forKey:key];
    [defaults synchronize];
    
    // 发送设置变更通知，让相关模块能够及时更新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYSettingChanged"
                                                        object:nil
                                                      userInfo:@{@"key": key, @"value": object ?: @""}];
}

// 显示自定义关于弹窗
+ (void)showAboutDialog:(NSString *)title message:(NSString *)message onConfirm:(void (^)(void))onConfirm {
    DYYYAboutDialogView *aboutDialog = [[DYYYAboutDialogView alloc] initWithTitle:title message:message];
    aboutDialog.onConfirm = onConfirm;
    [aboutDialog show];
}

// 显示文本输入弹窗（完整版本）
+ (void)showTextInputAlert:(NSString *)title defaultText:(NSString *)defaultText placeholder:(NSString *)placeholder onConfirm:(void (^)(NSString *text))onConfirm onCancel:(void (^)(void))onCancel {
    DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:title defaultText:defaultText placeholder:placeholder];
    inputView.onConfirm = onConfirm;
    inputView.onCancel = onCancel;
    [inputView show];
}

// 显示文本输入弹窗（无placeholder版本）
+ (void)showTextInputAlert:(NSString *)title defaultText:(NSString *)defaultText onConfirm:(void (^)(NSString *text))onConfirm onCancel:(void (^)(void))onCancel {
    [self showTextInputAlert:title defaultText:defaultText placeholder:nil onConfirm:onConfirm onCancel:onCancel];
}

// 显示文本输入弹窗
+ (void)showTextInputAlert:(NSString *)title onConfirm:(void (^)(NSString *text))onConfirm onCancel:(void (^)(void))onCancel {
    [self showTextInputAlert:title defaultText:nil placeholder:nil onConfirm:onConfirm onCancel:onCancel];
}

+ (NSDictionary *)settingsDependencyConfig {
    static NSDictionary *config = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
      config = @{
          // ===== 依赖关系配置 =====
          @"dependencies" : @{
              // 普通依赖：当源设置开启时，目标设置项可用
              @"DYYYEnableDanmuColor" : @[ @"DYYYDanmuColor" ],
              @"DYYYEnableArea" : @[ @"DYYYGeonamesUsername", @"DYYYLabelColor", @"DYYYEnableRandomGradient" ],
              @"DYYYShowScheduleDisplay" : @[ @"DYYYScheduleStyle", @"DYYYProgressLabelColor", @"DYYYTimelineVerticalPosition" ],
              @"DYYYEnableNotificationTransparency" : @[ @"DYYYNotificationCornerRadius" ],
              @"DYYYEnableFloatSpeedButton" : @[ @"DYYYAutoRestoreSpeed", @"DYYYSpeedButtonShowX", @"DYYYSpeedButtonSize", @"DYYYSpeedSettings" ],
              @"DYYYEnableFloatClearButton" : @[
                  @"DYYYClearButtonIcon", @"DYYYEnableFloatClearButtonSize", @"DYYYRemoveTimeProgress", @"DYYYHideTimeProgress", @"DYYYHideDanmaku", @"DYYYHideSlider", @"DYYYHideTabBar",
                  @"DYYYHideSpeed", @"DYYYHideChapter"
              ],
              @"DYYYLongPressDownload" : @[ @"DYYYEnableModernPanel", @"DYYYLongPressPanelBlur", @"DYYYLongPressPanelDark" ],
              @"DYYYEnableModernPanel" : @[ @"DYYYLongPressPanelBlur", @"DYYYLongPressPanelDark" ],
              @"DYYYEnableDoubleTapMaster" : @[ @"DYYYDoubleTapDownload", @"DYYYDoubleTapDownloadAudio", @"DYYYDoubleInterfaceDownload", @"DYYYDoubleTapCopyDesc", @"DYYYDoubleTapComment", @"DYYYDoubleTapLike", @"DYYYDoubleTapPip", @"DYYYDoubleCreateVideo", @"DYYYDoubleTapshowDislikeOnVideo", @"DYYYDoubleTapshowSharePanel", @"DYYYListViewMode" ],
              // FLEX 调试功能开关 
              @"DYYYEnableFLEX" : @[],
              // PIP 小窗播放功能开关
              @"DYYYLongPressPip" : @[],
          },

          // ===== 条件依赖配置 =====
          // 一些设置项依赖于多个其他设置项的复杂条件
          @"conditionalDependencies" : @{
              @"DYYYCommentBlurTransparent" : @{@"condition" : @"OR", @"settings" : @[ @"DYYYEnableCommentBlur", @"DYYYEnableNotificationTransparency" ]},
          },

          // ===== 冲突配置 =====
          // 当源设置项开启时，会自动关闭目标设置项
          @"conflicts" : @{
              @"DYYYEnableDoubleOpenComment" : @[ @"DYYYEnableDoubleTapMaster" ],
              @"DYYYEnableDoubleTapMaster" : @[ @"DYYYEnableDoubleOpenComment" ],
              @"DYYYRemoveTimeProgress" : @[ @"DYYYHideTimeProgress" ],
              @"DYYYHideTimeProgress" : @[ @"DYYYRemoveTimeProgress" ],
              @"DYYYHideLOTAnimationView" : @[ @"DYYYHideFollowPromptView" ],
              @"DYYYHideFollowPromptView" : @[ @"DYYYHideLOTAnimationView" ],
              @"DYYYSkipLive" : @[ @"DYYYSkipAllLive" ],
              @"DYYYSkipAllLive" : @[ @"DYYYSkipLive" ],
              @"DYYYHideEntry" : @[ @"DYYYRemoveEntry" ],
              @"DYYYRemoveEntry" : @[ @"DYYYHideEntry" ],
          },

          // ===== 互斥激活配置 =====
          // 当源设置项关闭时，目标设置项才能激活
          @"mutualExclusions" : @{@"DYYYDanmuRainbowRotating" : @[ @"DYYYDanmuColor" ], @"DYYYEnableRandomGradient" : @[ @"DYYYLabelColor" ]},

          // ===== 值依赖配置 =====
          // 基于字符串值的依赖关系
          @"valueDependencies" :
              @{@"DYYYInterfaceDownload" : @{@"valueType" : @"string", @"condition" : @"isNotEmpty", @"dependents" : @[ @"DYYYShowAllVideoQuality", @"DYYYDoubleInterfaceDownload" ]}},

          // ===== 同步配置 =====
          // 当源设置项打开时目标设置项也同步打开，当源设置项关闭时目标设置项也同步关闭
          @"synchronizations" : @{
              @"DYYYLongPressPanelBlur" : @[ @"DYYYLongPressPanelDark" ],
              @"DYYYLongPressPanelDark" : @[ @"DYYYLongPressPanelBlur" ],
          },
      };
    });

    return config;
}

static BOOL settingActive(NSString *identifier) {
    id val = [[DYYYSettingsHelper getCorrectUserDefaults] objectForKey:identifier];
    if ([val isKindOfClass:[NSNumber class]]) {
        return [val boolValue];
    } else if ([val isKindOfClass:[NSString class]]) {
        return ((NSString *)val).length > 0;
    }
    return NO;
}

static void collectSettingsVCs(UIViewController *vc, NSMutableArray *array) {
    if ([vc isKindOfClass:NSClassFromString(@"AWESettingBaseViewController")]) {
        [array addObject:vc];
    }
    for (UIViewController *child in vc.childViewControllers) {
        collectSettingsVCs(child, array);
    }
    if (vc.presentedViewController) {
        collectSettingsVCs(vc.presentedViewController, array);
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        for (UIViewController *c in ((UINavigationController *)vc).viewControllers) {
            collectSettingsVCs(c, array);
        }
    }
}

static NSArray *allSettingsViewControllers(void) {
    UIWindow *window = [DYYYUtils getActiveWindow];
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }
    NSMutableArray *result = [NSMutableArray array];
    if (window.rootViewController) {
        collectSettingsVCs(window.rootViewController, result);
    }
    return result;
}

// 原版双击菜单项目关联的复杂依赖处理逻辑已删除
// 现在使用 AWEPlayInteractionViewController.xm 中的现代化实现

+ (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict {
    return [self createSettingItem:dict cellTapHandlers:nil];
}

+ (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict cellTapHandlers:(NSMutableDictionary *)cellTapHandlers {
    AWESettingItemModel *item = [[NSClassFromString(@"AWESettingItemModel") alloc] init];
    item.identifier = dict[@"identifier"];
    item.title = dict[@"title"];
    item.subTitle = dict[@"subTitle"];

    NSString *savedDetail = [[DYYYSettingsHelper getCorrectUserDefaults] objectForKey:item.identifier];
    NSString *placeholder = dict[@"detail"];
    item.detail = savedDetail ?: @"";

    item.svgIconImageName = dict[@"imageName"];
    item.cellType = [dict[@"cellType"] integerValue];
    item.colorStyle = 0;
    item.isEnable = YES;
    item.isSwitchOn = [self getUserDefaults:item.identifier];

    if ((item.cellType == 20 || item.cellType == 26 || item.cellType == 38) && cellTapHandlers != nil) {
        cellTapHandlers[item.identifier] = ^{
          if (!item.isEnable)
              return;

          [self showTextInputAlert:item.title
                       defaultText:item.detail
                       placeholder:placeholder
                         onConfirm:^(NSString *text) {
                           [self setUserDefaults:text forKey:item.identifier];
                           item.detail = text;
                           [item refreshCell];
                         }
                          onCancel:nil];
        };
        item.cellTappedBlock = cellTapHandlers[item.identifier];
    } else if (item.cellType == 6 || item.cellType == 37) {
        __weak AWESettingItemModel *weakItem = item;
        item.switchChangedBlock = ^{
          __strong AWESettingItemModel *strongItem = weakItem;
          if (strongItem) {
              if (!strongItem.isEnable)
                  return;
              BOOL isSwitchOn = !strongItem.isSwitchOn;
              strongItem.isSwitchOn = isSwitchOn;
              [self setUserDefaults:@(isSwitchOn) forKey:strongItem.identifier];
          }
        };
    }

    return item;
}

#pragma mark

extern void showDYYYSettingsVC(UIViewController *rootVC);
extern void *kViewModelKey;

static void showIconOptionsDialog(NSString *title, UIImage *previewImage, NSString *saveFilename, void (^onClear)(void), void (^onSelect)(void)) {
    DYYYIconOptionsDialogView *optionsDialog = [[DYYYIconOptionsDialogView alloc] initWithTitle:title previewImage:previewImage];
    optionsDialog.onClear = onClear;
    optionsDialog.onSelect = onSelect;
    [optionsDialog show];
}

+ (AWESettingItemModel *)createIconCustomizationItemWithIdentifier:(NSString *)identifier title:(NSString *)title svgIcon:(NSString *)svgIconName saveFile:(NSString *)saveFilename {
    AWESettingItemModel *item = [[NSClassFromString(@"AWESettingItemModel") alloc] init];
    item.identifier = identifier;
    item.title = title;

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
    NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
    item.detail = fileExists ? @"已设置" : @"默认";

    item.type = 0;
    item.svgIconImageName = svgIconName;
    item.cellType = 26;
    item.colorStyle = 0;
    item.isEnable = YES;

    __weak AWESettingItemModel *weakItem = item;
    item.cellTappedBlock = ^{
      if (![[NSFileManager defaultManager] fileExistsAtPath:dyyyFolderPath]) {
          [[NSFileManager defaultManager] createDirectoryAtPath:dyyyFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
      }

      UIViewController *topVC = topView();

      UIImage *previewImage = nil;
      if (fileExists) {
          previewImage = [UIImage imageWithContentsOfFile:imagePath];
      }

      showIconOptionsDialog(
          title, previewImage, saveFilename,
          ^{
            if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
                NSError *error = nil;
                [[NSFileManager defaultManager] removeItemAtPath:imagePath error:&error];
                if (!error) {
                    weakItem.detail = @"默认";
                    [weakItem refreshCell];
                }
            }
          },
          ^{
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            picker.allowsEditing = NO;
            picker.mediaTypes = @[ @"public.image" ];

            DYYYImagePickerDelegate *pickerDelegate = [[DYYYImagePickerDelegate alloc] init];
            pickerDelegate.completionBlock = ^(NSDictionary *info) {
              NSURL *originalImageURL = info[UIImagePickerControllerImageURL];
              if (!originalImageURL) {
                  originalImageURL = info[UIImagePickerControllerReferenceURL];
              }
              if (originalImageURL) {
                  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                  NSString *dyyyFolderPath = [documentsPath stringByAppendingPathComponent:@"DYYY"];
                  NSString *imagePath = [dyyyFolderPath stringByAppendingPathComponent:saveFilename];

                  NSData *imageData = [NSData dataWithContentsOfURL:originalImageURL];
                  const char *bytes = (const char *)imageData.bytes;
                  BOOL isGIF = (imageData.length >= 6 && (memcmp(bytes, "GIF87a", 6) == 0 || memcmp(bytes, "GIF89a", 6) == 0));
                  if (isGIF) {
                      [imageData writeToFile:imagePath atomically:YES];
                  } else {
                      UIImage *selectedImage = [UIImage imageWithData:imageData];
                      imageData = UIImagePNGRepresentation(selectedImage);
                      [imageData writeToFile:imagePath atomically:YES];
                  }

                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    weakItem.detail = @"已设置";
                    [weakItem refreshCell];
                  });
              }
            };

            static char kDYYYPickerDelegateKey;
            picker.delegate = pickerDelegate;
            objc_setAssociatedObject(picker, &kDYYYPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [topVC presentViewController:picker animated:YES completion:nil];
          });
    };

    return item;
}

+ (AWESettingSectionModel *)createSectionWithTitle:(NSString *)title items:(NSArray *)items {
    return [self createSectionWithTitle:title footerTitle:nil items:items];
}

+ (AWESettingSectionModel *)createSectionWithTitle:(NSString *)title footerTitle:(NSString *)footerTitle items:(NSArray *)items {
    AWESettingSectionModel *section = [[NSClassFromString(@"AWESettingSectionModel") alloc] init];
    section.sectionHeaderTitle = title;
    section.sectionHeaderHeight = 40;
    section.sectionFooterTitle = footerTitle;
    section.useNewFooterLayout = YES;
    section.type = 0;
    section.itemArray = items;
    return section;
}

+ (AWESettingBaseViewController *)createSubSettingsViewController:(NSString *)title sections:(NSArray *)sectionsArray {
    AWESettingBaseViewController *settingsVC = [[NSClassFromString(@"AWESettingBaseViewController") alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([settingsVC.view isKindOfClass:[UIView class]]) {
          Class navBarClass = NSClassFromString(@"AWENavigationBar");
          for (UIView *subview in settingsVC.view.subviews) {
              if (navBarClass && [subview isKindOfClass:navBarClass]) {
                  id navigationBar = subview;
                  if ([navigationBar respondsToSelector:@selector(titleLabel)]) {
                      UILabel *label = [navigationBar valueForKey:@"titleLabel"];
                      label.text = title;
                  }
                  break;
              }
          }
      }
    });

    AWESettingsViewModel *viewModel = [[NSClassFromString(@"AWESettingsViewModel") alloc] init];
    viewModel.colorStyle = 0;
    viewModel.sectionDataArray = sectionsArray;
    objc_setAssociatedObject(settingsVC, &kViewModelKey, viewModel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return settingsVC;
}

+ (UIViewController *)findViewController:(UIResponder *)responder {
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

+ (void)openSettingsWithViewController:(UIViewController *)vc {
    showDYYYSettingsVC(vc);
}

+ (void)openSettingsFromView:(UIView *)view {
    UIViewController *currentVC = [self findViewController:view];
    if ([currentVC isKindOfClass:NSClassFromString(@"AWELeftSideBarViewController")]) {
        [self openSettingsWithViewController:currentVC];
    }
}

+ (void)addTapGestureToView:(UIView *)view target:(id)target {
    view.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(openDYYYSettings)];
    [view addGestureRecognizer:tapGesture];
}

+ (void)showSearchSettingsPage:(UIViewController *)rootVC {
    // 创建一个简单的搜索提示页面
    Class settingVCClass = NSClassFromString(@"AWESettingBaseViewController");
    AWESettingBaseViewController *searchVC = [[settingVCClass alloc] init];
    searchVC.title = @"搜索设置";
    
    // 创建搜索提示项
    NSMutableArray *searchItems = [NSMutableArray array];
    
    // 添加各个分类的快速入口
    NSDictionary *categories = @{
        @"基本设置": @"DYYYBasicSettings",
        @"交互设置": @"DYYYInteractionSettings", 
        @"视频设置": @"DYYYVideoSettings",
        @"界面设置": @"DYYYUISettings",
        @"双击菜单": @"DYYYDoubleTapMenuSettings",
        @"LiquidGlass": @"DYYYLiquidGlassSettings",
        @"关于": @"DYYYAboutSettings"
    };
    
    for (NSString *title in categories.allKeys) {
        NSDictionary *itemDict = @{
            @"identifier": categories[title],
            @"title": [NSString stringWithFormat:@"📂 %@", title],
            @"subTitle": [NSString stringWithFormat:@"查看%@相关功能", title],
            @"type": @0,
            @"cellType": @26,
            @"svgIconImageName": @"ic_folder_outlined_20"
        };
        
        AWESettingItemModel *item = [self createSettingItem:itemDict];
        if (item) {
            [searchItems addObject:item];
        }
    }
    
    // 创建搜索分区
    AWESettingSectionModel *searchSection = [self createSectionWithTitle:@"快速导航" 
                                                              footerTitle:@"点击分类快速查找相关设置项" 
                                                                    items:searchItems];
    
    // 使用setValue来设置sectionsArray属性
    [searchVC setValue:@[searchSection] forKey:@"sectionsArray"];
    
    // 创建导航控制器并推送
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:searchVC];
    [rootVC presentViewController:navController animated:YES completion:nil];
}

+ (NSArray *)getAllSettingsItems {
    // 返回空数组，暂时不实现复杂的搜索功能
    return @[];
}

@end
