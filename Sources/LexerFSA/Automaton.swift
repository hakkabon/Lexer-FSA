//
//  Automaton.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/16.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz

public struct Automaton<Type> {

    /// Automaton is either nfa | dfa.
    public var state: State<Type> = .nfa(initial: 0, finals: Set<Int>(), transitions: Set<Transition>(), tokenMap: [:])

    /// empty automaton is NOT defined.
    private init() {}

    public init<T: Deterministic>(_ fs: T) where T.Subtype == Type {
        guard case let .dfa(initial, finals, transitions, minimal, tokenMap) = fs.state else { fatalError() }
        self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
    }
    
    public init<T: Nondeterministic>(_ fs: T) where T.Subtype == Type {
        guard case let .nfa(initial, finals, transitions, tokenMap) = fs.state else { fatalError() }
        self.state = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)
    }

    public init<T: RegularLanguage>(_ fs: T) where T.Subtype == Type {
        // RegularLanguage (Regex) still uses the token-map–free 4-tuple internally;
        // pass an empty tokenMap so the arity matches State<T>'s 5-tuple cases.
        switch fs.state {
        case .nfa(let initial, let finals, let transitions, let tokenMap):
            self.state = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)
        case .dfa(let initial, let finals, let transitions, let minimal, let tokenMap):
            self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
        }
    }
}

extension Automaton : FSA {

    /// Actual internal subtype.
    public typealias Subtype = Type

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
    
    /// Returns alphabet defined on automaton.
    public var alphabet: Alphabet {
        self.state.alphabet
    }
    
    /// Returns true if given state is the `final` state of automaton.
    public func isFinal(state: Int) -> Bool {
        self.state.isFinal(state: state)
    }
    
    /// Returns true if given state is the `initial` state of automaton.
    public func isInitial(state: Int) -> Bool {
        self.state.isInitial(state: state)
    }
    
    public func reachableStates(from source: Int) -> Set<Int> {
        return self.state.reachableStates(from: source)
    }

    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        return self.state.move(state: state, symbol: symbol, over: transitions)
    }
}


extension Automaton: CustomStringConvertible {

    /// Output internal representation in String format. States are not re-numbered.
    public var description: String {
        return self.state.description
    }
}


extension Automaton: Graphvizable {

    /// Output internal representation in graphviz format. States are not re-numbered.
    /// Note that the states are always re-numbered.
    public var graphviz: GraphViz.Graph {
        self.state.graphviz
    }
}


extension Automaton where Subtype == NFSA {

