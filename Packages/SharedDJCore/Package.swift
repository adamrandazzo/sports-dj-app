// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedDJCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "MusicService", targets: ["MusicService"]),
        .library(name: "StoreService", targets: ["StoreService"]),
        .library(name: "AnalyticsService", targets: ["AnalyticsService"]),
        .library(name: "CommonUI", targets: ["CommonUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.8.0"),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "MusicService", dependencies: ["Core"]),
        .target(name: "StoreService", dependencies: ["Core"]),
        .target(name: "AnalyticsService", dependencies: [
            "Core",
            .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        ]),
        .target(name: "CommonUI", dependencies: [
            "Core", "MusicService", "StoreService", "AnalyticsService"
        ]),
    ]
)
