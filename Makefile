APP_NAME = SwiftSweeper
BUILD_DIR = .build/debug
APP_PATH = $(BUILD_DIR)/$(APP_NAME).app
INFO_PLIST = Info.plist
SWIFT_FILES = $(shell find . -name "*.swift")

all: build run

build:
	swift build

run: $(APP_PATH)
	@echo "Running $(APP_NAME)..."
	@$(APP_PATH)/Contents/MacOS/$(APP_NAME)

clean:
	swift package clean
	rm -rf $(BUILD_DIR)

$(APP_PATH): $(SWIFT_FILES)
	swift build -c debug
	mkdir -p $(APP_PATH)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_PATH)/Contents/MacOS/$(APP_NAME)
	cp $(INFO_PLIST) $(APP_PATH)/Contents/Info.plist

.PHONY: all build run clean