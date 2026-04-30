APP_NAME = kokai
BUNDLE = $(APP_NAME).app
CONFIG ?= release
BUILD_DIR = .build/$(CONFIG)
BIN = $(BUILD_DIR)/$(APP_NAME)

.PHONY: all build bundle run clean

all: bundle

build:
	swift build -c $(CONFIG)

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - --entitlements kokai.entitlements $(BUNDLE) 2>/dev/null || codesign --force --sign - $(BUNDLE)

run: bundle
	open $(BUNDLE)

clean:
	rm -rf .build $(BUNDLE)
