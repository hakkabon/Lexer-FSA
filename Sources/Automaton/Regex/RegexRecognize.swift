//
//  RegexRecognize.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/02.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension Regex {
    
    /// NFA move(A,ch).
    /// - Parameters:
    ///   - state: a given start state
    ///   - ch: a given character which selects a valid transition
    ///   - transitions: set of transitions
    /// - Returns: Set of valid destination states, if a matching outgoing transition was found
    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }
        
        transitions.forEach({ edge in
            switch edge.alphabetRange {
            case .epsilon: break
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    nextStates.insert(edge.target)
                }
            }
        })
        return nextStates
    }
    
    /// DFA step(A,ch).
    /// - Parameters:
    ///   - state: a given start state
    ///   - ch: a given character which selects a valid transition
    /// - Returns: destination state, if a matching outgoing transition was found
    public func step(_ state: Int, symbol: Character, over transitions: Set<Transition>) -> Int? {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }

        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: fatalError()
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    nextStates.insert(edge.target)
                }
            }
        }
        return nextStates.first
    }

    /// This approach simulates the NFA directly, essentially building each DFA state on demand and
    /// then discarding it at the next step. This keeps the DFA implicit and avoids the exponential
    /// construction cost, but running cost rises to O(mn).
    /// A strategy that has been used in a number of text-editing programs is to construct an NFA
    /// from a regular expression and then simulate the NFA using something like on-the-fly subset
    /// construction.
    ///
    /// [1] Alfred V. Aho; Monica S. Lam; Ravi Sethi; Jeffrey D. Ullman (2007).
    /// Algorithm 3.22

    /// Given string is tried for acceptance against the implemented language of the regular expression.
    /// The string is rejected if it doesn't mach the language of the regular expression.   
    /// - Parameters:
    ///   - s: string to be examined
    ///   - deterministic: method of the regular expression to be used { nfa | dfa }
    /// - Returns: true if given string is accepted, otherwise false.
    public func recognize(string s: String) -> Bool {
        switch state {
        case let .nfa(start,finals,transitions):
            var states = epsClosure(state: start, over: transitions)
            for ch in s {
                // move(A,ch)
                states = states.reduce(Set<Int>(), { $0.union(move(state: $1, symbol: ch, over: transitions)) })
                guard !states.isEmpty else { return false }
                // 𝛆-closure( move(A,ch) )
                states = states.reduce(Set<Int>(), { $0.union(epsClosure(state: $1, over: transitions)) })
            }
            return !states.intersection(finals).isEmpty

        case .dfa(var state,let finals,let transitions ,_):
            for ch in s {
                if let next: Int = step(state, symbol: ch, over: transitions) {
                    state = next
                } else {
                    return false
                }
            }
            return finals.contains(state)
        }
    }
    
    /// 𝛆-closure
    /// - Parameter state: a given start state
    /// - Returns: Set of states that are reachable from the given start state merely using 𝛆-moves.
    func epsClosure(state: Int, over transitions: Set<Transition>) -> Set<Int> {
        var closure: Set<Int> = [state]

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
