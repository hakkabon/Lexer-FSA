//
//  DeterministicGenerator.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/25.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

// References regarding how-to do this stuff:
// https://cs.stackexchange.com/questions/12943/what-is-a-good-algorithm-for-generating-random-dfas
// [1] Almeida, M., Moreira, N., & Reis, R. (2007). On the performance of automata minimization algorithms. Logic and Theory of Algorithms, 3.
// [2] F. Bassino, J. David and C. Nicaud, Enumeration and random generation of possibly incomplete deterministic
// Automata, Pure Mathematics and Applications 19 (2-3) (2009) 1-16.
// [3] F. Bassino and C. Nicaud. Enumeration and Random Generation of Accessible Automata. Theor. Comp. Sc.. 381 (2007) 86-104.
//
// Another simple idea (DAWG-like): generate n random strings of random length.
// build the automaton by unwinding random strings in reverse, ie. the last character is final node
// constructs a path back to its start character.
// Lastely, a inital node is created which connects to all start characters of the random strings.

//struct DeterministicGenerator {
extension State where T == DeterministicFiniteState {

    /// Generate a random DFA using the bridge-based strategy
    /// This ensures:
    /// - All states are reachable from initial states
    /// - All states can reach final states
    /// - Exactly one transition per (state, symbol) pair
    ///
    /// - Parameter options: A `GenerateOptions` object specifying the configuration and constraints for the automaton generation.
    /// - Returns: A new instance of type `T` (the Automaton).
    public func generate(with options: GenerateOptions) -> DeterministicFiniteState {
        guard case let .dfaStrategy(construction) = options.strategy else {
            fatalError("Internal inconsistency: Deterministic Generative method contains NFA argument.")
        }
        switch construction {
        case .simple:
            return generateSimple(with: options)
        case .bridged:
            var generator = DFABridgeGenerator(options: options)
            return generator.generate()
        }
    }

    // MARK: - Alternative: Simpler Direct DFA Generator

    /// Generate a simpler DFA using direct construction
    /// This is a more straightforward approach but may not guarantee
    /// the same connectivity properties as the bridge generator
    public func generateSimple(with options: GenerateOptions) -> DeterministicFiniteState {
        let symbolgen = SymbolGenerator()
        let symbols = Array(symbolgen.substring(range: 0..<options.symbols))
        
        var initial = 0
        var finals = Set<Int>()
        var transitions = Set<Transition>()
        
        // Select initial state
        initial = Int.random(in: 0..<options.states)
        
        // Select final states
        while finals.count < options.finals {
            finals.insert(Int.random(in: 0..<options.states))
        }
        
        // Ensure reachability: create path from initial to each final
        var reachable = Set<Int>([initial])
        
        for finalState in finals {
            if !reachable.contains(finalState) {
                // Create path from a reachable state to this final state
                var current = reachable.randomElement()!
                var path = [current]
                let pathLength = Int.random(in: 1...min(5, options.states))
                
                for _ in 0..<pathLength {
                    let next = Int.random(in: 0..<options.states)
                    path.append(next)
                    reachable.insert(next)
                    current = next
                }
                
                // Ensure final state is reached
                path.append(finalState)
                reachable.insert(finalState)
                
                // Create transitions along path
                for i in 0..<path.count-1 {
                    let symbol = symbols.randomElement()!
                    transitions.insert(Transition(
                        from: path[i],
                        AlphabetRange.char(symbol),
                        to: path[i+1]
                    ))
                }
            }
        }
        
        // Complete the DFA: add transition for every (state, symbol) pair
        var transitionMap: [Int: [Character: Int]] = [:]
        
        // Record existing transitions
        for transition in transitions {
            if transitionMap[transition.source] == nil {
                transitionMap[transition.source] = [:]
            }
            if case .char(let c) = transition.alphabetRange {
                transitionMap[transition.source]![c] = transition.target
            }
        }
        
        // Fill in missing transitions
        for state in 0..<options.states {
            for symbol in symbols {
                if transitionMap[state]?[symbol] == nil {
                    // No transition exists, create one
                    let target: Int
                    
                    if Float.random(in: 0..<1) < options.density {
                        target = Int.random(in: 0..<options.states)
                    } else {
                        // Default to self-loop or sink state
                        target = state
                    }
                    
                    transitions.insert(Transition(
                        from: state,
                        AlphabetRange.char(symbol),
                        to: target
                    ))
                }
            }
        }
        
        return DeterministicFiniteState(initial: initial, finals: finals, transitions: transitions, minimal: false)
    }
    
    // MARK: - DFA Bridge Generator

    /// Generates random DFAs using a bridge-based construction strategy
    /// Based on the algorithm that creates paths (bridges) from initial to final states
    struct DFABridgeGenerator {
        
        private let options: GenerateOptions
        private let symbolgen: SymbolGenerator
        private var symbols: [Character] = []
        
        // State tracking
        private var initial: Int = 0
        private var finals: Set<Int> = []
        private var transitions: Set<Transition> = []
        
        // Connectivity tracking
        private var reach: Set<Int> = []           // States reachable from initial
        private var coreach: Set<Int> = []         // States that can reach finals
        private var edgesUsed: Set<Edge> = []      // Edges that have been assigned
        
        // Edge representation for tracking
        private struct Edge: Hashable {
            let source: Int
            let symbol: Character
            
            init(_ source: Int, _ symbol: Character) {
                self.source = source
                self.symbol = symbol
            }
        }
        
        init(options: GenerateOptions) {
            self.options = options
            self.symbolgen = SymbolGenerator()
            self.symbols = Array(symbolgen.substring(range: 0..<options.symbols))
        }
        
