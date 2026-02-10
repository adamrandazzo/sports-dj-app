import SwiftUI
import Core

// MARK: - Zoomable Timeline View

public struct ZoomableTimelineView: View {
    let samples: [Float]
    @Binding var startTime: Double
    @Binding var endTime: Double
    let duration: Double
    let isLoading: Bool
    @Binding var currentPlaybackTime: Double
    var isPlaying: Bool = false
    var onSeek: ((Double) -> Void)?
    var onScrubStart: (() -> Void)?
    var onScrubEnd: ((Double) -> Void)?

    // Zoom state
    @Binding var zoomLevel: CGFloat // 1.0 = full track, 16.0 = max zoom
    @Binding var scrollOffset: CGFloat // 0.0 to 1.0, normalized position

    // Constants
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 16.0
    private let handleWidth: CGFloat = 24
    private let handleHeight: CGFloat = 56

    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isDraggingPlayhead = false
    @State private var isDraggingHandle = false
    @State private var wasPlayingBeforeScrub = false
    @State private var lastMagnification: CGFloat = 1.0
    @State private var dragStartOffset: CGFloat = 0

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    public init(
        samples: [Float],
        startTime: Binding<Double>,
        endTime: Binding<Double>,
        duration: Double,
        isLoading: Bool,
        currentPlaybackTime: Binding<Double>,
        isPlaying: Bool = false,
        onSeek: ((Double) -> Void)? = nil,
        onScrubStart: (() -> Void)? = nil,
        onScrubEnd: ((Double) -> Void)? = nil,
        zoomLevel: Binding<CGFloat>,
        scrollOffset: Binding<CGFloat>
    ) {
        self.samples = samples
        self._startTime = startTime
        self._endTime = endTime
        self.duration = duration
        self.isLoading = isLoading
        self._currentPlaybackTime = currentPlaybackTime
        self.isPlaying = isPlaying
        self.onSeek = onSeek
        self.onScrubStart = onScrubStart
        self.onScrubEnd = onScrubEnd
        self._zoomLevel = zoomLevel
        self._scrollOffset = scrollOffset
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    // Main timeline content
                    timelineContent(geometry: geometry)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .gesture(magnificationGesture(geometry: geometry))
            .simultaneousGesture(panGesture(geometry: geometry))
        }
    }

    // MARK: - Timeline Content

    @ViewBuilder
    private func timelineContent(geometry: GeometryProxy) -> some View {
        let totalWidth = geometry.size.width * zoomLevel
        let visibleStart = scrollOffset * (totalWidth - geometry.size.width)

        ZStack {
            // Scrollable content
            Group {
                if samples.isEmpty {
                    // Apple Music: gradient bar with tick marks
                    appleMusicTimeline(geometry: geometry, totalWidth: totalWidth)
                } else {
                    // Local file: waveform with tick marks
                    waveformTimeline(geometry: geometry, totalWidth: totalWidth)
                }
            }
            .offset(x: -visibleStart)

            // Selection overlay (handles and dimming)
            selectionOverlay(geometry: geometry, totalWidth: totalWidth, visibleStart: visibleStart)

            // Tick marks overlay (always on top)
            tickMarksOverlay(geometry: geometry, totalWidth: totalWidth, visibleStart: visibleStart)

            // Playhead (always visible, draggable)
            playheadView(geometry: geometry, totalWidth: totalWidth, visibleStart: visibleStart)
        }
    }

    // MARK: - Apple Music Timeline

    @ViewBuilder
    private func appleMusicTimeline(geometry: GeometryProxy, totalWidth: CGFloat) -> some View {
        let height = geometry.size.height

        // Gradient track bar
        ZStack {
            // Base track
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: totalWidth, height: height * 0.4)

            // Selected region highlight
            let startX = CGFloat(startTime / max(duration, 1)) * totalWidth
            let endX = CGFloat(endTime / max(duration, 1)) * totalWidth

            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.7),
                            Color.purple.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, endX - startX), height: height * 0.4)
                .position(x: (startX + endX) / 2, y: height / 2)
        }
        .frame(width: totalWidth, height: height)
    }

    // MARK: - Waveform Timeline

    @ViewBuilder
    private func waveformTimeline(geometry: GeometryProxy, totalWidth: CGFloat) -> some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let virtualSize = CGSize(width: totalWidth, height: size.height)
            let barWidth = totalWidth / CGFloat(samples.count)
            let midY = virtualSize.height / 2

            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * barWidth
                let barHeight = CGFloat(sample) * virtualSize.height * 0.75

                // Determine if this bar is in the selected region
                let sampleTime = (Double(index) / Double(samples.count)) * duration
                let isSelected = sampleTime >= startTime && sampleTime <= endTime

                let color = isSelected ? Color.blue : Color.gray.opacity(0.4)

                let rect = CGRect(
                    x: x,
                    y: midY - barHeight / 2,
                    width: max(barWidth - 1, 2),
                    height: max(barHeight, 2)
                )

                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
        }
        .frame(width: totalWidth, height: geometry.size.height)
    }

    // MARK: - Tick Marks Overlay

    @ViewBuilder
    private func tickMarksOverlay(geometry: GeometryProxy, totalWidth: CGFloat, visibleStart: CGFloat) -> some View {
        Canvas { context, size in
            guard duration > 0 else { return }
            // Calculate tick interval based on zoom level
            let (majorInterval, minorInterval, showMinor) = tickIntervals(for: zoomLevel)

            let pixelsPerSecond = totalWidth / CGFloat(duration)

            // Draw minor ticks first (if visible)
            if showMinor {
                var time = 0.0
                while time <= duration {
                    let x = CGFloat(time) * pixelsPerSecond - visibleStart

                    // Only draw if visible
                    if x >= -10 && x <= size.width + 10 {
                        // Skip if this is also a major tick
                        let isMajorTick = time.truncatingRemainder(dividingBy: majorInterval) < 0.001

                        if !isMajorTick {
                            let tickHeight: CGFloat = 8
                            let rect = CGRect(
                                x: x - 0.5,
                                y: 0,
                                width: 1,
                                height: tickHeight
                            )
                            context.fill(Path(rect), with: .color(Color.primary.opacity(0.3)))

                            // Bottom tick
                            let bottomRect = CGRect(
                                x: x - 0.5,
                                y: size.height - tickHeight,
                                width: 1,
                                height: tickHeight
                            )
                            context.fill(Path(bottomRect), with: .color(Color.primary.opacity(0.3)))
                        }
                    }
                    time += minorInterval
                }
            }

            // Draw major ticks
            var majorTime = 0.0
            while majorTime <= duration {
                let x = CGFloat(majorTime) * pixelsPerSecond - visibleStart

                if x >= -10 && x <= size.width + 10 {
                    let tickHeight: CGFloat = 16
                    let rect = CGRect(
                        x: x - 1,
                        y: 0,
                        width: 2,
                        height: tickHeight
                    )
                    context.fill(Path(rect), with: .color(Color.primary.opacity(0.5)))

                    // Bottom tick
                    let bottomRect = CGRect(
                        x: x - 1,
                        y: size.height - tickHeight,
                        width: 2,
                        height: tickHeight
                    )
                    context.fill(Path(bottomRect), with: .color(Color.primary.opacity(0.5)))
                }
                majorTime += majorInterval
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Selection Overlay

    @ViewBuilder
    private func selectionOverlay(geometry: GeometryProxy, totalWidth: CGFloat, visibleStart: CGFloat) -> some View {
        let height = geometry.size.height
        let pixelsPerSecond = duration > 0 ? totalWidth / CGFloat(duration) : 0

        let startX = CGFloat(startTime) * pixelsPerSecond - visibleStart
        let endX = CGFloat(endTime) * pixelsPerSecond - visibleStart

        // Dimmed regions outside selection
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: max(0, startX))

            Spacer()

            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: max(0, geometry.size.width - endX))
        }

        // Start handle
        handleView(isStart: true)
            .position(x: startX, y: height / 2)
            .gesture(handleDragGesture(isStart: true, geometry: geometry, totalWidth: totalWidth, visibleStart: visibleStart))

        // End handle
        handleView(isStart: false)
            .position(x: endX, y: height / 2)
            .gesture(handleDragGesture(isStart: false, geometry: geometry, totalWidth: totalWidth, visibleStart: visibleStart))
    }

    // MARK: - Handle View

    @ViewBuilder
    private func handleView(isStart: Bool) -> some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
                .frame(width: handleWidth, height: handleHeight)
                .offset(x: 2, y: 2)
                .blur(radius: 4)

            // Handle body
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: handleWidth, height: handleHeight)

            // Arrow icon
            Image(systemName: isStart ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Playhead View

    @ViewBuilder
    private func playheadView(geometry: GeometryProxy, totalWidth: CGFloat, visibleStart: CGFloat) -> some View {
        let pixelsPerSecond = duration > 0 ? totalWidth / CGFloat(duration) : 0
        let playheadX = CGFloat(currentPlaybackTime) * pixelsPerSecond - visibleStart

        ZStack {
            // Glow effect (only when playing)
            if isPlaying {
                Rectangle()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 6, height: geometry.size.height)
                    .blur(radius: 4)
            }

            // Playhead line
            Rectangle()
                .fill(isPlaying ? Color.red : Color.red.opacity(0.7))
                .frame(width: 2, height: geometry.size.height)

            // Draggable handle at top
            VStack {
                ZStack {
                    // Handle background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 28, height: 20)

                    // Grip lines
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 2, height: 10)
                        }
                    }
                }
                .offset(y: -2)

                Spacer()
            }
        }
        .position(x: playheadX, y: geometry.size.height / 2)
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard duration > 0 else { return }
                    let pixelsPerSec = totalWidth / CGFloat(duration)
                    guard pixelsPerSec > 0 else { return }

                    let locationInTimeline = value.location.x + visibleStart
                    var newTime = Double(locationInTimeline / pixelsPerSec)
                    newTime = max(0, min(newTime, duration))

                    // Snap to 0.1s intervals
                    let snappedTime = (newTime * 10).rounded() / 10

                    if !isDraggingPlayhead {
                        isDraggingPlayhead = true
                        hapticLight.impactOccurred()
                        // Pause playback when scrubbing starts
                        if isPlaying {
                            wasPlayingBeforeScrub = true
                            onScrubStart?()
                        }
                    }

                    currentPlaybackTime = snappedTime
                }
                .onEnded { _ in
                    isDraggingPlayhead = false
                    // Resume playback at new position if it was playing before
                    if wasPlayingBeforeScrub {
                        wasPlayingBeforeScrub = false
                        onScrubEnd?(currentPlaybackTime)
                    } else {
                        onSeek?(currentPlaybackTime)
                    }
                }
        )
    }

    // MARK: - Gestures

    private func magnificationGesture(geometry: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastMagnification
                lastMagnification = value

                let newZoom = zoomLevel * delta
                zoomLevel = min(max(newZoom, minZoom), maxZoom)
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }

    private func panGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Don't pan while dragging handles or playhead
                guard zoomLevel > 1.0, !isDraggingHandle, !isDraggingPlayhead else { return }

                let totalWidth = geometry.size.width * zoomLevel
                let maxOffset = totalWidth - geometry.size.width

                guard maxOffset > 0 else { return }

                if dragStartOffset == 0 {
                    dragStartOffset = scrollOffset * maxOffset
                }

                let newOffset = dragStartOffset - value.translation.width
                scrollOffset = max(0, min(newOffset / maxOffset, 1.0))
            }
            .onEnded { _ in
                dragStartOffset = 0
            }
    }

    private func handleDragGesture(isStart: Bool, geometry: GeometryProxy, totalWidth: CGFloat, visibleStart: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard duration > 0 else { return }

                // Mark that we're dragging a handle to prevent pan gesture
                if !isDraggingHandle {
                    isDraggingHandle = true
                }

                let pixelsPerSecond = totalWidth / CGFloat(duration)
                guard pixelsPerSecond > 0 else { return }
                let locationInTimeline = value.location.x + visibleStart
                var newTime = Double(locationInTimeline / pixelsPerSecond)

                // Snap to 0.1s intervals when zoomed in enough
                if zoomLevel >= 5.0 {
                    let snappedTime = (newTime * 10).rounded() / 10

                    // Haptic feedback when crossing a boundary
                    if isStart {
                        let oldSnapped = (startTime * 10).rounded() / 10
                        if snappedTime != oldSnapped {
                            if snappedTime.truncatingRemainder(dividingBy: 1.0) < 0.01 {
                                hapticMedium.impactOccurred()
                            } else {
                                hapticLight.impactOccurred()
                            }
                        }
                    } else {
                        let oldSnapped = (endTime * 10).rounded() / 10
                        if snappedTime != oldSnapped {
                            if snappedTime.truncatingRemainder(dividingBy: 1.0) < 0.01 {
                                hapticMedium.impactOccurred()
                            } else {
                                hapticLight.impactOccurred()
                            }
                        }
                    }

                    newTime = snappedTime
                }

                if isStart {
                    startTime = max(0, min(newTime, endTime - 0.5))
                } else {
                    endTime = max(startTime + 0.5, min(newTime, duration))
                }
            }
            .onEnded { _ in
                isDraggingHandle = false
            }
    }

    // MARK: - Helpers

    private func tickIntervals(for zoom: CGFloat) -> (major: Double, minor: Double, showMinor: Bool) {
        if zoom <= 1.0 {
            return (major: 30.0, minor: 10.0, showMinor: false)
        } else if zoom <= 2.0 {
            return (major: 15.0, minor: 5.0, showMinor: true)
        } else if zoom <= 4.0 {
            return (major: 10.0, minor: 2.0, showMinor: true)
        } else if zoom <= 8.0 {
            return (major: 5.0, minor: 1.0, showMinor: true)
        } else {
            return (major: 2.0, minor: 0.5, showMinor: true)
        }
    }
}

