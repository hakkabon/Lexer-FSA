//
//  Split.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/25.
//

import Foundation

struct SplitData {
    let block: Int
    let symbol: Character
}
extension SplitData: Comparable {
    static func < (lhs: SplitData, rhs: SplitData) -> Bool {
        return (lhs.block,lhs.symbol) < (rhs.block,rhs.symbol)
    }
}
extension SplitData: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(block)
        hasher.combine(symbol)
    }
}
extension SplitData : CustomStringConvertible {
    public var description: String {
        var s = ""
        s += "("
        s += "\(block), "
        s += "\(symbol)"
        s += ")"
        return s
    }
}


struct Splitter {
    let block: Int
    var set: Set<Int>
}
extension Splitter: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(block)
        hasher.combine(set)
    }
}
extension Splitter : CustomStringConvertible {
    public var description: String {
        var s = ""
        s += "("
        s += "\(block), "
        s += "\(setNotation(set))"
        s += ")"
        return s
    }
}
