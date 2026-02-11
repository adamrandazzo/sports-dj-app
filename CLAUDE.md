# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules

- **Do NOT run xcodebuild or compile unless explicitly asked.** Only build when the user requests it.

## Build Commands

Both apps build via the shared Xcode workspace. Always use the workspace, not individual `.xcodeproj` files.

```bash
# Hockey DJ
xcodebuild -workspace SportsDJ.xcworkspace -scheme "Hockey DJ" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Dugout DJ
xcodebuild -workspace SportsDJ.xcworkspace -scheme "Dugout DJ" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

There are no tests or linting configured.

## Architecture

This is a **monorepo** for two iOS apps (Hockey DJ and Dugout DJ) that share a core Swift package.

### Workspace Layout

```
SportsDJ.xcworkspace          ← open this, not individual projects
├── Apps/HockeyDJ/            ← Hockey DJ app target
├── Apps/DugoutDJ/            ← Dugout DJ app target
└── Packages/SharedDJCore/    ← local Swift package with 5 library targets
```

### SharedDJCore Package (5 modules)

- **Core** — Models (`Event`, `SongClip`, `Team`, `Player`, `GameSession`, `Setlist`, etc.), `SportConfig` protocol, `DJCoreConfiguration` singleton, `CloudStorage`
- **MusicService** — `AudioPlayerService`, `PlayerIntroCoordinator`, `SetlistManager`, `FileStorageManager`, `PlaylistImporter`, announcer/TTS (depends on Core)
- **StoreService** — `StoreKitManager`, `ProStatusManager` (depends on Core)
- **AnalyticsService** — Firebase Analytics/Crashlytics wrapper (depends on Core + Firebase)
- **CommonUI** — All shared SwiftUI views: event buttons, playlist browser, setlist views, pro tab, upgrade prompts, song picker (depends on all above)

### Sport Configuration Pattern

Each app defines a `SportConfig` conformance (`HockeyConfig`, `BaseballConfig`) that provides sport-specific events, IAP product IDs, tier limits, and feature flags. At launch, the app calls `DJCoreSetup.configure(with: HockeyConfig.self)` to register its config in the `DJCoreConfiguration` singleton, which shared code reads at runtime.

### What Lives in App Targets vs SharedDJCore

**App targets contain only:** App entry point (`@main`), `SportConfig` conformance, `AppConfig` (URLs), sport-specific views (ContentView, DJView/MusicView, WalkUpView, SetupView, HelpView), sport-specific analytics extensions, QuickStart page data.

**Everything else is in SharedDJCore.** When adding shared functionality, put it in the appropriate SharedDJCore module. When adding sport-specific behavior, put it in the app target.

### Key Patterns

- **Closure-based DI** for cross-module callbacks (e.g., `StoreKitManager.analyticsPurchase`, `ProStatusManager.analyticsSetIsPro`) to avoid circular dependencies between modules
- **`Result<ModelContainer, Error>`** for safer SwiftData initialization
- **`Event.createStandardEvents(from:)`** for parameterized seeding from `SportConfig.standardEvents`
- **`@MainActor`** on `PlayerIntroCoordinator` and `AudioPlayerService` session methods
- **`QuickStartOverlay`** takes `pages: [QuickStartPageData]` — pages are defined in app targets
- **`selectedTab` environment** is `Binding<Int>?` — app Tab enums use `Int` raw values

### IAP Differentiation

- Hockey DJ: 6-month subscription + lifetime purchase (`supportsLifetimePurchase = true`)
- Dugout DJ: 1-year subscription only (`supportsLifetimePurchase = false`)
- `ProTabView` conditionally shows the lifetime option based on `SportConfig`

### Xcode Project Notes

- Projects use `PBXFileSystemSynchronizedRootGroup` — Xcode auto-syncs with the filesystem, so no manual `.pbxproj` edits are needed when adding/removing Swift files
- Firebase is resolved via the workspace-level SPM package graph (declared in SharedDJCore's `Package.swift`)
