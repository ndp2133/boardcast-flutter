import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct BoardcastEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct BoardcastTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardcastEntry {
        BoardcastEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardcastEntry) -> Void) {
        if context.isPreview {
            completion(BoardcastEntry(date: Date(), data: .placeholder))
        } else {
            completion(BoardcastEntry(date: Date(), data: .read()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardcastEntry>) -> Void) {
        let entry = BoardcastEntry(date: Date(), data: .read())
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
