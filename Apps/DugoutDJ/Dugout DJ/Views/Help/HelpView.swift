import SwiftUI
import Core

struct HelpView: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HelpSectionView(
                        title: "Getting Started",
                        icon: "play.circle.fill",
                        iconColor: .green
                    ) {
                        GettingStartedContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Teams & Players",
                        icon: "person.3.fill",
                        iconColor: .blue
                    ) {
                        TeamsPlayersContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Player Announcements",
                        icon: "mic.fill",
                        iconColor: .purple
                    ) {
                        PlayerAnnouncementsContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Using Walk Up",
                        icon: "figure.baseball",
                        iconColor: .teal
                    ) {
                        WalkUpContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Setting Up Events",
                        icon: "calendar.badge.plus",
                        iconColor: .blue
                    ) {
                        EventsSetupContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Adding Local Music",
                        icon: "folder.fill",
                        iconColor: .orange
                    ) {
                        LocalMusicContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Apple Music",
                        icon: "apple.logo",
                        iconColor: .red
                    ) {
                        AppleMusicContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Importing Playlists",
                        icon: "music.note.list",
                        iconColor: .purple
                    ) {
                        PlaylistImportContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Editing Clips",
                        icon: "slider.horizontal.3",
                        iconColor: .cyan
                    ) {
                        ClipEditingContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Using the DJ",
                        icon: "music.note.tv.fill",
                        iconColor: .indigo
                    ) {
                        UsingDJContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    HelpSectionView(
                        title: "Setlists",
                        icon: "rectangle.stack.fill",
                        iconColor: .orange
                    ) {
                        SetlistsContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }
                }

                Section {
                    HelpSectionView(
                        title: "Tips & Tricks",
                        icon: "lightbulb.fill",
                        iconColor: .yellow
                    ) {
                        TipsContent(
                            selectedTab: $selectedTab,
                            setupNavigationPath: $setupNavigationPath
                        )
                    }

                    Link(destination: URL(string: "https://ultimatesportsdj.app/contact")!) {
                        Label("Contact Us", systemImage: "envelope.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Help")
        }
    }
}

// MARK: - Help Section View

struct HelpSectionView<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationLink {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(iconColor)
        }
    }
}

// MARK: - Getting Started

struct GettingStartedContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Dugout DJ helps you play walk-up songs and game music at baseball, softball, and teeball games."
            )

            HelpSubheading("How It Works")
            HelpNumberedList([
                "Create a team and add your players",
                "Import songs from local files or Apple Music",
                "Assign walk-up songs to each player",
                "Play announcements and songs at the game"
            ])

            HelpSubheading("App Tabs")
            HelpBulletList([
                "Walk Up: Play announcements and walk-up songs for each batter",
                "DJ: Trigger event music (Home Run, Strike Out, etc.)",
                "Setlists: Save and load song configurations",
                "Setup: Configure teams, events, and import songs",
                "Help: You are here!"
            ])

            HelpSubheading("Quick Start")
            HelpNumberedList([
                "Go to Setup > Teams and create your team",
                "Add players with their names and jersey numbers",
                "Use the Import section in Setup to add music",
                "Assign walk-up songs to players and add songs to events"
            ])

            AppLinkButton(
                "Go to Teams",
                icon: "person.3.fill",
                color: .blue,
                selectedTab: $selectedTab,
                setupNavigationPath: $setupNavigationPath,
                destination: .teams
            )
        }
    }
}

// MARK: - Teams & Players

