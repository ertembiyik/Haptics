import Dependencies

public extension DependencyValues {

    private enum LinksFactoryKey: DependencyKey {
        static let liveValue: LinksFactory = LinksFactoryImpl()
    }

    var linksFactory: LinksFactory {
        get {
            self[LinksFactoryKey.self]
        }

        set {
            self[LinksFactoryKey.self] = newValue
        }
    }

}
