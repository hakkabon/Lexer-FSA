//
//  State.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2019/02/19.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

// MARK: - Extended State with Token Tracking

/// Enhanced State enum with token class tracking
public enum State<T> {
    case nfa(
        initial: Int,
        finals: Set<Int>,
        transitions: Set<Transition>,
        tokenMap: [Int: TokenClass]  // Maps final states to their token classes
    )
    case dfa(
        initial: Int,
        finals: Set<Int>,
        transitions: Set<Transition>,
        minimal: Bool,
        tokenMap: [Int: TokenClass]  // Maps final states to their token classes
    )
    
    // MARK: Constructors
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>) where T == NFSA {
        self = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: [:])
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, tokenMap: [Int: TokenClass]) where T == NFSA {
        self = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool) where T == DFSA {
        self = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: [:])
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool, tokenMap: [Int: TokenClass]) where T == DFSA {
        self = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>) where T == Regex {
        self = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: [:])
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, tokenMap: [Int: TokenClass]) where T == Regex {
        self = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool) where T == Regex {
        self = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: [:])
    }
    
    init(initial: Int, finals: Set<Int>, transitions: Set<Transition>, minimal: Bool, tokenMap: [Int: TokenClass]) where T == Regex {
        self = .dfa(initial: initial, finals: finals, transitions: transitions, minimal: minimal, tokenMap: tokenMap)
    }
    
    // MARK: Accessors
    
    var tokenMap: [Int: TokenClass] {
        switch self {
        case .nfa(_, _, _, let map): return map
        case .dfa(_, _, _, _, let map): return map
        }
    }
    
    mutating public func setTokenMap(_ newMap: [Int: TokenClass]) {
        switch self {
        case .nfa(let i, let f, let t, _):
            self = .nfa(initial: i, finals: f, transitions: t, tokenMap: newMap)
        case .dfa(let i, let f, let t, let m, _):
            self = .dfa(initial: i, finals: f, transitions: t, minimal: m, tokenMap: newMap)
        }
    }
}


extension State {

    /// Common payload shared by both representations (`.nfa` and `.dfa`).
    /// Most accessors below don't care about `.dfa`'s extra `minimal` flag,
    /// so rather than re-switching on `self` in every one of them (as this
    /// type used to), the shared fields are extracted here once.
    private var fields: (initial: Int, finals: Set<Int>, transitions: Set<Transition>, tokenMap: [Int: TokenClass]) {
        switch self {
        case let .nfa(initial, finals, transitions, tokenMap):
            return (initial, finals, transitions, tokenMap)
        case let .dfa(initial, finals, transitions, _, tokenMap):
            return (initial, finals, transitions, tokenMap)
        }
    }

    /// Returns true if the automaton accepts no string (no final states and no transitions).
    public var isEmpty: Bool {
        fields.finals.isEmpty && fields.transitions.isEmpty
    }
    
    /// Returns true if state of automaton is `deterministic`.
    public var isDeterministic: Bool {
        get {
            guard case .dfa(_,_,_,_,_) = self else { return false }
            return true
        }
    }
    
    /// Returns true if state of automaton is `minimal`.
    public var isMinimal: Bool {
        get {
            guard case let .dfa(_,_,_,minimal,_) = self else { return false }
            return minimal
        }
    }
    
    /// Initial state of automaton.
    public var initial: Int { fields.initial }
    
    /// Final states of automaton.
    public var finals: Set<Int> { fields.finals }
    
    /// Number of states, not taking into account for non-relevant zombie states.
    public var stateCount: Int { fields.transitions.states().count }
    
    /// Number of final states.
    public var finalCount: Int { fields.finals.count }
    
    /// Returns alphabet defined on automaton.
    public var alphabet: Alphabet { fields.transitions.alphabet() }
    
    /// Returns true if given state is the `final` state of automaton.
    public func isFinal(state: Int) -> Bool { fields.finals.contains(state) }
    
    /// Returns true if given state is the `initial` state of automaton.
    public func isInitial(state: Int) -> Bool { fields.initial == state }

    // Helper: epsilon closure
    func epsilonClosure(_ states: Set<Int>, over transitions: Set<Transition>) -> Set<Int> {
        var closure = states
        var workList = Array(states)
        
        while let state = workList.popLast() {
            for transition in transitions where transition.source == state {
                if case .epsilon = transition.alphabetRange {
                    if !closure.contains(transition.target) {
                        closure.insert(transition.target)
                        workList.append(transition.target)
                    }
                }
            }
        }
        
        return closure
    }
    
    /// Get token class for a final state
    public func tokenClass(for finalState: Int) -> TokenClass? { fields.tokenMap[finalState] }
    