struct TeamsPlayersContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Organize your roster by team. Each team has its own set of players, batting order, and announcer voice."
            )

            HelpSubheading("Creating a Team")
            HelpNumberedList([
                "Go to Setup > Teams",
                "Tap the + button",
                "Enter a team name (e.g., \"Little League Tigers\")",
                "Optionally choose an announcer voice"
            ])

            HelpSubheading("Managing Multiple Teams")
            HelpParagraph(
                "Free users can create 1 team. Pro users can create up to 3 teams. Switch between teams in the Walk Up tab to manage different rosters."
            )

            HelpSubheading("Adding Players")
            HelpNumberedList([
                "Open your team",
                "Tap \"Add Player\"",
                "Enter the player's name and jersey number",
                "The player is added to the end of the batting order"
            ])

            HelpSubheading("Setting Batting Order")
            HelpParagraph(
                "Drag players to reorder them within the team. The batting order determines the sequence on the Walk Up tab."
            )

            HelpSubheading("Player Limits")
            HelpBulletList([
                "Free: 8 players per team",
                "Pro: Up to 24 players per team"
            ])

            HelpTip("Set up your full roster before game day so you can focus on the game instead of data entry.")

            AppLinkButton(
                "Go to Teams",
                icon: "person.3.fill",
                color: .blue,
                selectedTab: $selectedTab,
                setupNavigationPath: $setupNavigationPath,
                destination: .teams
            )
        }
    }
}

// MARK: - Player Announcements

struct PlayerAnnouncementsContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Create a professional announcement for each batter. The announcement plays automatically before their walk-up song."
            )

            HelpSubheading("The Walk-Up Sequence")
            HelpNumberedList([
                "Batting number announcement (e.g., \"Now batting, number 7\")",
                "Player name announcement",
                "Walk-up song plays"
            ])

            HelpSubheading("Batting Number Announcement")
            HelpBulletList([
                "Toggle on/off in player settings",
                "Announces \"Now batting, number X\"",
                "Uses the team's announcer voice",
                "Preview with the play button"
            ])

            HelpSubheading("AI Name Announcement (Pro)")
            HelpBulletList([
                "Toggle on/off in player settings",
                "Generates a natural-sounding name announcement",
                "Each generation uses 1 AI credit (100/year with Pro)",
                "Preview before committing"
            ])

            HelpSubheading("Phonetic Spelling")
            HelpParagraph(
                "Helps the AI pronounce names correctly. Enter how the name sounds."
            )
            HelpBulletList([
                "\"Nguyen\" → \"Win\"",
                "\"Siobhan\" → \"Shiv-awn\"",
                "\"Czajkowski\" → \"Chai-kow-ski\""
            ])

            HelpSubheading("Regenerating")
            HelpParagraph(
                "A warning icon appears when the phonetic spelling has changed since the last generation. Tap Generate again to create a new announcement with the updated pronunciation."
            )

            HelpSubheading("Preview Full Walk-Up")
            HelpParagraph(
                "Use the large play button at the bottom of the player edit screen to hear the complete walk-up sequence — announcement followed by song."
            )

            HelpTip("Use phonetic spelling for any name the announcer might mispronounce. Test with the preview button.")

            AppLinkButton(
                "Go to Teams",
                icon: "person.3.fill",
                color: .blue,
                selectedTab: $selectedTab,
                setupNavigationPath: $setupNavigationPath,
                destination: .teams
            )
        }
    }
}

// MARK: - Using Walk Up

struct WalkUpContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "The Walk Up tab is your game-day command center. See your lineup, trigger announcements and walk-up songs, and manage the batting order on the fly."
            )

            HelpSubheading("The Player List")
            HelpBulletList([
                "Shows active players in batting order",
                "Green dot indicates the next batter",
                "Icons show announcement and song status"
            ])

            HelpSubheading("Playing a Walk-Up")
            HelpParagraph(
                "Tap the play button on any player. The announcement and song play in sequence."
            )

            HelpSubheading("Managing the Lineup")
            HelpBulletList([
                "Swipe right → \"On Deck\" (green) marks as next batter",
                "Swipe right → \"Bench\" (orange) moves to inactive section",
                "Benched players appear separately and can be reactivated by tapping"
            ])

            HelpSubheading("Reordering Players")
            HelpNumberedList([
                "Hold and drag a player to change position",
                "Or tap the reorder button in the toolbar for edit mode",
                "Tap the checkmark when done reordering"
            ])

            HelpSubheading("The Next Batter Bar")
            HelpBulletList([
                "Persistent bar at the bottom of the screen",
                "Shows next player's name and walk-up song",
                "Tap Play to trigger the next walk-up",
                "During playback, shows status (Announcing / Playing) with a stop button"
            ])

            HelpTip("Swipe right to mark the on-deck batter so you're always one tap away from the next walk-up.")

            TabLinkButton(
                "Go to Walk Up",
                icon: "figure.baseball",
                color: .teal,
                selectedTab: $selectedTab,
                tab: .walkUp
            )
        }
    }
}

