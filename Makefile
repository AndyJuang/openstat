.PHONY: build run app clean

build:
	swift build -c release 2>&1

run: build
	.build/release/MacPrism

app: build icon
	@rm -rf MacPrism.app
	@mkdir -p MacPrism.app/Contents/MacOS
	@mkdir -p MacPrism.app/Contents/Resources
	@cp .build/release/MacPrism MacPrism.app/Contents/MacOS/MacPrism
	@cp Info.plist               MacPrism.app/Contents/Info.plist
	@cp Assets/AppIcon.icns      MacPrism.app/Contents/Resources/AppIcon.icns
	@echo "✓ MacPrism.app 已建立"
	@echo "  執行方式: open MacPrism.app"

icon:
	@swift Assets/make_icon.swift Assets/AppIcon.iconset
	@iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns

clean:
	swift package clean
	rm -rf MacPrism.app
