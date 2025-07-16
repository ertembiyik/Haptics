import Foundation

protocol ParticleEngineSubject: AnyObject {
    
    var internalId: Int { get set }
    
    func setNeedsUpdate()
    
    func update(context: ParticleRenderingContext)
    
}

// MARK: - ParticleEngineSubject Extension

extension ParticleEngineSubject {
    
    func setNeedsUpdate() {
        ParticleRenderingEngine.shared.addSubjectNeedsUpdate(subject: self)
    }
    
}