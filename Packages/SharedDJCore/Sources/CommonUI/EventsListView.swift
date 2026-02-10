import SwiftUI
import SwiftData
import Core
import StoreService

public struct EventsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.sortOrder) private var events: [Event]

    private let proStatus = ProStatusManager.shared

    @State private var showingAddEvent = false
    @State private var eventToEdit: Event?
    @State private var showingUpgradePrompt = false

    public init() {}

    public var body: some View {
        List {
            // Pro feature banner for free users
            if !proStatus.isPro {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Custom events are a Pro feature")
                        Spacer()
                    }
                    .font(.subheadline)
                }
            }

            ForEach(events) { event in
                NavigationLink {
                    EventPoolView(event: event)
                } label: {
                    EventButtonCompact(event: event)
                }
                .swipeActions(edge: .trailing) {
                    if !event.isStandard {
                        Button(role: .destructive) {
                            deleteEvent(event)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    Button {
                        eventToEdit = event
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onMove(perform: moveEvents)
        }
        .navigationTitle("Events")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if proStatus.isPro {
                        showingAddEvent = true
                    } else {
                        showingUpgradePrompt = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventEditView(mode: .add)
        }
        .sheet(item: $eventToEdit) { event in
            EventEditView(mode: .edit(event))
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .customEvents) {
            // Navigate to Pro tab handled by parent
        }
    }

    private func moveEvents(from source: IndexSet, to destination: Int) {
        var reorderedEvents = events
        reorderedEvents.move(fromOffsets: source, toOffset: destination)

        // Update sort orders
        for (index, event) in reorderedEvents.enumerated() {
            event.sortOrder = index
        }

        try? modelContext.save()
    }

    private func deleteEvent(_ event: Event) {
        modelContext.delete(event)
        try? modelContext.save()
    }
}

// MARK: - Event Edit View
public struct EventEditView: View {
    public enum Mode: Identifiable {
        case add
        case edit(Event)

        public var id: String {
            switch self {
            case .add: return "add"
            case .edit(let event): return event.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String = ""
    @State private var icon: String = "star.fill"
    @State private var colorHex: String = "#AF52DE"

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingEvent: Event? {
        if case .edit(let event) = mode { return event }
        return nil
    }

    public init(mode: Mode) {
        self.mode = mode
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Event Info") {
                    TextField("Name", text: $name)

                    Picker("Icon", selection: $icon) {
                        ForEach(availableIcons, id: \.symbol) { icon in
                            Label(icon.name, systemImage: icon.symbol)
                                .tag(icon.symbol)
                        }
                    }

                    ColorPicker("Color", selection: colorBinding)
                }

                Section {
                    // Preview
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Circle()
                                .fill((Color(hex: colorHex) ?? .purple).gradient)
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: icon)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                            Text(name.isEmpty ? "Event Name" : name)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let event = existingEvent {
                    name = event.name
                    icon = event.icon
                    colorHex = event.colorHex
                }
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) ?? .purple },
            set: { colorHex = $0.toHex() }
        )
    }

    private func saveEvent() {
        if let event = existingEvent {
            // Update existing
            event.name = name
            event.icon = icon
            event.colorHex = colorHex
        } else {
            // Create new
            let newEvent = Event(
                name: name,
                icon: icon,
                colorHex: colorHex,
                isStandard: false,
                sortOrder: 999 // Will be placed at end
            )
            modelContext.insert(newEvent)

            // Create empty pool
            let pool = EventPool(event: newEvent)
            modelContext.insert(pool)
            newEvent.pool = pool
        }

        try? modelContext.save()
    }

    private let availableIcons: [(name: String, symbol: String)] = [
        // Sports & Competition
        ("Trophy", "trophy.fill"),
        ("Medal", "medal.fill"),
        ("Flag", "flag.fill"),
        ("Whistle", "bubble.left.fill"),
        ("Stopwatch", "stopwatch.fill"),
        ("Timer", "timer"),
        ("Clock", "clock.fill"),

        // Music & Sound
        ("Music Note", "music.note"),
        ("Music Notes", "music.note.list"),
        ("Speaker", "speaker.wave.3.fill"),
        ("Guitar", "guitars.fill"),
        ("Mic", "mic.fill"),
        ("Waveform", "waveform"),

        // Actions & Status
        ("Play", "play.circle.fill"),
        ("Pause", "pause.circle.fill"),
        ("Stop", "stop.circle.fill"),
        ("Lightning", "bolt.fill"),
        ("Power", "bolt.circle.fill"),
        ("Checkmark", "checkmark.circle.fill"),
        ("X Mark", "xmark.circle.fill"),
        ("Flame", "flame.fill"),

        // Celebration
        ("Star", "star.fill"),
        ("Sparkles", "sparkles"),
        ("Party", "party.popper.fill"),
        ("Heart", "heart.fill"),
        ("Hands Up", "hands.clap.fill"),
        ("Crown", "crown.fill"),

        // Alerts & Info
        ("Bell", "bell.fill"),
        ("Megaphone", "megaphone.fill"),
        ("Siren", "light.beacon.max.fill"),
        ("Alert", "exclamationmark.circle.fill"),
        ("Info", "info.circle.fill"),
        ("Warning", "exclamationmark.triangle.fill"),

        // Misc
        ("Person", "person.fill"),
        ("People", "person.2.fill"),
        ("House", "house.fill"),
        ("Building", "building.2.fill"),
        ("Gear", "gearshape.fill")
    ]
}
