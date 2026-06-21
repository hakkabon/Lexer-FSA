//
//  Alphabet.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/18.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation

/// Defines an unicode character interval, internally stored as a tuple
/// (lower,upper) of values, where the first value represents the lower end-point
/// and the last value represents the upper end-point of the interval.
/// Single characters are stored (ch, ch).
public struct Interval {

    var range: (Character, Character)
    
    /// Constructs single point [char, char] interval.
    init(_ char: Character) {
        self.range = (char, char)
    }

    /// Constructs range [lower, upper] interval.
    init(_ lower: Character, _ upper: Character) {
        self.range = (lower, upper)
    }
}

extension Interval : Equatable {
    public static func == (lhs: Interval, rhs: Interval) -> Bool {
        return lhs.range.0 == rhs.range.0 && lhs.range.1 == rhs.range.1
    }
}

extension Interval : Comparable {
    public static func < (lhs: Interval, rhs: Interval) -> Bool {
        switch (lhs.range, rhs.range) {
        case let ((l1,l2), (r1,r2)):
            return l1 != r1 ? l1 < r1 : l2 < r2
        }
    }
}

extension Interval : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(range.0)
        hasher.combine(range.1)
    }
}

/// Alphabet definition over Unicode characters
///
/// Set of character intervals [last,first] are kept internally. The intervals
/// are constructed from the input in such a way that the intervals are merged
/// where possible to maximum length.
///
/// Used algorithm: sort all the values in a list (while keeping whether
/// it's beginning or end of the interval along with  each item). This
/// operation is O(n log n). Then you loop in a single pass  along the sorted
/// items and compute the intervals O(n).
///
public struct Alphabet {
    
    /// Set of character intervals [last,first].
    public var intervals: Set<Interval> = Set<Interval>()
    
    /// Returns all alphabet intervals.
    public var characterClasses: [Interval] {
        return Array(intervals)
    }

    // Returns alphabet end-points [low .. high] over all merged intervals.
    public var endPoints : (Character,Character) {
        return (Array(intervals).first!.range.0, Array(intervals).last!.range.1)
    }
    
    /// Returns all alphabet intervals merged into one interval of characters.
    private(set) public var characters: [Character] = []

    private(set) public var characterMap: [Character:Int] = [:]

    func index(of character: Character) -> Int? {
        let alphabet = self.characters
        return binarySearch(alphabet, character)
    }

    /// Creates an alphabet wich contains the interval [MIN, MAX].
    public init(_ values: [Interval], _ merge: Bool = false) {
        guard values.count > 0 else { return }

        // Sort all input intervals.
        let svals = values.sorted(by: { $0.range.0 != $1.range.0 ?
                $0.range.0 < $1.range.0 : $0.range.1 < $1.range.1 })

        if merge {
            // Sweep through sorted intervals and check for overlaps with its
            // (right-hand) neighbor as moving through the list.
            var current = svals[0]
            for n in 1 ..< svals.count {
                if current.range.1 < svals[n].range.0 {
                    interval(current.range.0, current.range.1);
                    current = svals[n]
                }
                else {
                    // update right interval end if necessary
                    if current.range.1 < svals[n].range.1 {
                        current.range.1 = svals[n].range.1
                    }
                }
            }
            // dont't forget the last interval
            interval(current.range.0, current.range.1);
        } else {
            for ival in svals {
                interval(ival.range.0, ival.range.1)
            }
        }
        
        var chars: [Character] = []
        for interval in intervals {
            if interval.range.0 == interval.range.1 {
                chars.append(interval.range.0)
            }
            else {
                let lower = UInt16(interval.range.0.unicodeScalars.first!.value)
                let upper = UInt16(interval.range.1.unicodeScalars.first!.value)
                let range = lower...upper
                let string = range.reduce("") { $0 + String(Character(UnicodeScalar($1)!)) }
                chars += Array(string)
            }
        }
        characters = chars
        characterMap = Dictionary(uniqueKeysWithValues: zip(characters,0..<characters.count))
    }
}

extension Alphabet {

    /// Creates new character interval [first,last] and adds it to the alphabet.
    private mutating func interval(_ lower: Character, _ upper: Character) {
        // Insert interval into data structure.
        intervals.insert(Interval(lower, upper))
    }
}

extension Alphabet: CustomStringConvertible {

    /// Returns a string representation of the alphabet.
    public var description: String {
        return characters.map { "\($0)" }.joined(separator: ", ")
    }
}
