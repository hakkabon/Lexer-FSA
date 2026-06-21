//
//  Counter.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/01/18.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

/// A simple monotonic integer counter, used to mint fresh state IDs during
/// automaton construction.
///
/// Previously this was a class with a `shared` singleton, which meant:
///   - Building two automata interleaved their state IDs.
///   - IDs were non-reproducible across runs of the same input (test order
///     mattered).
///   - The singleton was not thread-safe.
///   - BerrySethi had to work around collisions with a private local counter
///     (see the `BUG 1` comment in BerrySehti.swift).
///
/// The singleton has been removed. Each construction algorithm now owns its
/// own `Counter()` instance, so its results are self-contained and
/// reproducible. The type is a class so that `let c = Counter(); c()`
/// works without forcing callers to mark every method `mutating`.
public final class Counter {

    private var count: Int

    /// Creates a new counter starting at zero.
    public init() {
        self.count = 0
    }

    /// Creates a new counter starting at `initialValue`.
    public init(startAt initialValue: Int) {
        self.count = initialValue
    }

    /// Returns the next integer, advancing the counter by `increment`.
    /// - Parameter increment: amount to advance (default 1).
    /// - Returns: the new value of the counter.
    public func callAsFunction(increment: Int = 1) -> Int {
        count += increment
        return count
    }

    /// The current value of the counter (the value that would be returned
    /// by the next call to `callAsFunction(increment: 1)` minus one).
    public var current: Int { count }

    /// Resets the counter to zero.
    public func reset() {
        count = 0
    }
}
