//
//  NFSA+Operations.swift
//  lexer-fsa
//
//  Created by code review on 2026/06/23.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

//  Convenience wrappers around `State<NFSA>.union(list:)` (State+Union.swift),
//  added so callers working with `NFSA` directly don't need to reach into
//  `State<NFSA>` themselves. Mirrors `DFSA.union(_:_:)`/`DFSA.union(_:)` in
//  `DFSA+Operations.swift`, which is implemented by projecting DFAs down to
//  this same NFA-level union and re-determinizing. Keeping both wrappers
//  side by side closes the asymmetry where `DFSA` had a public `union` API
//  and `NFSA` did not.

extension NFSA {

    /// Returns an NFA accepting the union of the languages of two NFAs.
    ///
    /// - Parameters:
    ///   - a: One automaton's language.
    ///   - b: Another automaton's language.
    /// - Returns: A nondeterministic automaton accepting the union language,
    ///   with token classes propagated from each component.
    public static func union(_ a: NFSA, _ b: NFSA) -> NFSA {
        return union([a, b])
    }

    /// Returns an NFA accepting the union of the languages of the given NFAs.
    ///
    /// - Parameter list: Automata whose languages are to be unified.
    /// - Returns: A nondeterministic automaton accepting the union language,
    ///   with token classes propagated from each component.
    /// - Complexity: O(|Q| + |Δ|) in the total size of the input automata.
    public static func union(_ list: [NFSA]) -> NFSA {
        guard !list.isEmpty else {
            return NFSA(initial: 0, finals: [], transitions: [])
        }
        if list.count == 1 { return list[0] }

        let components: [State<NFSA>] = list.map { $0.state }
        let united = State<NFSA>.union(list: components)

        guard case let .nfa(initial, finals, transitions, tokenMap) = united else {
            // State<NFSA>.union always returns .nfa. Defensive fallback.
            return NFSA(initial: 0, finals: [], transitions: [])
        }
        return NFSA(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)
    }
}
