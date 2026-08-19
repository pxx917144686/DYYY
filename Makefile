# 插件：显示编译成功，显示的信息
PACKAGE_IDENTIFIER = com.huami.dyyy
PACKAGE_NAME = DYYY++
PACKAGE_VERSION = 2.1-7++
PACKAGE_ARCHITECTURE = iphoneos-arm64
PACKAGE_REVISION = 1
PACKAGE_SECTION = Tweaks
PACKAGE_DEPENDS = firmware (>= 14.0), mobilesubstrate
PACKAGE_DESCRIPTION = DYYY （原作者：huami1314；魔改：pxx917144686）

# 插件：编译时，引用的信息
define Package/$(PACKAGE_IDENTIFIER)
  Package: com.huami.dyyy
  Name: DYYY++
  Version: 2.1-7++
  Architecture: iphoneos-arm64
  Author: pxx917144686
  Section: Tweaks
  Depends: firmware (>= 14.0), mobilesubstrate
endef

# 直接输出到根路径
export THEOS_PACKAGE_DIR = $(CURDIR)

# TARGET
ARCHS = arm64
TARGET = iphone:clang:latest:15.0
USE_SWIFT = 1

# 关闭严格错误检查和警告
export DEBUG = 0
export THEOS_STRICT_LOGOS = 0
export ERROR_ON_WARNINGS = 0
export LOGOS_DEFAULT_GENERATOR = internal

# Rootless 插件配置
export THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

# 目标进程
INSTALL_TARGET_PROCESSES = Aweme

# 引入 Theos 的通用设置
include $(THEOS)/makefiles/common.mk

# 插件名称
TWEAK_NAME = DYYY++

# 源代码文件
$(TWEAK_NAME)_FILES = Sources/Hooks/DYYYMainSupport.mm \
            Sources/Hooks/DYYYSpeedHooks.xm \
            Sources/Hooks/DYYYSettingsGestureHooks.xm \
            Sources/Hooks/DYYYStoryFeedHooks.xm \
            Sources/Hooks/DYYYFullScreenCommentHooks.xm \
            Sources/Hooks/DYYYCommentPanelHooks.xm \
            Sources/Hooks/DYYYAdFilterHooks.xm \
            Sources/Hooks/DYYYTabBarHooks.xm \
            Sources/Hooks/DYYYFeedLayoutHooks.xm \
            Sources/Hooks/DYYYLongPressPanelManagerHooks.xm \
            Sources/Hooks/DYYYPlayerInteractionHooks.xm \
            Sources/Hooks/DYYYCityTimestampHooks.xm \
            Sources/Hooks/DYYYIncognitoServiceHooks.xm \
            Sources/Hooks/DYYYAutoPlayHooks.xm \
            Sources/Hooks/DYYYSystemUIHooks.xm \
            Sources/Hooks/DYYYFeedHooks.xm \
            Sources/Hooks/DYYYPlaybackHooks.xm \
            Sources/Hooks/DYYYCommentHooks.xm \
            Sources/Hooks/DYYYLiveHooks.xm \
            Sources/Hooks/DYYYServiceHooks.xm \
            Sources/Hooks/DYYYNavigationHooks.xm \
            Sources/Core/DYYYTheme.m \
            Sources/Core/DYYYGlass.m \
            Sources/Core/DYYYUtils.m \
            Sources/Core/DYYYUtilsConfig.m \
            Sources/Core/DYYYUtilsTraversal.m \
            Sources/Core/DYYYUtilsAdFilter.m \
            Sources/Core/DYYYUtilsMedia.m \
            Sources/Core/DYYYPaths.m \
            Sources/Core/DYYYFishhook.c \
            Sources/Core/DYYYSDKPatch.m \
            Sources/Hooks/DYYYFloatSpeedButton.xm \
            Sources/Hooks/DYYYFloatClearButton.xm \
            Sources/Hooks/DYYYPlayInteractionDoubleTapHooks.xm \
            Sources/Hooks/DYYYPlayInteractionMenuHooks.xm \
            Sources/Hooks/DYYYPlayInteractionVisualHooks.xm \
            Sources/Views/DYYYMenuComponents.m \
            Sources/Hooks/DYYYLongPressPanelHooks.xm \
            Sources/Hooks/DYYYLongPressPanelCellHooks.xm \
            Sources/Hooks/DYYYLongPressPanelSupport.m \
            Sources/Manager/DYYYCityManager.m \
            Sources/Manager/DYYYCityManagerGeoData.m \
            Sources/Manager/DYYYCityManagerAddress.m \
            Sources/Manager/DYYYCityManagerSelector.m \
            Sources/Manager/DYYYManager.m \
            Sources/Manager/DYYYManagerUI.m \
            Sources/Manager/DYYYManagerDownload.m \
            Sources/Manager/DYYYManagerCompose.m \
            Sources/Manager/DYYYManagerComment.m \
            Sources/Manager/DYYYSwitchManager.m \
            Sources/Manager/DYYYScreenshot.m \
            Sources/Settings/DYYYSettingViewController.m \
            Sources/Settings/DYYYSettingViewControllerAppearance.m \
            Sources/Settings/DYYYSettingViewControllerBackup.m \
            Sources/Settings/DYYYSettingViewControllerTable.m \
            Sources/Settings/DYYYSettingViewControllerPresentation.m \
            Sources/Settings/DYYYSettingViewControllerActions.m \
            Sources/Settings/DYYYSettingItem.m \
            Sources/Settings/DYYYSettingSectionProvider.m \
            Sources/Settings/DYYYSettingUIComponents.m \
            Sources/Views/DYYYToast.m \
            Sources/Views/DYYYBottomAlertView.m \
            Sources/Views/DYYYConfirmCloseView.m \
            Sources/Views/DYYYCustomInputView.m \
            Sources/Views/DYYYFilterSettingsView.m \
            Sources/Views/DYYYKeywordListView.m \
            Sources/Views/DYYYPipContainerView.m \
            Sources/Views/DYYYPipManager.m \
            Sources/Diagnostics/DYYYSelfTest.m \
            Sources/Diagnostics/DYYYCrashCatcher.m
