import WidgetKit
import SwiftUI

@main
struct BoardcastWidgetBundle: WidgetBundle {
    var body: some Widget {
        BoardcastMediumWidget()
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
