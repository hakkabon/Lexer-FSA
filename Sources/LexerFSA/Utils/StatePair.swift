//
//  StatePair.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/05/28.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

/// Pair of states.
/// Is needed in abscence of Tuple with auto hash code.
public struct StatePair {
    public var s1: Int
    public var s2: Int

    public init(first s1: Int, second s2: Int) {
        self.s1 = s1
        self.s2 = s2
    }
}

extension StatePair: Equatable {

    public static func == (lhs: StatePair, rhs: StatePair) -> Bool {
        return lhs.s1 == rhs.s1 && lhs.s2 == rhs.s2
    }
}

extension StatePair: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(s1)
        hasher.combine(s2)
    }
}

extension StatePair: Comparable {

    public static func < (lhs: StatePair, rhs: StatePair) -> Bool {
        return lhs.s1 != rhs.s1 ? lhs.s1 < rhs.s1 : lhs.s2 < rhs.s2
    }
}
