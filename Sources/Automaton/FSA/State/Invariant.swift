//
//  Invariant.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/04.
//

import Foundation
import os.log

/// Deterministic invariants:
/// An automaton is either represented explicitly
/// • with *State* and *Transition* objects or
/// • with a singleton string in case the automaton is known to accept exactly one string.
/// Automata are always reduced (see *reduce()*) and have no transitions to dead states (see *removeDeadTransitions()*).
/// If an automaton is nondeterministic, then isDeterministic() returns false (but the converse is not required).
/// Automata provided as input to operations are generally assumed to be disjoint.
///
/// If the states or transitions are manipulated manually, then the *restoreInvariant()* and
/// *setDeterministic(boolean)* methods should be used afterwards to preserve representation invariants
/// that are assumed by the built-in automata operations.

extension FSA {

    /// Removes all zombie states among the accept states.
    /// Accept states that do not have any transitions attached should be removed.
    /// This might occur when parsing Automata from file, or by human error during automata
    /// construction.
    ///
    /// Works on both DFAs and NFAs.
    mutating func removeZombieAcceptStates() {
        switch self.state {
        case let .nfa(initial, finals, transitions, tokenMap):
            let zombies = finals.subtracting(transitions.states())
            if !zombies.isEmpty {
                let newFinals = finals.subtracting(zombies)
                let newTokenMap = tokenMap.filter { !zombies.contains($0.key) }
                os_log("zombie accept states removed %@", log: OSLog.default, type: .debug, "\(zombies)")
                self.state = .nfa(initial: initial, finals: newFinals, transitions: transitions, tokenMap: newTokenMap)
            }
        case let .dfa(initial, finals, transitions, minimal, tokenMap):
            let zombies = finals.subtracting(transitions.states())
            if !zombies.isEmpty {
                let newFinals = finals.subtracting(zombies)
                let newTokenMap = tokenMap.filter { !zombies.contains($0.key) }
                os_log("zombie accept states removed %@", log: OSLog.default, type: .debug, "\(zombies)")
                self.state = .dfa(initial: initial, finals: newFinals, transitions: transitions, minimal: minimal, tokenMap: newTokenMap)
            }
        }
    }

