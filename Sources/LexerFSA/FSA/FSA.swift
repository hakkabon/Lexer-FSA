//
//  FSA.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/16.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz

// MARK: - Token Class

/// Represents a token class (lexeme category)
public struct TokenClass: Hashable, Codable {
    public let id: Int
    public let name: String
    public let priority: Int  // Lower number = higher priority
    
    public init(id: Int, name: String, priority: Int = 0) {
        self.id = id
        self.name = name
        self.priority = priority
    }
}


/// Shortcuts for the tuples involved
/// Note that these tuples are not assign compatable with FiniteState!
public typealias NfaTuple = (initial: Int, finals: Set<Int>, transitions: Set<Transition>)
public typealias DfaTuple = (initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool)
public typealias FSATuple = (initial: Int, finals: Set<Int>, transitions: Set<Transition>)

/// Display graph of Finite State Automaton using graphviz.
protocol Graphvizable {
    var graphviz: Graph { get }
}


public protocol FSA {
    /// Actual type value of the Finite State Automaton.
    associatedtype Subtype
    
    /// Internal finite state of automaton.
    var state: State<Subtype> { get set }
    
    /// Indicates if `Automaton` is empty or not.
    var isEmpty: Bool { get }
    
    /// Indicates if `Automaton` is deterministic or not.
    var isDeterministic: Bool { get }
    
    /// Indicates if `Automaton` is mininal or not.
    var isMinimal: Bool { get }
    
    /// Initial `state` of automaton.
    var initial: Int { get }
    
    /// Final `states` of automaton.
    var finals: Set<Int> { get }
    
    /// Symbols on transitions used by the automaton.
    var alphabet: Alphabet { get }
    
    /// Number of states.
    var stateCount: Int { get }
    
    /// Number of final states.
    var finalCount: Int { get }
    
    /// Indicates if `state` is a Final State
    func isFinal(state: Int) -> Bool
    
    /// Indicates if `state` is an initial State.
    func isInitial(state: Int) -> Bool
    
    /// All states transitively reachable from `source` via any sequence of labelled
    /// transitions (ε and non-ε alike).
    func reachableStates(from source: Int) -> Set<Int>

    func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int>
}

// MARK: - Shared `FSA` Default Implementations

/// Default implementations of the `FSA` requirements (plus the token-tracking
/// helpers that both concrete automata expose) in terms of `state`.
///
/// `DFSA` and `NFSA` used to each redeclare every one of these members with
/// an identical one-line forwarding body (`self.state.x`). Since both types
/// only ever differ in their `Nondeterministic`/`Deterministic`-specific
/// behaviour (`step`, `run`, `determinize`, `minimize`, …), the FSA-level
/// surface can live here once and be inherited by any conforming type.
extension FSA {

    /// Returns true if `state` is `empty`.
    public var isEmpty: Bool { state.isEmpty }

    /// Returns true if `state` is `deterministic`.
    public var isDeterministic: Bool { state.isDeterministic }

    /// Returns true if `state` is `minimal`.
    public var isMinimal: Bool { state.isMinimal }

    /// Initial state of automaton.
    public var initial: Int { state.initial }

    /// Final states of automaton.
    public var finals: Set<Int> { state.finals }

    /// Number of states, not taking into account non-relevant zombie states.
    public var stateCount: Int { state.stateCount }

    /// Number of final states.
    public var finalCount: Int { state.finalCount }

    /// Returns alphabet defined on automaton.
    public var alphabet: Alphabet { state.alphabet }

    /// Returns true if given state is a `final` state of automaton.
    public func isFinal(state: Int) -> Bool { self.state.isFinal(state: state) }

    /// Returns true if given state is the `initial` state of automaton.
    public func isInitial(state: Int) -> Bool { self.state.isInitial(state: state) }

    /// Returns the set of states directly reachable from `source` via `symbol`.
    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        self.state.move(state: state, symbol: symbol, over: transitions)
    }

    /// Computes the set of all states transitively reachable from `source`.
    public func reachableStates(from source: Int) -> Set<Int> {
        state.reachableStates(from: source)
    }

    // MARK: Token Tracking

    /// Maps final-state identifiers to their token class. Empty by default.
    public var tokenMap: [Int: TokenClass] { state.tokenMap }

    /// Returns the token class attached to `finalState`, if any.
    public func tokenClass(for finalState: Int) -> TokenClass? { state.tokenClass(for: finalState) }

    /// Replaces the entire token-class map. Mutating.
    public mutating func setTokenMap(_ newMap: [Int: TokenClass]) { state.setTokenMap(newMap) }

    /// Runs the automaton against `s` and returns the token class attached to
    /// the accepting state reached, or `nil` if `s` is rejected.
    public func recognizeWithToken(string s: String) -> TokenClass? { state.recognizeWithToken(string: s) }
}


