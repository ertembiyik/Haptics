import Foundation

public extension Sequence where Element: Hashable {

    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []

        return self.filter { element in
            seen.insert(element).inserted
        }
    }

}

public extension Sequence {
    
    func unique<T: Hashable>(with resolver: (Iterator.Element) -> T) -> [Iterator.Element] {
        var seen: Set<T> = []
        
        return self.filter { element in
            let hashable = resolver(element)
            return seen.insert(hashable).inserted
        }
    }
    
    func unique<T: Hashable>(with resolver: (Iterator.Element) -> T?) -> [Iterator.Element] {
        var seen: Set<T> = []
        
        return self.filter { element in
            guard let hashable = resolver(element) else {
                return false
            }
            
            return seen.insert(hashable).inserted
        }
    }
}
