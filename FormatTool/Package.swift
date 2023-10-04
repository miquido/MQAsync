// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "tools",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-format.git", 
      exact: "509.0.0"
    ),
  ],
  targets: [
    .target(
      name: "format",
      dependencies: [
        .product(
          name: "swift-format", 
          package: "swift-format"
        )
      ]
    ),
  ]
)
