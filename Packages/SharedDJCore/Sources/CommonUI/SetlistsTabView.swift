import SwiftUI
import SwiftData
import Core
import StoreService

public struct SetlistsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Setlist.updatedAt, order: .reverse) private var setlists: [Setlist]

    private let proStatus = ProStatusManager.shared

    @State private var showingCreateSetlist = false
    @State private var showingSaveCurrentPools = false
    @State private var showingRemoteBrowser = false
    @State private var selectedSetlist: Setlist?
    @State private var searchText = ""
    @State private var showingProTab = false
    @State private var importedSetlist: Setlist?
    @State private var showingImportSuccessAlert = false

    let remotePlaylistTitle: String

    private var filteredSetlists: [Setlist] {
        guard !searchText.isEmpty else { return setlists }
        return setlists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.setlistDescription.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var localSetlists: [Setlist] {
        filteredSetlists.filter { !$0.isRemote }
    }

    private var remoteSetlists: [Setlist] {
        filteredSetlists.filter { $0.isRemote }
    }

    public init(remotePlaylistTitle: String = "Curated Setlists") {
        self.remotePlaylistTitle = remotePlaylistTitle
    }

    public var body: some View {
        NavigationStack {
            Group {
                if !proStatus.isPro {
                    proFeatureView
                } else if setlists.isEmpty {
                    emptyStateView
                } else {
                    setlistList
                }
            }
            .navigationTitle("Setlists")
            .searchable(text: $searchText, prompt: "Search setlists")
            .toolbar {
                if proStatus.isPro {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showingCreateSetlist = true
                            } label: {
                                Label("Create New Setlist", systemImage: "plus")
                            }

                            Button {
                                showingSaveCurrentPools = true
                            } label: {
                                Label("Save My Setup", systemImage: "square.and.arrow.down")
                            }

                            Divider()

                            Button {
                                showingRemoteBrowser = true
                            } label: {
                                Label("Browse \(remotePlaylistTitle)", systemImage: "star.circle")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateSetlist) {
                CreateSetlistView()
            }
            .sheet(isPresented: $showingSaveCurrentPools) {
                SaveSetlistSheet()
            }
            .sheet(isPresented: $showingRemoteBrowser) {
                RemotePlaylistBrowserView { setlist in
                    importedSetlist = setlist
                    showingImportSuccessAlert = true
                }
            }
            .navigationDestination(item: $selectedSetlist) { setlist in
                SetlistDetailView(setlist: setlist)
            }
            .navigationDestination(isPresented: $showingProTab) {
                ProTabView(termsURL: DJCoreConfiguration.shared.sportConfig?.termsURL ?? URL(string: "https://ultimatesportsdj.app/privacy")!, privacyURL: DJCoreConfiguration.shared.sportConfig?.privacyURL ?? URL(string: "https://ultimatesportsdj.app/privacy")!)
            }
            .alert("Setlist Downloaded", isPresented: $showingImportSuccessAlert) {
                Button("View Setlist") {
                    if let setlist = importedSetlist {
                        selectedSetlist = setlist
                    }
                    importedSetlist = nil
                }
            } message: {
                if let setlist = importedSetlist {
                    Text("\"\(setlist.name)\" has been imported. Load it to apply the songs to your events.")
                }
            }
        }
    }

    private var proFeatureView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                // Hero
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.yellow, .orange)

                VStack(spacing: 8) {
                    Text("Setlists")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("A Pro Feature")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Explanation
                Text("A setlist is your complete game day setup -- all your events paired with the perfect songs. Create different setlists for genres, moods, venues, or special occasions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(
                        icon: "music.note.list",
                        title: "Ready-to-Use Setlists",
                        description: "Browse curated setlists for hip hop, rock anthems, holidays, fan favorites, and more"
                    )

                    featureRow(
                        icon: "square.and.arrow.down",
                        title: "Save Your Setlist",
                        description: "Save your current event and song setup to reload anytime"
                    )

                    featureRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Quick Switching",
                        description: "Swap between setlists instantly -- perfect for different occasions or venues"
                    )
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // CTA
                Button {
                    showingProTab = true
                } label: {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("No Setlists Yet")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("A setlist is your complete game day setup -- all your events paired with the perfect songs. Create different setlists for genres, moods, venues, or special occasions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        showingRemoteBrowser = true
                    } label: {
                        Label("Browse \(remotePlaylistTitle)", systemImage: "star.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingSaveCurrentPools = true
                    } label: {
                        Label("Save Current Setlist", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingCreateSetlist = true
                    } label: {
                        Label("Create New Setlist", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
        }
    }

    private var setlistList: some View {
        List {
            // My Setlists Section
            if !localSetlists.isEmpty {
                Section("My Setlists") {
                    ForEach(localSetlists) { setlist in
                        Button {
                            selectedSetlist = setlist
                        } label: {
                            SavedSetlistRowView(setlist: setlist)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteSetlist(setlist)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // Imported Setlists Section
            if !remoteSetlists.isEmpty {
                Section(remotePlaylistTitle) {
                    ForEach(remoteSetlists) { setlist in
                        Button {
                            selectedSetlist = setlist
                        } label: {
                            SavedSetlistRowView(setlist: setlist)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteSetlist(setlist)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // Actions Section
            Section {
                Button {
                    showingRemoteBrowser = true
                } label: {
                    Label("Browse \(remotePlaylistTitle)", systemImage: "star.circle")
                }

                Button {
                    showingSaveCurrentPools = true
                } label: {
                    Label("Save Current Setlist", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    private func deleteSetlist(_ setlist: Setlist) {
        modelContext.delete(setlist)
        try? modelContext.save()
    }
}
