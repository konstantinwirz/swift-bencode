# swift-bencode
[![Build](https://github.com/konstantinwirz/swift-bencode/actions/workflows/build.yaml/badge.svg)](https://github.com/konstantinwirz/swift-bencode/actions/workflows/build.yaml)

Encoder/Decoder for Bencode written in Swift

## Getting started

Add following dependency to your `Package.swift`
```swift
dependencies: [
    // ...
    .package(url: "https://github.com/konstantinwirz/swift-bencode", from: "0.4.0"),
    // ...
]
```

And also to your target
```swift
dependencies: [
    // ...
    .product(name: "Bencode", package: "swift-bencode")
    // ...
]
```

## Decoding

```swift
// Download ubuntu torrent file
let ubuntu = try await URLSession.shared.data(from: URL(string: "https://releases.ubuntu.com/25.10/ubuntu-25.10-desktop-amd64.iso.torrent")!).0

// Decode
let bencodeValue = try BencodeDecoder.decode(ubuntu)
print(bencodeValue)
// Example ouput:
//
// { created by : mktorrent 1.1, creation date : 1759993240, announce-list : [ [  
// https://torrent.ubuntu.com/announce ], [ https://ipv6.torrent.ubuntu.com/announce ] ], 
// info : { pieces : <invalid UTF-8>, name : ubuntu-25.10-desktop-amd64.iso, piece length : 262144, 
// length : 5702520832 }, comment : Ubuntu CD releases.ubuntu.com, 
// announce : https://torrent.ubuntu.com/announce }
```
