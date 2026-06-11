//
//  FiniteState.swift
//  Automaton
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
    mutating func determinize(nondeterministic nfa: NfaTuple) -> DfaTuple

    /// Returns a randomly created Nondeterministic Finit Automaton.
    func generate(with options: GenerateOptions) -> Subtype
}


/// Minimization algorithms.
public enum Algorithm {
    /// Complexity: O(n^2)
    case berstel

    /// Complexity: O(2^n)
    case brzozowski

    /// Complexity: O(n log n)
    case hopcroft

    /// Complexity: O(n^2)
    case myhillNerode

    /// Complexity: O(n^2)
    case moore

    /// Complexity: O(n + m log m)
    case valmari
}


/// Deterministic Finite State Protocol definition.
public protocol Deterministic : FSA {
    /// Actual type value of the Finite State Automaton.
    associatedtype Subtype

    /// Initializer method.
    var algorithm: Algorithm { get set }

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
    func reachableStates(from source: Int) -> Set<Int>

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
