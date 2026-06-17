//
//  Determinize.swift
//  Grammar-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/11.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

// MARK: - Determinization with Token Tracking
//
// Lives on the generic `State` extension rather than `State<NFSA>` so that
// both `NFSA.determinize()` and `Regex.isDeterministic = true` go through
// the *same* token-aware powerset construction. Previously `Regex` had its
// own non-token-aware `powerset(...)` in RegexPowerset.swift; that path
// silently dropped every TokenClass attached to the NFA's accepting states.

extension State {

    /// Converts this NFA into a DFA using the powerset (subset) construction,
    /// preserving the token-class map so that each DFA accepting state is labelled
    /// with the highest-priority token class from the corresponding NFA state set.
    ///
    /// Priority resolution: when several NFA accepting states collapse into one DFA
    /// state the token class with the *lowest* `priority` integer wins, matching the
    /// first-rule-wins convention used by scanner generators.
    ///
    /// - Complexity: O(2^|Q|) worst case, O(|Q|·|Σ|) typical.
    public mutating func determinize() {
        guard case .nfa(let initial, let finals, let transitions, let tokenMap) = self else {
            return  // Already deterministic; nothing to do.
        }

        typealias StateSet = Set<Int>

        var dfaStates: [StateSet: Int] = [:]   // NFA state-set  →  DFA state id
        var dfaFinals      = Set<Int>()
        var dfaTransitions = Set<Transition>()
        var dfaTokenMap: [Int: TokenClass] = [:]
        var nextId = 0                          // DFA state-id counter
        var workList: [StateSet] = []

        // ── Initial DFA state ────────────────────────────────────────────────
        let initialClosure = epsilonClosure(Set([initial]), over: transitions)
        dfaStates[initialClosure] = nextId
        let dfaInitial = nextId
        nextId += 1
        workList.append(initialClosure)

        // Tag the initial state if it is already accepting.
        if let rep = findHighestPriorityAcceptingState(
                in: initialClosure, finals: finals, tokenMap: tokenMap) {
            dfaFinals.insert(dfaInitial)
            if let token = tokenMap[rep] { dfaTokenMap[dfaInitial] = token }
        }

        // ── Main subset-construction loop ────────────────────────────────────
        //
        // Optimisation (§3.5): the previous implementation iterated over
        // `transitions.alphabet().characters`, which materialises every
        // Unicode scalar in every range — thousands of characters for a
        // regex like [\p{L}]. Instead we iterate over *equivalence
        // classes* of the alphabet, computed from the boundary points of
        // every transition range. Within each equivalence class the set
        // of matching NFA transitions is constant, so the move set is
        // constant across the class and we can emit a single `.range`
        // transition covering the whole class.
        let equivalenceClasses = computeAlphabetEquivalenceClasses(transitions)

        while let nfaStateSet = workList.popLast() {
            let currentDfaState = dfaStates[nfaStateSet]!

            for cls in equivalenceClasses {

                // move(nfaStateSet, representative) — representative is
                // any character in [cls.lo, cls.hi]; we use cls.lo.
                let representative = Character(UnicodeScalar(cls.lo)!)

                var nextNfaStates = Set<Int>()
                for nfaState in nfaStateSet {
                    nextNfaStates.formUnion(
                        move(state: nfaState, symbol: representative, over: transitions))
                }
                guard !nextNfaStates.isEmpty else { continue }

                let nextClosure = epsilonClosure(nextNfaStates, over: transitions)

                // Get or create the DFA state for this NFA state set.
                let targetDfaState: Int
                if let existing = dfaStates[nextClosure] {
                    targetDfaState = existing
                } else {
                    targetDfaState = nextId          // assign fresh id
                    dfaStates[nextClosure] = targetDfaState
                    nextId += 1
                    workList.append(nextClosure)

                    // Tag if accepting.
                    if let rep = findHighestPriorityAcceptingState(
                            in: nextClosure, finals: finals, tokenMap: tokenMap) {
                        dfaFinals.insert(targetDfaState)
                        if let token = tokenMap[rep] { dfaTokenMap[targetDfaState] = token }
                    }
                }

                let rangeLabel: AlphabetRange
                if cls.lo == cls.hi {
                    rangeLabel = .char(Character(UnicodeScalar(cls.lo)!))
                } else {
                    rangeLabel = .range(
                        Character(UnicodeScalar(cls.lo)!),
                        Character(UnicodeScalar(cls.hi)!))
                }
                dfaTransitions.insert(
                    Transition(from: currentDfaState, rangeLabel, to: targetDfaState))
            }
        }

        // ── Replace this state with the resulting DFA ────────────────────────
        // We must preserve the phantom type T by re-wrapping through whichever
        // case pattern matched above. The simplest portable approach is to
        // re-construct via the concrete constructors the runtime already knows
        // are valid (we matched `.nfa`, so the original T must accept a `.dfa`
        // payload — this is true for NFSA, DFSA, and Regex alike because all
        // three allow both enum cases).
        switch self {
        case .nfa:
            self = .dfa(
                initial:    dfaInitial,
                finals:     dfaFinals,
                transitions: dfaTransitions,
                minimal:    false,
                tokenMap:   dfaTokenMap
            )
        case .dfa:
            // Already deterministic; guarded above. No-op.
            return
        }
    }

    // MARK: - Private helpers

    /// Returns the NFA accepting state with the highest priority (lowest `priority`
    /// integer) from `stateSet ∩ finals`, or `nil` if the intersection is empty.
    private func findHighestPriorityAcceptingState(
        in stateSet: Set<Int>,
        finals: Set<Int>,
        tokenMap: [Int: TokenClass]
    ) -> Int? {
        stateSet.intersection(finals).min { a, b in
            (tokenMap[a]?.priority ?? Int.max) < (tokenMap[b]?.priority ?? Int.max)
        }
    }

    /// Computes the disjoint equivalence classes of the alphabet implied by
    /// `transitions`.
    ///
    /// Two characters belong to the same equivalence class iff they match the
    /// *same* set of transitions in `transitions`. We compute these by
    /// collecting every range's lower bound and (upper bound + 1) as boundary
    /// points; between two consecutive boundaries the matching-transition set
    /// is constant.
    ///
    /// The result is a sorted list of half-open intervals expressed as
    /// `(lo, hi)` inclusive pairs. ε-transitions are ignored.
    ///
    /// - Complexity: O(|Δ| · log |Δ|) — one sort of the boundary set.
    private func computeAlphabetEquivalenceClasses(
        _ transitions: Set<Transition>
    ) -> [(lo: UInt32, hi: UInt32)] {
        // Collect boundary points: every range's lo and (hi+1).
        // We use UInt32 to support the full Unicode scalar range.
        var boundaries = Set<UInt32>()
        for t in transitions {
            switch t.alphabetRange {
            case .epsilon:
                continue
            case .char(let ch):
                let v = ch.unicodeScalars.first!.value
                boundaries.insert(v)
                boundaries.insert(v + 1)
            case .range(let lo, let hi):
                let loV = lo.unicodeScalars.first!.value
                let hiV = hi.unicodeScalars.first!.value
                boundaries.insert(loV)
                boundaries.insert(hiV + 1)
            }
        }
        guard !boundaries.isEmpty else { return [] }

        let sorted = boundaries.sorted()
        var classes: [(lo: UInt32, hi: UInt32)] = []
        for i in 0..<(sorted.count - 1) {
            let lo = sorted[i]
            let hi = sorted[i + 1] - 1
            if hi >= lo {   // skip empty intervals (shouldn't happen, but defensive)
                classes.append((lo, hi))
            }
        }
        return classes
    }
}
