//
//  Moore.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/07/02.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension State where T == DeterministicFiniteState {

    /// Minimizes the given automaton using Moore's algorithm.
    /// Evaluates the equivalent minimal automata with Moore's algorithm
    ///
    /// [1] John E. Hopcroft and Jeffrey D. Ullman,
    /// Introduction to Automata Theory, Languages, and Computation, AW, 1979
    /// Lemma 3.2, p 69-71.
    ///
    /// Constructs a minimal complete DFA.
    func minimizeMoore(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
        let alphabet = dfa.transitions.alphabet()
        
        func markList(_ p: Int, _ q: Int) {
            let t = Tup(p,q)
            for tuple in moorePairList[t]! {
                if !mooreMarked[tuple]! {
                    mooreMarked[tuple] = true
                    markList(tuple.a,tuple.b)
                }
            }
        }

        let debug: Bool = true
        // defer { invariant() }
        
        // Original states are indentified by their position in the sorted list of states.
        let states = dfa.transitions.states().sorted()
        
        // Initial partition of states F and Q \ F.
        let classes = states.map { dfa.finals.contains($0) ? 1 : 0 }
        
        // Create initial partition.
        let partition = Partition(classes)
        if debug { print("initial partition: \(partition)") }
        
        var moorePairList: [Tup<Int>:[Tup<Int>]] = [:]
        var mooreMarked: [Tup<Int>:Bool] = [:]

        for p in states {
            for q in states {
                //if q == p { continue }
                moorePairList[Tup(p,q)] = []
                mooreMarked[Tup(p,q)] = false
                if dfa.finals.contains(p) != finals.contains(q) {
                    mooreMarked[Tup(p,q)] = true
                }
            }
        }
        for p in states {
            var markedFound: Bool = false
            for q in states {
                if !(dfa.finals.contains(p) != finals.contains(q)) {
                    markedFound = false
                    for alpha in alphabet.characters {
                        let foo = Tup(successor(source: p, symbol: alpha)!, successor(source: q, symbol: alpha)!)
                        if mooreMarked[foo]! {
                            markedFound = true
                            break
                        }
                    }
                    if markedFound {
                        mooreMarked[Tup(p,q)] = true
                        markList(p,q)
                    } else {
                        for alpha in alphabet.characters {
                            if successor(source: p, symbol: alpha) != successor(source: q, symbol: alpha) {
                                let pair = Tup(successor(source: p, symbol: alpha)!, successor(source: q, symbol: alpha)!)
                                moorePairList[pair]!.append(Tup(p,q))
                            }
                        }
                    }
                }
            }
        }
        
        var quotient = Array(0..<states.count)
        for p in states {
            for q in 0..<p {
                let t = Tup(p,q)
                if !mooreMarked[t]! {
                    print("equivalent states: \(t.a) ≣ \(t.b)")
                    quotient[p] = q
                }
            }
        }
        
        // Start state
        let initialQuotient = quotient[dfa.initial]
        
        // Accumulate all final, or accept, states.
        var finalQuotients = Set<Int>()
        dfa.finals.forEach { finalQuotients.insert(quotient[$0]) }

        // Create new transitions.
        var newTransitions = Set<Transition>()
        for t in dfa.transitions {
            newTransitions.insert(Transition(from: quotient[t.source], t.alphabetRange, to: quotient[t.target]))
        }
        
        // Return the minimized finite state atomaton.
        return (initial: initialQuotient, finals: finalQuotients, transitions: newTransitions, minimal: true)
    }
}