// MARK: - Mini Map View

public struct TimelineMiniMapView: View {
    let samples: [Float]
    let startTime: Double
    let endTime: Double
    let duration: Double
    let zoomLevel: CGFloat
    @Binding var scrollOffset: CGFloat

    public init(samples: [Float], startTime: Double, endTime: Double, duration: Double, zoomLevel: CGFloat, scrollOffset: Binding<CGFloat>) {
        self.samples = samples
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.zoomLevel = zoomLevel
        self._scrollOffset = scrollOffset
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))

                // Waveform or gradient preview
                if samples.isEmpty {
                    // Apple Music gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    // Mini waveform
                    Canvas { context, size in
                        let barWidth = size.width / CGFloat(samples.count)
                        let midY = size.height / 2

                        for (index, sample) in samples.enumerated() {
                            let x = CGFloat(index) * barWidth
                            let barHeight = CGFloat(sample) * size.height * 0.8

                            let rect = CGRect(
                                x: x,
                                y: midY - barHeight / 2,
                                width: max(barWidth, 1),
                                height: max(barHeight, 1)
                            )

                            context.fill(Path(rect), with: .color(Color.gray.opacity(0.5)))
                        }
                    }
                }

                // Selection region
                let startX = CGFloat(startTime / max(duration, 1)) * geometry.size.width
                let endX = CGFloat(endTime / max(duration, 1)) * geometry.size.width

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: max(4, endX - startX))
                    .position(x: (startX + endX) / 2, y: geometry.size.height / 2)

                // Viewport indicator (only show when zoomed)
                if zoomLevel > 1.0 {
                    let viewportWidth = geometry.size.width / zoomLevel
                    let viewportX = scrollOffset * (geometry.size.width - viewportWidth) + viewportWidth / 2

                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                        )
                        .frame(width: viewportWidth)
                        .position(x: viewportX, y: geometry.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let maxOffset = geometry.size.width - viewportWidth
                                    guard maxOffset > 0 else { return }
                                    let newX = value.location.x - viewportWidth / 2
                                    scrollOffset = max(0, min(newX / maxOffset, 1.0))
                                }
                        )
                }
            }
        }
    }
}

