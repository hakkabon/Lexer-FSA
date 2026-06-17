//
//  RegexThompson.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/03.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

/// Constructs an ε-NFA from this regular expression using Thompson's construction algorithm.
///
/// In computer science, Thompson's construction algorithm, also called the McNaughton-Yamada-Thompson
/// algorithm [1], is a method of transforming a regular expression into an equivalent nondeterministic
/// finite automaton (NFA). This NFA can be used to match strings against the regular expression.
/// This algorithm is credited to Ken Thompson.
///
/// [1] Alfred Vaino Aho; Monica S. Lam; Ravi Sethi; Jeffrey D. Ullman (2007).
///     "3.7.4 Construction of an NFA from a Regular Expression"
/// - Returns: Nondeterministic finite automaton with ε-moves (ε-NFA).
///
/// NFA with ε-moves. Start and terminal NFA states.
extension Regex {

    // ThompsonAutomata = (start: Int, terminal: Int, transitions: Set<Transition>)
    typealias ThompsonAutomata = (Int, Int, Set<Transition>)

    struct Thompson: RegularLanguageBuilder {

        // Regex string parser.
        var parser: RegexParser
        
        /// The parsed regular expression.
        var expression: Expression = .empty
        
        /// Number generator.
        let state = Counter.shared
        
        /// Thompson construction method.
        func compile(_ expression: Expression) throws -> ThompsonAutomata {
            switch expression {
            case let .union(e1,e2): return try union(automaton: compile(e1), with: compile(e2))
            case let .concatenation(e1,e2): return try concat(automaton: compile(e1), with: compile(e2))
            case let .optional(e): return try optional(automaton: compile(e))
            case let .repeat(e): return try `repeat`(automaton: compile(e))
            case let .repeatMin(e,n): return try repeatMin(automaton: compile(e), n: n)
            case let .repeatMinMax(e,n,m): return try repeatMinMax(automaton: compile(e), n: n, m: m)
            case let .charRange(ch1,ch2): return charRange(min: ch1, max: ch2)
            case let .char(ch): return char(ch: ch)
            case .anyChar: return anyChar()
            case let .string(s): return string(s: s)
            case .anyString: return anyString()
            case let .interval(min,max,digits):
                return try makeInterval(min: min, max: max, digits: digits)
            case .empty: return empty()
            }
        }
        
        init(expression: String, flags: SyntaxOptions) {
            parser = RegexParser(expression: expression, flags)
        }
        
        mutating func construct() throws -> State<Regex> {
            self.expression = try parser.parse()
            let enfa = try compile(self.expression)
            return .nfa(initial: enfa.0, finals: Set<Int>([enfa.1]), transitions: enfa.2, tokenMap: [:])
        }
        
        /// Concatenation of two ϵ-NFAs (e1 e2).
        /// - Parameters:
        ///   - automaton: one ϵ-NFA
        ///   - anotherAutomaton: another ϵ-NFA
        /// - Returns: concatenated automata with new start and terminal state.
        func concat(automaton: ThompsonAutomata, with anotherAutomaton: ThompsonAutomata) -> ThompsonAutomata {
            let (aStart,aTerminal,aTransitions) = automaton
            let (bStart,bTerminal,bTransitions) = anotherAutomaton

            var transitions = Set<Transition>()
            transitions.formUnion(aTransitions)
            transitions.formUnion(bTransitions)
            transitions.insert(Transition(from: aTerminal, .epsilon, to: bStart))
            return ThompsonAutomata(aStart, bTerminal, transitions)
        }
        
        /// Concatenation of a list of ϵ-NFAs (e1 e2 ... en).
        /// - Parameter automaton: list of ϵ-NFAs
        /// - Returns: concatenated automata with new start and terminal state.
        func concat(automata list: [ThompsonAutomata]) -> ThompsonAutomata {
            guard list.count > 0 else { return ThompsonAutomata(state(), state(), Set<Transition>()) }
            guard list.count > 1 else {
                let (start,terminal,transitions) = list[0]
                return (start,terminal,transitions)
            }
            
            var previous: Int?
            var transitions = Set<Transition>()
            let isOdd = !list.count.isMultiple(of: 2)
            let count = isOdd ? list.count - 2 : list.count - 1
            
            for (left, right) in stride(from: 0, to: count, by: 2).lazy.map( { (list[$0], list[$0+1]) } ) {
                let (_,leftTerminal,leftTransitions) = left
                let (rightStart,rightTerminal,rightTransitions) = right

                transitions.formUnion(leftTransitions)
                transitions.formUnion(rightTransitions)
                transitions.insert(Transition(from: leftTerminal, .epsilon, to: rightStart))
                previous = rightTerminal
            }

            let (firstStart,_,_) = list.first!
            let (lastStart,lastTerminal,_) = list.last!

            let accept = lastTerminal
            if let previous = previous, isOdd {
                transitions.insert(Transition(from: previous, .epsilon, to: lastStart))
            }
            return ThompsonAutomata(firstStart, accept, transitions)
        }
        
