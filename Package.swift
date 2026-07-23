// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YKImageEditor",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "YKImageEditorCore", targets: ["YKImageEditorCore"]),
        .library(name: "YKImageEditorUI", targets: ["YKImageEditorUI"])
    ],
    targets: [
        .target(
            name: "YKImageEditorCore",
            path: "Sources/YKImageEditorCore"
        ),
        .target(
            name: "YKImageEditorUI",
            dependencies: ["YKImageEditorCore"],
            path: "Sources/YKImageEditorUI"
        ),
        .testTarget(
            name: "YKImageEditorCoreTests",
            dependencies: ["YKImageEditorCore"],
            path: "Tests/YKImageEditorCoreTests"
        )
    ]
)