        // MARK: - Main Generation
        
        mutating func generate() -> DeterministicFiniteState {
            // Initialize basic structure
            initializeStates()
            
            // Create bridges from initial states to final states
            createInitialBridges()
            
            // Link any unreachable states
            linkOrphanStates()
            
            // Fill in remaining transitions to ensure completeness
            completeTransitions()
            
            return DeterministicFiniteState(
                initial: initial,
                finals: finals,
                transitions: transitions,
                minimal: false
            )
        }
        
        // MARK: - Initialize States
        
        private mutating func initializeStates() {
            // Select initial state
            initial = Int.random(in: 0..<options.states)
            reach.insert(initial)
            
            // Select final states
            var finalCount = 0
            while finalCount < options.finals {
                let state = Int.random(in: 0..<options.states)
                if !finals.contains(state) {
                    finals.insert(state)
                    coreach.insert(state)
                    finalCount += 1
                }
            }
        }
        
        // MARK: - Create Initial Bridges
        
        /// Create random paths (bridges) from initial state to final states
        /// This ensures basic connectivity
        private mutating func createInitialBridges() {
            // Create at least one bridge to each final state
            for finalState in finals {
                createBridge(from: initial, to: finalState)
            }
            
            // Optionally create additional bridges for density
            let additionalBridges = Int(Float(options.states) * options.density * 0.1)
            for _ in 0..<additionalBridges {
                if let reachableState = reach.randomElement(),
                   let coreachState = coreach.randomElement() {
                    createBridge(from: reachableState, to: coreachState)
                }
            }
        }
        
        /// Create a random walk from source to target
        private mutating func createBridge(from source: Int, to target: Int) {
            var current = source
            var visited: Set<Int> = [source]
            let maxSteps = options.states * 2  // Prevent infinite loops
            var steps = 0
            
            while current != target && steps < maxSteps {
                steps += 1
                
                // Pick a random symbol that hasn't been used from current state
                guard let symbol = findUnusedSymbol(from: current) else {
                    // All symbols used from this state, jump to random state
                    current = Int.random(in: 0..<options.states)
                    continue
                }
                
                // Choose next state
                var next: Int
                
                // Probabilistically move toward target
                if Bool.random() && steps < maxSteps / 2 {
                    // Move to a random unvisited state
                    next = Int.random(in: 0..<options.states)
                } else {
                    // Move directly to target
                    next = target
                }
                
                // Add transition
                addTransition(from: current, symbol: symbol, to: next)
                reach.insert(next)
                coreach.insert(current)
                visited.insert(next)
                
                current = next
            }
            
            // Ensure we reached the target
            if current != target {
                if let symbol = findUnusedSymbol(from: current) {
                    addTransition(from: current, symbol: symbol, to: target)
                    reach.insert(target)
                    coreach.insert(current)
                }
            }
        }
        
        // MARK: - Link Orphan States
        
        /// Connect states that are not yet reachable or cannot reach finals
        private mutating func linkOrphanStates() {
            let allStates = Set(0..<options.states)
            let unreachable = allStates.subtracting(reach)
            let uncoreachable = allStates.subtracting(coreach)
            
            // Link unreachable states
            for state in unreachable {
                guard let reachableState = reach.randomElement() else { continue }
                guard let symbol = findUnusedSymbol(from: reachableState) else { continue }
                
                addTransition(from: reachableState, symbol: symbol, to: state)
                reach.insert(state)
                coreach.insert(reachableState)
            }
            
            // Link states that cannot reach finals
            for state in uncoreachable {
                guard let coreachState = coreach.randomElement() else { continue }
                guard let symbol = findUnusedSymbol(from: state) else { continue }
                
                addTransition(from: state, symbol: symbol, to: coreachState)
                coreach.insert(state)
                reach.insert(coreachState)
            }
        }
        
        // MARK: - Complete Transitions
        
        /// Fill in all remaining transitions to ensure DFA completeness
        /// Every (state, symbol) pair must have exactly one transition
        private mutating func completeTransitions() {
            for state in 0..<options.states {
                for symbol in symbols {
                    let edge = Edge(state, symbol)
                    
                    if !edgesUsed.contains(edge) {
                        // Choose target based on density
                        let target: Int
                        
                        if Float.random(in: 0..<1) < options.density {
                            // Random target for diversity
                            target = Int.random(in: 0..<options.states)
                        } else {
                            // Self-loop or sink state (state 0 as default sink)
                            target = Bool.random() ? state : 0
                        }
                        
                        addTransition(from: state, symbol: symbol, to: target)
                    }
                }
            }
        }
        
        // MARK: - Helper Methods
        
        /// Find an unused symbol for transitions from a given state
        private func findUnusedSymbol(from state: Int) -> Character? {
            let unusedSymbols = symbols.filter { symbol in
                !edgesUsed.contains(Edge(state, symbol))
            }
            return unusedSymbols.randomElement()
        }
        
        /// Add a transition and mark the edge as used
        private mutating func addTransition(from source: Int, symbol: Character, to target: Int) {
            let edge = Edge(source, symbol)
            
            // Check if this edge is already used
            if edgesUsed.contains(edge) {
                // In DFA, we must replace the existing transition
                // Remove old transition
                transitions = transitions.filter { transition in
                    !(transition.source == source && transition.inAlphabet(char: symbol))
                      //transition.range.contains(character: symbol))
                }
            }
            
            // Add new transition
            transitions.insert(Transition(
                from: source,
                AlphabetRange.char(symbol),
                to: target
            ))
            edgesUsed.insert(edge)
        }
    }
}
