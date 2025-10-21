# 遇到问题联系中文翻译作者：pxx917144686

# 使用 iPhoneOS15.6 SDK，支持 iOS 9.0 及以上
TARGET = iphone:15.6:9.0

# 支持的架构
ARCHS = armv7 arm64

# 名称和类型
LIBRARY_NAME = FLEX

# 配置为动态库
LIBRARY_TYPE = dynamic

# 设置输出路径
THEOS_LIBRARY_PATH = /Users/pxx917144686/theos/lib/iphone/rootless

# 添加必要的框架和库
$(LIBRARY_NAME)_FRAMEWORKS = Foundation UIKit CoreGraphics CoreFoundation
$(LIBRARY_NAME)_PRIVATE_FRAMEWORKS =
$(LIBRARY_NAME)_LIBRARIES = objc c++ system

# 编译设置
$(LIBRARY_NAME)_CFLAGS = -fobjc-arc -include flex_fishhook.h \
                 -DFLEX_LIVE_OBJECTS_CONTROLLER_IS_VIEW_CONTROLLER=1 \
                 -DFLEX_LIVE_OBJECTS_VIEW_CONTROLLER=FLEXLiveObjectsController \
                 -Wno-unsupported-availability-guard \
                 -Wno-unused-but-set-variable

# 添加警告抑制
$(LIBRARY_NAME)_CCFLAGS = -std=c++11 -Wno-unused-function -Wno-objc-missing-property-synthesis
$(LIBRARY_NAME)_OBJCFLAGS = -fobjc-arc
$(LIBRARY_NAME)_LDFLAGS += -Wl,-no_warn_inits

# 兼容性标志
$(LIBRARY_NAME)_CFLAGS += -miphoneos-version-min=9.0

# 包含源文件，使用 wildcard 只包含当前目录的文件
$(LIBRARY_NAME)_FILES = $(wildcard *.m *.mm) flex_fishhook.c

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
