import AppIntents
import SwiftUI
import WidgetKit

enum PlayerWidgetAppearance: String, AppEnum {
    case artwork, light, dark
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Appearance"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .artwork: "Artwork colors", .light: "Light", .dark: "Dark",
    ]
}

struct PlayerWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Player appearance"
    static var description = IntentDescription("Choose the colors and details shown in your music widget.")
    @Parameter(title: "Appearance", default: .artwork) var appearance: PlayerWidgetAppearance
    @Parameter(title: "Show artist name", default: true) var showArtist: Bool
}

struct PlayerEntry: TimelineEntry {
    let date: Date
    let state: PlayerWidgetState
    let configuration: PlayerWidgetConfiguration
}

struct PlayerTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlayerEntry {
        PlayerEntry(date: .now, state: .preview, configuration: PlayerWidgetConfiguration())
    }

    func snapshot(for configuration: PlayerWidgetConfiguration, in context: Context) async -> PlayerEntry {
        PlayerEntry(date: .now, state: context.isPreview ? .preview : .read(), configuration: configuration)
    }

    func timeline(for configuration: PlayerWidgetConfiguration, in context: Context) async -> Timeline<PlayerEntry> {
        Timeline(entries: [PlayerEntry(date: .now, state: .read(), configuration: configuration)], policy: .never)
    }
}

struct PlayerWidgetView: View {
    let entry: PlayerEntry
    @Environment(\.widgetFamily) private var family
    // iOS 26 Liquid Glass home screens can show widgets in the clear and tinted
    // styles, where the system renders them in a single accented color.
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var fullColor: Bool { renderingMode == .fullColor }

