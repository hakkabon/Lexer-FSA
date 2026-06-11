//
//  Powerset.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/15.
//  Copyright © 2020 hakkabon software. All rights reserved.
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

extension State where T == NondeterministicFiniteState {

    /// Converts a Nondeterministic Finite Automaton (NFA) into a Deterministic Finite Automaton (DFA).
    ///
    /// This method implements the **Powerset Construction** (also known as Subset Construction) algorithm.
    /// It creates a new DFA where each state represents a set of states from the original NFA.
    ///
    /// - Parameter nfa: The input `NfaTuple` representing the nondeterministic automaton.
    /// - Returns: A `DfaTuple` representing the equivalent deterministic automaton.
    /// - Complexity: Exponential in the worst case relative to the number of NFA states, though often much smaller in practice.
    public func determinize(nondeterministic nfa: NfaTuple) -> DfaTuple {
        /// Number generator.
        let S = Counter.shared
        
        /// Deterministic Finite State Automaton.
        var fsa: DfaTuple = (initial: S(), finals: Set<Int>(), transitions: Set<Transition>(), minimal: false)
        
        let alphabet = nfa.transitions.alphabet()
        guard alphabet.characterClasses.count > 0 else { return fsa }
        
        // Mapping from NFA states to their corresponding DFA state.
        var nfa2dfa = Dictionary<Set<Int>, Int>()
        
        let collectSets = { (nfaStates: Set<Int>) -> Int in
            if let state = nfa2dfa[nfaStates] {
                return state
            } else {
                let dfaState = S()
                nfa2dfa[nfaStates] = dfaState
                return dfaState
            }
        }
        
        let initStates = epsClosure(nfa.initial, over: nfa.transitions)
        
        os_log("initial 𝛆-closure %@", log: OSLog.default, type: .debug, " \(setNotation(initStates))")
        
        var worklist: [Set<Int>] = [initStates]
        var visited: Set<Set<Int>> = []
        
        fsa.initial = collectSets(initStates)
        while !worklist.isEmpty {
            let states = worklist.removeFirst()
            if visited.contains(states) { continue }
            visited.insert(states)
            
            let state = collectSets(states)
            
            // Mark terminal if containing terminal NFA state.
            if states.contains(where: { nfa.finals.contains($0) }) {
                fsa.finals.insert(state)
            }
            
            for ch in alphabet.characters {
                // step(A,ch)
                var nextStates = states.reduce(Set<Int>(), { $0.union(delta($1, ch: ch, over: nfa.transitions)) })
                
                os_log("step (%@, %@): %@", log: OSLog.default, type: .debug, "\(setNotation(states))", "\(ch)", "\(setNotation(nextStates))")
                
                // Skip empty states.
                if nextStates.isEmpty { continue }
                
                // 𝛆-closure( step(state,ch) )
                nextStates = nextStates.reduce(Set<Int>(), { $0.union(epsClosure($1, over: nfa.transitions)) })
                
                os_log("𝛆-closure(step(state,%@): ", log: OSLog.default, type: .debug, "\(ch)", "\(setNotation(nextStates))")
                
                let dfaState = collectSets(nextStates)
                fsa.transitions.insert(Transition(from: state, .char(ch), to: dfaState))
                worklist.append(nextStates)
            }
        }
        return fsa
    }

    // NFA move(A,ch) without 𝛆-Transition.
    private func delta(_ state: Int, ch: Character, over transitions: Set<Transition>) -> Set<Int> {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }
        transitions.forEach({ edge in
            switch edge.alphabetRange {
            case .epsilon: fatalError()
            case .char(_):
                if edge.inAlphabet(char: ch) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(ch, ch) {
                    nextStates.insert(edge.target)
                }
            }
        })
        return nextStates
    }

    /// 𝛆-closure
    /// - Parameter state: a given start state
    /// - Returns: Set of states that are reachable from the given start state merely using 𝛆-moves.
    private func epsClosure(_ state: Int, over transitions: Set<Transition>) -> Set<Int> {
        var closure: Set<Int> = [state]

        // DFS with a stack.
        var stack: [Int] = [state]
        while !stack.isEmpty {
            let state = stack.removeLast()
            let transitions = transitions.filter { $0.source == state }
            transitions.forEach({ edge in
                switch edge.alphabetRange {
                case .epsilon:
                    if closure.insert(edge.target).inserted {
                        stack.append(edge.target)
                    }
                case .char(_): break
                case .range(_,_): break
                }
            })
        }
        return closure
    }
}
