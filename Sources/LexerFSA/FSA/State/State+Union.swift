//
//  State+Union.swift
//  lexer-fsa
//
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/21.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

//  NFA ε-union with token-map propagation, relocated from the former
//  `Automaton<Type>` container. Lives on `State<NFSA>` so both
//  `LexerBuilder.build()` (which unions NFA components before determinizing)
//  and `DFSA.union(_:)` (which projects DFAs to NFAs, unions, and
//  re-determinizes) can share the exact same construction.

extension State where T == NFSA {

    /// Returns the union of two NFAs: a fresh automaton whose language is
    /// `L(a) ∪ L(b)` and whose token map is the disjoint union of the two
    /// component token maps (with state ids renumbered so the two component
    /// state spaces do not collide).
    public static func union(_ a: State<NFSA>, _ b: State<NFSA>) -> State<NFSA> {
        return union(list: [a, b])
    }

    /// Returns an NFA accepting the union of the languages of the given
    /// automata, with token classes propagated from each component.
    ///
    /// Construction (textbook ε-union):
    ///   1. Renumber each component's states into a disjoint range using a
    ///      *local* counter (not a global singleton — a global counter made
    ///      union results depend on prior builds, which broke reproducibility).
    ///   2. Allocate a fresh initial state `q0`.
    ///   3. Add an ε-transition from `q0` to each component's renumbered
    ///      initial state.
    ///   4. Take the union of all transition sets and all final-state sets.
    ///   5. Build the resulting token map by renumbering each component's
    ///      `(finalState, tokenClass)` pairs.
    ///
    /// - Complexity: O(|Q| + |Δ|) in the total size of the input automata.
    public static func union(list: [State<NFSA>]) -> State<NFSA> {
        guard !list.isEmpty else {
            return .nfa(initial: 0, finals: [], transitions: [], tokenMap: [:])
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
            guard case let .nfa(cInitial, cFinals, cTransitions, cTokenMap) = component else {
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

        return .nfa(
            initial: newInitial,
            finals: unionFinals,
            transitions: unionTransitions,
            tokenMap: unionTokenMap)
    }
}