    /// Run automaton and return matched token class
    public func recognizeWithToken(string s: String) -> TokenClass? {
        guard let finalState = runAndGetFinalState(string: s) else {
            return nil
        }
        return tokenClass(for: finalState)
    }
    
    /// Run automaton and return the final state reached (if accepting)
    func runAndGetFinalState(string s: String) -> Int? {
        switch self {
        case .dfa(let initial, let finals, let transitions, _, _):
            var current = initial
            for char in s {
                guard let next = step(current, char, over: transitions) else {
                    return nil
                }
                current = next
            }
            return finals.contains(current) ? current : nil
            
        case .nfa(let initial, let finals, let transitions, _):
            var currentStates = Set<Int>([initial])
            
            // Epsilon closure of initial state
            currentStates = epsilonClosure(currentStates, over: transitions)
            
            for char in s {
                var nextStates = Set<Int>()
                for state in currentStates {
                    let successors = move(state: state, symbol: char, over: transitions)
                    nextStates.formUnion(successors)
                }
                currentStates = epsilonClosure(nextStates, over: transitions)
                
                if currentStates.isEmpty {
                    return nil
                }
            }
            
            // Find highest priority accepting state
            let acceptingStates = currentStates.intersection(finals)
            return acceptingStates.min { state1, state2 in
                let priority1 = tokenClass(for: state1)?.priority ?? Int.max
                let priority2 = tokenClass(for: state2)?.priority ?? Int.max
                return priority1 < priority2
            }
        }
    }
    
    // Helper: move function
    public func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int> {
        var result = Set<Int>()
        for transition in transitions where transition.source == state {
            if transition.alphabetRange.contains(character: symbol) {
                result.insert(transition.target)
            }
        }
        return result
    }
    
    // Helper: step function for DFA
    private func step(_ state: Int, _ symbol: Character, over transitions: Set<Transition>) -> Int? {
        for transition in transitions where transition.source == state {
            if transition.alphabetRange.contains(character: symbol) {
                return transition.target
            }
        }
        return nil
    }
    
    public func reachableStates(from source: Int) -> Set<Int> {
        let transitions = fields.transitions
        var visited = Set<Int>([source])
        var queue = [source]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for t in transitions where t.source == current {
                if visited.insert(t.target).inserted { queue.append(t.target) }
            }
        }
        return visited
    }
}


extension State: CustomStringConvertible {

    /// Print internal representation. States are not re-numbered.
    public var description: String {
        let (initial, finals, transitions) = (fields.initial, fields.finals, fields.transitions)
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

extension State where T == NFSA {
    
    /// Simulates the automaton to determine if it accepts the given input string.
    ///
    /// This function processes the string character by character, traversing the states
    /// according to the transition function.
    ///
    /// - Parameter s: The input string to test.
    /// - Returns: `true` if the automaton ends in an accepting state after consuming the string, `false` otherwise.
    /// - Complexity: Linear in the length of the string `O(|s|)` for a DFA.
    public func run(string s: String) -> Bool {
        switch self {
        case let .nfa(start, finals, transitions, _):
            var states = epsClosure(state: start, over: transitions)
            for ch in s {
                // move(A,ch)
                states = states.reduce(Set<Int>(), { $0.union(step(state: $1, symbol: ch, over: transitions)) })
                guard !states.isEmpty else { return false }
                // 𝛆-closure( move(A,ch) )
                states = states.reduce(Set<Int>(), { $0.union(epsClosure(state: $1, over: transitions)) })
            }
            return !states.intersection(finals).isEmpty
        case .dfa(var current, let finals, let transitions, _, _):
            // After determinize() the state becomes .dfa; use the DFA simulator.
            for ch in s {
                guard let next = step(current, ch, over: transitions) else { return false }
                current = next
            }
            return finals.contains(current)
        }
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
        guard case let .nfa(initial: _, finals: _, transitions: transitions, _) = self else { return Set<Int>() }
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
        guard case let .nfa(initial: _, finals: _, transitions: trans, _) = self else { return Set<Int>() }
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
        guard case let .nfa(initial: _, finals: _, transitions: nfaTransitions, _) = self else { return Set<Int>() }
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
        guard case let .nfa(initial: _, finals: _, transitions: transitions, _) = self else { return false }
        // Iterate transitions and ask each one if it matches the symbol,
        // rather than synthesising a `.char(symbol)` Transition and looking
        // it up via Set.contains. The latter missed any transition stored
        // as a `.range` (e.g. [a-z]) even though step() would happily match
        // the symbol against that range.
        return transitions.contains {
            $0.source == source && $0.target == target && $0.inAlphabet(char: symbol)
        }
    }
    
    /// Computes the set of all states transitively reachable from `source` via
    /// any sequence of labelled transitions (ε and non-ε alike).
    ///
    /// Uses an iterative BFS so it correctly returns the full transitive closure,
    /// not just the one-hop neighbours.
    ///
    /// - Parameter source: The identifier of the starting state.
    /// - Returns: A `Set` of reachable state identifiers, including `source` itself.
//    public func reachableStates(from source: Int) -> Set<Int> {
//        guard case let .nfa(_, _, transitions, _) = self else { return Set<Int>() }
//        var visited = Set<Int>([source])
//        var queue   = [source]
//        while !queue.isEmpty {
//            let current = queue.removeFirst()
//            for t in transitions where t.source == current {
//                if visited.insert(t.target).inserted { queue.append(t.target) }
//            }
//        }
//        return visited
//    }

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
        guard case .nfa(let initial, let finals, var transitions, let tokenMap) = self else { return }
        transitions.insert(transition)
        self = .nfa(initial: initial, finals: finals, transitions: transitions, tokenMap: tokenMap)
    }
}

extension State where T == DFSA {

