// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-bencode",
    platforms: [.macOS(.v10_15)],
    targets: [
        .target(
            name: "Bencode"
        ),
        .testTarget(
            name: "BencodeTests",
            dependencies: [
                .target(name: "Bencode"),
            ]
        ),
    ]
)