    private var isLight: Bool { entry.configuration.appearance == .light }
    private var foreground: Color { isLight ? Color(red: 0.10, green: 0.09, blue: 0.12) : .white }
    private var background: Color {
        switch entry.configuration.appearance {
        case .light: return Color(red: 0.96, green: 0.95, blue: 0.97)
        case .dark: return Color(red: 0.11, green: 0.10, blue: 0.13)
        case .artwork:
            let value = entry.state.background
            return Color(red: Double((value >> 16) & 255) / 255,
                         green: Double((value >> 8) & 255) / 255,
                         blue: Double(value & 255) / 255)
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            lockScreen
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "mornye://player"))
        default:
            homeScreen
        }
    }

    private var title: String { entry.state.title.isEmpty ? "Mornye" : entry.state.title }

    /// Lock screen widgets (Tune feature): play/pause, now playing, inline title.
    @ViewBuilder
    private var lockScreen: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Button(intent: PlayerControlIntent("toggle")) {
                    Image(systemName: entry.state.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!entry.state.canPlay)
                .accessibilityLabel(entry.state.playing ? "Pause" : "Play")
            }
        case .accessoryInline:
            Label(entry.state.canPlay ? title : "Mornye", systemImage: entry.state.playing ? "waveform" : "music.note")
        default:
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Label(entry.state.playing ? "Now Playing" : "Mornye", systemImage: entry.state.playing ? "waveform" : "music.note")
                        .font(.caption2.weight(.semibold))
                        .widgetAccentable()
                    Text(title).font(.headline).lineLimit(1)
                    if entry.configuration.showArtist, !entry.state.artist.isEmpty {
                        Text(entry.state.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button(intent: PlayerControlIntent("toggle")) {
                    Image(systemName: entry.state.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!entry.state.canPlay)
                .accessibilityLabel(entry.state.playing ? "Pause" : "Play")
            }
        }
    }

    private var homeScreen: some View {
        GeometryReader { bounds in
            if family == .systemMedium {
                HStack(spacing: 16) {
                    artwork.frame(width: min(116, bounds.size.height), height: min(116, bounds.size.height))
                    VStack(alignment: .leading, spacing: 8) {
                        metadata
                        Spacer(minLength: 0)
                        controls
                    }
                }
            } else if family == .systemLarge {
                VStack(alignment: .leading, spacing: 12) {
                    artwork.frame(maxWidth: .infinity, maxHeight: .infinity)
                    metadata
                    controls
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        artwork.frame(width: max(44, bounds.size.height - 76), height: max(44, bounds.size.height - 76))
                        Spacer(minLength: 4)
                        Image(systemName: "music.note").font(.system(size: 19, weight: .semibold)).opacity(0.8)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 6) {
                        metadata
                        Spacer(minLength: 0)
                        control(entry.state.playing ? "pause" : "play", symbol: entry.state.playing ? "pause.fill" : "play.fill", prominent: true, enabled: entry.state.canPlay)
                    }
                }
            }
        }
        .foregroundStyle(foreground)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [background.opacity(0.88), background], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: "mornye://player"))
    }

    private var artwork: some View {
        Group {
            if let url = entry.state.artworkURL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().glassArtworkRendering().scaledToFit()
            } else {
                ContainerRelativeShape().fill(foreground.opacity(0.08))
                    .overlay(Image(systemName: "music.note").font(.system(size: 32, weight: .medium)))
            }
        }
        // Concentric with the widget's own corners, as the HIG asks for
        // content inset inside a rounded container.
        .clipShape(ContainerRelativeShape())
        .accessibilityHidden(true)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.state.title.isEmpty ? "Mornye Player" : entry.state.title)
                .font(.system(size: family == .systemSmall ? 14 : 17, weight: .semibold))
                .lineLimit(family == .systemMedium ? 2 : 1)
                .minimumScaleFactor(0.85)
            if entry.configuration.showArtist {
                Text(entry.state.canPlay ? entry.state.artist : "Choose music in the app")
                    .font(.system(size: family == .systemSmall ? 12 : 14))
                    .foregroundStyle(foreground.opacity(0.7)).lineLimit(1)
            }
        }
    }

    private var controls: some View {
        HStack {
            control("previous", symbol: "backward.fill", enabled: entry.state.canPlay && entry.state.canPrevious)
            Spacer(minLength: 4)
            control(entry.state.playing ? "pause" : "play", symbol: entry.state.playing ? "pause.fill" : "play.fill", prominent: true, enabled: entry.state.canPlay)
            Spacer(minLength: 4)
            control("next", symbol: "forward.fill", enabled: entry.state.canPlay && entry.state.canNext)
        }
    }

    private func control(_ action: String, symbol: String, prominent: Bool = false, enabled: Bool) -> some View {
        Button(intent: PlayerControlIntent(action == "play" || action == "pause" ? "toggle" : action)) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 19 : 20, weight: .semibold))
                .frame(width: family == .systemSmall ? 36 : 44, height: family == .systemSmall ? 36 : 44)
                // Clear and tinted styles keep only alpha, so a solid glyph on
                // a solid circle would vanish. Use a translucent platter there.
                .foregroundStyle(prominent && fullColor ? background : foreground)
                .background(
                    prominent ? (fullColor ? foreground : foreground.opacity(0.22)) : .clear,
                    in: Circle()
                )
                .widgetAccentable(prominent)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(action == "previous" ? "Previous track" : action == "next" ? "Next track" : action == "pause" ? "Pause" : "Play")
    }
}

private extension Image {
    /// Keep artwork recognisable in the tinted and clear home screen styles
    /// instead of letting the system flatten it into a solid tint.
    @ViewBuilder
    func glassArtworkRendering() -> some View {
        if #available(iOS 18.0, *) {
            self.widgetAccentedRenderingMode(.desaturated)
        } else {
            self
        }
    }
}

/// Control Center and Lock Screen controls (iOS 18), from Tune.
@available(iOS 18.0, *)
struct MornyePlayPauseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MornyePlayPause") {
            ControlWidgetButton(action: MornyeTogglePlaybackIntent()) {
                Label("Play or pause", systemImage: "playpause.fill")
            }
        }
        .displayName("Mornye play/pause")
        .description("Plays or pauses the current music.")
    }
}

@available(iOS 18.0, *)
struct MornyeShuffleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MornyeShuffleLibrary") {
            ControlWidgetButton(action: MornyeShuffleLibraryIntent()) {
                Label("Shuffle library", systemImage: "shuffle")
            }
        }
        .displayName("Mornye shuffle")
        .description("Shuffles every song in your library.")
    }
}

@main
struct MornyeWidgets: WidgetBundle {
    var body: some Widget {
        MornyePlayerWidget()
        if #available(iOS 18.0, *) {
            MornyePlayPauseControl()
            MornyeShuffleControl()
        }
    }
}

struct MornyePlayerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: PlayerWidgetState.kind, intent: PlayerWidgetConfiguration.self, provider: PlayerTimelineProvider()) { entry in
            PlayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Mornye Player")
        .description("Your music, artwork, and playback controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
