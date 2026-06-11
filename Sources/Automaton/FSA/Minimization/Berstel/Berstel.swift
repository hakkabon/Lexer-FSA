//
//  Berstel.swift
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
    /// Constructs a minimal complete DFA.
    func minimizeBerstel(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
        let debug: Bool = true
        // defer { invariant() }

        // Original states are indentified by their position in the sorted list of states.
        let states = dfa.transitions.states().sorted()

        // Initial partition of states F and Q \ F.
        let classes = states.map { dfa.finals.contains($0) ? 1 : 0 }

        // Create initial partition.
        var partition = Partition(classes)
        if debug { print("initial partition: \(partition)") }
        
        var changed: Bool = false
        repeat {

            let pi = refine(partition: partition)
            if debug { print("refined partition: \(pi)") }
            changed = (partition.count == pi.count)
            partition = pi

        } while !changed

        // Start state
        let startBlock = partition.classes[dfa.initial]
        
        // Accumulate all final, or accept, states.
        var finals = Set<Int>()
        for final in dfa.finals {
            let block = partition.classes[final]
            finals.insert(block)
        }

        // Create new transitions.
        var transitions = Set<Transition>()
        for t in dfa.transitions {
            transitions.insert(Transition(from: partition.classes[t.source], t.alphabetRange, to: partition.classes[t.target]))
        }
        
        // Return the minimized finite state atomaton.
        return (initial: startBlock, finals: finals, transitions: transitions, minimal: true)
    }
    
    /// Refines the partition part.
    /// - Parameter part: a complete DFA
    /// - Returns: The refined partition
    func refine(partition: Partition) -> Partition {
        var m: Int = 0
        let c = partition.classes
        var d = [Int](repeating: 0, count: partition.Q)
        // iterate over (q,p)
        for q in 0..<partition.Q {
            var found = false
            for p in 0..<q {
                if equivalent(p: p, q: q, c: c) {
                    d[q] = d[p]
                    found = true
                    break
                }
            }
            if !found {
                d[q] = m
                m += 1
            }
        }
        return Partition(d)
    }
    
    /// Tests whether two states p,q are locally equivalent in the
    /// sense that p=q mod c and p.a=q.a mod c for every symbol in the alphabet.
    /// - Parameters:
    ///   - p: a state
    ///   - q: a state
    ///   - c: c block numbers (or classes)
    /// - Returns: true if p=q mod c and p.u=q.u mod c for every letter u
    func equivalent(p: Int, q: Int, c: [Int]) -> Bool {
        if c[p] != c[q] {
            print("different blocks: (\(p),\(q)) -> (\(c[p]),\(c[q]))  ")
            return false
        }
        for alpha in alphabet.characters {
            if
                let s1 = successor(source: p, symbol: alpha),
                let s2 = successor(source: q, symbol: alpha)
            {
                if c[s1] != c[s2] {
                    print("different blocks: (\(p),\(q)) -\(alpha)-> (\(c[s1]),\(c[s2])) ")
                    return false
                }
                print("equal blocks: (\(p),\(q)) -\(alpha)-> (\(c[s1]),\(c[s2])) ")
            } else {
                print("(\(p),\(q)) -\(alpha)-> (?,?) ")
            }
        }
        return true
    }
}
