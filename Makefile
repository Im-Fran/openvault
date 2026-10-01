PREFIX ?= $(HOME)/.local
BUILD_DIR := build

.PHONY: test cli install-cli project app open dmg release clean

test:
	swift test

cli:
	swift build -c release --product ovault

install-cli: cli
	install -d $(PREFIX)/bin
	install -m 0755 .build/release/ovault $(PREFIX)/bin/ovault
	@echo "ovault installed to $(PREFIX)/bin (make sure it's on your PATH)"

project:
	cd App && xcodegen generate --quiet

app: project
	xcodebuild -project App/OpenVault.xcodeproj -scheme OpenVault -configuration Release \
		-derivedDataPath $(BUILD_DIR) -allowProvisioningUpdates -quiet build
	@echo "App: $(BUILD_DIR)/Build/Products/Release/OpenVault.app"

open: app
	open $(BUILD_DIR)/Build/Products/Release/OpenVault.app

## Unsigned-app DMG for a quick local check (fastlane, see .github/RELEASING.md)
dmg:
	bundle exec fastlane build signed:false
	bundle exec fastlane dmg

## Signed and notarized DMG + CLI into build/dist (needs fastlane/.env)
release:
	bundle exec fastlane release

clean:
	rm -rf .build $(BUILD_DIR) App/OpenVault.xcodeproj
