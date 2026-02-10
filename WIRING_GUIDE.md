# Wiring Guide: Connect Apps to SharedDJCore

## Step 1: Open in Xcode

Open `SportsDJ.xcworkspace` (or create it per instructions below).

## Step 2: Add SharedDJCore Package to Each App

For **both** Hockey DJ and Dugout DJ:

1. Select the `.xcodeproj` in the project navigator
2. Select the app target → General → Frameworks, Libraries, and Embedded Content
3. Click "+" → Add Package Dependency → Add Local → navigate to `Packages/SharedDJCore`
4. Add all 5 library products: **Core**, **MusicService**, **StoreService**, **AnalyticsService**, **CommonUI**

## Step 3: Remove Extracted Files from Hockey DJ Target

These files now live in SharedDJCore. Remove them from the Hockey DJ Xcode target (delete reference, NOT move to trash — or move to trash if you want, the source of truth is now in SharedDJCore):

### Models → Core
- `Models/Event.swift`
- `Models/SongClip.swift`
- `Models/EventPool.swift`
- `Models/GameSession.swift`
- `Models/Setlist.swift`
- `Models/SetlistEntry.swift`

### Utilities → Core
- `Utilities/CloudStorage.swift`

### Services → MusicService
- `Services/AudioPlayerService.swift`
- `Services/MusicLibraryService.swift`
- `Services/UserLibraryService.swift`
- `Services/PlaylistImporter.swift`
- `Services/RemotePlaylistService.swift`
- `Services/SetlistManager.swift`
- `Services/FileStorageManager.swift`
- `Services/NetworkMonitor.swift`
- `Services/ImageCache.swift`

### Services → StoreService
- `Services/StoreKitManager.swift`
- `Services/ProStatusManager.swift`

### Services → AnalyticsService
- `Services/AnalyticsService.swift` — **NOTE**: If this file has hockey-specific analytics events, keep just those as an extension file importing `AnalyticsService`. Remove the base struct definition.

### Views → CommonUI
- `Views/Components/CachedArtworkView.swift`
- `Views/Components/QuickStartOverlay.swift`
- `Views/Components/UpdatedPlaylistsCard.swift`
- `Views/Components/UpdatedPlaylistsOverlay.swift`
- `Views/Components/UpgradePromptView.swift`
- `Views/Game/EventButton.swift`
- `Views/Game/SongPickerSheet.swift`
- `Views/Game/GameHistoryView.swift`
- `Views/Setup/SongClipEditView.swift`
- `Views/Setup/ZoomableTimelineView.swift`
- `Views/Setup/EventsListView.swift`
- `Views/Setup/ImportSongView.swift`
- `Views/Setup/SongLibraryView.swift`
- `Views/Setup/EventPoolView.swift`
- `Views/Setup/PlaylistImport/PlaylistBrowserView.swift`
- `Views/Setup/PlaylistImport/PlaylistDetailView.swift`
- `Views/Setup/PlaylistImport/PlaylistRowView.swift`
- `Views/Setup/PlaylistImport/PlaylistTrackRow.swift`
- `Views/Setup/PlaylistImport/PlaylistImportSheet.swift`
- `Views/Setup/PlaylistImport/RecentlyPlayedView.swift`
- `Views/ProTabView.swift`
- `Views/Setlists/SetlistsTabView.swift`
- `Views/Setlists/SetlistDetailView.swift`
- `Views/Setlists/CreateSetlistView.swift`
- `Views/Setlists/SaveSetlistSheet.swift`
- `Views/Setlists/LoadSetlistSheet.swift`
- `Views/Setlists/SavedSetlistRowView.swift`
- `Views/Setlists/AddSongsToSetlistView.swift`
- `Views/Playlists/RemotePlaylistBrowserView.swift`

### Files that STAY (Hockey-specific)
- `App/Hockey_DJApp.swift` — Add `import Core, MusicService, StoreService, AnalyticsService, CommonUI`
- `App/HockeyConfig.swift` — Already imports `Core`
- `App/AppConfig.swift` — Keep for URLs (terms, privacy)
- `Views/ContentView.swift` — Add shared imports
- `Views/Game/DJView.swift` — Add shared imports
- `Views/Setup/SetupTabView.swift` — Add shared imports
- `Views/Setup/SettingsView.swift` — Add shared imports
- `Views/Setup/HelpView.swift` — Keep as-is

---

## Step 4: Remove Extracted Files from Dugout DJ Target

### Models → Core
- `Models/Event.swift`
- `Models/SongClip.swift`
- `Models/EventPool.swift`
- `Models/GameSession.swift`
- `Models/Setlist.swift`
- `Models/SetlistEntry.swift`
- `Models/Team.swift`
- `Models/Player.swift`
- `Models/Announcer.swift`

