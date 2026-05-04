.PHONY: build run app clean

build:
	swift build -c release 2>&1

run: build
	.build/release/OpenStat

app: build icon
	@rm -rf OpenStat.app
	@mkdir -p OpenStat.app/Contents/MacOS
	@mkdir -p OpenStat.app/Contents/Resources
	@cp .build/release/OpenStat OpenStat.app/Contents/MacOS/OpenStat
	@cp Info.plist               OpenStat.app/Contents/Info.plist
	@cp Assets/AppIcon.icns      OpenStat.app/Contents/Resources/AppIcon.icns
	@echo "✓ OpenStat.app 已建立"
	@echo "  執行方式: open OpenStat.app"

icon:
	@swift Assets/make_icon.swift Assets/AppIcon.iconset
	@iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns

clean:
	swift package clean
	rm -rf OpenStat.app
