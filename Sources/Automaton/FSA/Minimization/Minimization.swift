//
//  Minimization.swift
//  automaton
//
//  Created by Ulf Akerstedt-Inoue on 2026/02/16.
//

import Foundation

///```
/// Finite Automata (DFAs), aim to reduce the number of states while preserving the language accepted by the automaton.
/// These methods can be combined into a cohesive unit within a library or toolkit.
///
/// Key similar FSA minimization algorithms include:
/// - Moore's Algorithm (Partition Refinement): Iteratively partitions states into equivalence classes,
/// separating states that transition to different classes on the same input.
/// - Hopcroft's Algorithm: A more efficient algorithm for DFA minimization, reducing time complexity compared to Moore's
/// by using a more efficient partition refinement strategy.
/// - Myhill-Nerode Based Minimization: Uses the Myhill-Nerode theorem to determine state equivalence, often implemented
/// via a "table-filling" method.
/// - Brzozowski's Algorithm: A concise method that minimizes a DFA by reversing it (NFA), converting it to a DFA
/// (subset construction), reversing it again, and converting back to a DFA.
///```
/*
public struct Minimization {
    
    public var algorithm: Algorithm

    /// Symbols on transitions used by the automaton.
    var alphabet: Alphabet {  }

    public func successor(source: Int, symbol: Character) -> Int? {
    }
    
    public func predecessors(target: Int, symbol: Character) -> Set<Int> {
    }
    
    public func isSuccessor(source: Int, symbol: Character, target: Int) -> Bool {
    }
    
    public func reachableStates(from source: Int) -> Set<Int> {
    }
    
    public mutating func minimize() {
    }
}

extension Minimization {
    
    static func minimize(algorith: Algorithm, dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
    }
}
*/
