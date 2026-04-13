import Foundation

public extension Sequence {

    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }

    func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = self.map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }

}

public extension Sequence where Element: Sequence {

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
