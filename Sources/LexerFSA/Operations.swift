//
//  Operation.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/05/29.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

// MARK: - NFA Union with Token-Map Propagation

extension Automaton where Type == NFSA.Subtype {

    /// Returns the union of two NFAs: a fresh automaton whose language is
    /// `L(a) ∪ L(b)` and whose token map is the disjoint union of the two
    /// component token maps (with state ids renumbered so the two component
    /// state spaces do not collide).
    public static func union(a: Automaton, b: Automaton) -> Automaton {
        return union(list: [a, b])
    }

    /// Returns an NFA accepting the union of the languages of the given
    /// automata, with token classes propagated from each component.
    ///
    /// Construction (textbook ε-union):
    ///   1. Renumber each component's states into a disjoint range using a
    ///      *local* counter (not the global `Counter.shared` singleton — the
    ///      singleton made union results depend on prior builds, which broke
    ///      reproducibility).
    ///   2. Allocate a fresh initial state `q0`.
    ///   3. Add an ε-transition from `q0` to each component's renumbered
    ///      initial state.
    ///   4. Take the union of all transition sets and all final-state sets.
    ///   5. Build the resulting token map by renumbering each component's
    ///      `(finalState, tokenClass)` pairs.
    ///
    /// - Complexity: O(|Q| + |Δ|) in the total size of the input automata.
    public static func union(list: [Automaton]) -> Automaton {
        guard !list.isEmpty else {
            return Automaton(initial: 0, finals: [], transitions: [])
        }
        if list.count == 1 { return list[0] }

        // Local counter — fresh per call, so the result is reproducible.
        var nextId: Int = 0
        func fresh() -> Int { defer { nextId += 1 }; return nextId }

        let newInitial = fresh()    // q0

        var unionTransitions = Set<Transition>()
        var unionFinals      = Set<Int>()
        var unionTokenMap    = [Int: TokenClass]()

        for component in list {
            // Skip empty components — they contribute nothing.
            guard case let .nfa(cInitial, cFinals, cTransitions, cTokenMap) = component.state else {
                continue
            }
            // Don't bother with components that have no transitions and no finals.
            if cTransitions.isEmpty && cFinals.isEmpty { continue }

            // Map this component's state ids into a fresh disjoint range.
            // We rebuild the id map eagerly so we can remap both source/target
            // in transitions AND final-state ids in one pass.
            var idMap: [Int: Int] = [:]
            func remap(_ id: Int) -> Int {
                if let mapped = idMap[id] { return mapped }
                let mapped = fresh()
                idMap[id] = mapped
                return mapped
            }

            let remappedInitial = remap(cInitial)

            // ε-edge from the new global initial to this component's initial.
            unionTransitions.insert(
                Transition(from: newInitial, AlphabetRange.epsilon, to: remappedInitial))

            // Remap and union all transitions.
            for t in cTransitions {
                unionTransitions.insert(
                    Transition(from: remap(t.source), t.alphabetRange, to: remap(t.target)))
            }

            // Remap and union final states; propagate token map.
            for f in cFinals {
                let remappedF = remap(f)
                unionFinals.insert(remappedF)
                if let token = cTokenMap[f] {
                    unionTokenMap[remappedF] = token
                }
            }
        }

        return Automaton(
            initial: newInitial,
            finals: unionFinals,
            transitions: unionTransitions,
            tokenMap: unionTokenMap)
    }
}

// MARK: - DFA Union (delegates to NFA union + determinize)

extension Automaton where Type == DFSA.Subtype {

    /// Returns an automaton that accepts the union of the languages of the given automata.
    /// - Parameters:
    ///   - a: One automata language.
    ///   - b: Another automata language.
    /// - Returns: The modified automaton.
    /// Complexity: linear in number of states.
    public static func union(a: Automaton, b: Automaton) -> Automaton {
        return union(list: [a, b])
    }

    /// Returns an automaton that accepts the union of the languages of the given automata.
    ///
    /// DFA union is implemented by treating each DFA as an NFA (same topology,
    /// drop the `minimal` flag), performing the textbook ε-union on the NFAs
    /// (which preserves token-class priority via the determinizer's
    /// highest-priority resolution), then re-determinizing.
    ///
    /// - Parameter list: list of automata languages to be unified.
    /// - Returns: A deterministic automaton accepting the union language.
    /// Complexity: linear in number of states for the union; the subsequent
    ///             powerset construction may be exponential in the worst case.
    public static func union(list: [Automaton]) -> Automaton {
        guard !list.isEmpty else {
            return Automaton(initial: 0, finals: [], transitions: [], minimal: false)
        }
        if list.count == 1 { return list[0] }

        // Project each DFA to its underlying NFA topology.
        let nfas: [Automaton<NFSA>] = list.map { dfa in
            switch dfa.state {
            case let .dfa(initial, finals, transitions, _, tokenMap):
                return Automaton<NFSA>(
                    initial: initial,
                    finals: finals,
                    transitions: transitions,
                    tokenMap: tokenMap)
            case .nfa:
                // Should not happen for Automaton<DFSA>, but be defensive.
                return Automaton<NFSA>(initial: 0, finals: [], transitions: [])
            }
        }

        // NFA ε-union with token-map propagation.
        var united = Automaton<NFSA>.union(list: nfas)
        // Re-determinize; the token-aware powerset construction in
        // Determinize.swift will collapse accepting NFA state sets and pick
        // the highest-priority token class for each DFA accepting state.
        united.determinize()

        // Re-wrap as Automaton<DFSA>.
        switch united.state {
        case let .dfa(initial, finals, transitions, minimal, tokenMap):
            return Automaton<DFSA>(
                initial: initial,
                finals: finals,
                transitions: transitions,
                minimal: minimal,
                tokenMap: tokenMap)
        case .nfa:
            // determinize() should always produce .dfa. Defensive fallback.
            return Automaton<DFSA>(
                initial: 0, finals: [], transitions: [], minimal: false)
        }
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
        return Automaton(DFSA(initial: initial, finals: accept, transitions: transitions))
    }
}