$(TWEAK_NAME)_FILES += Sources/Hooks/DYYYABTestHook.xm Sources/Hooks/DYYYSocialStatsHooks.xm Sources/Hooks/DYYYVideoStatsHooks.xm Sources/Hooks/DYYYVideoStatsMenu.mm Sources/Hooks/DYYYVideoStatsEditor.mm Sources/Hooks/AWEPlayerPlayControlHandler.xm Sources/Hooks/AFDPrivacyHalfScreenViewController.xm Sources/Hooks/UITextField.xm Sources/Hooks/AWEElementStackView.xm Sources/Hooks/AWELeftSideBarViewController.xm Sources/Hooks/AWEFeedProgressSlider.xm Sources/Hooks/AWEPOIDetailUGCPhotosPreviewViewController.xm
$(TWEAK_NAME)_FILES += Sources/Hooks/DYYYSystemVersionSpoof.xm

# DYYY 内联玻璃、音频与评论体验模块
$(TWEAK_NAME)_FILES += Sources/Features/DYYYCommentGlass.xm Sources/Features/DYYYCommentDanmaku.xm Sources/Features/DYYYCommentBottomBar.xm Sources/Features/DYYYCommentMediaCleaner.xm
$(TWEAK_NAME)_FILES += Sources/Features/DYYYSharePanelGlass.xm Sources/Features/DYYYInnerNotificationGlass.xm Sources/Features/DYYYGlassTabBar.xm Sources/Features/DYYYAudioVisualizer.xm Sources/Features/DYYYDetailBottomBar.xm
$(TWEAK_NAME)_FILES += Sources/Audio/DYYYAudioTap.mm Sources/Audio/DYYYAudioReport.mm Sources/Audio/DYYYAudioAnalysis.mm