    /// Eliminate all non-initial states from the automaton from which no final state is reachable.
    ///
    /// Works on both DFAs and NFAs. The previous implementation `fatalError`-ed
    /// when called on an `.nfa` state — which made the invariant pass unusable
    /// during NFA construction, exactly when it is most useful.
    mutating func eliminateDeadStates() {
        switch self.state {
        case let .nfa(initial, var finals, var transitions, var tokenMap):
            // Forward reachability — keep only states reachable from the initial state.
            let stack = Stack<Int>()
            stack.push(initial)
            var reachables: Set<Int> = [initial]
            while !stack.isEmpty {
                let q = stack.pop()
                for s in reachableStates(from: q) {
                    if reachables.insert(s).inserted { stack.push(s) }
                }
            }

            var unreachable: [Int] = []
            for s in transitions.states() {
                if !reachables.contains(s) { unreachable.append(s) }
            }
            os_log("unreachable states %@", log: OSLog.default, type: .debug, "\(unreachable)")

            for s in unreachable {
                transitions = transitions.filter { $0.source != s && $0.target != s }
                finals.remove(s)
                tokenMap.removeValue(forKey: s)
            }
            self.state = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)

        case let .dfa(initial, var finals, var transitions, minimal, var tokenMap):
            // Forward reachability — keep only states reachable from the initial state.
            let stack = Stack<Int>()
            stack.push(initial)
            var reachables: Set<Int> = [initial]
            while !stack.isEmpty {
                let q = stack.pop()
                for s in reachableStates(from: q) {
                    if reachables.insert(s).inserted { stack.push(s) }
                }
            }

            var unreachable: [Int] = []
            for s in transitions.states() {
                if !reachables.contains(s) { unreachable.append(s) }
            }
            os_log("unreachable states %@", log: OSLog.default, type: .debug, "\(unreachable)")

            for s in unreachable {
                transitions = transitions.filter { $0.source != s && $0.target != s }
                finals.remove(s)
                tokenMap.removeValue(forKey: s)
            }
            self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
        }
    }

    /// Removes transitions to dead states, where a state is "dead" if no accept state is reachable from it.
    ///
    /// Works on both DFAs and NFAs. (NFAs typically don't accumulate dead
    /// transitions during construction, but manual editing or file parsing
    /// can introduce them — being able to clean them up uniformly is
    /// convenient.)
    mutating func removeDeadTransitions() {
        switch self.state {
        case let .nfa(initial, finals, var transitions, tokenMap):
            let all: Set<Int> = transitions.states()
            let forwardMap = transitions.forwardMap()
            var reachable: Set<Int> = [initial]
            var newStates: Set<Int> = [initial]

            repeat {
                var temp = Set<Int>()
                for s in newStates {
                    if let states = forwardMap[s] { temp.formUnion(Set<Int>(states)) }
                }
                newStates = temp.subtracting(reachable)
                reachable.formUnion(newStates)
            } while !newStates.isEmpty

            let unreachableStates: Set<Int> = all.subtracting(reachable)
            os_log("unreachable states %@", log: OSLog.default, type: .debug, "\(unreachableStates)")

            if !unreachableStates.isEmpty {
                var useful: [Transition] = []
                for s in unreachableStates {
                    useful.append(contentsOf: transitions.filter { $0.target != s })
                }
                transitions = Set<Transition>(useful)
            }
            self.state = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)

        case let .dfa(initial, finals, var transitions, minimal, tokenMap):
            let all: Set<Int> = transitions.states()
            let forwardMap = transitions.forwardMap()
            var reachable: Set<Int> = [initial]
            var newStates: Set<Int> = [initial]

            repeat {
                var temp = Set<Int>()
                for s in newStates {
                    if let states = forwardMap[s] { temp.formUnion(Set<Int>(states)) }
                }
                newStates = temp.subtracting(reachable)
                reachable.formUnion(newStates)
            } while !newStates.isEmpty

            let unreachableStates: Set<Int> = all.subtracting(reachable)
            os_log("unreachable states %@", log: OSLog.default, type: .debug, "\(unreachableStates)")

            if !unreachableStates.isEmpty {
                var useful: [Transition] = []
                for s in unreachableStates {
                    useful.append(contentsOf: transitions.filter { $0.target != s })
                }
                transitions = Set<Transition>(useful)
            }
            self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
        }
    }
}

extension Deterministic {

    mutating func invariant() {
        // deterministic()
        removeZombieAcceptStates()
        eliminateDeadStates()
        removeDeadTransitions()
        reduce()
    }

    /// Reduces this automaton.
    /// An automaton is "reduced" by combining overlapping and adjacent edge intervals with same destination.
    /// 1. Sort the transitions based on increasing order.
    /// 2. Push the first transition onto the stack.
    /// 3. For each transition do the following
    ///    a. If the current transition does not overlap with the stack top, push it.
    ///    b. If the current transition overlaps with stack top and character interval
    ///       of current transition is wider than that of stack top, update stack top
    ///       with the character endpoint of current transition.
    /// 4. At the end stack contains the merged intervals.
    /// - Note: Transitions have to be sorted.
    mutating func reduce() {
        guard case .dfa(let initial, let finals, var transitions, let minimal, let tokenMap) = self.state else { return }

        // Transitions must be sorted: 1. source, 2. alphabetRange, 3. target.
        let stack = Stack<Transition>()

        if let first = transitions.sorted().first { stack.push(first) }

        transitions.sorted().dropFirst().forEach { transition in
            guard let top = stack.top, !stack.isEmpty else { return }
            if Transition.equalEndpoints(lhs: top, rhs: transition) {
                if AlphabetRange.overlapping(lhs: top.alphabetRange, rhs: transition.alphabetRange) {
                    if top.alphabetRange.upper < transition.alphabetRange.upper {
                        _ = stack.pop()
                        stack.push(Transition(from: top.source, .range(top.alphabetRange.lower, transition.alphabetRange.upper), to: top.target))
                    }
                } else {
                    stack.push(transition)
                }
            } else {
                stack.push(transition)
            }
        }

        transitions = Set<Transition>(stack.content())
        self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
    }
}
