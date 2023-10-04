SHELL = sh
.ONESHELL:
.SHELLFLAGS = -e

clean:
	swift package reset

build:
	swift build

ci_build:
	# build debug and release for all supported platforms
	# iOS
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination generic/platform=iOS -configuration debug
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination generic/platform=iOS -configuration release
	# macOS
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination platform="macOS" -configuration debug
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination platform="macOS" -configuration release
	# Catalyst
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination platform="macOS,variant=Mac Catalyst" -configuration debug
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination platform="macOS,variant=Mac Catalyst" -configuration release
	# watchOS
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination generic/platform=watchOS -configuration debug
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination generic/platform=watchOS -configuration release
	# tvOS
	xcodebuild build -workspace MQ.xcworkspace -scheme MQAsync -destination generic/platform=tvOS -configuration debug
	xcodebuild build -workspace MQAsync.xcworkspace -scheme MQAsync -destination generic/platform=tvOS -configuration release
	
test:
	swift test --configuration release

lint:
	swift run --configuration release --package-path ./FormatTool --scratch-path ./.toolsCache -- swift-format lint --configuration ./FormatTool/formatterConfig.json --parallel --recursive ./Package.swift ./Sources ./Tests

format:
	swift run --configuration release --package-path ./FormatTool --scratch-path ./.toolsCache -- swift-format format --configuration ./FormatTool/formatterConfig.json --parallel --recursive ./Package.swift ./Sources ./Tests --in-place
