//
//  DFSA.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2021/05/15.
//  Copyright © 2021 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz

public struct DFSA {

    /// Actual internal subtype.
    public typealias Subtype = DFSA

    /// Internal value state of automaton.
    public var state: State<Subtype> = .dfa(initial: 0, finals: Set<Int>(), transitions: Set<Transition>(), minimal: false, tokenMap: [:])

    /// Creates a deterministic finite state automaton.
    public init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool = false) {
        self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: [:])
    }
}

extension DFSA: FSA {
    
    /// Returns true if state of automaton is `empty`.
    public var isEmpty: Bool {
        self.state.isEmpty
    }
    
    /// Returns true if state of automaton is `deterministic`.
    public var isDeterministic: Bool {
        self.state.isDeterministic
    }
    
    /// Returns true if state of automaton is `minimal`.
    public var isMinimal: Bool {
        self.state.isMinimal
    }
    
    /// Initial state of automaton.
    public var initial: Int {
        self.state.initial
    }
    
    /// Final states of automaton.
    public var finals: Set<Int> {
        self.state.finals
    }
    
    /// Number of states, not taking into account for non-relevant zombie states.
    public var stateCount: Int {
        self.state.stateCount
    }
    
    /// Number of final states.
    public var finalCount: Int {
        self.state.finalCount
    }
    
    /// Returns alphabet defined on autmaton.
    public var alphabet: Alphabet {
        self.state.alphabet
    }
    
    /// Returns true if given state is the `final` state of autmaton.
    public func isFinal(state: Int) -> Bool {
        self.state.isFinal(state: state)
    }
    
    /// Returns true if given state is the `initial` state of autmaton.
    public func isInitial(state: Int) -> Bool {
        self.state.isInitial(state: state)
    }
    
    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        return self.state.move(state: state, symbol: symbol, over: transitions)
    }
}

extension DFSA: Deterministic {    

    /// Simulates the automaton to determine if it accepts the given input string.
    ///
    /// This function processes the string character by character, traversing the states
    /// according to the transition function.
    ///
    /// - Parameter s: The input string to test.
    /// - Returns: `true` if the automaton ends in an accepting state after consuming the string, `false` otherwise.
    /// - Complexity: Linear in the length of the string `O(|s|)` for a DFA.
    public func run(string s: String) -> Bool {
        return self.state.run(string: s)
    }

    /// Computes the single-step transition for a state and a symbol.
    ///
    /// Represents the transition function `δ(q, a)`. In a DFA, this returns one potential
    /// next states.
    ///
    /// - Parameters:
    ///   - state: The current state identifier.
    ///   - symbol: The input character to consume.
    /// - Returns: A `Set` of valid destination states. Returns an empty set if no matching transition exists.
    public func step(state: Int, symbol: Character) -> Int? {
        return self.state.step(state: state, symbol: symbol)
    }
    
    /// Returns the set of states directly reachable from a given state via a specific symbol.
    ///
    /// This function computes the direct image of the transition function:
    /// `S = { q' | (source, symbol, q') ∈ Δ }`.
    ///
    /// - Parameters:
    ///   - source: The identifier of the source state.
    ///   - symbol: The input character triggering the transition.
    /// - Returns: An optional state identifier that is successor of `source` on input `symbol`.
    public func successor(source: Int, symbol: Character) -> Int? {
        return self.state.successor(source: source, symbol: symbol)
    }
    
    /// Returns the set of states that transition to a specific target state via a specific symbol.
    ///
    /// This is the inverse lookup of the transition function. It finds all states `q` such that
    /// there is a transition from `q` to `target` labeled `symbol`.
    ///
    /// - Parameters:
    ///   - target: The identifier of the destination state.
    ///   - symbol: The input character on the transition.
    /// - Returns: A `Set` of state identifiers that are predecessors of `target` via `symbol`.
    public func predecessors(target: Int, symbol: Character) -> Set<Int> {
        return self.state.predecessors(target: target, symbol: symbol)
    }
    
    /// Checks if a specific transition exists in the automaton.
    ///
    /// Verifies if there is a direct edge from the `source` state to the `target` state
    /// labeled with the given `symbol`.
    ///
    /// - Parameters:
    ///   - source: The identifier of the source state.
    ///   - symbol: The input character required to traverse the transition.
    ///   - target: The identifier of the destination state.
    /// - Returns: `true` if the transition exists, `false` otherwise.
    public func isSuccessor(source: Int, symbol: Character, target: Int) -> Bool {
        return self.state.isSuccessor(source: source, symbol: symbol, target: target)
    }
    
    /// Computes the set of all states transitively reachable from the source state.
    ///
    /// This function performs a traversal (e.g., BFS or DFS) starting from `source`
    /// to find all states `q` where a path exists from `source` to `q`.
    ///
    /// - Parameter source: The identifier of the starting state.
    /// - Returns: A `Set` of all reachable state identifiers, including `source` itself.
    public func reachableStates(from source: Int) -> Set<Int> {
        return self.state.reachableStates(from: source)
    }

//    public mutating func minimize() {
//        self.state.minimize()
//    }

    /// Generates a new automaton instance based on the provided configuration options.
    /// Generate a random DFA using the bridge-based strategy
    /// This ensures:
    /// - All states are reachable from initial states
    /// - All states can reach final states
    /// - Exactly one transition per (state, symbol) pair
    ///
    /// - Parameter options: A `GenerateOptions` object specifying the configuration and constraints for the automaton generation.
    /// - Returns: A new instance of type `T` (the Automaton).
    public func generate(with options: GenerateOptions) -> Self {
        return self.state.generate(with: options)
    }

    public func isEquivalent(a: DFSA, p: Int, q: Int, c: [Int]) -> Bool {
        return false
    }
}

// MARK: - CustomStringConvertible Conformance

extension DFSA: CustomStringConvertible {

    /// Output internal representation in String format. States are not re-numbered.
    public var description: String {
        return self.state.description
    }
}

// MARK: - Graphvizable Conformance

extension DFSA: Graphvizable {

    /// Output internal representation in graphviz format. States are not re-numbered.
    /// Note that the states are always re-numbered.
    public var graphviz: GraphViz.Graph {
        self.state.graphviz
    }
}