// MARK: - Setting Up Events

struct EventsSetupContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Events are the game moments you want to trigger music for. The app comes with standard baseball events, and you can create custom ones."
            )

            HelpSubheading("Default Events")
            HelpBulletList([
                "Home Run - Celebrate the big hit",
                "Strike Out - Pitcher gets a K",
                "Double Play - Two outs at once",
                "Foul Ball - Fun foul ball moments",
                "Base Hit - Batter gets on base",
                "Inning Start - Between-inning music",
                "7th Inning Stretch - Take Me Out to the Ball Game",
                "Victory - Post-game celebration",
                "National Anthem - Pre-game ceremony",
                "Warm Ups - Pre-game warmup music",
                "Sound Effects - General sound effects"
            ])

            HelpSubheading("Creating a Custom Event")
            HelpNumberedList([
                "Go to Setup > Events",
                "Tap the + button in the top right",
                "Enter a name for your event",
                "Choose an icon from the available options",
                "Select a color for the event button",
                "Tap Save"
            ])

            HelpSubheading("Reordering Events")
            HelpParagraph(
                "Long press on an event to drag it to a new position. The order here determines the order of buttons on the DJ screen."
            )

            HelpSubheading("Adding Songs to an Event")
            HelpNumberedList([
                "Go to Setup > Events",
                "Tap on the event you want to configure",
                "Tap 'Add Song' or the + button",
                "Select songs from your library",
                "Drag songs to reorder them (affects sequential playback)"
            ])

            HelpSubheading("Playback Modes")
            HelpBulletList([
                "Shuffle: Plays songs randomly. Once all songs have played, the cycle resets.",
                "In Order: Plays songs sequentially from top to bottom, then wraps around.",
                "Pick: Shows a list of songs each time, letting you manually choose which to play."
            ])

            HelpTip("Use 'In Order' mode for events where you want predictable song sequences, like a specific home run celebration routine.")

            AppLinkButton(
                "Go to Events",
                icon: "list.bullet.circle.fill",
                color: .blue,
                selectedTab: $selectedTab,
                setupNavigationPath: $setupNavigationPath,
                destination: .events
            )
        }
    }
}

// MARK: - Adding Local Music

struct LocalMusicContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Import audio files directly from your device. Local files work offline and give you full control over playback timing and fade effects."
            )

            HelpSubheading("Supported Formats")
            HelpBulletList([
                "MP3 (.mp3)",
                "AAC/M4A (.m4a)",
                "WAV (.wav)",
                "AIFF (.aiff)"
            ])

            HelpSubheading("How to Import")
            HelpNumberedList([
                "Go to Setup",
                "Tap 'Import Local File' in the Import section",
                "Browse to your audio file using the file picker",
                "Select the file to import",
                "The clip editor opens automatically",
                "Adjust the start and end times for your clip",
                "Tap Save"
            ])

            HelpSubheading("Getting Files on Your Device")
            HelpBulletList([
                "Use the Files app to access iCloud Drive, Dropbox, etc.",
                "Transfer files via AirDrop from your Mac",
                "Download from cloud storage apps",
                "Connect to a computer and add files via Finder/iTunes"
            ])

            HelpSubheading("Metadata")
            HelpParagraph(
                "The app automatically extracts title, artist, duration, and album artwork from your audio files. You can edit the title and artist in the clip editor."
            )

            HelpTip("Local files support fade in/out effects, which Apple Music songs do not. Use local files when you need smooth transitions.")

            TabLinkButton(
                "Go to Setup",
                icon: "gear",
                color: .blue,
                selectedTab: $selectedTab,
                tab: .setup
            )
        }
    }
}

