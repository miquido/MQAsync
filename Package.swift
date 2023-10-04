// swift-tools-version: 5.9

import PackageDescription

let package = Package(
	name: "MQAsync",
	platforms: [
		.iOS(.v16),
		.macOS(.v14),
		.macCatalyst(.v16),
		.tvOS(.v16),
		.watchOS(.v9),
	],
	products: [
		.library(
			name: "MQAsync",
			targets: ["MQAsync"]
		),
		.library(
			name: "MQAsyncTest",
			targets: ["MQAsyncTest"]
		),
	],
	dependencies: [
		.package(
			url: "https://github.com/apple/swift-atomics.git",
			.upToNextMajor(from: "1.2.0")
		)
	],
	targets: [
		.target(
			name: "MQAsync",
			dependencies: [
				.product(
					name: "Atomics",
					package: "swift-atomics"
				)
			]
		),
		.target(
			name: "MQAsyncTest",
			dependencies: [
				.product(
					name: "Atomics",
					package: "swift-atomics"
				)
			]
		),
		.testTarget(
			name: "MQAsyncTests",
			dependencies: [
				"MQAsync",
				"MQAsyncTest",
			]
		),
	]
)
