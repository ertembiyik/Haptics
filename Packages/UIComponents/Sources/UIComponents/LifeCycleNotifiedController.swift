import UIKit

public final class LifeCycleNotifiedController: UIViewController {

    public typealias LifeCycleBlock = (LifeCycleNotifiedController) -> Void

    public var onViewDidLoad: LifeCycleBlock?

    public var onViewWillAppear: LifeCycleBlock?

    public var onViewDidAppear: LifeCycleBlock?

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.onViewDidLoad?(self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.onViewWillAppear?(self)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.onViewDidAppear?(self)
    }
}