        /// Union of two ϵ-NFAs (e1 | e2).
        /// - Parameters:
        ///   - automaton: one ϵ-NFA
        ///   - anotherAutomaton: another ϵ-NFA
        /// - Returns: unified automata with new start and terminal state.
        func union(automaton: ThompsonAutomata, with anotherAutomaton: ThompsonAutomata) -> ThompsonAutomata {
            let (aStart,aTerminal,aTransitions) = automaton
            let (bStart,bTerminal,bTransitions) = anotherAutomaton

            let newStart = state()
            let newAccept = state()

            var transitions = Set<Transition>()
            transitions.formUnion(aTransitions)
            transitions.formUnion(bTransitions)
            transitions.insert(Transition(from: newStart, .epsilon, to: aStart))
            transitions.insert(Transition(from: newStart, .epsilon, to: bStart))
            transitions.insert(Transition(from: aTerminal, .epsilon, to: newAccept))
            transitions.insert(Transition(from: bTerminal, .epsilon, to: newAccept))
            return ThompsonAutomata(newStart, newAccept, transitions)
        }
        
        /// Optional ϵ-NFA (e?).
        /// Very similar to `repeat` but without the back ϵ-transition, i.e. this construct
        /// counts three ϵ-transitions only.
        /// - Parameter automaton: ϵ-NFA automaton
        /// - Returns: optinal automata with new start and terminal state.
        func optional(automaton: ThompsonAutomata) -> ThompsonAutomata {
            let (start,terminal,aTransitions) = automaton
            let newStart = state()
            let newTerminal = state()

            var transitions = Set<Transition>()
            transitions.formUnion(aTransitions)
            transitions.insert(Transition(from: newStart, .epsilon, to: start))
            transitions.insert(Transition(from: newStart, .epsilon, to: newTerminal))
            transitions.insert(Transition(from: terminal, .epsilon, to: newTerminal))
            return ThompsonAutomata(newStart, newTerminal, transitions)
        }
        
        /// Closure of a ϵ-NFA (e*) by Kleene star, a repeating automaton.
        /// This construct has four ϵ-transitions. See `optinal` above.
        /// - Parameter automaton: ϵ-NFA automaton
        /// - Returns: optional automata with new start and terminal state.
        func `repeat`(automaton: ThompsonAutomata) -> ThompsonAutomata {
            let (start,terminal,aTransitions) = automaton
            let newStart = state()
            let newTerminal = state()

            var transitions = Set<Transition>()
            transitions.formUnion(aTransitions)
            transitions.insert(Transition(from: newStart, .epsilon, to: start))
            transitions.insert(Transition(from: terminal, .epsilon, to: newTerminal))
            transitions.insert(Transition(from: newStart, .epsilon, to: newTerminal))
            transitions.insert(Transition(from: terminal, .epsilon, to: start))
            return ThompsonAutomata(newStart, newTerminal, transitions)
        }
        
        /// Implements the regular expresion `A{n,}`, an automaton repeating at least n times.
        /// The expression `A{n,}` is rewritten in terms of already known constructs
        ///     A1 A2 ... An A*, for n > 0 and
        ///     A* , if n = 0
        /// - Parameters:
        ///   - automaton: ϵ-NFA automaton
        ///   - n: repeat counter, where n >= 0
        /// - Returns: repeated automata with new start and terminal state.
        func repeatMin(automaton: ThompsonAutomata, n: Int) throws -> ThompsonAutomata {
            guard n >= 0 else { throw RegexError.illegalLowerBound(n) }

            switch n {
            case 0:
                return `repeat`(automaton: automaton)
            default:
                var list = Array(repeating: automaton, count: n)
                list.append(`repeat`(automaton: automaton))
                return concat(automata: list)
            }
        }
        
        /// Implements the regular expresion `A{n,m}`, an automaton that repeats at least n times
        /// and at most m times.
        /// The expression `A{n,m}` is rewritten in terms of already known constructs
        ///     A1 A2 ... An A1? A2? ... Am-n?, where n < m, n > 0
        /// - Parameters:
        ///   - automaton: ϵ-NFA automaton
        ///   - min: lower bound of repeat counter
        ///   - max: upper bound of repeat counter, where min < max, min > 0
        /// - Returns: repeated automata with new start and terminal state.
        func repeatMinMax(automaton: ThompsonAutomata, n: Int, m: Int) throws -> ThompsonAutomata {
            guard n <= m else { throw RegexError.illegalIntervalBounds(n,m) }

            let opt = m-n
            var list: [ThompsonAutomata] = []
            switch n {
            case 0:
                list.append( empty() )
            default:
                list = Array(repeating: automaton, count: n)
                list.append(`repeat`(automaton: automaton))
            }
            if opt > 0 {
                list = Array(repeating: automaton, count: opt)
                list.append(optional(automaton: automaton))
            }
            return concat(automata: list)
        }
        
