//
//  Determinize.swift
//  Grammar-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/11.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

// MARK: - Determinization with Token Tracking

extension State where T == NFSA {

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
        let alphabet = transitions.alphabet().characters

        while let nfaStateSet = workList.popLast() {
            let currentDfaState = dfaStates[nfaStateSet]!

            for symbol in alphabet {

                // move(nfaStateSet, symbol)
                var nextNfaStates = Set<Int>()
                for nfaState in nfaStateSet {
                    nextNfaStates.formUnion(
                        move(state: nfaState, symbol: symbol, over: transitions))
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

                dfaTransitions.insert(
                    Transition(from: currentDfaState, AlphabetRange.char(symbol), to: targetDfaState))
            }
        }

        // ── Replace this state with the resulting DFA ────────────────────────
        self = .dfa(
            initial:    dfaInitial,
            finals:     dfaFinals,
            transitions: dfaTransitions,
            minimal:    false,
            tokenMap:   dfaTokenMap
        )
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
}
