//
//  DFSA+Operations.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/21.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

//  Union operations on deterministic automata, relocated from the former
//  `Automaton<Type>` container. DFA union is implemented by projecting each
//  DFA to its underlying NFA topology, performing the textbook ε-union
//  (which preserves token-class priority through the determinizer's
//  highest-priority resolution), then re-determinizing.
//
//  The NFA ε-union helper (`State<NFSA>.union(list:)`) lives on `State<T>`
//  so that `LexerBuilder.build()` — which unions NFA components before
//  determinizing — can reuse the exact same construction.

// MARK: - DFA Union (delegates to NFA union + determinize)

extension DFSA {

    /// Returns an automaton that accepts the union of the languages of two
    /// deterministic automata.
    ///
    /// - Parameters:
    ///   - a: One automaton's language.
    ///   - b: Another automaton's language.
    /// - Returns: A deterministic automaton accepting the union language.
    public static func union(_ a: DFSA, _ b: DFSA) -> DFSA {
        return union([a, b])
    }

    /// Returns a deterministic automaton that accepts the union of the
    /// languages of the given automata.
    ///
    /// DFA union is implemented by treating each DFA as an NFA (same
    /// topology, dropping the `minimal` flag), performing the textbook
    /// ε-union on the NFAs (which preserves token-class priority via the
    /// determinizer's highest-priority resolution), then re-determinizing.
    ///
    /// - Parameter list: Automata whose languages are to be unified.
    /// - Returns: A deterministic automaton accepting the union language.
    /// - Complexity: Linear in the number of states for the union; the
    ///   subsequent powerset construction may be exponential in the worst case.
    public static func union(_ list: [DFSA]) -> DFSA {
        guard !list.isEmpty else {
            return DFSA(initial: 0, finals: [], transitions: [], minimal: false)
        }
        if list.count == 1 { return list[0] }

        // Project each DFA to its underlying NFA topology.
        let nfas: [State<NFSA>] = list.map { dfa -> State<NFSA> in
            switch dfa.state {
            case let .dfa(initial, finals, transitions, _, tokenMap):
                return .nfa(initial: initial, finals: finals,
                            transitions: transitions, tokenMap: tokenMap)
            case .nfa:
                // Should not happen for a DFSA, but be defensive.
                return .nfa(initial: 0, finals: [], transitions: [], tokenMap: [:])
            }
        }

        // NFA ε-union with token-map propagation, then re-determinize.
        var united = State<NFSA>.union(list: nfas)
        united.determinize()

        // Extract the resulting deterministic state.
        switch united {
        case let .dfa(initial, finals, transitions, minimal, tokenMap):
            return DFSA(initial: initial, finals: finals,
                        transitions: transitions, minimal: minimal,
                        tokenMap: tokenMap)
        case .nfa:
            // determinize() should always produce .dfa. Defensive fallback.
            return DFSA(initial: 0, finals: [], transitions: [], minimal: false)
        }
    }

    /// Creates a new (deterministic and minimal) automaton that accepts the
    /// union of the given set of strings, built as a trie / directed acyclic
    /// word graph.
    ///
    /// - Parameter words: Array of strings to accept. The character sequences
    ///   are sorted in-place during trie construction, so the input array may
    ///   be modified.
    /// - Returns: A deterministic automaton that accepts exactly `words`.
    public static func stringUnion(words: [String]) -> DFSA {

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
        return DFSA(initial: initial, finals: accept, transitions: transitions)
    }
}