        /// Creates a new (deterministic) automaton that accepts only the empty string.
        /// - Returns: Automaton accepting the specified language.
        func empty() -> ThompsonAutomata {
            let v = state()
            return ThompsonAutomata(v, v, Set<Transition>())
        }
        
        /// Creates a new (deterministic) automaton that accepts the given string.
        /// - Parameter s: The alphabet accepted.
        /// - Returns: Automaton accepting the specified language.
        func string(s: String) -> ThompsonAutomata {
            let start = state()
            var transitions = Set<Transition>()
            var st = start
            var terminal: Int?
            for ch in s {
                terminal = state()
                transitions.insert(Transition(from: st, .char(ch), to: terminal!))
                st = terminal!
            }
            return ThompsonAutomata(start, terminal!, transitions)
        }
        
        /// Creates a new (deterministic) automaton that accepts a single character
        /// in the given set.
        /// - Parameter set: The alphabet accepted.
        /// - Returns: Automaton accepting the specified language.
        func charSet(string: String) -> ThompsonAutomata {
            let start = state()
            let terminal = state()
            var transitions = Set<Transition>()
            for ch in string {
                transitions.insert(Transition(from: start, .char(ch), to: terminal))
            }
            return ThompsonAutomata(start, terminal, transitions)
        }
        
        /// Creates a new (deterministic) automaton that accepts all strings.
        /// - Returns: Automaton accepting the specified language.
        func anyString() -> ThompsonAutomata {
            let start = state()
            let terminal = state()
            var transitions = Set<Transition>()
            transitions.insert(Transition(from: start, .range(Transition.lowerBound, Transition.upperBound), to: terminal))
            return ThompsonAutomata(start, terminal, transitions)
        }
        
        /// Creates a new (deterministic) automaton that accepts any single character.
        /// - Returns: Automaton accepting the specified language.
        func anyChar() -> ThompsonAutomata {
            return charRange(min: Transition.lowerBound, max: Transition.upperBound)
        }
        
        /// Creates a new (deterministic) automaton that accepts a single character.
        /// - Parameter c: The alphabet accepted.
        /// - Returns: Automaton accepting the specified language.
        func char(ch: Character) -> ThompsonAutomata {
            let start = state()
            let terminal = state()
            var transitions = Set<Transition>()
            transitions.insert(Transition(from: start, .char(ch), to: terminal))
            return ThompsonAutomata(start, terminal, transitions)
        }
        
        /// Creates a new (deterministic) automaton that accepts a single char
        /// whose value is in the given interval (including both end points).
        /// - Parameters:
        ///   - min: Lower bound of character range.
        ///   - max: Upper bound of character range.
        /// - Returns: Automaton accepting the specified language.
        func charRange(min: Character, max: Character) -> ThompsonAutomata {
            guard min < max else { return ThompsonAutomata(state(), state(), Set<Transition>()) }
            guard min != max else { return char(ch: min) }
            
            let start = state()
            let terminal = state()
            var transitions = Set<Transition>()
            transitions.insert(Transition(from: start, .range(min, max), to: terminal))
            return ThompsonAutomata(start, terminal, transitions)
        }
        
        /// Creates a new automaton that accepts strings representing
        /// decimal non-negative integers in the given interval.
        /// - Parameters:
        ///   - min: minimal value of interval
        ///   - max: maximal value of inverval (both end points are included in the interval)
        ///   - digits: if > 0, use fixed number of digits (strings must be prefixed by 0's to obtain the right length) -
        ///   otherwise, the number of digits is not fixed
        /// - Returns: Automaton accepting the specified language
        /// - Throws: Exception is thrown if min>max or if numbers in the interval cannot be expressed
        ///   with the given fixed number of digits
        func makeInterval(min: Int, max: Int, digits: Int) throws -> ThompsonAutomata {
            guard min <= max else { throw RegexError.illegalInterval(min, max, "malformed interval.") }
            let x = String(min)
            let y = String(max)
            if digits > 0 && y.count > digits {
                throw RegexError.illegalInterval(min, max, "number cannot be expressed with the given number of digits.")
            }
            let d = digits > 0 ? digits : y.count
            var /*xstr*/ _ = x.leftPadding(toLength: d, withPad: "0")
            var /*ystr*/ _ = y.leftPadding(toLength: d, withPad: "0")
            
            return ThompsonAutomata(state(), state(), Set<Transition>())
        }
    }
}
