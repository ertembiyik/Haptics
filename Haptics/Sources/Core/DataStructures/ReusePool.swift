import Foundation

final class ReusePool<T, H: Hashable> {
    
    private final class ReusePoolStackItem {
        
        let object: T
        
        let previousItem: ReusePoolStackItem?
        
        init(object: T,
             previousItem: ReusePoolStackItem?) {
            self.object = object
            self.previousItem = previousItem
        }
        
    }
    
    private var objectsPool = [H: ReusePoolStackItem]()
    
    func add(_ object: T, for type: H) {
        let newItem = ReusePoolStackItem(object: object,
                                         previousItem: self.objectsPool[type])
        self.objectsPool[type] = newItem
    }
    
    func pop<V>(for type: H) -> V? {
        guard let lastItem = self.objectsPool[type],
              let object = lastItem.object as? V else {
            return nil
        }
        
        self.objectsPool[type] = lastItem.previousItem
        
        return object
    }
    
}


