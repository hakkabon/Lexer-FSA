//
//  NondeterministicGenerator.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/02/16.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation


//extension State where T == NFSA {
extension Nondeterministic {

    /// Generates a new automaton instance based on the provided configuration options.
    ///
    /// - Parameter options: A `GenerateOptions` object specifying the configuration and constraints for the automaton generation.
    /// - Returns: A new instance of type `T` (the Automaton).
    public static func generate(with options: GenerateOptions) -> NFSA {
        guard case let .nfaStrategy(construction) = options.strategy else {
            fatalError("Internal inconsistency: Nondeterministic Generative method contains DFA argument.")
        }
        switch construction {
        case .standard:
            return generate1(with: options)
        case .simple:
            return generate2(with: options)
        }
    }

    static func generate1(with options: GenerateOptions) -> NFSA {
        var initial = 0
        var transitions = Set<Transition>()
        var finals = Set<Int>()
        
        let symbolgen = SymbolGenerator()
        let symbols = symbolgen.substring(range: 0..<options.symbols)
        
        // Determine initial states
        initial = Int.random(in: 0..<options.states)
        
        // Determine final states
        for _ in 0..<options.finals {
            finals.insert(Int.random(in: 0..<options.states))
        }
        
        let totalTransitions: Int = options.states * options.states * options.symbols
        var transitionCount = 0
        
        let requiredTransitions = Int(Float(totalTransitions) * options.density)
        var reach: Set<Int> = Set<Int>(arrayLiteral: initial)
        var nreach: Set<Int> = Set<Int>(finals)
        for i in 0..<options.states {
            if !reach.contains(i) {
                let qs = reach.randomElement()!
                reach.insert(i)
                // the next block ensures that it is not achievable, therefore qs becomes
                // reachable in this iteration
                nreach.insert(qs)
                let c = symbolgen.randomElement(range: 0..<options.symbols)
                transitions.insert(Transition(from: qs, AlphabetRange.char(c), to: i))
                transitionCount += 1
            }
            if !nreach.contains(i) {
                let qt = nreach.randomElement()!
                nreach.insert(i)
                // like the previous block ensures that i is reachable
                // here it becomes achievable
                assert(reach.contains(i))
                reach.insert(qt)
                let c = symbolgen.randomElement(range: 0..<options.symbols)
                transitions.insert(Transition(from: i, AlphabetRange.char(c), to: qt))
                transitionCount += 1
            }
        }
        
        if transitionCount > requiredTransitions {
            return NFSA(initial: initial, finals: Set<Int>(finals), transitions: transitions)
        }
        
        var list: [(Int,Character,Int)] = []
        for qs in 0..<options.states {
            for qt in 0..<options.states {
                for s in symbols {
                    list.append( (qs,s,qt) )
                }
            }
        }
        list.shuffle()
        while transitionCount < requiredTransitions && !list.isEmpty {
            let tuple = list.removeFirst()
            transitions.insert(Transition(from: tuple.0, AlphabetRange.char(tuple.1), to: tuple.2))
            transitionCount += 1
        }
        return NFSA(initial: initial, finals: Set<Int>(finals), transitions: transitions)
    }
    
    // MARK: - Alternative: Similar NFA Generator
    
    static func generate2(with options: GenerateOptions) -> NFSA {
        var initial = 0
        var transitions = Set<Transition>()
        var finals = Set<Int>()

        let symbolgen = SymbolGenerator()
        let symbols = symbolgen.substring(range: 0..<options.symbols)

        // Determine initial states
        initial = Int.random(in: 0..<options.states)

        // Determine final states
        for _ in 0..<options.finals {
            finals.insert(Int.random(in: 0..<options.states))
        }

        var reach: Set<Int> = Set<Int>(arrayLiteral: initial)
        var nreach = finals
        for i in 0..<options.states {
            if !reach.contains(i) {
                let qs = reach.randomElement()!
                reach.insert(i)
                let c = symbolgen.randomElement(range: 0..<options.symbols)
                transitions.insert(Transition(from: qs, AlphabetRange.char(c), to: i))
            }
            if !nreach.contains(i) {
                let qt = nreach.randomElement()!
                nreach.insert(i)
                let c = symbolgen.randomElement(range: 0..<options.symbols)
                transitions.insert(Transition(from: i, AlphabetRange.char(c), to: qt))
            }
        }
        for qs in 0..<options.states {
            for c in symbols {
                for qt in 0..<options.states {
                    let p = Float.random(in: 0..<1)
                    if p < options.density {
                        transitions.insert(Transition(from: qs, AlphabetRange.char(c), to: qt))
                    }
                }
            }
        }
        return NFSA(initial: initial, finals: Set<Int>(finals), transitions: transitions)
    }
}
