import Foundation

/// Implements a stack - helper class that uses an array internally.
public class Stack<T> {
    private var container: [T] = [T]()
    public var isEmpty: Bool { return container.isEmpty }
    public var top: T? { return container.last }
    public func push(_ thing: T) { container.append(thing) }
    public func pop() -> T { return container.removeLast() }
    public func content() -> [T] { return container }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible
extension Stack: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String { return container.description }
    public var debugDescription: String { return container.debugDescription }
}
