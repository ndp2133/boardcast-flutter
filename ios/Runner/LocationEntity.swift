import AppIntents

struct LocationEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Surf Spot")
    static var defaultQuery = LocationEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    // All 11 locations matching lib/logic/locations.dart
    static let allLocations: [LocationEntity] = [
        LocationEntity(id: "rockaway", name: "Rockaway Beach, NY"),
        LocationEntity(id: "longbeach", name: "Long Beach, NY"),
        LocationEntity(id: "asbury", name: "Asbury Park, NJ"),
        LocationEntity(id: "belmar", name: "Belmar, NJ"),
        LocationEntity(id: "huntington", name: "Huntington Beach, CA"),
        LocationEntity(id: "santacruz", name: "Santa Cruz, CA"),
        LocationEntity(id: "oceanbeach", name: "Ocean Beach, SF, CA"),
        LocationEntity(id: "clearwater", name: "Clearwater Beach, FL"),
        LocationEntity(id: "cocoa", name: "Cocoa Beach, FL"),
        LocationEntity(id: "jacksonville", name: "Jacksonville Beach, FL"),
        LocationEntity(id: "miami", name: "Miami Beach, FL"),
    ]
}

struct LocationEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LocationEntity] {
        LocationEntity.allLocations.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LocationEntity] {
        LocationEntity.allLocations
    }

    func defaultResult() async -> LocationEntity? {
        let defaults = UserDefaults(suiteName: "group.com.boardcast.app")
        let selectedId = defaults?.string(forKey: "selectedLocationId") ?? "rockaway"
        return LocationEntity.allLocations.first { $0.id == selectedId }
    }
}
