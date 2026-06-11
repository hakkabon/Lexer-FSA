//
//  RegexDfa.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/05/27.
//

import Foundation
import os.log

/// An NFA can be made deterministic by the powerset construction and then be minimized to get an optimal
/// automaton corresponding to the given regular expression. However, an NFA may also be interpreted
/// directly.
///
/// [1] Alfred V. Aho; Monica S. Lam; Ravi Sethi; Jeffrey D. Ullman (2007).
///     "3.7.1 Conversion of an NFA to a DFA"
/// - Returns: Deterministic finite automaton without ε-moves.

/// ε-NFA to DFA transform.
/// In the theory of computation and automata theory, the powerset, or subset, construction
/// is a standard method for converting a nondeterministic finite automaton (NFA) into a deterministic
/// finite automaton (DFA) which recognizes the same formal language. It is important in theory because
/// it establishes that NFAs, despite their additional flexibility, are unable to recognize any language
/// that cannot be recognized by some DFA. It is also important in practice for converting easier-to-construct
/// NFAs into more efficiently executable DFAs. However, if the NFA has n states, the resulting DFA may
/// have up to 2^n states, an exponentially larger number, which sometimes makes the construction impractical
/// for large NFAs.

extension Regex {
    
    // Powerset construction method.
    public mutating func powerset(initial: Int, finals: Set<Int>, transitions: Set<Transition>) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>) {
        /// Number generator.
        let S = Counter.shared

        /// Deterministic Finite State Automaton.
        var dfa = (initial: S(), finals: Set<Int>(), transitions: Set<Transition>())

        let alphabet = transitions.alphabet()
        guard alphabet.characterClasses.count > 0 else { return dfa }

        // Mapping from NFA states to their corresponding DFA state.
        var nfa2dfa = Dictionary<Set<Int>, Int>()
         
        let collectSets = { (nfaStates: Set<Int>) -> Int in
            if let state = nfa2dfa[nfaStates] {
                return state
            } else {
                let dfaState: Int = S()
                nfa2dfa[nfaStates] = dfaState
                return dfaState
            }
        }

        let initStates = epsClosure(state: initial, over: transitions)

        os_log("initial 𝛆-closure %@", log: OSLog.default, type: .debug, " \(setNotation(initStates))")

        var worklist: [Set<Int>] = [initStates]
        var visited: Set<Set<Int>> = []
        
        dfa.initial = collectSets(initStates)
        while !worklist.isEmpty {
            let states = worklist.removeFirst()
            if visited.contains(states) { continue }
            visited.insert(states)
            
            let state = collectSets(states)
            
            // Mark terminal if containing terminal NFA state.
            if !states.intersection(finals).isEmpty {
                dfa.finals.insert(state)
            }
            
            for ch in alphabet.characters {
                // move(A,ch)
                var nextStates = states.reduce(Set<Int>(), { $0.union(move(state: $1, symbol: ch, over: transitions)) })

                os_log("step (%@, %@): %@", log: OSLog.default, type: .debug, "\(setNotation(states))", "\(ch)", "\(setNotation(nextStates))")

                // Skip empty states.
                if nextStates.isEmpty { continue }

                // 𝛆-closure( move(A,ch) )
                nextStates = nextStates.reduce(Set<Int>(), { $0.union(epsClosure(state: $1, over: transitions)) })

                os_log("𝛆-closure(step(state,%@): ", log: OSLog.default, type: .debug, "\(ch)", "\(setNotation(nextStates))")

                let dfaState = collectSets(nextStates)
                dfa.transitions.insert(Transition(from: state, .char(ch), to: dfaState))
                worklist.append(nextStates)
            }
        }
        return dfa
    }
}