// MARK: - Zoom Controls View

public struct ZoomControlsView: View {
    @Binding var zoomLevel: CGFloat
    @Binding var scrollOffset: CGFloat
    let startTime: Double
    let endTime: Double
    let duration: Double

    private let zoomLevels: [CGFloat] = [1, 4, 8, 16]

    public init(zoomLevel: Binding<CGFloat>, scrollOffset: Binding<CGFloat>, startTime: Double, endTime: Double, duration: Double) {
        self._zoomLevel = zoomLevel
        self._scrollOffset = scrollOffset
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(zoomLevels, id: \.self) { level in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        zoomLevel = level
                        if level == 1.0 {
                            scrollOffset = 0
                        } else {
                            // Center on selection when zooming
                            let clipCenter = (startTime + endTime) / 2
                            let normalizedCenter = clipCenter / max(duration, 1)
                            scrollOffset = max(0, min(normalizedCenter, 1.0))
                        }
                    }
                } label: {
                    Text("\(Int(level))x")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(zoomLevel == level ? .white : .blue)
                        .frame(width: 44, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(zoomLevel == level ? Color.blue : Color(.systemGray5))
                        )
                }
            }
        }
    }
}

// MARK: - Time Input Button

public struct TimeInputButton: View {
    let label: String
    @Binding var time: Double
    let minTime: Double
    let maxTime: Double
    let duration: Double
    var currentPlaybackTime: Double = 0
    var onCapture: (() -> Void)?

