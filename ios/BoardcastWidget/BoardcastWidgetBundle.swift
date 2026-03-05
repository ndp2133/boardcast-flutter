import WidgetKit
import SwiftUI

@main
struct BoardcastWidgetBundle: WidgetBundle {
    var body: some Widget {
        BoardcastMediumWidget()
        BoardcastSmallWidget()
        BoardcastLargeWidget()
        BoardcastLockScreenWidget()
        BoardcastLockScreenCircularWidget()
        SurfLiveActivityWidget()
    }
}

struct BoardcastMediumWidget: Widget {
    let kind = "BoardcastWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardcastTimelineProvider()) { entry in
            MediumWidgetView(data: entry.data)
        }
        .configurationDisplayName("Surf Conditions")
        .description("See your surf score and best window at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct BoardcastSmallWidget: Widget {
    let kind = "BoardcastSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardcastTimelineProvider()) { entry in
            SmallWidgetView(data: entry.data)
        }
        .configurationDisplayName("Surf Score")
        .description("Your current surf score at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct BoardcastLargeWidget: Widget {
    let kind = "BoardcastLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardcastTimelineProvider()) { entry in
            LargeWidgetView(data: entry.data)
        }
        .configurationDisplayName("Surf Dashboard")
        .description("Full surf dashboard with timeline, waves, tides, and upcoming windows.")
        .supportedFamilies([.systemLarge])
    }
}

struct BoardcastLockScreenWidget: Widget {
    let kind = "BoardcastLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardcastTimelineProvider()) { entry in
            LockScreenRectangularView(data: entry.data)
        }
        .configurationDisplayName("Surf Conditions")
        .description("Surf score and conditions on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct BoardcastLockScreenCircularWidget: Widget {
    let kind = "BoardcastLockScreenCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardcastTimelineProvider()) { entry in
            LockScreenCircularView(data: entry.data)
        }
        .configurationDisplayName("Surf Score")
        .description("Surf score gauge on your Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}
