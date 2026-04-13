import Metal

struct RenderOperation {

        weak var layer: ParticleEngineSubjectLayer?

        let spec: RenderLayerSpec

        let state: ParticleDissolveRenderState

        let commands: (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void

    }
