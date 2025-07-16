import Foundation

public protocol LinkLabelDelegate: AnyObject {

    func labelDidDetectLink(_ label: LinkLabel, link: URL)

}
