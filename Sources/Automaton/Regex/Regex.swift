//
//  Regex.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/15.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz
import os.log

/// An NFA is represented formally by a 5-tuple, (Q,Σ,Δ,q0,F) where
///     Q is a finite set of states
///     Σ is a finite set of symbols, called the alphabet of the automaton.
///     Δ is the transition function Δ: Q×Σ → P(Q).
///     q0 is the initial (or start) state, where q0 ∈ Q.
///     a set of states F distinguished as accepting (or final) states F ⊆ Q.
/// Here, P(Q) denotes the power set of Q.
/// A deterministic finite automaton is represented formally by a 5-tuple (Q,Σ,δ,q0,F), where:
///     Q is a finite set of states
///     Σ is a finite set of symbols, called the alphabet of the automaton.
///     δ is the transition function, that is, δ: Q × Σ → Q.
///     q0 is the start (initial) state, where q0 ∈ Q.
///     F is a set of states of Q (i.e. F ⊆ Q) called final, or accept, states.
///
/// Nfa and Dfa representation are in compact form, ie. Q and Σ can be derived from
/// the transitions, since any non-reachable nodes can be regarded as dead states.
///
/// Operations on Regular Expressions
/// • Removal of epsilon transitions
/// • Determinization
///     By applying the subset construction algorithm
///

/// Regular expressions and nondeterministic finite automata are two representations of formal languages.
/// For instance, text processing utilities use regular expressions to describe advanced search patterns,
/// but NFAs are better suited for execution on a computer. Hence, this algorithm is of practical interest,
/// since it can compile regular expressions into NFAs. From a theoretical point of view, this algorithm
/// is a part of the proof that they both accept exactly the same languages, that is, the regular languages.
public struct Regex: RegularLanguage {

    /// Actual internal subtype.
    public typealias Subtype = Regex

    /// Errors thrown during construction of the regular expression.
    enum RegexError: Swift.Error {
        case illegalIdentifier(Character,Int)
        case illegalLowerBound(Int)
        case illegalIntervalBounds(Int,Int)
        case illegalInterval(Int,Int,String)
    }

    // used in `RegexBerrySehti.swift` only.
    enum Metasymbol: String, CaseIterable {
        case or = "|"
        case colon = ":"
        case comma = ","
        case derives = "->"
        case geater = ">"
        case lbrace = "{"
        case lbracket = "["
        case lparen = "("
        case less = "<"
        case not = "!"
        case mul = "*"
        case plus = "+"
        case rbrace = "}"
        case rbracket = "]"
        case rparen = ")"
        case semicolon = ";"
    }
    /// Meta symbols used when parsing
    var metasymbols: Set<String> = Set()

    struct InternalState {
        /// containing epsilon transitions or not.
        var isEpsilonFree: Bool = false
        /// Indicates if *Automaton* is deterministic or not.
        var isDeterministic: Bool = false
    }

    /// Compiled and constructed finite state machine.
    public var state: State<Regex>
    
    // Regex builder using one of the above methods for construction.
    public var builder: RegularLanguageBuilder

    // Regex builder method for construction.
    public var method: ConstructionMethod

    /// Alphabet defined on regular expression.
    public var alphabet: Alphabet {
        get {
            switch self.state {
            case let .nfa(_,_,transitions): return transitions.alphabet()
            case let .dfa(_,_,transitions,_): return transitions.alphabet()
            }
        }
    }

    /// Deterministic state of Automaton.
    public var isDeterministic: Bool {
        get {
            return internalState.isDeterministic
        }
        set(value) {
            if value, !internalState.isDeterministic {
                guard case let .nfa(initial,finals,transitions) = self.state else { return }
                let dfa = powerset(initial: initial, finals: finals, transitions: transitions)
                self.state = .dfa(initial: dfa.initial, finals: dfa.finals, transitions: dfa.transitions, minimal: false)
                internalState.isDeterministic = true
            }
        }
    }

    /// Epsilon abscent state of Automaton.
    public var epsilonFree: Bool {
        get {
            switch self.state {
            case .nfa(_,_,_): return internalState.isEpsilonFree
            case .dfa(_,_,_,_): return true
            }
        }
        set(value) {
            if value, !internalState.isEpsilonFree {
                guard case let .nfa(initial,finals,transitions) = self.state else { return }
                let nfa = removeEps(initial: initial, finals: finals, transitions: transitions)
                self.state = .nfa(initial: nfa.initial, finals: nfa.finals, transitions: nfa.transitions)
                internalState.isEpsilonFree = true
            }
        }
    }
    
    /// Returns true if state of automaton is `minimal`.
    public var isMinimal: Bool {
        self.state.isMinimal
    }

    /// Current internal state of automaton.
    internal var internalState = InternalState(isEpsilonFree: false, isDeterministic: false)
    
