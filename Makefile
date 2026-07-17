.PHONY: build run test icon app

APP_DIR = .build/Stein.app

build:
	swift build

run:
	swift run Stein

test:
	swift run SteinCoreChecks

# 重新生成图标(画稿改动后执行)
icon:
	swift tools/generate_icon.swift Resources/AppIcon.iconset
	iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns

# 打包成带图标的 Stein.app(release 构建)
app:
	swift build -c release
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp .build/release/Stein "$(APP_DIR)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP_DIR)/Contents/"
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/"
	@echo "已生成 $(APP_DIR),可用 open $(APP_DIR) 启动"
