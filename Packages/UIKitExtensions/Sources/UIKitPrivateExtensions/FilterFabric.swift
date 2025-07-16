import UIKit

public enum FilterFabric {

    public static func filter(with name: String) -> NSObject {
        let filterClass = NSClassFromString("CAFilter") as! NSObject.Type

        let filter = filterClass
            .perform(#selector(CIFilterConstructor.filter(withName:)), with: name as NSString)
            .takeUnretainedValue()

        return filter as! NSObject
    }

}
