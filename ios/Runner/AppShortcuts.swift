import AppIntents

struct BoardcastShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckConditionsIntent(),
            phrases: [
                "How's the surf on \(.applicationName)",
                "Check conditions on \(.applicationName)",
                "Surf report from \(.applicationName)",
                "\(.applicationName) conditions"
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
                "\(.applicationName) best time"
            ],
            shortTitle: "Best Time to Surf",
            systemImageName: "clock.badge.checkmark"
        )
    }
}
