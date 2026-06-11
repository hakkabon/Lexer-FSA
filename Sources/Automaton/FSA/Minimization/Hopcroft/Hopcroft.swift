//
//  Hopcroft.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/07.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension State where T == DeterministicFiniteState {

    /// Minimizes the given automaton using Hopcroft's algorithm.
    ///
    /// This is regarded as the most generally efficient algorithm to minimize a Finite State
    /// Automaton as of current date.
    /// - Complexity: O(|A|n log n), where |A| is the cardinality of the used alphabet.
    ///
    /// Constructs a minimal complete DFA.
    func minimizeHopcroft(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
        let debug: Bool = true
        //defer { invariant() }

        // Original states are indentified by their position in the sorted list of states.
        let states = dfa.transitions.states().sorted()
        
        // Initial partition of states: first block: Q \ F, second block: F
        let classes = states.map { dfa.finals.contains($0) ? 1 : 0 }

        // In order to obtain T, we use the following three date structures
        // • Involved: a list of the names of classes in T
        // • Size: an integer array, such that for each class B with
        // name i, Size[i] is the cardinality of B􏰍 a^−1C. This array should be
        // cleared to 0 every time the while loop is executed
        // • Twin: an integer array, such that Twin[i] is the name of the new class
        // created while splitting the class named i. This array should also be initialized
        // every time the while loop is executed.

        var size = [Int](repeating: 0, count: classes.count)
        var twin = [Int](repeating: 0, count: classes.count)

        var S = [SplitData]()
        var splitTable: [SplitData:Int] = [:]   // fast lookup for (B,b) ∈ S

        // Create initial partition.
        var partition = Partition(classes)
        if debug { print("initial partition: \(partition)") }

        // Block, or class, of min( Q \ F, F )
        let least = partition.cardinality[0] < partition.cardinality[1] ? 0 : 1
        for symbol in alphabet.characters.sorted() {
            let split = SplitData(block: least, symbol: symbol)
            S.append(split)
            splitTable[split] = 1
        }
        
        while !S.isEmpty {
            print("waitlist: \(S)")
            // Delete (C,a) from S
            let Ca = S.removeFirst()
            splitTable[Ca] = 0

            // Inverse ← a^−1C
            let splitters: Splitter = classSplitters(partition, block: Ca.block, letter: Ca.symbol)
            
            print("current split: \(Ca) -> \(splitters)")

            // list of the names of classes in T
            var Involved: [Int] = []

            // Decide subset T of P with element B such that B⋂Inverse ≠ ∅
            for q in splitters.set {
                let i = partition.classes[q]
                if size[i] == 0 {
                    size[i] = 1
                    Involved.append(i)
                } else {
                   size[i] += 1
                }
            }
            if debug { print("partition blocks \(Involved) size \(size)") }

            for q in splitters.set {
                let i = partition.classes[q]
                if debug { print("potential re-partitioning (s:block)=(\(q),\(i))") }
                if size[i] < partition.cardinality[i] {
                    if twin[i] == 0 {
                        twin[i] = partition.count
                        // split block(i) -> block(i) \ q u twin[i], move q to block twin[i]
                        partition.transfer(state: q, target: twin[i])
                        if debug { print("state \(q) block transfer (\(i)->\(twin[i])) new partition \(partition)") }
                        
                        for symbol in alphabet.characters {
                            // if (B,b) ∈ S
                            let split = SplitData(block: twin[i], symbol: symbol)
                            if let value = splitTable[split], value == 1 {
                                // Replace (B,b) by (B′,b) and (B′′,b) in S
                                if debug { print("Replace (B,b) by (B′,b) and (B′′,b) in S -> \(split)") }
                                S.append(split)
                                splitTable[split] = 1
                            } else {
                                // Insert (min(B′,B′′),b) to S
                                if debug { print("Insert (min(B′,B′′),b) to S -> \(split)") }
                                let b = partition.cardinality[i] < partition.cardinality[twin[i]] ? i : twin[i]
                                let split = SplitData(block: b, symbol: symbol)
                                S.append(split)
                                splitTable[split] = 1
                            }
                        }
                    }
                }
            }

            for j in Involved {
                size[j] = 0
                twin[j] = 0
            }
        }
        
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
            transitions.insert( Transition(
                from: partition.classes[t.source],
                t.alphabetRange,
                to: partition.classes[t.target])
            )
        }
        
        // Construct the minimized finite state atomaton.
        return (initial: startBlock, finals: finals, transitions: transitions, minimal: true)
    }
    
    /// Refines the partition classes by usisng equivalence relation.
    /// Split is generated with inverse delta function, or *predecessors()*.
    /// - Parameter part: a complete DFA
    /// - Returns: The refined partition
    func classSplitters(_ partition: Partition, block: Int, letter: Character) -> Splitter {
//        let c = partition.classes
        var split = Splitter(block: block, set: Set<Int>())
        let list = partition.blocks[block]!
        for q in list {
            let preds = predecessors(target: q, symbol: letter)
            let ids = preds.map { $0 }
            //let ids = preds.filter { c[$0.id] == block }.map { $0.id }

            //print("δ−1(\(block),\(letter)) -> \(setNotation(preds)) -> \(setNotation(ids))")

            split.set.formUnion(ids)
        }
        return split
    }
}
