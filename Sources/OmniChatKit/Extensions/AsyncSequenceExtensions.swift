import Foundation

public extension AsyncThrowingStream where Element == String {
    func collectToString() async throws -> String {
        var result = ""
        for try await chunk in self {
            result += chunk
        }
        return result
    }
    
    func collectToArray() async throws -> [String] {
        var result: [String] = []
        for try await chunk in self {
            result.append(chunk)
        }
        return result
    }
}

public extension AsyncSequence {
    func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(self)
    }
}

public struct AnyAsyncSequence<Element>: AsyncSequence {
    private let _makeAsyncIterator: () -> AnyAsyncIterator<Element>
    
    init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
        self._makeAsyncIterator = {
            AnyAsyncIterator(sequence.makeAsyncIterator())
        }
    }
    
    public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        _makeAsyncIterator()
    }
}

public struct AnyAsyncIterator<Element>: AsyncIteratorProtocol {
    private var iterator: any AsyncIteratorProtocol
    
    init<I: AsyncIteratorProtocol>(_ iterator: I) where I.Element == Element {
        self.iterator = iterator
    }
    
    public mutating func next() async throws -> Element? {
        try await iterator.next() as? Element
    }
}