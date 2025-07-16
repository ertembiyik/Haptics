import Foundation
import AppIntents

struct ProfileAppEntity: AppEntity {
    struct ProfileAppEntityQuery: EntityQuery {
        func entities(for identifiers: [ProfileAppEntity.ID]) async throws -> [ProfileAppEntity] {
            return []
        }

        func suggestedEntities() async throws -> [ProfileAppEntity] {
            return []
        }
    }
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Profile")

    static var defaultQuery = ProfileAppEntityQuery()

    var id: String

    var displayString: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(id: String, displayString: String) {
        self.id = id
        self.displayString = displayString
    }
}