    /// Creates an automaton wrapping a nondeterministic finite state.
    /// Previously this initializer had an empty body and silently discarded
    /// its arguments — `Automaton<NFSA>(initial: 5, …)` returned an empty
    /// automaton with `initial == 0`. Now it actually populates `state`.
    public init(initial: Int, finals: Set<Int>, transitions: Set<Transition>) {
        self.state = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: [:])
    }

    /// Convenience initializer that attaches a token-class map up-front.
    public init(
        initial: Int,
        finals: Set<Int>,
        transitions: Set<Transition>,
        tokenMap: [Int: TokenClass]
    ) {
        self.state = .nfa(
            initial: initial, finals: finals,
            transitions: transitions, tokenMap: tokenMap)
    }

    // MARK: - Token Tracking

    /// Maps final-state identifiers to their token class. Empty by default.
    public var tokenMap: [Int: TokenClass] { self.state.tokenMap }

    /// Returns the token class attached to `finalState`, if any.
    public func tokenClass(for finalState: Int) -> TokenClass? {
        self.state.tokenClass(for: finalState)
    }

    /// Replaces the entire token-class map. Mutating.
    public mutating func setTokenMap(_ newMap: [Int: TokenClass]) {
        self.state.setTokenMap(newMap)
    }

    /// Runs the automaton against `s` and returns the token class attached to
    /// the accepting state reached, or `nil` if `s` is rejected.
    public func recognizeWithToken(string s: String) -> TokenClass? {
        self.state.recognizeWithToken(string: s)
    }
    
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

    /// Computes the ε-closure (epsilon closure) of a given state.
    ///
    /// The ε-closure is the set of all states reachable from `state` by following zero or more
    /// ε-transitions (transitions that consume no input).
    ///
    /// - Parameters:
    ///   - state: The starting state identifier.
    ///   - transitions: The set of all transitions available in the automaton context.
    /// - Returns: A `Set` of states reachable via ε-moves, including the start `state` itself.
    public func epsClosure(state: Int, over transitions: Set<Transition>) -> Set<Int> {
        return self.state.epsClosure(state: state, over: transitions)
    }

    /// Computes the single-step transition for a state and a symbol.
    ///
    /// Represents the transition function `δ(q, a)`. In an NFA, this returns a set of potential
    /// next states.
    ///
    /// - Parameters:
    ///   - state: The current state identifier.
    ///   - symbol: The input character to consume.
    /// - Returns: A `Set` of valid destination states. Returns an empty set if no matching transition exists.
    public func step(state: Int, symbol: Character) -> Set<Int> {
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
    /// - Returns: A `Set` of state identifiers that are successors of `source` on input `symbol`.
    public func successor(source: Int, symbol: Character) -> Set<Int> {
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
    
    /// Adds a new transition to the automaton.
    ///
    /// Inserts a directed edge from `source` to `target` labeled with `symbol`.
    ///
    /// - Parameters:
    ///   - source: The identifier of the source state.
    ///   - symbol: The input character for the transition.
    ///   - target: The identifier of the destination state.
    public mutating func addTransition(source: Int, symbol: Character, target: Int) {
        return self.state.addTransition(source: source, symbol: symbol, target: target)
    }
    
    /// Adds a predefined transition object to the automaton.
    ///
    /// - Parameter transition: The `Transition` structure containing the source, symbol, and target.
    public mutating func add(_ transition: Transition) {
        return self.state.add(transition)
    }

    /// Converts a Nondeterministic Finite Automaton (NFA) into a Deterministic Finite Automaton (DFA).
    ///
    /// This method implements the **Powerset Construction** (also known as Subset Construction) algorithm.
    /// It creates a new DFA where each state represents a set of states from the original NFA.
    ///
    /// - Parameter nfa: The input `NfaTuple` representing the nondeterministic automaton.
    /// - Returns: A `DfaTuple` representing the equivalent deterministic automaton.
    /// - Complexity: Exponential in the worst case relative to the number of NFA states, though often much smaller in practice.
    public mutating func determinize(){
        self.state.determinize()
    }
    
    /// Generates a new automaton instance based on the provided configuration options.
    ///
    /// - Parameter options: A `GenerateOptions` object specifying the configuration and constraints for the automaton generation.
    /// - Returns: A new instance of type `Type` (the Automaton).
    public func generate(with options: GenerateOptions) -> Type {
        return self.state.generate(with: options)
    }
}


extension Automaton where Subtype == DFSA {

    /// Creates an automaton wrapping a deterministic finite state.
    /// Previously this initializer had an empty body and silently discarded
    /// its arguments — `Automaton<DFSA>(initial: 5, …)` returned an empty
    /// automaton with `initial == 0`. Now it actually populates `state`.
    public init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool) {
        self.state = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: [:])
    }

    /// Convenience initializer that attaches a token-class map up-front.
    public init(
        initial: Int,
        finals: Set<Int>,
        transitions: Set<Transition>,
        minimal: Bool = false,
        tokenMap: [Int: TokenClass]
    ) {
        self.state = .dfa(
            initial: initial, finals: finals,
            transitions: transitions, minimal: minimal, tokenMap: tokenMap)
    }

    // MARK: - Token Tracking

    /// Maps final-state identifiers to their token class. Empty by default.
    public var tokenMap: [Int: TokenClass] { self.state.tokenMap }

    /// Returns the token class attached to `finalState`, if any.
    public func tokenClass(for finalState: Int) -> TokenClass? {
        self.state.tokenClass(for: finalState)
    }

    /// Replaces the entire token-class map. Mutating.
    public mutating func setTokenMap(_ newMap: [Int: TokenClass]) {
        self.state.setTokenMap(newMap)
    }

    /// Runs the automaton against `s` and returns the token class attached to
    /// the accepting state reached, or `nil` if `s` is rejected.
    public func recognizeWithToken(string s: String) -> TokenClass? {
        self.state.recognizeWithToken(string: s)
    }

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

    public mutating func minimize() {
        self.state.minimize()
    }
    
    public func isEquivalent(a: Automaton<Type>, p: Int, q: Int, c: [Int]) -> Bool {
        return false
    }

    /// Generates a new automaton instance based on the provided configuration options.
    ///
    /// - Parameter options: A `GenerateOptions` object specifying the configuration and constraints for the automaton generation.
    /// - Returns: A new instance of type `Type` (the Automaton).
    public func generate(with options: GenerateOptions) -> Type {
        return self.state.generate(with: options)
    }
}


extension Automaton where Subtype == Regex {
    
    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        return self.state.move(state: state, symbol: symbol, over: transitions)
    }
    
    public func step(_ state: Int, symbol: Character, over transitions: Set<Transition>) -> Int? {
        return self.state.step(state, symbol: symbol, over: transitions)
    }
    
    public func recognize(string s: String) -> Bool {
        return self.state.recognize(string: s)
    }
}