// MARK: - Apple Music

struct AppleMusicContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Connect to Apple Music to access millions of songs. Requires an active Apple Music subscription."
            )

            HelpSubheading("Connecting Apple Music")
            HelpNumberedList([
                "Go to Setup",
                "Tap 'Search Apple Music' in the Import section",
                "Tap 'Request Access' when prompted",
                "Allow access in the system dialog",
                "You can now search the Apple Music catalog"
            ])

            TabLinkButton(
                "Go to Setup",
                icon: "gear",
                color: .blue,
                selectedTab: $selectedTab,
                tab: .setup
            )

            HelpSubheading("If Access Is Denied")
            HelpNumberedList([
                "Open the Settings app on your device",
                "Scroll down and find Dugout DJ",
                "Tap on Media & Apple Music",
                "Enable access"
            ])

            SettingsLinkButton("Open App Settings")

            HelpSubheading("Searching for Songs")
            HelpBulletList([
                "Use the search bar to find songs, artists, or albums",
                "Filter by Songs, Artists, or Albums using the segmented control",
                "Tap a song to add it directly",
                "Tap an artist to see their top songs",
                "Tap an album to see all tracks"
            ])

            HelpSubheading("Search Options")
            HelpBulletList([
                "Hide Explicit Content: Filters out songs marked explicit",
                "Add to Apple Music Library: Automatically adds imported songs to your personal library"
            ])

            HelpSubheading("Downloading Songs for Offline Playback")
            HelpParagraph(
                "For reliable playback during games, download your Apple Music songs to your device beforehand. Downloaded songs play locally without needing internet."
            )

            HelpNumberedList([
                "Open the Music app on your iPhone",
                "Find the song, album, or playlist you want to download",
                "Tap and hold the item, then tap 'Add to Library'",
                "Tap and hold again, then tap 'Download'",
                "Look for the download icon (cloud with arrow) to confirm"
            ])

            HelpTip("To auto-download all added songs: Open Settings > Apps > Music and enable 'Automatic Downloads'. This ensures every song you add is downloaded for offline use.")

            SettingsLinkButton("Open Music Settings", urlString: "App-prefs:MUSIC")

            HelpSubheading("Important Notes")
            HelpBulletList([
                "Without downloads, Apple Music songs require internet to play",
                "An active Apple Music subscription is required",
                "Fade effects are not available for Apple Music songs",
                "Downloaded songs remain available offline as long as your subscription is active"
            ])
        }
    }
}

// MARK: - Importing Playlists

struct PlaylistImportContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "Import multiple songs at once from your Apple Music playlists. This is the fastest way to build your song library."
            )

            HelpSubheading("How to Import a Playlist")
            HelpNumberedList([
                "Go to Setup",
                "Tap 'Import from Playlist' in the Import section",
                "Browse your playlists or use search to find one",
                "Tap on a playlist to view its tracks",
                "Select the songs you want to import (all are selected by default)",
                "Tap 'Import' to configure import options",
                "Choose a target event (optional)",
                "Tap 'Import' to begin"
            ])

            TabLinkButton(
                "Go to Setup",
                icon: "gear",
                color: .blue,
                selectedTab: $selectedTab,
                tab: .setup
            )

            HelpSubheading("Import Options")
            HelpBulletList([
                "Target Event: Optionally assign all imported songs to a specific event",
                "Skip Existing Songs: Prevents duplicate imports based on Apple Music ID",
                "Add to Apple Music Library: Adds songs to your library"
            ])

            HelpSubheading("Recently Played")
            HelpParagraph(
                "The playlist browser also shows your recently played songs as a separate section. This is useful for quickly adding songs you've been listening to."
            )

            HelpSubheading("Selection Tools")
            HelpBulletList([
                "Tap the menu button (three dots) for bulk actions",
                "Select All: Select all songs in the playlist",
                "Deselect All: Clear all selections",
                "Hide Explicit: Filter out explicit songs"
            ])

            HelpTip("Create a dedicated playlist in Apple Music with all your game day songs, then import the entire playlist at once. Download the playlist in Apple Music first for offline playback.")
        }
    }
}