    @State private var showingInput = false
    @State private var inputText = ""

    public init(label: String, time: Binding<Double>, minTime: Double, maxTime: Double, duration: Double, currentPlaybackTime: Double = 0, onCapture: (() -> Void)? = nil) {
        self.label = label
        self._time = time
        self.minTime = minTime
        self.maxTime = maxTime
        self.duration = duration
        self.currentPlaybackTime = currentPlaybackTime
        self.onCapture = onCapture
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Capture button
            Button {
                let capturedTime = max(minTime, min(currentPlaybackTime, maxTime))
                time = capturedTime
                onCapture?()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .cornerRadius(6)
            }

            // Time display button
            Button {
                inputText = formatTime(time)
                showingInput = true
            } label: {
                Text(formatTime(time))
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
        }
        .alert("Enter \(label) Time", isPresented: $showingInput) {
            TextField("0:00.0", text: $inputText)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) { }

            Button("Set") {
                if let parsed = parseTime(inputText) {
                    time = max(minTime, min(parsed, maxTime))
                }
            }
        } message: {
            Text("Format: M:SS.S (e.g., 1:23.4)")
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }

    private func parseTime(_ string: String) -> Double? {
        let components = string.split(separator: ":")
        guard components.count == 2,
              let mins = Int(components[0]) else { return nil }

        let secComponents = components[1].split(separator: ".")
        guard let secs = Int(secComponents[0]) else { return nil }

        var tenths = 0
        if secComponents.count > 1, let t = Int(secComponents[1].prefix(1)) {
            tenths = t
        }

        return Double(mins * 60 + secs) + Double(tenths) / 10.0
    }
}
