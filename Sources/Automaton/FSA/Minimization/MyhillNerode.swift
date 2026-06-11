//
//  MyhillNerode.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/07/01.
//

import Foundation

extension State where T == DeterministicFiniteState {

    /// Minimizes the given automaton using Moore's algorithm.
    /// Evaluates the equivalent minimal automata with Moore's algorithm
    ///
    /// [1] F.Bassino, J.David and C.Nicaud
    /// On the Average Complexity of Moores's State Minimization Algorihm,
    /// Symposium on Theoretical Aspects of Computer Science
    ///
    /// Constructs a minimal complete DFA.
    func minimizeMyhillNerode(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
        let debug: Bool = true
        //defer { invariant() }

        // Original states are indentified by their position in the sorted list of states.
        let states = dfa.transitions.states().sorted()

        // Initial partition of states F and Q \ F.
        let classes = states.map { dfa.finals.contains($0) ? 1 : 0 }

        // Create initial partition.
        var partition: [Int:Int] = Dictionary(uniqueKeysWithValues: zip(states,classes))
        if debug { print("initial partition: \(tupleNotation(partition))") }

        var changed: Bool = false
        repeat {

            let pi = refine(partition: partition)
            if debug { print("new partition: \(tupleNotation(pi))") }
            changed = partition == pi
            partition = pi
            
        } while !changed

        // Start state
        let startBlock = partition[dfa.initial]!

        // Accumulate all final, or accept, states.
        var finals = Set<Int>()
        for final in dfa.finals {
            let block = partition[final]
            finals.insert(block!)
        }

        // Create new transitions.
        var transitions = Set<Transition>()
        for t in dfa.transitions {
            transitions.insert(Transition(from: partition[t.source]!, t.alphabetRange, to: partition[t.target]!))
        }
        
        // Return the minimized finite state atomaton.
        return (initial: startBlock, finals: finals, transitions: transitions, minimal: true)
    }

    func refine(partition: [Int:Int]) -> [Int:Int] {
        var p: [Block] = []
        var r: [Int] = []
        for s in partition.keys.sorted() {
            r = [partition[s]!]
            for alpha in alphabet.characters {
                if let succ = successor(source: s, symbol: alpha) {
                    if let block = partition[succ] {
                        print("\(s) : 𝛑[\(r[0])•\(alpha)] = 𝛑[\(succ)] = \(block)")
                        r.append(block)
                    }
                }
            }
            p.append( Block(c: s, l: r.sorted()) )
        }
        //p.sorted { $0.1 < $1.1 }
        p.sort(by: { $0 < $1 })
        print("refined partition: \(p)")
        var pi: [Int:Int] = [:]
        var i = 0
//        var (s0,l0) = p.removeFirst()
        var b0 = p.removeFirst()
        pi[b0.c] = i
        for b in p {
            if b.l != b0.l {
                i += 1
                b0 = b
                print("block \(b): c -> \(i)")
            }
            pi[b.c] = i
        }
        return pi
    }
}

/// Block tuple (c,l)
struct Block {
    let c: Int
    var l: [Int]
}
extension Block: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(c)
        hasher.combine(l)
    }
}
extension Block: Equatable {
    public static func == (lhs: Block, rhs: Block) -> Bool {
        return lhs.c == rhs.c && lhs.l == rhs.l
    }
}
extension Block: Comparable {
    public static func < (lhs: Block, rhs: Block) -> Bool {
        return lhs.l < rhs.l
    }
}
