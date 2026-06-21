import Foundation

/// 2-Tuple (V,V).
/// Is needed in abscence of Tuple with auto hash code.
public struct Tup<V: Hashable & Comparable & Codable> {
    public var a: V
    public var b: V

    public init(_ a: V, _ b: V) {
        self.a = a
        self.b = b
    }
}

extension Tup: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(a)
        hasher.combine(b)
    }
}

extension Tup: Equatable {
    public static func == (lhs: Tup, rhs: Tup) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Tup: Comparable {
    public static func < (lhs: Tup, rhs: Tup) -> Bool {
        if lhs.a != rhs.a {
            return lhs.a < rhs.a
        } else {
            return lhs.b < rhs.b
        }
    }
}

extension Tup: CustomStringConvertible {

    public var description: String {
        return "(\(a),\(b))"
    }
}

/// 2-Tuple (U,V).
/// Is needed in abscence of Tuple with auto hash code.
public struct Tuple<U: Hashable & Comparable, V: Hashable & Comparable> {
    public var a: U
    public var b: V

    public init(_ a: U, _ b: V) {
        self.a = a
        self.b = b
    }
}

extension Tuple: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(a)
        hasher.combine(b)
    }
}

extension Tuple: Equatable {
    public static func == (lhs: Tuple, rhs: Tuple) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Tuple: Comparable {
    public static func < (lhs: Tuple, rhs: Tuple) -> Bool {
        return (lhs.a,lhs.b) < (rhs.a,rhs.b)
    }
}

extension Tuple: CustomStringConvertible {

    public var description: String {
        return "(\(a),\(b))"
    }
}
