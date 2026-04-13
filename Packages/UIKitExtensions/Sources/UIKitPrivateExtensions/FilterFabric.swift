import UIKit

public enum FilterFabric {

    public static func filter(with name: String) -> NSObject {
        // Private UIKit class/selector. Obfuscate these in production if you keep shipping this path.
        let filterClass = NSClassFromString("CAFilter") as! NSObject.Type
        let selector = NSSelectorFromString("filterWithName:")

        let filter = filterClass
            .perform(selector, with: name as NSString)
            .takeUnretainedValue()

        return filter as! NSObject
    }

}
