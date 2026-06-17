//
//  Minimize.swift
//  Grammar-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/02/16.
//

import Foundation

// MARK: - Token-Class-Aware DFA Minimization (Hopcroft's algorithm)

extension DFSA {

    /// Minimizes this DFA using Hopcroft's algorithm, extended to treat states
    /// that carry *different* token classes as distinguishable even when their
    /// transition behaviour is otherwise identical.
    ///
    /// After minimization `isMinimal` returns `true`.
    ///
    /// - Note: Only DFA states are handled; the method is a no-op if the
    ///   internal state is `.nfa`.
    public mutating func minimize() {
        guard case .dfa(let initial, let finals, let transitions, _, let tokenMap) = state else {
            return  // Only minimize DFAs.
        }

        let allStates = Set(transitions.flatMap { [$0.source, $0.target] }).union([initial])
        let alphabet  = transitions.alphabet().characters

        // ── Initial partition ────────────────────────────────────────────────
        // Non-accepting states share one block; accepting states are grouped by
        // token class so that states with different classes are never merged.
        //
        // We use a sorted array of partitions rather than Set<Set<Int>> so
        // that the new-state-id assignment is deterministic across runs
        // (Set<Set<Int>> iteration order is unstable).

        var partitions: [Set<Int>] = []

        let nonAccepting = allStates.subtracting(finals)
        if !nonAccepting.isEmpty { partitions.append(nonAccepting) }

        var tokenGroups: [TokenClass: Set<Int>] = [:]
        for s in finals {
            if let token = tokenMap[s] {
                tokenGroups[token, default: []].insert(s)
            } else {
                // Accepting state with no token class gets its own singleton block.
                partitions.append([s])
            }
        }
        // Sort token groups by token id so partition order is stable.
        for (_, group) in tokenGroups.sorted(by: { $0.key.id < $1.key.id }) {
            partitions.append(group)
        }

        // ── Hopcroft refinement loop ─────────────────────────────────────────
        var workList = Array(partitions)

        while let splitter = workList.popLast() {
            for symbol in alphabet {

                // Collect states that transition into `splitter` via `symbol`.
                var predecessors = Set<Int>()
                for s in splitter {
                    predecessors.formUnion(
                        getPredecessors(of: s, with: symbol, in: transitions))
                }

                var newPartitions: [Set<Int>] = []
                for partition in partitions {
                    let inside  = partition.intersection(predecessors)
                    let outside = partition.subtracting(predecessors)

                    if inside.isEmpty || outside.isEmpty {
                        newPartitions.append(partition)     // no split
                        continue
                    }

                    // Split: replace `partition` with the two halves.
                    newPartitions.append(inside)
                    newPartitions.append(outside)

                    // Update the work list.
                    if let idx = workList.firstIndex(of: partition) {
                        workList.remove(at: idx)
                        workList.append(inside)
                        workList.append(outside)
                    } else {
                        // Add the smaller half (standard Hopcroft optimisation).
                        workList.append(inside.count <= outside.count ? inside : outside)
                    }
                }
                partitions = newPartitions
            }
        }

        // ── Build the minimized DFA ──────────────────────────────────────────
        // Sort partitions by their minimum state id so the new sequential ids
        // are assigned deterministically across runs.
        partitions.sort { $0.min() ?? -1 < $1.min() ?? -1 }

        // Assign a fresh sequential id to each equivalence class.
        var stateMap: [Int: Int] = [:]
        var newId = 0
        for partition in partitions {
            for s in partition { stateMap[s] = newId }
            newId += 1
        }

        let newInitial = stateMap[initial]!
        var newFinals      = Set<Int>()
        var newTransitions = Set<Transition>()
        var newTokenMap: [Int: TokenClass] = [:]

        // Map accepting states and their token classes.
        for s in finals {
            let mapped = stateMap[s]!
            newFinals.insert(mapped)
            if let token = tokenMap[s] { newTokenMap[mapped] = token }
        }

        // Map transitions, deduplicated.
        // Support both .char and .range labels so the minimizer works on the
        // full AlphabetRange, not just single-character transitions.
        var seen = Set<Transition>()
        for t in transitions {
            let src = stateMap[t.source]!
            let tgt = stateMap[t.target]!
            let mapped: Transition
            switch t.alphabetRange {
            case .epsilon:
                mapped = Transition(from: src, AlphabetRange.epsilon, to: tgt)
            case .char(let c):
                mapped = Transition(from: src, AlphabetRange.char(c), to: tgt)
            case .range(let lo, let hi):
                mapped = Transition(from: src, AlphabetRange.range(lo, hi), to: tgt)
            }
            if seen.insert(mapped).inserted { newTransitions.insert(mapped) }
        }

        state = State(
            initial:     newInitial,
            finals:      newFinals,
            transitions: newTransitions,
            minimal:     true,
            tokenMap:    newTokenMap
        )
    }

    // MARK: - Private helper

    /// Returns all states that reach `target` by consuming `symbol`.
    private func getPredecessors(
        of target: Int,
        with symbol: Character,
        in transitions: Set<Transition>
    ) -> Set<Int> {
        var result = Set<Int>()
        for t in transitions where t.target == target {
            switch t.alphabetRange {
            case .char(let c) where c == symbol:
                result.insert(t.source)
            case .range(let lo, let hi) where symbol >= lo && symbol <= hi:
                result.insert(t.source)
            default:
                break
            }
        }
        return result
    }
}
