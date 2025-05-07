# 遇到问题联系中文翻译作者：pxx917144686
TARGET := iphone:15.6:15.6
ARCHS = arm64 arm64e

# 名称和类型
LIBRARY_NAME = FLEX

# 配置为动态库
LIBRARY_TYPE = dynamic

# 设置输出路径
THEOS_LIBRARY_PATH = /Users/pxx917144686/theos/lib/iphone/rootless

# 添加必要的框架和库
$(LIBRARY_NAME)_FRAMEWORKS = Foundation UIKit CoreGraphics CoreFoundation
$(LIBRARY_NAME)_PRIVATE_FRAMEWORKS = LoggingSupport

# 系统库
$(LIBRARY_NAME)_LIBRARIES = system

# 编译设置
$(LIBRARY_NAME)_CFLAGS = -fobjc-arc -include flex_fishhook.h \
                 -DFLEX_LIVE_OBJECTS_CONTROLLER_IS_VIEW_CONTROLLER=1 \
                 -DFLEX_LIVE_OBJECTS_VIEW_CONTROLLER=FLEXLiveObjectsController

# 添加警告抑制
$(LIBRARY_NAME)_CCFLAGS = -std=c++11 -Wno-unused-function -Wno-objc-missing-property-synthesis
$(LIBRARY_NAME)_OBJCFLAGS = -fobjc-arc

# 包含所有源文件 
$(LIBRARY_NAME)_FILES = $(shell find . -name '*.m' -o -name '*.mm')
$(LIBRARY_NAME)_FILES += flex_fishhook.c

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk