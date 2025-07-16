import UIKit

enum FilterFabric {

    static func filter(with name: String) -> NSObject {
        let filterClass = NSClassFromString("CAFilter") as! NSObject.Type

        let filter = filterClass
            .perform(Selector("filterWithName:"), with: name as NSString)
            .takeUnretainedValue()

        return filter as! NSObject
    }

}
