//
//  State.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2019/02/19.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

/// The Internal values of Finite State Automaton can only be one of `Deterministic` or `Nondeterministic`.
public enum State<T> {
    case nfa(initial: Int, finals: Set<Int>, transitions: Set<Transition>)
    case dfa(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool)
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>) where T == NondeterministicFiniteState  {
        self = .nfa(initial: initial, finals: finals, transitions: transitions)
    }
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool) where T == DeterministicFiniteState {
        self = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal)
    }
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>) where T == Regex {
        self = .nfa(initial: initial, finals: finals, transitions: transitions)
    }
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool) where T == Regex {
        self = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal)
    }
}


extension State {    

    /// Returns true if state of automaton is `empty`.
    public var isEmpty: Bool {
//        guard case .empty = self.finiteState else { return false }
        return false
    }
    
    /// Returns true if state of automaton is `deterministic`.
    public var isDeterministic: Bool {
        get {
            guard case .dfa(_,_,_,_) = self else { return false }
            return true
        }
    }
    
    /// Returns true if state of automaton is `minimal`.
    public var isMinimal: Bool {
        get {
            guard case let .dfa(_,_,_,minimal) = self else { return false }
            return minimal
        }
    }
    
    /// Initial state of automaton.
    public var initial: Int {
        switch self {
        case let .nfa(initial,_,_): return initial
        case let .dfa(initial,_,_,_): return initial
//        case .empty: return 0
        }
    }
    
    /// Final states of automaton.
    public var finals: Set<Int> {
        switch self {
        case let .nfa(_,finals,_): return finals
        case let .dfa(_,finals,_,_): return finals
//        case .empty: return Set<Int>()
        }
    }
    
    /// Number of states, not taking into account for non-relevant zombie states.
    public var stateCount: Int {
        switch self {
        case let .nfa(_,_,transitions): return transitions.states().count
        case let .dfa(_,_,transitions,_): return transitions.states().count
//        case .empty: return 0
        }
    }
    
    /// Number of final states.
    public var finalCount: Int {
        switch self {
        case let .nfa(_,finals,_): return finals.count
        case let .dfa(_,finals,_,_): return finals.count
//        case .empty: return 0
        }
    }
    
    /// Returns alphabet defined on autmaton.
    public var alphabet: Alphabet {
        switch self {
        case let .nfa(_,_,transitions): return transitions.alphabet()
        case let .dfa(_,_,transitions,_): return transitions.alphabet()
//        case .empty: return Alphabet([])
        }
    }
    
    /// Returns true if given state is the `final` state of autmaton.
    public func isFinal(state: Int) -> Bool {
        switch self {
        case let .nfa(_,finals,_): return finals.contains(state)
        case let .dfa(_,finals,_,_): return finals.contains(state)
//        case .empty: return false
        }
    }
    
    /// Returns true if given state is the `initial` state of autmaton.
    public func isInitial(state: Int) -> Bool {
        switch self {
        case let .nfa(initial,_,_): return initial == state
        case let .dfa(initial,_,_,_): return initial == state
            //        case .empty: return false
        }
    }
}


extension State: CustomStringConvertible {

    /// Print internal representation. States are not re-numbered.
    public var description: String {
        switch self {
        case let .nfa(initial,finals,transitions):
            let states = transitions.states()
            
            var s: String = ""
            s.append( "states \(states.count) initial state: \(initial)\n" )
            s.append( "\(setNotation(states))\n" )
            s.append( "accept states: \(setNotation(finals))\n" )
            s.append( "transitions: \(transitions.count)\n" )
            for t in transitions {
                s.append( ("\(t)\n") )
            }
            return s

        case let .dfa(initial,finals,transitions,_):
            let states = transitions.states()
            
            var s: String = ""
            s.append( "states \(states.count) initial state: \(initial)\n" )
            s.append( "\(setNotation(states))\n" )
            s.append( "accept states: \(setNotation(finals))\n" )
            s.append( "transitions: \(transitions.count)\n" )
            for t in transitions {
                s.append( ("\(t)\n") )
            }
            return s
        }
    }
}


extension State where T == NondeterministicFiniteState {
    