// MARK: - Editing Clips

struct ClipEditingContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "The clip editor lets you define exactly which portion of a song plays. Set start and end points, preview your clip, and add fade effects for local files."
            )

            HelpSubheading("Opening the Clip Editor")
            HelpBulletList([
                "The editor opens automatically when importing a new song",
                "To edit an existing clip, go to Song Library and tap on a song"
            ])

            AppLinkButton(
                "Go to Song Library",
                icon: "music.note.list",
                color: .purple,
                selectedTab: $selectedTab,
                setupNavigationPath: $setupNavigationPath,
                destination: .songLibrary
            )

            HelpSubheading("Timeline Controls")
            HelpBulletList([
                "Drag the left handle to set the start time",
                "Drag the right handle to set the end time",
                "The dimmed areas show what won't play",
                "Local files show a waveform; Apple Music shows a gradient bar"
            ])

            HelpSubheading("Time Buttons")
            HelpBulletList([
                "In: Tap to manually enter the start time",
                "Out: Tap to manually enter the end time",
                "Clip: Shows the duration of your clip"
            ])

            HelpSubheading("Zoom Controls")
            HelpBulletList([
                "Pinch on the timeline to zoom in/out",
                "Use + and - buttons for precise zooming",
                "Fit to Selection: Zooms to show just your clip",
                "When zoomed, a mini-map appears for navigation"
            ])

            HelpSubheading("Preview")
            HelpParagraph(
                "Tap the Preview button to hear your clip from start to end. The playback automatically stops at your end point. Tap 'Stop Preview' to stop early."
            )

            HelpSubheading("Fade Effects (Local Files Only)")
            HelpBulletList([
                "Expand the 'Fade Effects' section",
                "Fade In: Gradually increase volume at the start (0-15 seconds)",
                "Fade Out: Gradually decrease volume at the end (0-15 seconds)",
                "Use 0.5 second increments for precise control"
            ])

            HelpSubheading("Editing Song Info")
            HelpBulletList([
                "Tap the title field to edit the song name",
                "Tap the artist field to edit the artist name",
                "Changes are saved when you tap Save"
            ])

            HelpTip("Find the most exciting part of a walk-up song — the chorus drop or a big riff — and set your clip to start right there. A 15-30 second clip usually works best.")
        }
    }
}

// MARK: - Using the DJ

struct UsingDJContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "The DJ tab is your event music interface during games. Tap event buttons to trigger music instantly for home runs, strike outs, and more."
            )

            HelpSubheading("Playing Music")
            HelpNumberedList([
                "Tap an event button (Home Run, Strike Out, etc.)",
                "The assigned song plays immediately",
                "A player overlay appears at the bottom",
                "The song plays for the duration of your clip"
            ])

            TabLinkButton(
                "Go to DJ",
                icon: "music.note.list",
                color: .indigo,
                selectedTab: $selectedTab,
                tab: .music
            )

            HelpSubheading("Player Overlay")
            HelpBulletList([
                "Shows artwork, song title, and artist",
                "Progress bar shows current position in clip",
                "Tap pause to pause playback",
                "Tap the stop button to stop and dismiss"
            ])

            HelpSubheading("Playback Behavior")
            HelpBulletList([
                "Shuffle mode: Random song each time, no repeats until all played",
                "In Order mode: Sequential playback through your song list",
                "Pick mode: A sheet appears to choose your song",
                "Tapping a new event while music plays switches immediately"
            ])

            HelpTip("Keep the DJ tab active during the game for quick access to all event buttons. The buttons are designed for easy one-handed operation.")
        }
    }
}

