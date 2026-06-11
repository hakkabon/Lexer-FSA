import Foundation

/// Implements a queue - helper class that uses an array internally.
public class Queue<T> {
    private var container = [T]()
    private var head = 0

    public init() {}

    public var isEmpty: Bool {
        return count == 0
    }

    public func enqueue(_ element: T) {
        container.append(element)
    }

    public func enqueue(_ elements: [T]) {
        for element in elements {
            container.append(element)
        }
    }

    public func dequeue() -> T {
        let element = container[head]
        head += 1

        // If queue has more than 50 elements and more than 50% of allocated elements are popped.
        // Don't calculate the percentage with floating point, it decreases the performance considerably.
        if container.count > 50 && head * 2 > container.count {
            container.removeFirst(head)
            head = 0
        }

        return element
    }

    public var front: T {
        return container[head]
    }

    public var count: Int {
        return container.count - head
    }
}

extension Queue where T: Equatable {
    public func contains(_ thing: T) -> Bool {
        let content = container.dropFirst(head)
        if content.firstIndex(of: thing) != nil {
            return true
        }
        return false
    }
}