    /// Simulates the automaton to determine if it accepts the given input string.
    ///
    /// This function processes the string character by character, traversing the states
    /// according to the transition function.
    ///
    /// - Parameter s: The input string to test.
    /// - Returns: `true` if the automaton ends in an accepting state after consuming the string, `false` otherwise.
    /// - Complexity: Linear in the length of the string `O(|s|)` for a DFA.
    public func run(string s: String) -> Bool {
        guard case let .nfa(start,finals,transitions) = self else { return false }
        var states = epsClosure(state: start, over: transitions)
        for ch in s {
            // move(A,ch)
            states = states.reduce(Set<Int>(), { $0.union(step(state: $1, symbol: ch, over: transitions)) })
            guard !states.isEmpty else { return false }
            // 𝛆-closure( move(A,ch) )
            states = states.reduce(Set<Int>(), { $0.union(epsClosure(state: $1, over: transitions)) })
        }
        return !states.intersection(finals).isEmpty
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
        var closure: Set<Int> = [state]

        var stack: [Int] = [state]
        while !stack.isEmpty {
            let state = stack.removeLast()
            let transitions = transitions.filter { $0.source == state }
            transitions.forEach({ edge in
                switch edge.alphabetRange {
                case .epsilon:
                    if closure.insert(edge.target).inserted {
                        stack.append(edge.target)
                    }
                case .char(_): break
                case .range(_,_): break
                }
            })
        }
        return closure
    }
    
    /// NFA step(A,ch).
    /// - Parameters:
    ///   - state: a given start state
    ///   - ch: a given character which selects a valid transition
    ///   - transitions: set of transitions
    /// - Returns: Set of valid destination states, if a matching outgoing transition was found
    private func step(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }

        transitions.forEach({ edge in
            switch edge.alphabetRange {
            case .epsilon: break
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    nextStates.insert(edge.target)
                }
            }
        })
        return nextStates
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
        guard case let .nfa(initial: _, finals: _, transitions: transitions) = self else { return Set<Int>() }
        return step(state: state, symbol: symbol, over: transitions)
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
        guard case let .nfa(initial: _, finals: _, transitions: trans) = self else { return Set<Int>() }
        let transitions = trans.filter { $0.source == source }
        var succStates = Set<Int>()

        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: break
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    succStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    succStates.insert(edge.target)
                }
            }
        }
        return succStates
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
        guard case let .nfa(initial: _, finals: _, transitions: nfaTransitions) = self else { return Set<Int>() }
        let transitions = nfaTransitions.filter { $0.target == target }
        var predStates = Set<Int>()

        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: break
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    predStates.insert(edge.source)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    predStates.insert(edge.source)
                }
            }
        }
        return predStates
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
        guard case let .nfa(initial: _, finals: _, transitions: transitions) = self else { return false }
        return transitions.contains(Transition(from: source, AlphabetRange.char(symbol), to: target))
    }
    
    /// Computes the set of all states transitively reachable from the source state.
    ///
    /// This function performs a traversal (e.g., BFS or DFS) starting from `source`
    /// to find all states `q` where a path exists from `source` to `q`.
    ///
    /// - Parameter source: The identifier of the starting state.
    /// - Returns: A `Set` of all reachable state identifiers, including `source` itself.
    public func reachableStates(from source: Int) -> Set<Int> {
        guard case let .nfa(initial: _, finals: _, transitions: transitions) = self else { return Set<Int>() }
        let targetStates = transitions.filter { $0.source == source }.map { $0.target }
        return Set<Int>(targetStates)
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
        let transition = Transition(from: source, AlphabetRange.char(symbol), to: target)
        add(transition)
    }
    
    /// Adds a predefined transition object to the automaton.
    ///
    /// - Parameter transition: The `Transition` structure containing the source, symbol, and target.
    public mutating func add(_ transition: Transition) {
        guard case .nfa(let initial, let finals, var transitions) = self else { return }
        transitions.insert(transition)
        self = .nfa(initial: initial, finals: finals, transitions: transitions)
    }
}

extension State where T == DeterministicFiniteState {

    /// Simulates the automaton to determine if it accepts the given input string.
    ///
    /// This function processes the string character by character, traversing the states
    /// according to the transition function.
    ///
    /// - Parameter s: The input string to test.
    /// - Returns: `true` if the automaton ends in an accepting state after consuming the string, `false` otherwise.
    /// - Complexity: Linear in the length of the string `O(|s|)` for a DFA.
    public func run(string s: String) -> Bool {
        guard case .dfa(initial: var state, finals: let finals, transitions: let transitions, _) = self else { return false }
        for ch in s {
            if let next: Int = step(state: state, symbol: ch, over: transitions) {
                state = next
            } else {
                return false
            }
        }
        return finals.contains(state)
    }

