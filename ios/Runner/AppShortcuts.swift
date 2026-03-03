import AppIntents

struct BoardcastShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckConditionsIntent(),
            phrases: [
                "How's the surf on \(.applicationName)",
                "Check conditions on \(.applicationName)",
                "Surf report from \(.applicationName)",
                "\(.applicationName) conditions",
                "Is it good to surf on \(.applicationName)",
                "What's it like out there on \(.applicationName)",
                "Should I go surfing on \(.applicationName)"
            ],
            shortTitle: "Check Conditions",
            systemImageName: "water.waves"
        )
        AppShortcut(
            intent: GetBestTimeIntent(),
            phrases: [
                "When should I surf on \(.applicationName)",
                "Best time to surf on \(.applicationName)",
                "Surf window from \(.applicationName)",
                "\(.applicationName) best time",
                "When's the best surf on \(.applicationName)",
                "When should I paddle out on \(.applicationName)"
            ],
            shortTitle: "Best Time to Surf",
            systemImageName: "clock.badge.checkmark"
        )
    }
}
