import simd

extension float4x4 {

    var translation: SIMD3<Float> {
        get {
            let translation = self.columns.3
            return [translation.x, translation.y, translation.z]
        }

        set {
            self.columns.3 = [newValue.x, newValue.y, newValue.z, columns.3.w]
        }
    }

    var rotation: simd_quatf {
        return simd_quaternion(self)
    }

}
