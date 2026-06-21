//
//  Transition.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/16.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation

public struct Transition {

    static let lowerBound: Character = "a"
    static let upperBound: Character = "Z"

    let alphabetRange: AlphabetRange
    let source: Int
    let target: Int
    
    /// Range of characters on transition between *from* and *to* states.
    ///
    /// - Note: For `.epsilon` transitions this returns an empty `Alphabet`,
    ///   rather than synthesising a literal `𝛆` character. The previous
    ///   implementation called `AlphabetRange.lower`/`upper` on `.epsilon`,
    ///   both of which return `"𝛆"` — leaking a phantom character into the
    ///   alphabet of any NFA that contained ε-transitions.
    var alphabet: Alphabet {
        switch alphabetRange {
        case .epsilon:
            return Alphabet([], true)
        case let .char(ch):
            return Alphabet([Interval(ch)], true)
        case let .range(lo, hi):
            return Alphabet([Interval(lo, hi)], true)
        }
    }
    
    /// Creates a new transition between two given states.
    /// - Parameters:
    ///   - from: start state of transition
    ///   - range: valid alphabet range of transition
    ///   - state: end state of transition
    init(from: Int, _ range: AlphabetRange, to state: Int) {
        assert(range.invariant)
        self.alphabetRange = range
        self.source = from
        self.target = state
    }

    /// Returns true if given character is in alphabet, false otherwise.
    ///
    /// - Note: Returns `false` for `.epsilon` transitions; the ε-closure
    ///   computation should pattern-match on `.epsilon` directly rather than
    ///   calling this method.
    /// - Parameter char: Character to test for alphabet inclusion.
    /// - Returns: Returns `true` if given character is in alphabet, `false` otherwise.
    public func inAlphabet(char: Character) -> Bool {
        switch alphabetRange {
        case .epsilon: return false
        case let .char(ch):
            return ch <= char && char <= ch
        case let .range(minChar, maxChar):
            return minChar <= char && char <= maxChar
        }
    }
    
    /// Returns true if given character range is in alphabet range, false otherwise.
    ///
    /// - Note: Returns `false` for `.epsilon` transitions.
    /// - Parameters:
    ///   - first: Lower bound of character range.
    ///   - last: Upper bound of character range.
    /// - Returns: Returns `true` if given character range is contained, `false` otherwise.
    public func inAlphabet(_ first: Character, _ last: Character) -> Bool {
        assert(first <= last)
        switch alphabetRange {
        case .epsilon: return false
        case let .char(ch):
            return ch <= first && last <= ch
        case let .range(minChar,maxChar):
            return minChar <= first && last <= maxChar
        }
    }
}

extension Transition: Equatable {
    public static func == (lhs: Transition, rhs: Transition) -> Bool {
        return lhs.alphabetRange == rhs.alphabetRange && lhs.source == rhs.source && lhs.target == rhs.target
    }
}

extension Transition: Comparable {
    public static func < (lhs: Transition, rhs: Transition) -> Bool {
        return (lhs.source, lhs.alphabetRange, lhs.target) < (rhs.source, rhs.alphabetRange, rhs.target)
    }
}

extension Transition: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch alphabetRange {
        case .epsilon:
            hasher.combine(source)
            hasher.combine(target)
        case let .char(ch):
            hasher.combine(source)
            hasher.combine(ch)
            hasher.combine(target)
        case .range(let ch1, let ch2):
            hasher.combine(source)
            hasher.combine(ch1)
            hasher.combine(ch2)
            hasher.combine(target)
        }
    }
}

// MARK: - Printable Conformance

extension Transition: CustomStringConvertible {

    public var description: String {
        return "\(source) \(alphabetRange) \(target)"
    }
}

extension Transition {
    
    public static func equalEndpoints(lhs: Transition, rhs: Transition) -> Bool {
        return lhs.source == rhs.source && lhs.target == rhs.target
    }

    public static func reverse(_ transition: Transition) -> Transition {
        return Transition(from: transition.target, transition.alphabetRange, to: transition.source)
    }
}

extension Set where Element == Transition {
        
    /// Returns alphabet defined on automaton.
    /// See also alphabet data structure for more information.
    /// Returns: Defined alphabet.
    public func alphabet() -> Alphabet {
        var intervals = [Interval]()
        for t in self {
            switch t.alphabetRange {
            case .epsilon: break
            case let .char(ch):
                intervals.append( Interval(ch) )
            case let .range(ch1, ch2):
                intervals.append( Interval(ch1, ch2) )
            }
        }
        return Alphabet(intervals, true)
    }

    // reverse all transitions.
    public func reversed() -> Set<Transition> {
        var reverse = Set<Transition>()
        self.forEach { (transition) in
                switch transition.alphabetRange {
                case .epsilon:
                    reverse.insert(Transition(from: transition.target, AlphabetRange.epsilon, to: transition.source))
                case let .char(ch):
                    reverse.insert(Transition(from: transition.target, AlphabetRange.char(ch), to: transition.source))
                case let .range(ch1,ch2):
                    reverse.insert(Transition(from: transition.target, AlphabetRange.range(ch1,ch2), to: transition.source))
                }
        }
        return reverse
    }

    // reverse all transitions to 𝛆-transitions.
//    public func reversed() -> Set<Transition> {
//        var reverse = Set<Transition>()
//        self.forEach { (transition) in
//                switch transition.alphabetRange {
//                case .epsilon:
//                    reverse.insert(Transition(from: transition.target, AlphabetRange.epsilon, to: transition.source))
//                case let .char(ch):
//                    reverse.insert(Transition(from: transition.target, AlphabetRange.char(ch), to: transition.source))
//                case let .range(ch1,ch2):
//                    reverse.insert(Transition(from: transition.target, AlphabetRange.range(ch1,ch2), to: transition.source))
//                }
//        }
//        return reverse
//    }

    /// Returns the set of states that are connected by transitions. Not necessarily reachable
    /// from the start state.
    /// - Return: set of `State` objects
    public func states() -> Set<Int> {
        let list = self.flatMap { [$0.source, $0.target] }
        return Set<Int>(list)
    }
    
    /// Returns the set of states that are connected by transitions. Not necessarily reachable
    /// from the start state.
    /// - Return: set of `State` objects
    public func forwardMap() -> [Int:[Int]] {
        var map: [Int:[Int]] = [:]

        self.forEach { (transition) in
            if let i = map.index(forKey: transition.source) {
                if !map.values[i].contains(transition.target) {
                    map.values[i].append(transition.target)
                }
            } else {
                map[transition.source] = [transition.target]
            }
        }
        return map
    }
}
