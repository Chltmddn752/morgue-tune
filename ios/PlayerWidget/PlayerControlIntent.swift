import AppIntents

@available(iOS 17.0, *)
struct PlayerControlIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Control music playback"
    static var openAppWhenRun = false

    @Parameter(title: "Action") var action: String

    init() { action = "toggle" }
    init(_ action: String) { self.action = action }

    func perform() async throws -> some IntentResult {
        #if !PLAYER_WIDGET_EXTENSION
        _ = await PlayerWidgetBridge.shared.perform(action)
        #endif
        return .result()
    }
}

// Tune features: Siri and Shortcuts phrases, and Control Center controls.
// Each intent runs in the app, which forwards it to the Flutter player.

@available(iOS 17.0, *)
private func performPlayerCommand(_ command: String) async {
    #if !PLAYER_WIDGET_EXTENSION
    _ = await PlayerWidgetBridge.shared.perform(command)
    #endif
}

@available(iOS 17.0, *)
struct MornyeTogglePlaybackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play or pause"
    static var description = IntentDescription("Plays or pauses the current music in Mornye.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await performPlayerCommand("toggle")
        return .result()
    }
}

@available(iOS 17.0, *)
struct MornyeNextTrackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Next track"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await performPlayerCommand("next")
        return .result()
    }
}

@available(iOS 17.0, *)
struct MornyePreviousTrackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Previous track"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await performPlayerCommand("previous")
        return .result()
    }
}

@available(iOS 17.0, *)
struct MornyeShuffleLibraryIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Shuffle library"
    static var description = IntentDescription("Shuffles every song in your Mornye library.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await performPlayerCommand("shuffle")
        return .result()
    }
}

#if !PLAYER_WIDGET_EXTENSION
@available(iOS 17.0, *)
struct MornyeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MornyeShuffleLibraryIntent(),
            phrases: [
                "\(.applicationName)에서 셔플 재생",
                "\(.applicationName) 보관함 셔플",
                "Shuffle my library in \(.applicationName)",
            ],
            shortTitle: "Shuffle library",
            systemImageName: "shuffle"
        )
        AppShortcut(
            intent: MornyeTogglePlaybackIntent(),
            phrases: [
                "\(.applicationName) 재생",
                "\(.applicationName) 일시정지",
                "Play or pause \(.applicationName)",
            ],
            shortTitle: "Play or pause",
            systemImageName: "playpause.fill"
        )
        AppShortcut(
            intent: MornyeNextTrackIntent(),
            phrases: [
                "\(.applicationName) 다음 곡",
                "Next song in \(.applicationName)",
            ],
            shortTitle: "Next track",
            systemImageName: "forward.fill"
        )
        AppShortcut(
            intent: MornyePreviousTrackIntent(),
            phrases: [
                "\(.applicationName) 이전 곡",
                "Previous song in \(.applicationName)",
            ],
            shortTitle: "Previous track",
            systemImageName: "backward.fill"
        )
    }
}
#endif
