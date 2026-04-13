import QuartzCore

extension CGPoint {

    subscript(index: Int) -> CGFloat {
        get {
            assert(index == 0 || index == 1)
            if index == 0 {
                return self.x
            } else {
                return self.y
            }
        }
        set(newValue) {
            assert(index == 0 || index == 1)
            if index == 0 {
                self.x = newValue
            } else {
                self.y = newValue
            }
        }
    }

}
