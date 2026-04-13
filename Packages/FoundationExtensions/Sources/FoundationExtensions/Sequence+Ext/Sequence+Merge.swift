import Foundation

public extension Sequence where Element: Hashable {

    func merge(with sequences: [Element]...) -> [Element] {
        (self + sequences.flatMap { element in
            return element
        })
        .reversed()
        .unique()
        .reversed()
    }

}

public extension Sequence {

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