// MARK: - Setlists

struct SetlistsContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpParagraph(
                "A setlist is your complete game day setup — all your events paired with the perfect songs. Use setlists for themed games, different venues, or just to save your favorite configuration."
            )

            HelpSubheading("What's in a Setlist?")
            HelpBulletList([
                "All songs assigned to each event (Home Run, Strike Out, etc.)",
                "The order of songs within each event",
                "Songs in your library that aren't assigned to events"
            ])

            HelpSubheading("Ultimate Dugout DJ Setlists")
            HelpParagraph(
                "Browse curated setlists created by the Ultimate Dugout DJ team. These are ready-to-use configurations with great songs for various themes."
            )
            HelpBulletList([
                "Ballpark Classics - Timeless stadium anthems",
                "Rally Songs - High-energy crowd favorites",
                "Walk-Up Hits - Popular walk-up songs",
                "Kids Favorites - Fun songs for youth leagues",
                "And more being added regularly"
            ])

            HelpSubheading("Importing a Curated Setlist")
            HelpNumberedList([
                "Go to the Setlists tab",
                "Tap 'Browse Ultimate Dugout DJ Setlists'",
                "Browse the available setlists",
                "Tap a setlist to preview its songs",
                "Tap 'Import' to download it to your device",
                "The setlist is now saved and ready to load"
            ])

            TabLinkButton(
                "Go to Setlists",
                icon: "rectangle.stack.fill",
                color: .orange,
                selectedTab: $selectedTab,
                tab: .setlists
            )

            HelpSubheading("Loading a Setlist")
            HelpParagraph(
                "Once you have setlists saved, you can load them to apply the songs to your events."
            )
            HelpNumberedList([
                "Go to the Setlists tab",
                "Tap on the setlist you want to load",
                "Tap the 'Load' button",
                "Choose a load mode (see below)",
                "Tap 'Load' to apply the setlist"
            ])

            HelpSubheading("Load Modes")
            HelpBulletList([
                "Add to Existing: Songs are added to your current event pools. Existing songs are kept.",
                "Replace All: Your current event pools are cleared first. Use this for a fresh start with the new setlist."
            ])

            HelpTip("Before using 'Replace All', you can save your current setup as a setlist so you don't lose it.")

            HelpSubheading("Saving Your Current Setup")
            HelpParagraph(
                "Save your current event and song configuration as a new setlist to reload later."
            )
            HelpNumberedList([
                "Go to the Setlists tab",
                "Tap 'Save Current Setlist' or the + menu",
                "Enter a name for your setlist",
                "Optionally add a description",
                "Tap 'Save'"
            ])

            HelpSubheading("Managing Setlists")
            HelpBulletList([
                "View: Tap a setlist to see all its songs and event assignments",
                "Delete: Swipe left on a setlist and tap Delete",
                "Re-sync: For imported setlists, tap 'Re-sync' to get the latest version"
            ])

            HelpSubheading("Setlist Ideas")
            HelpBulletList([
                "Create a setlist for each team you manage",
                "Build themed setlists for special games (rivalry night, playoffs, etc.)",
                "Save your 'go-to' setup as your default setlist",
                "Try different genres to keep games fresh"
            ])

            HelpTip("Setlists are a Pro feature. Upgrade to Pro to unlock setlist management and access curated setlists from Ultimate Dugout DJ.")
        }
    }
}

// MARK: - Tips & Tricks

