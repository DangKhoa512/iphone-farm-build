export TARGET     := iphone:clang:latest:14.0
export ARCHS       = arm64
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = iphone-farm-server

iphone-farm-server_FILES          = src/main.m src/HTTPServer.m src/ScreenCapture.m src/DeviceInfo.m
iphone-farm-server_FRAMEWORKS     = Foundation UIKit CoreGraphics ImageIO
iphone-farm-server_CFLAGS         = -fobjc-arc -Isrc
iphone-farm-server_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS)/makefiles/tool.mk