    /// Simulates the automaton to determine if it accepts the given input string.
    ///
    /// This function processes the string character by character, traversing the states
    /// according to the transition function.
    ///
    /// - Parameter s: The input string to test.
    /// - Returns: `true` if the automaton ends in an accepting state after consuming the string, `false` otherwise.
    /// - Complexity: Linear in the length of the string `O(|s|)` for a DFA.
    public func run(string s: String) -> Bool {
        guard case .dfa(initial: var state, finals: let finals, transitions: let transitions, _, _) = self else { return false }
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
        guard case let .dfa(_, _, transitions: transitions, _, _) = self else { return nil }
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
        guard case let .dfa(_, _, transitions: trans, _, _) = self else { return nil }
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
        guard case let .dfa( _, _, transitions: trans, _, _) = self else { return Set<Int>() }
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
        guard case let .dfa(_, _, transitions: transitions, _, _) = self else { return false }
        // Same fix as the NFA variant: match by `inAlphabet(char:)` so that
        // `.range` transitions are recognised as successors too.
        return transitions.contains {
            $0.source == source && $0.target == target && $0.inAlphabet(char: symbol)
        }
    }
    
    /// Computes the set of all states transitively reachable from `source` via
    /// any sequence of labelled transitions.
    ///
    /// Uses an iterative BFS, returning the full transitive closure.
    ///
    /// - Parameter source: The identifier of the starting state.
    /// - Returns: A `Set` of reachable state identifiers, including `source` itself.
//    public func reachableStates(from source: Int) -> Set<Int> {
//        guard case let .dfa(_, _, transitions, _, _) = self else { return Set<Int>() }
//        var visited = Set<Int>([source])
//        var queue = [source]
//        while !queue.isEmpty {
//            let current = queue.removeFirst()
//            for t in transitions where t.source == current {
//                if visited.insert(t.target).inserted { queue.append(t.target) }
//            }
//        }
//        return visited
//    }

    /// Deterministic invariant
    mutating func invariant() {
        
    }

    /// Minimizes this DFA. Delegates to `DFSA.minimize()`.
    ///
    /// The previous implementation constructed a throwaway `DFSA` wrapper,
    /// called `wrapper.minimize()`, then unwrapped. That round-trip is
    /// unnecessary now that `DFSA.minimize()` operates directly on its
    /// `state` field — we can just construct the wrapper inline.
    mutating func minimize() {
        var wrapper = DFSA(
            initial: self.initial,
            finals:  self.finals,
            transitions: (extractTransitions() ?? [])
        )
        wrapper.state = self
        wrapper.minimize()
        self = wrapper.state
    }

    /// Helper: pull out the transition set regardless of which case we are.
    private func extractTransitions() -> Set<Transition>? {
        switch self {
        case let .nfa(_, _, t, _): return t
        case let .dfa(_, _, t, _, _): return t
        }
    }
}


extension State where T == Regex {

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
        case let .nfa(start,finals,transitions,_):
            var states = epsClosure(state: start, over: transitions)
            for ch in s {
                // move(A,ch)
                states = states.reduce(Set<Int>(), { $0.union(move(state: $1, symbol: ch, over: transitions)) })
                guard !states.isEmpty else { return false }
                // 𝛆-closure( move(A,ch) )
                states = states.reduce(Set<Int>(), { $0.union(epsClosure(state: $1, over: transitions)) })
            }
            return !states.intersection(finals).isEmpty

        case .dfa(var state,let finals,let transitions ,_, _):
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
