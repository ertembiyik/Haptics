import WidgetKit
import RemoteDataModels

struct AyoWidgetEntry: TimelineEntry {

    struct SelectedData {

        let peer: RemoteDataModels.Profile

        let conversationId: String

    }

    enum `Type` {
        case selected(SelectedData)
        case empty
        case loggedOut
        case skeleton
    }

    let type: AyoWidgetEntry.`Type`

    let date: Date

    init(type: AyoWidgetEntry.`Type`,
         date: Date = Date()) {
        self.type = type
        self.date = date
    }

}