    /// Constructs a Regular Expression from a string.
    /// - Parameters:
    ///   - expression: Regular expression string.
    ///   - flags: Optional syntax constructs to be enabled.
    ///   - method: Construction method used to build the compiled internal form of the regex.
    /// - Throws: Exceptions are thrown if ill-formed, or unsupported syntax are encountered.
    public init(_ expression: String, method: ConstructionMethod = .thompson, flags: SyntaxOptions = .basic) throws {
        self.method = method
        switch method {
        case .thompson:
            builder = Thompson(expression: expression, flags: flags)
            self.state = try builder.construct()
        case .berrySethi:
            builder = BerrySethi(expression: expression, flags: flags)
            self.state = try builder.construct()
        }
    }

    /// [1] Finite-State Machines, Foundations and Applications to Text Processing and Pattern Recognition
    ///     Wojciech Skut, Jakub Piskorski and Jan Daciuk, June 1, 2005. p.26
    ///
    /// Algorithm 1.5.2: Remove-ε(Σ,Q,I,F,∆)
    ///
    /// Compute-ε-Closures(A)
    /// I′ ← ε-Closure(I)
    /// F′ ← ∅
    /// ∆′ ← ∅
    /// for ⟨q,a,r⟩ ∈ ∆, a ≠ ε
    ///    for r′ ∈ ε-Closure(r)
    ///        ∆′ ← ∆′ ∪ {⟨q,a,r′⟩}
    ///    for q ∈ Q
    ///        if ε-Closure[q] ∩ F ≠ ∅
    ///            F′ ← F′ ∪ {q}
    /// return (A′ = (Σ, Q, I′, F′, ∆′))
    ///
    public mutating func removeEps(initial: Int, finals: Set<Int>, transitions: Set<Transition>) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>) {
        let states: Set<Int> = epsClosure(state: initial, over: transitions)
        var finalStates = Set<Int>()
        var epsfree = Set<Transition>()

        for t in transitions.filter( { $0.alphabetRange != AlphabetRange.epsilon } ) {
            for r in epsClosure(state: t.target, over: transitions) {
                switch t.alphabetRange {
                case .epsilon: fatalError()
                case let.char(ch):
                    epsfree.insert(Transition(from: t.source, AlphabetRange.char(ch), to: r))
                case let.range(lower,upper):
                    epsfree.insert(Transition(from: t.source, AlphabetRange.range(lower,upper), to: r))
                }
            }
        }
        for q in transitions.states() {
            for s in epsClosure(state: q, over: transitions) {
                if finals.contains(s) {
                    finalStates.insert(s)
                }
            }
        }
        return (initial, finalStates, epsfree)
    }
}

extension Regex {
    public var flattenExpressionTree: String {
        return builder.expression.flattened
    }
}

extension Regex {
    
    /// Convert a Regular Expression to an Automaton of nondeterministic type.
    public static func nondeterministicFiniteState(_ r: Regex) -> NondeterministicFiniteState  {
        guard case let .nfa(initial, finals, transitions) = r.state else { fatalError() }
        return NondeterministicFiniteState(initial: initial, finals: finals, transitions: transitions)
    }

    /// Convert a Regular Expression to an Automaton of deterministic type.
    public static func deterministicFiniteState(_ r: Regex) -> DeterministicFiniteState {
        guard case let .dfa(initial,finals,transitions,minimal) = r.state else { fatalError() }
        return DeterministicFiniteState(initial: initial, finals: finals, transitions: transitions, minimal: minimal)
    }
    
    /// Print internal representation.
    /// Note also that there is no renumbering of states.
    /// Q, initial state (start state), final states (terminal state) and all transitions.
    public func printGraph() {
        
        switch state {
        case let .nfa(initial,finals,transitions):
            let list = transitions.flatMap { [$0.source, $0.target]  }
            let states = Set<Int>(list)
            
            print("states \(states.count) initial state: \(initial)")
            print("final states: \(setNotation(finals))")
            print("transitions: \(transitions.count)" )
            transitions.forEach { print("\($0)") }

        case let .dfa(initial,finals,transitions,_):
            let list = transitions.flatMap { [$0.source, $0.target]  }
            let states = Set<Int>(list)

            print("states \(states.count) initial state: \(initial)")
            print("final states: \(setNotation(finals))")
            print("transitions: \(transitions.count)" )
            transitions.forEach { print("\($0)") }
        }
    }
}

// MARK: - CustomStringConvertible Conformance

extension Regex: CustomStringConvertible {

    public var description: String {
        var result = ""
        unparse(builder.expression, &result)
        return result
    }
}

// MARK: - Graphvizable Conformance

extension Regex: Graphvizable {
    
    /// Output internal representation in graphviz format. States are not re-numbered.
    /// Note that the states are always re-numbered.
    public var graphviz: GraphViz.Graph {
        self.state.graphviz
    }
}
