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
$(TWEAK_NAME)_FILES = DYYY.xm \
            DYYYFloatSpeedButton.xm \
            DYYYFloatClearButton.xm \
            AWEPlayInteractionViewController.xm \
            AWEModernLongPressPanelTableViewController.xm \
            DYYYCityManager.m \
            DYYYManager.m \
            DYYYSettingViewController.m \
            DYYYSwitchManager.m \
            DYYYToast.m \
            DYYYBottomAlertView.m \
            DYYYUtils.m
$(TWEAK_NAME)_FILES += DYYYABTestHook.xm DYYYScreenshot.m DYYYSocialStats.xm AWEPlayerPlayControlHandler.xm AFDPrivacyHalfScreenViewController.xm UITextField.xm AWEElementStackView.xm AWELeftSideBarViewController.xm AWEFeedProgressSlider.xm AWEPOIDetailUGCPhotosPreviewViewController.xm
$(TWEAK_NAME)_FILES += DYYYConfirmCloseView.m DYYYCustomInputView.m DYYYFilterSettingsView.m DYYYKeywordListView.m DYYYPipPlayer.m
$(TWEAK_NAME)_FILES += DYYYSystemVersionSpoof.xm

# Swift 源文件
$(TWEAK_NAME)_FILES += DYYYSDKPatch.m

# 添加 FLEX 源文件
FLEX_FILES := $(shell find FLEX -name '*.m' -o -name '*.mm' | grep -v 'FLEX/x/retdec' | grep -v 'FLEX/x/capstone' | grep -v 'UCDecompiler')
$(TWEAK_NAME)_FILES += $(FLEX_FILES) FLEX/flex_fishhook.c

# Capstone 源文件（使用 FLEX 自带的 iOS 版本，用于反汇编）
CAPSTONE_CORE := $(shell find FLEX/x/capstone -maxdepth 1 -name "*.c")
CAPSTONE_ARM := $(shell find FLEX/x/capstone/arch/ARM -name "*.c")
CAPSTONE_ARM64 := $(shell find FLEX/x/capstone/arch/AArch64 -name "*.c")
$(TWEAK_NAME)_FILES += $(CAPSTONE_CORE) $(CAPSTONE_ARM) $(CAPSTONE_ARM64)

# 编译标志
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -w
# 解决class_ro_t指针签名警告
$(TWEAK_NAME)_CFLAGS += -Wno-deprecated-declarations -Wno-sign-compare -Wno-pointer-sign
# 统一启用class_ro_t指针签名，避免混合编译警告
$(TWEAK_NAME)_CFLAGS += -fobjc-runtime=ios-15.0
# Capstone 架构支持
$(TWEAK_NAME)_CFLAGS += -DCAPSTONE_HAS_ARM -DCAPSTONE_HAS_AARCH64 -DCAPSTONE_USE_SYS_DYN_MEM

# 保留内部生成器选项
$(TWEAK_NAME)_LOGOS_DEFAULT_GENERATOR = internal

# 框架
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Security Metal MetalKit CoreImage SwiftUI Combine
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