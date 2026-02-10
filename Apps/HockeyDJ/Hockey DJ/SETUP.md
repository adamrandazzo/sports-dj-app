# Hockey DJ - Xcode Project Setup

Follow these steps to create the Xcode project and get the app running.

## Prerequisites

- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+
- Apple Developer account (free tier works for testing on device)

## Step 1: Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Choose **iOS** → **App**
4. Configure the project:
   - **Product Name**: `HockeyDJ`
   - **Team**: Select your Apple ID
   - **Organization Identifier**: `com.yourname` (or your domain)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None (we'll use SwiftData)
   - Uncheck "Include Tests" for now
5. Save to `hockey-dj/HockeyDJ/` (replace the existing empty folder or save alongside)

## Step 2: Add Swift Files

1. In Xcode, delete the auto-generated `ContentView.swift` and `HockeyDJApp.swift`
2. Right-click on the `HockeyDJ` folder in the navigator
3. Choose **Add Files to "HockeyDJ"...**
4. Navigate to and select all files from these folders:
   - `HockeyDJ/App/`
   - `HockeyDJ/Models/`
   - `HockeyDJ/Views/` (including subfolders)
   - `HockeyDJ/Services/`
5. Make sure "Copy items if needed" is **unchecked** (files are already in place)
6. Make sure "Create groups" is selected
7. Click Add

## Step 3: Configure Project Settings

### Deployment Target
1. Select the project in the navigator
2. Under "General" → "Minimum Deployments"
3. Set iOS to **17.0**

### iCloud Capability (for sync)
1. Select the project → "Signing & Capabilities"
2. Click "+ Capability"
3. Add "iCloud"
4. Check "CloudKit"
5. Create a new CloudKit container: `iCloud.com.yourname.HockeyDJ`

### Background Audio (optional but recommended)
1. Click "+ Capability"
2. Add "Background Modes"
3. Check "Audio, AirPlay, and Picture in Picture"

## Step 4: Info.plist Entries

Add these to your Info.plist (or via Project → Info → Custom iOS Target Properties):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Not used - placeholder for audio framework</string>

<key>NSAppleMusicUsageDescription</key>
<string>Access your Apple Music library to play songs during games</string>

<key>UISupportsDocumentBrowser</key>
<true/>
```

## Step 5: Build and Run

1. Select a simulator (iPhone 15 Pro or iPad recommended)
2. Press Cmd+R to build and run
3. The app should launch with the default events

## File Structure

```
HockeyDJ/
├── App/
│   └── HockeyDJApp.swift         # App entry point
├── Models/
│   ├── Event.swift               # Event model
│   ├── SongClip.swift            # Song clip model
│   ├── EventPool.swift           # Event-song relationship
│   └── GameSession.swift         # Runtime game state
├── Views/
│   ├── ContentView.swift         # Root tab view
│   ├── Game/
│   │   ├── GameView.swift        # Main game interface
│   │   └── EventButton.swift     # Event trigger button
│   └── Setup/
│       ├── SetupTabView.swift    # Setup navigation
│       ├── EventsListView.swift  # Manage events
│       ├── EventPoolView.swift   # Assign songs to events
│       ├── SongLibraryView.swift # View all songs
│       ├── ImportSongView.swift  # Import new songs
│       ├── SongClipEditView.swift# Edit clip times
│       └── SettingsView.swift    # App settings
└── Services/
    └── AudioPlayerService.swift  # Audio playback
```

## Testing the App

1. **Import a song**: Setup → Import Song → Import Local File
2. **Edit the clip**: Select start/end times on the waveform
3. **Assign to event**: Setup → Events → Goal Home → Add Songs
4. **Play**: Go to Game tab → Tap "Goal Home" button

## Next Steps (Future Development)

- [ ] Complete Apple Music integration (search, playback)
- [ ] Add visual feedback during playback (animated buttons)
- [ ] Implement iPad split-view layouts
- [ ] Add more waveform visualization options
- [ ] TestFlight deployment

## Troubleshooting

### "No such module 'SwiftData'"
- Ensure deployment target is iOS 17.0+
- Clean build folder (Cmd+Shift+K)

### CloudKit errors
- Make sure you're signed into iCloud in Simulator
- CloudKit container must match your bundle ID

### Audio not playing
- Check audio file format (MP3, M4A, WAV supported)
- Verify the file was copied to Documents directory
