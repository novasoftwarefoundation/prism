// swift-tools-version: 6.2
// Prism's Swift package rendered on the iOS Simulator: CI runs
// `xcodebuild test -scheme PrismChecks-Package` in design/test/swiftui. Not part of the released package.
import PackageDescription

let package = Package(
    name: "PrismChecks",
    platforms: [.iOS(.v26)],
    dependencies: [.package(path: "../../../targets/swift")],
    targets: [
        .testTarget(name: "PrismTests", dependencies: [.product(name: "Prism", package: "swift")])
    ]
)
