//
//  Operation.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/05/29.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension Automaton where Type == DeterministicFiniteState.Subtype {

    /// Returns an automaton that accepts the union of the languages of the given automata.
    /// - Parameters:
    ///   - a: One automata language.
    ///   - b: Another automata language.
    /// - Returns: The modified automaton.
    /// Complexity: linear in number of states.
    public static func union(a: Automaton, b: Automaton) -> Automaton {
        return union(list: [a,b])
    }
    
    /// Returns an automaton that accepts the union of the languages of the given automata.
    /// - Parameter list: list of automata languages to be unified.
    /// - Returns: modified automaton.
    /// Complexity: linear in number of states.
    public static func union(list: [Automaton]) -> Automaton {
        /// Number generator.
        let S = Counter.shared

//        var s = S()
//        for a in list {
//            if a.isEmpty { continue }
//            let b = Automaton(a, expand: true)
//            s.addEpsilon(to: b.initial)
//        }
//        let automaton = Automaton(initial: s)
//        automaton.deterministic = false
//        return automaton
        return Automaton(initial: 0, finals: Set<Int>(), transitions: Set<Transition>(), minimal: false)
    }
    
    /// Creates a new (deterministic and minimal) automaton that accepts the union of the
    /// given set of strings. The input character sequences are internally sorted in-place,
    /// so the input array is modified.
    /// - Parameter words: array of strings
    /// - Returns: Automaton that accepts the union of the given set of strings.
    public static func stringUnion(words: [String]) -> Automaton {

        func traverseTrie(node: TrieNode) {
            if node.final {
                accept.insert(node.id)
            }
            for edge in node.edges {
                transitions.insert(Transition(from: node.id, AlphabetRange.char(edge.key), to: edge.value.id))
                traverseTrie(node: edge.value)
            }
        }
        
        let builder = TrieBuilder()
        words.forEach { builder.insert(word: $0) }
        builder.minimize()

        let initial = builder.root.id
        var transitions = Set<Transition>()
        var accept = Set<Int>()

        traverseTrie(node: builder.root)
        return Automaton(DeterministicFiniteState(initial: initial, finals: accept, transitions: transitions))
    }
}