    /// DFA step(A,ch).
    /// - Parameters:
    ///   - state: a given start state
    ///   - ch: a given character which selects a valid transition
    ///   - transitions: set of transitions
    /// - Returns: destination state, if a matching outgoing transition was found
    private func step(state: Int, symbol: Character, over transitions: Set<Transition>) -> Int? {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }

        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: fatalError()
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    nextStates.insert(edge.target)
                }
            }
        }
        return nextStates.first
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
        guard case let .dfa(_, _, transitions: transitions, _) = self else { return nil }
        return step(state: state, symbol: symbol, over: transitions)
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
        guard case let .dfa(_, _, transitions: trans, _) = self else { return nil }
        let transitions = trans.filter { $0.source == source }
        var succStates = Set<Int>()
        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: fatalError()
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    succStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    succStates.insert(edge.target)
                }
            }
        }
        return succStates.first
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
        guard case let .dfa( _, _, transitions: trans, _) = self else { return Set<Int>() }
        let transitions = trans.filter { $0.target == target }
        var predStates = Set<Int>()
        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: fatalError()
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    predStates.insert(edge.source)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    predStates.insert(edge.source)
                }
            }
        }
        return predStates
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
        guard case let .dfa(_, _, transitions: transitions, _) = self else { return false }
        return transitions.contains(Transition(from: source, AlphabetRange.char(symbol), to: target))
    }
    
    /// Computes the set of all states transitively reachable from the source state.
    ///
    /// This function performs a traversal (e.g., BFS or DFS) starting from `source`
    /// to find all states `q` where a path exists from `source` to `q`.
    ///
    /// - Parameter source: The identifier of the starting state.
    /// - Returns: A `Set` of all reachable state identifiers, including `source` itself.
    public func reachableStates(from source: Int) -> Set<Int> {
        guard case let .dfa(_, _, transitions: transitions, _) = self else { return Set<Int>() }
        let targetStates = transitions.filter { $0.source == source }.map { $0.target }
        return Set<Int>(targetStates)
    }

    /// Minimize finite state automaton.
    mutating func minimize() {
        guard case let .dfa(initial: initial, finals: finals, transitions: transitions, _) = self else { return }
        let (i,f,t,m) = self.minimizeMoore(dfa: (initial: initial, finals: finals, transitions: transitions))
        self = State( initial: i,finals: f,transitions: t,minimal: m )
    }
}


extension State where T == Regex {
    
    /// NFA move(A,ch).
    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }
        
        transitions.forEach({ edge in
            switch edge.alphabetRange {
            case .epsilon: break
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    nextStates.insert(edge.target)
                }
            }
        })
        return nextStates
    }

    /// DFA step(A,ch).
    public func step(_ state: Int, symbol: Character, over transitions: Set<Transition>) -> Int? {
        var nextStates = Set<Int>()
        let transitions = transitions.filter { $0.source == state }

        for edge in transitions {
            switch edge.alphabetRange {
            case .epsilon: fatalError()
            case .char(_):
                if edge.inAlphabet(char: symbol) {
                    nextStates.insert(edge.target)
                }
            case .range(_,_):
                if edge.inAlphabet(symbol, symbol) {
                    nextStates.insert(edge.target)
                }
            }
        }
        return nextStates.first
    }

    /// This approach simulates the NFA directly building each DFA state on demand.
    public func recognize(string s: String) -> Bool {
        switch self {
        case let .nfa(start,finals,transitions):
            var states = epsClosure(state: start, over: transitions)
            for ch in s {
                // move(A,ch)
                states = states.reduce(Set<Int>(), { $0.union(move(state: $1, symbol: ch, over: transitions)) })
                guard !states.isEmpty else { return false }
                // 𝛆-closure( move(A,ch) )
                states = states.reduce(Set<Int>(), { $0.union(epsClosure(state: $1, over: transitions)) })
            }
            return !states.intersection(finals).isEmpty

        case .dfa(var state,let finals,let transitions ,_):
            for ch in s {
                if let next: Int = step(state, symbol: ch, over: transitions) {
                    state = next
                } else {
                    return false
                }
            }
            return finals.contains(state)
        }
    }

    /// 𝛆-closure
    /// - Parameter state: a given start state
    /// - Returns: Set of states that are reachable from the given start state merely using 𝛆-moves.
    func epsClosure(state: Int, over transitions: Set<Transition>) -> Set<Int> {
        var closure: Set<Int> = [state]

        var stack: [Int] = [state]
        while !stack.isEmpty {
            let state = stack.removeLast()
            let transitions = transitions.filter { $0.source == state }
            transitions.forEach({ edge in
                switch edge.alphabetRange {
                case .epsilon:
                    if closure.insert(edge.target).inserted {
                        stack.append(edge.target)
                    }
                case .char(_): break
                case .range(_,_): break
                }
            })
        }
        return closure
    }
}