# ===== 发布版 / 调试版开关 =====
# make            调试版（默认）：主功能 + FLEX + Capstone 反汇编 + 逆向助手 + 一键自检，dylib 约 14.6MB
# make DYYY_RELEASE=1  发布版：主功能 + 一键自检（唯一保留的调试功能），dylib 约 1.65MB
#   排除 FLEX 全部 / Capstone / 逆向助手 Decrypt / flex_fishhook；长按面板 FLEX 菜单与设置页调试入口随之隐藏
ifneq ($(DYYY_RELEASE),1)
# 调试版：添加 FLEX 源文件
FLEX_FILES := $(shell find FLEX -name '*.m' -o -name '*.mm' | grep -v 'FLEX/x/retdec' | grep -v 'FLEX/x/capstone' | grep -v 'UCDecompiler')
$(TWEAK_NAME)_FILES += $(FLEX_FILES) FLEX/flex_fishhook.c

# Capstone 源文件（使用 FLEX 自带的 iOS 版本，用于反汇编）
CAPSTONE_CORE := $(shell find FLEX/x/capstone -maxdepth 1 -name "*.c")
CAPSTONE_ARM := $(shell find FLEX/x/capstone/arch/ARM -name "*.c")
CAPSTONE_ARM64 := $(shell find FLEX/x/capstone/arch/AArch64 -name "*.c")
$(TWEAK_NAME)_FILES += $(CAPSTONE_CORE) $(CAPSTONE_ARM) $(CAPSTONE_ARM64)
endif

# 编译标志
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -w
# 发布版宏（必须在基础 CFLAGS 赋值之后追加，否则被覆盖）
ifeq ($(DYYY_RELEASE),1)
$(TWEAK_NAME)_CFLAGS += -DDYYY_RELEASE_BUILD=1
endif
# 解决class_ro_t指针签名警告
$(TWEAK_NAME)_CFLAGS += -Wno-deprecated-declarations -Wno-sign-compare -Wno-pointer-sign
# 统一启用class_ro_t指针签名，避免混合编译警告
$(TWEAK_NAME)_CFLAGS += -fobjc-runtime=ios-15.0
# Capstone 架构支持
$(TWEAK_NAME)_CFLAGS += -DCAPSTONE_HAS_ARM -DCAPSTONE_HAS_AARCH64 -DCAPSTONE_USE_SYS_DYN_MEM

# 保留内部生成器选项
$(TWEAK_NAME)_LOGOS_DEFAULT_GENERATOR = internal

# 框架
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security Metal MetalKit CoreImage SwiftUI Combine AudioToolbox AVFAudio AVFoundation CoreMedia MediaToolbox Accelerate
# 链接器标志，解决class_ro_t指针签名警告
$(TWEAK_NAME)_LDFLAGS += -Xlinker -no_adhoc_codesign -Xlinker -objc_abi_version -Xlinker 2
# 统一class_ro_t指针签名设置，解决链接警告
$(TWEAK_NAME)_LDFLAGS += -Xlinker -no_warn_duplicate_libraries
# 抑制class_ro_t指针签名不一致警告
$(TWEAK_NAME)_LDFLAGS += -Wl,-w

# FLEX 库和头文件路径
$(TWEAK_NAME)_LIBRARIES = 
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)
$(TWEAK_NAME)_CFLAGS += -I$(THEOS)/include
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/FLEX
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Core
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Hooks
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Manager
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Settings
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Audio
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Views
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Features
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Diagnostics
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/Sources/Headers
$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/FLEX/x/capstone/include
$(TWEAK_NAME)_CCFLAGS = -std=c++17 -fno-rtti -fno-modules
$(TWEAK_NAME)_CCFLAGS += -I$(THEOS_PROJECT_DIR)/FLEX/x/capstone/include

# 编译标志
$(TWEAK_NAME)_CFLAGS += -Wno-everything
$(TWEAK_NAME)_CFLAGS += -Wno-incomplete-implementation
$(TWEAK_NAME)_CFLAGS += -Wno-protocol

# 预处理变量
$(TWEAK_NAME)_CFLAGS += -DDOKIT_FULL_BUILD=1
$(TWEAK_NAME)_CFLAGS += -DDORAEMON_FULL_BUILD=1

include $(THEOS_MAKE_PATH)/tweak.mk
