//
//  Brzozowski.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/07.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension State where T == DeterministicFiniteState {

    /// This algorithm uses the reverse-determinize-reverse-determinize
    /// trick, which has a bad worst-case behavior but often works very well
    /// in practice (even better than Hopcroft's).

    /// Minimizes the given automaton using Brzozowski's algorithm.
    /// The 'reverse-determinize-reverse-determinize' magical trick.
    ///
    /// Constructs a minimal complete DFA.
    func minimizeBrzozowski(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
//        defer { invariant() }
        
//        var reversedFiniteStates = determinize(nondeterministic: reverse(dfa))
//        reversedFiniteStates = determinize(nondeterministic: reverse(reversedFiniteStates))
//        return (initial: reversedFiniteStates.initial, finals: reversedFiniteStates.finals, transitions: reversedFiniteStates.transitions, minimal: true)
        return (initial: 0, finals: Set<Int>(), transitions: Set<Transition>(), minimal: false)
    }
    
    /// Reverses the language of the given DFA.
    /// - Parameter dfa: deterministic Finite State Automaton
    /// Returns: reversed automaton.
    func reverse(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> (initial: Int, finals: [Int], transitions: [Transition]) {
        let S = Counter.shared
        let (initial: start, finals: accept, transitions: transitions) = dfa
        let newStart = S()
        var reversed: Set<Transition> = transitions.reversed()

        // ensures that all initial states are reachable
        for s in accept {
            reversed.insert(Transition(from: newStart, .epsilon, to: s))
        }

        // old start state becomes the new terminal
        return (initial: newStart, finals: [start], transitions: Array(reversed))
    }
}