struct TipsContent: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HelpSubheading("Preparation Tips")
            HelpBulletList([
                "Build your library before game day — importing takes time",
                "Assign walk-up songs to every player in the lineup",
                "Test all clips to ensure they start at the right moment",
                "Create a pre-game playlist in Apple Music for easy bulk import"
            ])

            HelpSubheading("Apple Music Best Practice")
            HelpParagraph(
                "Download your Apple Music songs to your device before the game. This ensures reliable playback even with a poor field-side connection."
            )
            HelpNumberedList([
                "Open the Music app",
                "Go to Library and find your game day songs or playlist",
                "Tap and hold, then tap 'Download'",
                "Wait for downloads to complete before game time"
            ])

            HelpTip("Enable 'Automatic Downloads' in Settings > Apps > Music so every song you add downloads automatically.")

            SettingsLinkButton("Open Music Settings", urlString: "App-prefs:MUSIC")

            HelpSubheading("Game Day Tips")
            HelpBulletList([
                "Charge your device fully before the game",
                "Enable Do Not Disturb to prevent interruptions",
                "Connect your speaker or PA system before the first pitch",
                "Keep the app in the foreground for instant response"
            ])

            HelpSubheading("Audio Setup Tips")
            HelpBulletList([
                "Connect to your sound system before starting",
                "Test volume levels during warmups",
                "Use a Bluetooth speaker or plug into the PA system",
                "Have a backup device ready if possible"
            ])

            HelpSubheading("Best Practices")
            HelpBulletList([
                "Use local files for your most critical songs (walk-ups, victory)",
                "Keep walk-up clips between 15-30 seconds",
                "Use longer clips for warmup and inning break music",
                "Add fade effects to local files for smoother transitions",
                "Download all Apple Music songs for offline playback"
            ])

            HelpSubheading("Troubleshooting")
            HelpBulletList([
                "No sound? Check device volume and mute switch",
                "Apple Music not playing? Verify subscription is active and songs are downloaded",
                "Song not starting? Edit the clip and check the start time",
                "Announcement not playing? Check announcer settings in player details",
                "Events missing songs? Go to Setup > Events to add songs"
            ])

            AppLinkButton(
                "Go to Settings",
                icon: "gear",
                color: .gray,
                selectedTab: $selectedTab,
                setupNavigationPath: $setupNavigationPath,
                destination: .settings
            )
        }
    }
}

// MARK: - Helper Views

struct HelpSubheading: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.headline)
            .padding(.top, 4)
    }
}

struct HelpParagraph: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}

struct HelpBulletList: View {
    let items: [String]

    init(_ items: [String]) {
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(item)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct HelpNumberedList: View {
    let items: [String]

    init(_ items: [String]) {
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(item)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct HelpTip: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .background(.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Navigation Link Buttons

struct AppLinkButton: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var selectedTab: ContentView.Tab
    @Binding var setupNavigationPath: NavigationPath
    let destination: ContentView.SetupDestination

    init(
        _ title: String,
        icon: String,
        color: Color,
        selectedTab: Binding<ContentView.Tab>,
        setupNavigationPath: Binding<NavigationPath>,
        destination: ContentView.SetupDestination
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self._selectedTab = selectedTab
        self._setupNavigationPath = setupNavigationPath
        self.destination = destination
    }

    var body: some View {
        Button {
            setupNavigationPath = NavigationPath()
            setupNavigationPath.append(destination)
            selectedTab = .setup
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct TabLinkButton: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var selectedTab: ContentView.Tab
    let tab: ContentView.Tab

    init(
        _ title: String,
        icon: String,
        color: Color,
        selectedTab: Binding<ContentView.Tab>,
        tab: ContentView.Tab
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self._selectedTab = selectedTab
        self.tab = tab
    }

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsLinkButton: View {
    let title: String
    let urlString: String

    init(_ title: String, urlString: String = UIApplication.openSettingsURLString) {
        self.title = title
        self.urlString = urlString
    }

    var body: some View {
        Button {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: "gear")
                    .foregroundStyle(.gray)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var tab = ContentView.Tab.help
    @Previewable @State var path = NavigationPath()
    HelpView(selectedTab: $tab, setupNavigationPath: $path)
}
