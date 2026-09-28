PREFIX ?= $(HOME)/.local
BUILD_DIR := build

.PHONY: test cli install-cli project app open clean

test:
	swift test

cli:
	swift build -c release --product ovault

install-cli: cli
	install -d $(PREFIX)/bin
	install -m 0755 .build/release/ovault $(PREFIX)/bin/ovault
	@echo "ovault instalado en $(PREFIX)/bin (asegúrate de tenerlo en tu PATH)"

project:
	cd App && xcodegen generate --quiet

app: project
	xcodebuild -project App/OpenVault.xcodeproj -scheme OpenVault -configuration Release \
		-derivedDataPath $(BUILD_DIR) -allowProvisioningUpdates -quiet build
	@echo "App: $(BUILD_DIR)/Build/Products/Release/OpenVault.app"

open: app
	open $(BUILD_DIR)/Build/Products/Release/OpenVault.app

clean:
	rm -rf .build $(BUILD_DIR) App/OpenVault.xcodeproj