### Utilities → Core
- `Utilities/CloudStorage.swift`

### Services → MusicService
- `Services/AudioPlayerService.swift`
- `Services/MusicLibraryService.swift`
- `Services/UserLibraryService.swift`
- `Services/PlaylistImporter.swift`
- `Services/RemotePlaylistService.swift`
- `Services/SetlistManager.swift`
- `Services/FileStorageManager.swift`
- `Services/NetworkMonitor.swift`
- `Services/ImageCache.swift`
- `Services/AnnouncerService.swift`
- `Services/TTSService.swift`
- `Services/WalkUpCoordinator.swift` (→ renamed to PlayerIntroCoordinator in shared)

### Services → StoreService
- `Services/StoreKitManager.swift`
- `Services/ProStatusManager.swift`

### Services → AnalyticsService
- `Services/AnalyticsService.swift` — Same note as Hockey: keep sport-specific extension.

### Views → CommonUI
- `Views/Components/CachedArtworkView.swift`
- `Views/Components/QuickStartOverlay.swift`
- `Views/Components/NowPlayingBar.swift` (if equivalent exists in CommonUI)
- `Views/Components/UpgradePromptView.swift`
- `Views/Music/EventButton.swift`
- `Views/Setup/SongClipEditView.swift`
- `Views/Setup/ZoomableTimelineView.swift`
- `Views/Setup/EventsListView.swift`
- `Views/Setup/ImportSongView.swift`
- `Views/Setup/SongLibraryView.swift`
- `Views/Setup/EventPoolView.swift`
- `Views/Setup/PlaylistImport/PlaylistBrowserView.swift`
- `Views/Setup/PlaylistImport/PlaylistDetailView.swift`
- `Views/Setup/PlaylistImport/PlaylistRowView.swift`
- `Views/Setup/PlaylistImport/PlaylistTrackRow.swift`
- `Views/Setup/PlaylistImport/PlaylistImportSheet.swift`
- `Views/Setup/PlaylistImport/RecentlyPlayedView.swift`
- `Views/Pro/ProTabView.swift`
- `Views/Setlists/SetlistsTabView.swift`
- `Views/Setlists/SetlistDetailView.swift`
- `Views/Setlists/CreateSetlistView.swift`
- `Views/Setlists/SaveSetlistSheet.swift`
- `Views/Setlists/LoadSetlistSheet.swift`
- `Views/Setlists/SavedSetlistRowView.swift`
- `Views/Setlists/AddSongsToSetlistView.swift`
- `Views/Setlists/RemotePlaylistBrowserView.swift`

### Files that STAY (Baseball-specific)
- `App/Dugout_DJApp.swift` — Already updated with shared imports
- `App/BaseballConfig.swift` — Already imports `Core`
- `App/AppConfig.swift` — Keep for URLs
- `Views/ContentView.swift` — Add shared imports
- `Views/Music/MusicView.swift` — Add shared imports
- `Views/WalkUp/WalkUpView.swift` — Add shared imports
- `Views/WalkUp/PlayerListView.swift` — Add shared imports
- `Views/WalkUp/NextBatterBar.swift` — Add shared imports
- `Views/Setup/SetupView.swift` — Add shared imports
- `Views/Setup/TeamsListView.swift` — Add shared imports
- `Views/Setup/TeamDetailView.swift` — Add shared imports
- `Views/Setup/PlayersListView.swift` — Add shared imports
- `Views/Setup/PlayerDetailView.swift` — Add shared imports
- `Views/Setup/AppSettingsView.swift` — Add shared imports
- `Views/Setup/AnnouncerSettingsView.swift` — Add shared imports
- `Views/Help/HelpView.swift` — Keep as-is

---

## Step 5: Add Imports to Remaining App Files

For every file that stays in the app target and references types from SharedDJCore, add the appropriate imports at the top:

```swift
import Core            // Event, SongClip, GameSession, Team, Player, etc.
import MusicService    // AudioPlayerService, FileStorageManager, etc.
import StoreService    // ProStatusManager, StoreKitManager
import AnalyticsService // AnalyticsService
import CommonUI        // Shared views (EventButton, ProTabView, etc.)
```

Only add the imports actually needed by each file.

## Step 6: Create Xcode Workspace (if not already done)

Create `SportsDJ.xcworkspace` containing:
- `Apps/HockeyDJ/Ultimate Hockey DJ.xcodeproj`
- `Apps/DugoutDJ/Dugout DJ.xcodeproj`
- `Packages/SharedDJCore` (added as a local Swift Package to each project)

## Step 7: Build & Verify

Build each app target individually. Fix any remaining import/access issues.