/// Nondeterministic Finite State Protocol definition.
public protocol Nondeterministic : FSA {
    /// Actual type value of the Finite State Automaton.
    associatedtype Subtype

    // MARK: - Creation

    /// Initializer method.
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>)

    // MARK: - Runtime / Simulation

    /// Tests if a given string is recognized by the automaton. Returns true if recognized, false otherwise.
    func run(string s: String) -> Bool
    
    /// The 𝛆-closure of a given state. Set of states that are reachable from the given start state by merely using 𝛆-moves.
    func epsClosure(state: Int, over transitions: Set<Transition>) -> Set<Int>

    /// Step, delta or state-transition function, ∂: S x ∑ → P(S).
    func step(state: Int, symbol: Character) -> Set<Int>

    // MARK: - Query Functions

    /// Get the target state transitioned from `source` consuming `symbol`.
    func successor(source: Int, symbol: Character) -> Set<Int>

    /// Get the source state transitioned to `target` consuming `symbol`.
    func predecessors(target: Int, symbol: Character) -> Set<Int>

    /// Check if state `target` is reachable from state `source` consuming `symbol`.
    func isSuccessor(source: Int, symbol: Character, target: Int) -> Bool

    /// Get all reachable states from `source` regardless of `symbol` on transitions.
    func reachableStates(from source: Int) -> Set<Int>
    
    // MARK: - Mutation Functions
    
    /// Adds transition from `source` state with an input `symbol` and its `target` state.
    mutating func addTransition(source: Int, symbol: Character, target: Int)
    
    /// Adds transition from `source` state with an input `symbol` and its `target` state.
    mutating func add(_ transition: Transition)

    // MARK: - Transformation & Factory Methods

    /// Powerset construction method.
    mutating func determinize()

    /// Returns a randomly created Nondeterministic Finit Automaton.
    func generate(with options: GenerateOptions) -> Subtype
}


/// Deterministic Finite State Protocol definition.
public protocol Deterministic : FSA {
    /// Actual type value of the Finite State Automaton.
    associatedtype Subtype

    // MARK: - Creation

    /// Initializer method.
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool)

    // MARK: - Runtime / Simulation

    /// Tests if a given string is recognized by the automaton. Returns true if recognized, false otherwise.
    func run(string s: String) -> Bool

    /// Step, delta or state-transition function, ∂: S x ∑ → S.
    func step(state: Int, symbol: Character) -> Int?
    
    // MARK: - Query Functions

    /// Get the target state transitioned from `source` consuming `symbol`.
    func successor(source: Int, symbol: Character) -> Int?

    /// Get the source state transitioned to `target` consuming `symbol`.
    func predecessors(target: Int, symbol: Character) -> Set<Int>

    /// Check if state `target` is reachable from state `source` consuming `symbol`.
    /// - Complexity: O(1)
    func isSuccessor(source: Int, symbol: Character, target: Int) -> Bool
    
    /// Get all reachable states from `source` regardless of `symbol` on transitions.
//    func reachableStates(from source: Int) -> Set<Int>

    /// Deterministic invariant
    mutating func invariant()
    
    // MARK: - Factory Methods & Minimization

    /// Returns a randomly created Deterministic Finit Automaton.
    func generate(with options: GenerateOptions) -> Subtype

    /// Minimize finite state automaton.
    mutating func minimize()

    /// Tests whether two states p,q are equivalent (indistinguishable).
    func isEquivalent(a: Self, p: Int, q: Int, c: [Int]) -> Bool
}


/// Deterministic Finite State Protocol definition.
public protocol Regular {
    /// Actual type value of the Finite State Automaton.
    associatedtype Subtype
    
    // MARK: - Runtime / Simulation
    
    /// Tests if a given string is recognized by the automaton. Returns true if recognized, false otherwise.
    func run(string s: String) -> Bool
    
    /// Step, delta or state-transition function, ∂: S x ∑ → S.
    func step(state: Int, symbol: Character) -> Int?
}
