// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "AwakeCore", targets: ["AwakeCore"])]
var targets: [Target] = [
    .target(name: "AwakeCore", path: "core"),
    .testTarget(name: "AwakeCoreTests", dependencies: ["AwakeCore"], path: "tests")
]
#if os(macOS)
products += [.executable(name: "KeepMyMacAwake", targets: ["AwakeApp"]),
             .executable(name: "KeepMyMacAwakeHelper", targets: ["AwakeHelper"])]
targets += [
    .target(name: "AwakeShared", dependencies: ["AwakeCore"], path: "shared"),
    .executableTarget(name: "AwakeApp", dependencies: ["AwakeCore", "AwakeShared"], path: "app"),
    .executableTarget(name: "AwakeHelper", dependencies: ["AwakeCore", "AwakeShared"], path: "helper"),
    .testTarget(name: "AwakeMacTests", dependencies: ["AwakeApp", "AwakeShared"], path: "mac-tests")
]
#endif
let package = Package(name: "KeepMyMacAwake", platforms: [.macOS(.v14)],
                      products: products, targets: targets)
