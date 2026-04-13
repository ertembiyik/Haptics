import Foundation

extension Sequence where Element: Hashable {
    
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        
        return self.filter { element in
            seen.insert(element).inserted
        }
    }
    
    func merge(with sequences: [Element]...) -> [Element] {
        (self + sequences.flatMap { element in
            return element
        })
        .reversed()
        .unique()
        .reversed()
    }
    
}

extension Sequence {
    
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
    
    func merge<THashable: Hashable>(with sequences: [Element]..., resolver: (Element) -> THashable) -> [Element] {
        (self + sequences.flatMap { element in
            return element
        })
        .reversed()
        .unique(with: resolver)
        .reversed()
    }
    
    func mergeKeepingOrder<THashable: Hashable>(with sequences: [Element]...,
                                                resolver: (Element) -> THashable) -> [Element] {
        var result: [THashable: (element: Element, index: Int)] = [:]
        
        for (index, element) in self.enumerated() {
            let hashable = resolver(element)
            result[hashable] = (element, index)
        }
        
        for sequence in sequences {
            for element in sequence {
                let hashable = resolver(element)
                
                if let (_, index) = result[hashable] {
                    result[hashable] = (element, index)
                } else {
                    let newIndex = result.count
                    result[hashable] = (element, newIndex)
                }
            }
        }
        
        return result.values.sorted { element1, element2 in
            return element1.index < element2.index
        }.map { element in
            return element.element
        }
        
    }
    
}

extension Sequence {

    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }

    func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }

}

extension Sequence where Element: Sequence {
    func asyncFlatMap<T>(_ transform: (Element.Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            for subelement in element {
                try await values.append(transform(subelement))
            }
        }

        return values
    }

    func concurrentFlatMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map { element in
            element.map { subelement in
                Task {
                    try await transform(element)
                }
            }
        }

        return try await tasks.asyncFlatMap { task in
            try await task.value
        }
    }
}
