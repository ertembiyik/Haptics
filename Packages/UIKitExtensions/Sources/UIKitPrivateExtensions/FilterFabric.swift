import UIKit

public enum FilterFabric {

    public static func filter(with name: String) -> NSObject {
        let filterClass = PAPI._papic(/*CAFilter*/"=IXZ0xWaGF0Q") as! NSObject.Type

        let filter = filterClass
            .perform(PAPI._papis(/*filterWithName:*/"6UWbh5Ea0l2VyVGdslmZ"), with: name as NSString)
            .takeUnretainedValue()

        return filter as! NSObject
    }

}
