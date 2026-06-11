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

extension Deterministic {

    mutating func invariant() {
        // deterministic()
        removeZombieAcceptStates()
        eliminateDeadStates()
        removeDeadTransitions()
        reduce()
    }
    
    /// Removes all zombie states among the accept states.
    /// Accept states that do not have any transitions attached should be removed.
    /// This might occur when parsing Automata from file, or by human error during automata
    /// construction.
    mutating func removeZombieAcceptStates() {
        guard case let .dfa(initial,finals,transitions,minimal) = self.state else { fatalError() }

        let zombies = finals.subtracting(transitions.states())
        if zombies.count > 0 {
            let newAccepts = finals.subtracting(zombies)
            os_log("zombie accept states removed %@", log: OSLog.default, type: .debug, " \(zombies)")
            self.state = .dfa(initial: initial, finals: newAccepts, transitions: transitions, minimal: minimal)
        }
    }

    /// Eliminate all non-initial states from the automaton from which no final state is reachable.
    mutating func eliminateDeadStates() {
        guard case var .dfa(_,finals,transitions,_) = self.state else { fatalError() }

        // Forward reachability, keep only states that are reachable from the initial state
        let stack = Stack<Int>()
        stack.push(initial)
        var reachables: Set<Int> = Set<Int>(arrayLiteral: initial)
        while !stack.isEmpty {
            let q = stack.pop()
            for s in reachableStates(from: q) {
                if reachables.insert(s).inserted {
                    stack.push(s)
                }
            }
        }

        // Eliminate all nonreachable states, i.e. states not in set of reachables.
        var unreachableStates: [Int] = []
        for state in transitions.states() {
            if !reachables.contains(state) {
                unreachableStates.append(state)
            }
        }

        os_log("unreachable states %@", log: OSLog.default, type: .debug, " \(unreachableStates)")

        for state in unreachableStates {
            // erases the bad transitions and leaves the good ones.
            transitions = transitions.filter { $0.source != state && $0.target != state }
            // the opposite -> leaves only bad transitions.
            // dfa.transitions = dfa.transitions.filter { $0.source == state || $0.target == state }
            finals.remove(state)
        }
    }

    /// Removes transitions to dead states, where a state is "dead" if no accept state is reachable from it.
    /// This methid eliminates all non-initial states from the automaton from which no final state is reachable.
    mutating func removeDeadTransitions() {
        guard case var .dfa(_,_,transitions,_) = self.state else { fatalError() }
        
        let all: Set<Int> = transitions.states()
        let forwardMap = transitions.forwardMap()
        var reachable: Set<Int> = Set<Int>(arrayLiteral: initial)
        var newStates: Set<Int> = Set<Int>(arrayLiteral: initial)
        
        repeat {
            var temp = Set<Int>()
            for s in newStates {
                if let states = forwardMap[s] {
                    temp.formUnion( Set<Int>(states) )
                }
            }
            newStates = temp.subtracting(reachable)
            reachable.formUnion(newStates)
        } while (!newStates.isEmpty)
        let unreachableStates: Set<Int> = all.subtracting(reachable)
        
        os_log("unreachable states %@", log: OSLog.default, type: .debug, " \(unreachableStates)")
        
        if unreachableStates.count > 0 {
            var useful: [Transition] = []
            for s in unreachableStates {
                useful.append(contentsOf: transitions.filter { $0.target != s } )
            }
            transitions = Set<Transition>(useful)
        }
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
        guard case var .dfa(_,_,transitions,_) = self.state else { return }

        /// *** transitions have to be sorted ***
        /// sort order: 1.from 2.range 3.to

        // create an empty stack of transitions
        let stack = Stack<Transition>()
        
        // push the first interval to stack
        if let transition = transitions.first {
            stack.push(transition)
        }
        
        // Start from the next transition and merge with top transition in stack if they do overlap.
        transitions.dropFirst().forEach { (transition) in
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
    }
}
