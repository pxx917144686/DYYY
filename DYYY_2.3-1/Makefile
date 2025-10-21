export DEBUG = 0
export THEOS_STRICT_LOGOS = 0
export ERROR_ON_WARNINGS = 0
export LOGOS_DEFAULT_GENERATOR = internal

# Rootless 无根
export THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

# 直接输出到根路径
export THEOS_PACKAGE_DIR = $(CURDIR)

# 设置工具路径
export PATH := $(CURDIR):$(PATH)

# 支持iOS 15.0以上版本
ARCHS = arm64
TARGET = iphone:clang:latest:15.0

# 引入 Theos 的通用设置
include $(THEOS)/makefiles/common.mk

# 插件名称
TWEAK_NAME = DYYY

# 源代码文件 - 使用动态关联
C_SOURCES = $(shell find . -name "*.c" -not -path "./.*")
OBJC_SOURCES = $(shell find . -name "*.m" -not -path "./.*")
OBJCPP_SOURCES = $(shell find . -name "*.mm" -not -path "./.*")
XM_SOURCES = $(shell find . -name "*.xm" -not -path "./.*")
SWIFT_SOURCES = $(shell find . -name "*.swift" -not -path "./.*")

$(TWEAK_NAME)_FILES = $(C_SOURCES) $(OBJC_SOURCES) $(OBJCPP_SOURCES) $(XM_SOURCES) $(SWIFT_SOURCES)
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -w -Wno-deprecated-declarations

# 库搜索路径和头文件路径
$(TWEAK_NAME)_LIBRARY_SEARCH_PATHS = $(THEOS_PROJECT_DIR)/libs
$(TWEAK_NAME)_HEADER_SEARCH_PATHS = $(THEOS_PROJECT_DIR)/libs/include
$(TWEAK_NAME)_CFLAGS += -I$($(TWEAK_NAME)_HEADER_SEARCH_PATHS)

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreFoundation CoreAudio SwiftUI
$(TWEAK_NAME)_LDFLAGS = -L$($(TWEAK_NAME)_LIBRARY_SEARCH_PATHS) -lwebp -weak_framework AVFAudio
$(TWEAK_NAME)_SWIFTFLAGS = -swift-version 5

# 链接库
$(TWEAK_NAME)_LIBRARIES = 

# 目标进程
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS_MAKE_PATH)/tweak.mk

# 清理 packages 目录
clean::
	@echo -e "\033[31m==>\033[0m Cleaning packages…"
	@rm -rf .theos packages

# 编译完成后的处理
after-package::
	@echo -e "\033[32m==>\033[0m Packaging complete for rootless environment."