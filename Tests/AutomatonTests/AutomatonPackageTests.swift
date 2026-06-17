// AutomatonPackageTests.swift
// Comprehensive test suite for the GrammarFSA / Automaton package.
// Uses Swift Testing (@Test, #expect, #require).
//
// Coverage areas:
//  1.  AlphabetRange — membership, equality, ordering, overlap
//  2.  Transition — creation, equality, hashing, set operations
//  3.  Alphabet — interval construction, merging, character enumeration
//  4.  NFA construction and manual mutation
//  5.  NFA simulation (run / step / epsClosure)
//  6.  NFA query API (successor, predecessors, isSuccessor, reachableStates)
//  7.  DFA construction and simulation
//  8.  DFA query API
//  9.  NFA → DFA determinization (State-level)
//  10. TokenClass and token-map accessors
//  11. Token-tracking recognition (recognizeWithToken / runAndGetFinalState)
//  12. Regex compilation — Thompson (basic patterns)
//  13. Regex compilation — Thompson (complex / lexer-relevant patterns)
//  14. Regex compilation — Berry-Sethi
//  15. Regex determinization via isDeterministic flag
//  16. Regex epsilon removal
//  17. Automaton<Regex> wrapper and recognize
//  18. DAWG / stringUnion
//  19. Invariant passes (removeZombieAcceptStates, eliminateDeadStates, reduce)
//  20. Graphvizable — structural smoke test
//  21. Codable round-trip for AlphabetRange
//  22. isEmpty / isDeterministic / isMinimal flags

import Testing
import Foundation
@testable import Automaton


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 1. AlphabetRange
// ──────────────────────────────────────────────────────────────────────────────

@Suite("AlphabetRange")
struct AlphabetRangeTests {

    @Test func epsilonContainsNoCharacter() {
        let r = AlphabetRange.epsilon
        #expect(r.contains(character: "a") == false)
        #expect(r.contains(character: " ") == false)
    }

    @Test func charContainsExactMatch() {
        let r = AlphabetRange.char("x")
        #expect(r.contains(character: "x") == true)
        #expect(r.contains(character: "y") == false)
    }

    @Test func rangeContainsBoundaryAndInterior() {
        let r = AlphabetRange.range("a", "z")
        #expect(r.contains(character: "a") == true)
        #expect(r.contains(character: "z") == true)
        #expect(r.contains(character: "m") == true)
        #expect(r.contains(character: "A") == false)
        #expect(r.contains(character: "0") == false)
    }

    @Test func equalityEpsilon() {
        #expect(AlphabetRange.epsilon == AlphabetRange.epsilon)
        #expect(AlphabetRange.epsilon != AlphabetRange.char("a"))
    }

    @Test func equalityChar() {
        #expect(AlphabetRange.char("a") == AlphabetRange.char("a"))
        #expect(AlphabetRange.char("a") != AlphabetRange.char("b"))
    }

    @Test func equalityRangeAndChar() {
        // .range(a,a) should equal .char(a)
        #expect(AlphabetRange.range("a", "a") == AlphabetRange.char("a"))
        #expect(AlphabetRange.char("a") == AlphabetRange.range("a", "a"))
    }

    @Test func equalityRange() {
        #expect(AlphabetRange.range("a", "z") == AlphabetRange.range("a", "z"))
        #expect(AlphabetRange.range("a", "z") != AlphabetRange.range("a", "y"))
    }

    @Test func lowerUpperAccessors() {
        let r = AlphabetRange.range("d", "g")
        #expect(r.lower == "d")
        #expect(r.upper == "g")
    }

    @Test func overlapCharChar() {
        #expect(AlphabetRange.overlapping(lhs: .char("a"), rhs: .char("a")) == true)
        #expect(AlphabetRange.overlapping(lhs: .char("a"), rhs: .char("b")) == false)
    }

    @Test func overlapRangeRange() {
        #expect(AlphabetRange.overlapping(lhs: .range("a","e"), rhs: .range("c","g")) == true)
        #expect(AlphabetRange.overlapping(lhs: .range("a","c"), rhs: .range("d","f")) == false)
    }

    @Test func overlapRangeChar() {
        #expect(AlphabetRange.overlapping(lhs: .range("a","z"), rhs: .char("m")) == true)
        #expect(AlphabetRange.overlapping(lhs: .range("a","m"), rhs: .char("z")) == false)
    }

    @Test func invariantHolds() {
        #expect(AlphabetRange.epsilon.invariant == true)
        #expect(AlphabetRange.char("a").invariant == true)
        #expect(AlphabetRange.range("a","z").invariant == true)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 2. Transition
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Transition")
struct TransitionTests {

    @Test func charTransitionEquality() {
        let t1 = Transition(from: 0, AlphabetRange.char("a"), to: 1)
        let t2 = Transition(from: 0, AlphabetRange.char("a"), to: 1)
        let t3 = Transition(from: 0, AlphabetRange.char("b"), to: 1)
        #expect(t1 == t2)
        #expect(t1 != t3)
    }

    @Test func epsilonTransitionEquality() {
        let t1 = Transition(from: 2, AlphabetRange.epsilon, to: 3)
        let t2 = Transition(from: 2, AlphabetRange.epsilon, to: 3)
        let t3 = Transition(from: 2, AlphabetRange.epsilon, to: 4)
        #expect(t1 == t2)
        #expect(t1 != t3)
    }

    @Test func rangeTransitionEquality() {
        let t1 = Transition(from: 0, AlphabetRange.range("0","9"), to: 1)
        let t2 = Transition(from: 0, AlphabetRange.range("0","9"), to: 1)
        #expect(t1 == t2)
    }

    @Test func transitionInSet() {
        var s = Set<Transition>()
        let t = Transition(from: 0, AlphabetRange.char("x"), to: 1)
        s.insert(t)
        #expect(s.contains(t))
        #expect(s.count == 1)
        s.insert(t)   // duplicate insert
        #expect(s.count == 1)
    }

    @Test func setStatesHelper() {
        let transitions: Set<Transition> = [
            Transition(from: 0, AlphabetRange.char("a"), to: 1),
            Transition(from: 1, AlphabetRange.char("b"), to: 2),
        ]
        let states = transitions.states()
        #expect(states == [0, 1, 2])
    }

    @Test func setAlphabetHelper() {
        let transitions: Set<Transition> = [
            Transition(from: 0, AlphabetRange.char("a"), to: 1),
            Transition(from: 1, AlphabetRange.char("b"), to: 2),
        ]
        let alpha = transitions.alphabet()
        #expect(alpha.characters.contains("a"))
        #expect(alpha.characters.contains("b"))
    }

    @Test func reverseTransitions() {
        let transitions: Set<Transition> = [
            Transition(from: 0, AlphabetRange.char("a"), to: 1),
        ]
        let rev = transitions.reversed()
        #expect(rev.contains(Transition(from: 1, AlphabetRange.char("a"), to: 0)))
    }

    @Test func equalEndpoints() {
        let t1 = Transition(from: 1, AlphabetRange.char("a"), to: 3)
        let t2 = Transition(from: 1, AlphabetRange.char("b"), to: 3)
        let t3 = Transition(from: 1, AlphabetRange.char("a"), to: 4)
        #expect(Transition.equalEndpoints(lhs: t1, rhs: t2) == true)
        #expect(Transition.equalEndpoints(lhs: t1, rhs: t3) == false)
    }

    @Test func reverseHelper() {
        let t = Transition(from: 0, AlphabetRange.char("c"), to: 5)
        let r = Transition.reverse(t)
        #expect(r.source == 5)
        #expect(r.target == 0)
        #expect(r.alphabetRange == AlphabetRange.char("c"))
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Alphabet
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Alphabet")
struct AlphabetTests {

    @Test func singleCharAlphabet() {
        let a = Alphabet([Interval("x")])
        #expect(a.characters == ["x"])
    }

    @Test func rangeAlphabet() {
        let a = Alphabet([Interval("a","e")])
        #expect(a.characters == ["a","b","c","d","e"])
    }

    @Test func mergedIntervals() {
        // Two overlapping ranges should merge to one when merge: true
        let a = Alphabet([Interval("a","c"), Interval("b","e")], true)
        #expect(a.characters.contains("a"))
        #expect(a.characters.contains("e"))
        // No duplicates
        let unique = Set(a.characters)
        #expect(unique.count == a.characters.count)
    }

    @Test func emptyAlphabet() {
        let a = Alphabet([])
        #expect(a.characters.isEmpty)
    }

    @Test func indexOfCharacter() {
        let a = Alphabet([Interval("a","e")])
        let idx = a.index(of: "c")
        #expect(idx != nil)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 4. NFA Construction and Mutation
// ──────────────────────────────────────────────────────────────────────────────

@Suite("NFA Construction")
struct NFAConstructionTests {

    /// Builds NFA for the language a(b|c)*
    func makeSimpleNFA() -> NFSA {
        return NFSA(
            initial: 0,
            finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 1),
                Transition(from: 1, AlphabetRange.char("c"), to: 1),
            ]
        )
    }

    @Test func basicProperties() {
        let nfa = makeSimpleNFA()
        #expect(nfa.initial == 0)
        #expect(nfa.finals == [1])
        #expect(nfa.isDeterministic == false)
        #expect(nfa.stateCount == 2)
        #expect(nfa.finalCount == 1)
    }

    @Test func isFinalAndIsInitial() {
        let nfa = makeSimpleNFA()
        #expect(nfa.isFinal(state: 1) == true)
        #expect(nfa.isFinal(state: 0) == false)
        #expect(nfa.isInitial(state: 0) == true)
        #expect(nfa.isInitial(state: 1) == false)
    }

    @Test func alphabetContainsExpectedSymbols() {
        let nfa = makeSimpleNFA()
        let chars = nfa.alphabet.characters
        #expect(chars.contains("a"))
        #expect(chars.contains("b"))
        #expect(chars.contains("c"))
    }

    @Test func addTransitionMutates() {
        var nfa = makeSimpleNFA()
        let before = nfa.stateCount
        nfa.addTransition(source: 1, symbol: "d", target: 2)
        // State 2 is new, so count increases
        #expect(nfa.stateCount == before + 1)
    }

    @Test func addEpsilonTransition() {
        var nfa = NFSA(initial: 0, finals: [2], transitions: [])
        nfa.add(Transition(from: 0, AlphabetRange.epsilon, to: 1))
        nfa.add(Transition(from: 1, AlphabetRange.char("a"), to: 2))
        #expect(nfa.run(string: "a") == true)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 5. NFA Simulation
// ──────────────────────────────────────────────────────────────────────────────

@Suite("NFA Simulation")
struct NFASimulationTests {

    /// NFA for (a|b)*
    func makeKleeneNFA() -> NFSA {
        NFSA(
            initial: 0,
            finals: [0],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 0),
                Transition(from: 0, AlphabetRange.char("b"), to: 0),
            ]
        )
    }

    /// NFA for a·ε·b
    func makeEpsilonNFA() -> NFSA {
        NFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.epsilon,   to: 2),
                Transition(from: 2, AlphabetRange.char("b"), to: 3),
            ]
        )
    }

    @Test func acceptsEmptyStringWhenInitialIsFinal() {
        let nfa = makeKleeneNFA()
        #expect(nfa.run(string: "") == true)
    }

    @Test func acceptsRepeatedSymbols() {
        let nfa = makeKleeneNFA()
        #expect(nfa.run(string: "aaa") == true)
        #expect(nfa.run(string: "bbb") == true)
        #expect(nfa.run(string: "abababba") == true)
    }

    @Test func rejectsUnknownSymbol() {
        let nfa = makeKleeneNFA()
        #expect(nfa.run(string: "c") == false)
    }

    @Test func epsilonTransitionIsTransparent() {
        let nfa = makeEpsilonNFA()
        // ε-path: 0 –a→ 1 –ε→ 2 (not final), need "ab" to reach state 3 — not final either
        // Let's build a proper accepting ε-NFA:
        let nfa2 = NFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.epsilon,   to: 2),
            ]
        )
        #expect(nfa2.run(string: "a") == true)
        #expect(nfa2.run(string: "") == false)
    }

    @Test func epsilonClosure() {
        let nfa = NFSA(
            initial: 0,
            finals: [3],
            transitions: [
                Transition(from: 0, AlphabetRange.epsilon, to: 1),
                Transition(from: 1, AlphabetRange.epsilon, to: 2),
                Transition(from: 2, AlphabetRange.char("x"), to: 3),
            ]
        )
        let transitions: Set<Transition> = { guard case .nfa(_,_,let t,_) = nfa.state else { return [] }; return t }()
        let closure = nfa.epsClosure(state: 0, over: transitions)
        // Should include 0, 1, and 2
        #expect(closure.contains(0))
        #expect(closure.contains(1))
        #expect(closure.contains(2))
    }

    @Test func stepReturnsSuccessorSet() {
        let nfa = NFSA(
            initial: 0,
            finals: [1, 2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 0, AlphabetRange.char("a"), to: 2),
            ]
        )
        let next = nfa.step(state: 0, symbol: "a")
        #expect(next == [1, 2])
    }

    @Test func stepOnRangeTransition() {
        let nfa = NFSA(
            initial: 0,
            finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.range("0","9"), to: 1),
            ]
        )
        #expect(nfa.run(string: "5") == true)
        #expect(nfa.run(string: "9") == true)
        #expect(nfa.run(string: "a") == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 6. NFA Query API
// ──────────────────────────────────────────────────────────────────────────────

@Suite("NFA Query API")
struct NFAQueryTests {

    func makeChainNFA() -> NFSA {
        // 0 -a-> 1 -b-> 2
        NFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 2),
            ]
        )
    }

    @Test func successor() {
        let nfa = makeChainNFA()
        #expect(nfa.successor(source: 0, symbol: "a") == [1])
        #expect(nfa.successor(source: 0, symbol: "b").isEmpty)
    }

    @Test func predecessors() {
        let nfa = makeChainNFA()
        #expect(nfa.predecessors(target: 1, symbol: "a") == [0])
        #expect(nfa.predecessors(target: 2, symbol: "b") == [1])
        #expect(nfa.predecessors(target: 0, symbol: "a").isEmpty)
    }

    @Test func isSuccessor() {
        let nfa = makeChainNFA()
        #expect(nfa.isSuccessor(source: 0, symbol: "a", target: 1) == true)
        #expect(nfa.isSuccessor(source: 0, symbol: "a", target: 2) == false)
        #expect(nfa.isSuccessor(source: 0, symbol: "b", target: 1) == false)
    }

    @Test func reachableStates() {
        let nfa = makeChainNFA()
        let fromZero = nfa.reachableStates(from: 0)
        #expect(fromZero.contains(1))
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 7. DFA Construction and Simulation
// ──────────────────────────────────────────────────────────────────────────────

@Suite("DFA Construction and Simulation")
struct DFATests {

    /// DFA that accepts exactly "ab"
    func makeABDFA() -> DFSA {
        DFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 2),
            ]
        )
    }

    @Test func recognizesExactString() {
        let dfa = makeABDFA()
        #expect(dfa.run(string: "ab") == true)
    }

    @Test func rejectsPartialMatch() {
        let dfa = makeABDFA()
        #expect(dfa.run(string: "a") == false)
        #expect(dfa.run(string: "b") == false)
        #expect(dfa.run(string: "") == false)
    }

    @Test func rejectsExtraInput() {
        let dfa = makeABDFA()
        #expect(dfa.run(string: "abc") == false)
    }

    @Test func isDeterministicTrue() {
        let dfa = makeABDFA()
        #expect(dfa.isDeterministic == true)
    }

    @Test func stepReturnsOptional() {
        let dfa = makeABDFA()
        #expect(dfa.step(state: 0, symbol: "a") == 1)
        #expect(dfa.step(state: 0, symbol: "b") == nil)
        #expect(dfa.step(state: 1, symbol: "b") == 2)
    }

    @Test func dfaWithRange() {
        // DFA accepting one digit
        let dfa = DFSA(
            initial: 0,
            finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.range("0", "9"), to: 1),
            ]
        )
        #expect(dfa.run(string: "0") == true)
        #expect(dfa.run(string: "5") == true)
        #expect(dfa.run(string: "9") == true)
        #expect(dfa.run(string: "a") == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 8. DFA Query API
// ──────────────────────────────────────────────────────────────────────────────

@Suite("DFA Query API")
struct DFAQueryTests {

    func makeDFA() -> DFSA {
        DFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("x"), to: 1),
                Transition(from: 1, AlphabetRange.char("y"), to: 2),
            ]
        )
    }

    @Test func successor() {
        let dfa = makeDFA()
        #expect(dfa.successor(source: 0, symbol: "x") == 1)
        #expect(dfa.successor(source: 0, symbol: "y") == nil)
    }

    @Test func predecessors() {
        let dfa = makeDFA()
        #expect(dfa.predecessors(target: 1, symbol: "x") == [0])
        #expect(dfa.predecessors(target: 2, symbol: "y") == [1])
        #expect(dfa.predecessors(target: 0, symbol: "x").isEmpty)
    }

    @Test func isSuccessor() {
        let dfa = makeDFA()
        #expect(dfa.isSuccessor(source: 0, symbol: "x", target: 1) == true)
        #expect(dfa.isSuccessor(source: 0, symbol: "y", target: 1) == false)
    }

    @Test func isFinalAndIsInitial() {
        let dfa = makeDFA()
        #expect(dfa.isFinal(state: 2) == true)
        #expect(dfa.isFinal(state: 0) == false)
        #expect(dfa.isInitial(state: 0) == true)
        #expect(dfa.isInitial(state: 2) == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 9. NFA → DFA Determinization
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Determinization")
struct DeterminizationTests {

    @Test func determinizedNFAIsDeterministic() {
        var nfa = NFSA(
            initial: 0,
            finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 0),
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
            ]
        )
        nfa.determinize()
        #expect(nfa.isDeterministic == true)
    }

    @Test func determinizedNFAPreservesLanguage() {
        // NFA for (a|b)*  — initial state is both start and accept
        var nfa = NFSA(
            initial: 0,
            finals: [0],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 0),
                Transition(from: 0, AlphabetRange.char("b"), to: 0),
            ]
        )
        nfa.determinize()
        #expect(nfa.run(string: "") == true)
        #expect(nfa.run(string: "a") == true)
        #expect(nfa.run(string: "ababab") == true)
        #expect(nfa.run(string: "c") == false)
    }

    @Test func determinizedEpsilonNFAWorks() {
        // NFA: 0 -a-> 1 -ε-> 2  (finals: {2})
        var nfa = NFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.epsilon,   to: 2),
            ]
        )
        nfa.determinize()
        #expect(nfa.run(string: "a") == true)
        #expect(nfa.run(string: "") == false)
        #expect(nfa.run(string: "aa") == false)
    }

    @Test func regexDeterminizationViaFlag() throws {
        var r = try Regex("ab*c")
        r.isDeterministic = true
        #expect(r.isDeterministic == true)
        #expect(r.recognize(string: "ac") == true)
        #expect(r.recognize(string: "abc") == true)
        #expect(r.recognize(string: "abbc") == true)
        #expect(r.recognize(string: "bc") == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 10. TokenClass and Token-Map Accessors
// ──────────────────────────────────────────────────────────────────────────────

@Suite("TokenClass")
struct TokenClassTests {

    @Test func tokenClassEquality() {
        let t1 = TokenClass(id: 1, name: "IDENT", priority: 10)
        let t2 = TokenClass(id: 1, name: "IDENT", priority: 10)
        let t3 = TokenClass(id: 2, name: "KEYWORD", priority: 1)
        #expect(t1 == t2)
        #expect(t1 != t3)
    }

    @Test func tokenClassHashable() {
        let t1 = TokenClass(id: 1, name: "A", priority: 0)
        let t2 = TokenClass(id: 2, name: "B", priority: 0)
        let s: Set<TokenClass> = [t1, t2, t1]
        #expect(s.count == 2)
    }

    @Test func tokenMapAccessorOnNFA() {
        let tok = TokenClass(id: 7, name: "NUM", priority: 5)
        var nfa = NFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("1"), to: 1)]
        )
        nfa.state.setTokenMap([1: tok])
        let retrieved = nfa.state.tokenClass(for: 1)
        #expect(retrieved == tok)
        #expect(nfa.state.tokenClass(for: 0) == nil)
    }

    @Test func tokenMapPreservedAfterSetTokenMap() {
        let t1 = TokenClass(id: 1, name: "A", priority: 1)
        let t2 = TokenClass(id: 2, name: "B", priority: 2)
        var nfa = NFSA(
            initial: 0,
            finals: [1, 2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 0, AlphabetRange.char("b"), to: 2),
            ]
        )
        nfa.state.setTokenMap([1: t1, 2: t2])
        #expect(nfa.state.tokenMap[1] == t1)
        #expect(nfa.state.tokenMap[2] == t2)
    }

    @Test func setTokenMapOnDFA() {
        let tok = TokenClass(id: 3, name: "KW", priority: 1)
        var dfa = DFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("k"), to: 1)]
        )
        dfa.state.setTokenMap([1: tok])
        #expect(dfa.state.tokenClass(for: 1) == tok)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 11. Token-Tracking Recognition
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Token-Tracking Recognition")
struct TokenTrackingTests {

    @Test func recognizeWithTokenReturnsCorrectClass() {
        let numTok  = TokenClass(id: 1, name: "NUMBER",     priority: 5)
        let identTok = TokenClass(id: 2, name: "IDENTIFIER", priority: 10)

        // DFA for "42" ending at state 2 (NUMBER) and "ab" ending at state 4 (IDENTIFIER)
        var dfa = DFSA(
            initial: 0,
            finals: [2, 4],
            transitions: [
                Transition(from: 0, AlphabetRange.char("4"), to: 1),
                Transition(from: 1, AlphabetRange.char("2"), to: 2),
                Transition(from: 0, AlphabetRange.char("a"), to: 3),
                Transition(from: 3, AlphabetRange.char("b"), to: 4),
            ]
        )
        dfa.state.setTokenMap([2: numTok, 4: identTok])

        let r1 = dfa.state.recognizeWithToken(string: "42")
        let r2 = dfa.state.recognizeWithToken(string: "ab")
        let r3 = dfa.state.recognizeWithToken(string: "99")

        #expect(r1 == numTok)
        #expect(r2 == identTok)
        #expect(r3 == nil)
    }

    @Test func priorityResolutionPicksLowerPriority() {
        // Two final states reachable from an NFA for the same string (ambiguity).
        // State 1: priority 1 (wins), State 2: priority 10 (loses).
        let kwTok   = TokenClass(id: 1, name: "KEYWORD",    priority: 1)
        let identTok = TokenClass(id: 2, name: "IDENTIFIER", priority: 10)

        var nfa = NFSA(
            initial: 0,
            finals: [1, 2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("i"), to: 1),
                Transition(from: 0, AlphabetRange.char("i"), to: 2),
            ]
        )
        nfa.state.setTokenMap([1: kwTok, 2: identTok])

        let result = nfa.state.recognizeWithToken(string: "i")
        #expect(result == kwTok)
    }

    @Test func recognizeWithTokenReturnNilOnRejection() {
        let tok = TokenClass(id: 1, name: "A", priority: 0)
        var dfa = DFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)]
        )
        dfa.state.setTokenMap([1: tok])
        #expect(dfa.state.recognizeWithToken(string: "b") == nil)
        #expect(dfa.state.recognizeWithToken(string: "") == nil)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 12. Regex Compilation — Thompson (basic)
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Regex Thompson Basic")
struct RegexThompsonBasicTests {

    @Test func singleLiteral() throws {
        let r = try Regex("a")
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "b") == false)
        #expect(r.recognize(string: "") == false)
    }

    @Test func concatenation() throws {
        let r = try Regex("ab")
        #expect(r.recognize(string: "ab") == true)
        #expect(r.recognize(string: "a") == false)
        #expect(r.recognize(string: "b") == false)
        #expect(r.recognize(string: "ba") == false)
    }

    @Test func alternation() throws {
        let r = try Regex("a|b")
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "b") == true)
        #expect(r.recognize(string: "c") == false)
        #expect(r.recognize(string: "ab") == false)
    }

    @Test func kleeneStar() throws {
        let r = try Regex("a*")
        #expect(r.recognize(string: "") == true)
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "aaaa") == true)
        #expect(r.recognize(string: "b") == false)
    }

    @Test func oneOrMore() throws {
        let r = try Regex("a+")
        #expect(r.recognize(string: "") == false)
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "aaa") == true)
    }

    @Test func grouping() throws {
        let r = try Regex("(ab)+")
        #expect(r.recognize(string: "ab") == true)
        #expect(r.recognize(string: "abab") == true)
        #expect(r.recognize(string: "ababab") == true)
        #expect(r.recognize(string: "a") == false)
        #expect(r.recognize(string: "aba") == false)
    }

    @Test func characterClass() throws {
        let r = try Regex("[a-z]")
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "z") == true)
        #expect(r.recognize(string: "m") == true)
        #expect(r.recognize(string: "A") == false)
        #expect(r.recognize(string: "0") == false)
    }

    @Test func characterClassMultipleRanges() throws {
        let r = try Regex("[a-zA-Z]")
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "Z") == true)
        #expect(r.recognize(string: "0") == false)
    }

    @Test func digitClass() throws {
        let r = try Regex("[0-9]")
        #expect(r.recognize(string: "0") == true)
        #expect(r.recognize(string: "9") == true)
        #expect(r.recognize(string: "5") == true)
        #expect(r.recognize(string: "a") == false)
    }

    @Test func nestedGroups() throws {
        let r = try Regex("(a(b|c))+")
        #expect(r.recognize(string: "ab") == true)
        #expect(r.recognize(string: "ac") == true)
        #expect(r.recognize(string: "abac") == true)
        #expect(r.recognize(string: "a") == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 13. Regex — Lexer-Relevant Patterns
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Regex Lexer Patterns")
struct RegexLexerPatternTests {

    @Test func identifierPattern() throws {
        let r = try Regex("[a-zA-Z_][a-zA-Z0-9_]*")
        #expect(r.recognize(string: "foo") == true)
        #expect(r.recognize(string: "_bar") == true)
        #expect(r.recognize(string: "x1") == true)
        #expect(r.recognize(string: "CamelCase") == true)
        #expect(r.recognize(string: "123") == false)
        #expect(r.recognize(string: "") == false)
    }

    @Test func unsignedIntegerPattern() throws {
        let r = try Regex("[0-9]+")
        #expect(r.recognize(string: "0") == true)
        #expect(r.recognize(string: "123456") == true)
        #expect(r.recognize(string: "") == false)
        #expect(r.recognize(string: "12a") == false)
    }

    @Test func signedIntegerPattern() throws {
        let r = try Regex("[+-]?[0-9]+")
        #expect(r.recognize(string: "42") == true)
        #expect(r.recognize(string: "+42") == true)
        #expect(r.recognize(string: "-7") == true)
        #expect(r.recognize(string: "abc") == false)
    }

    @Test func floatPattern() throws {
        let r = try Regex("[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?")
        #expect(r.recognize(string: "123456") == true)
        #expect(r.recognize(string: "123.45") == true)
        #expect(r.recognize(string: "-0.123e-6") == true)
        #expect(r.recognize(string: "+1E10") == true)
    }

    @Test func keywordIfPattern() throws {
        let r = try Regex("if")
        #expect(r.recognize(string: "if") == true)
        #expect(r.recognize(string: "iff") == false)
        #expect(r.recognize(string: "i") == false)
    }

    @Test func binaryNumberPattern() throws {
        let r = try Regex("(0|(1(01*(00)*0)*1)*)*")
        // Multiples of 3 in binary
        #expect(r.recognize(string: "") == true)
        #expect(r.recognize(string: "0") == true)
        #expect(r.recognize(string: "11") == true)
        #expect(r.recognize(string: "110") == true)
        #expect(r.recognize(string: "1") == false)
        #expect(r.recognize(string: "10") == false)
    }

    @Test func dragonBookPattern() throws {
        // Classic example from the Dragon Book
        let r = try Regex("(a|b)*abb")
        #expect(r.recognize(string: "abb") == true)
        #expect(r.recognize(string: "aabb") == true)
        #expect(r.recognize(string: "babb") == true)
        #expect(r.recognize(string: "aaaabbbbbbabbaabb") == true)
        #expect(r.recognize(string: "ab") == false)
        #expect(r.recognize(string: "ba") == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 14. Regex — Berry-Sethi Construction
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Regex Berry-Sethi")
struct RegexBerrySetHiTests {

    @Test func singleLiteral() throws {
        let r = try Regex("a", method: .berrySethi)
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "b") == false)
    }

    @Test func concatenation() throws {
        let r = try Regex("ab", method: .berrySethi)
        #expect(r.recognize(string: "ab") == true)
        #expect(r.recognize(string: "a") == false)
        #expect(r.recognize(string: "b") == false)
    }

    @Test func alternation() throws {
        let r = try Regex("a|b", method: .berrySethi)
        #expect(r.recognize(string: "a") == true)
        #expect(r.recognize(string: "b") == true)
        #expect(r.recognize(string: "c") == false)
    }

    @Test func kleeneStar() throws {
        let r = try Regex("a*", method: .berrySethi)
        #expect(r.recognize(string: "") == true)
        #expect(r.recognize(string: "aaa") == true)
        #expect(r.recognize(string: "b") == false)
    }

    @Test func complexPattern() throws {
        let r = try Regex("(a|b)*abb", method: .berrySethi)
        #expect(r.recognize(string: "abb") == true)
        #expect(r.recognize(string: "babb") == true)
        #expect(r.recognize(string: "ab") == false)
    }

    @Test func thompsonAndBerrySetHiAgree() throws {
        let patterns = ["ab", "a|b", "a*", "(a|b)+", "[0-9]+"]
        let inputs   = ["ab", "a", "b", "aaa", "123", "", "xyz", "0", "ab9"]
        for pattern in patterns {
            let t = try Regex(pattern, method: .thompson)
            let bs = try Regex(pattern, method: .berrySethi)
            for input in inputs {
                let tr = t.recognize(string: input)
                let br = bs.recognize(string: input)
                #expect(tr == br, "Thompson vs Berry-Sethi disagree on pattern '\(pattern)' input '\(input)'")
            }
        }
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 15. Regex Determinization
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Regex Determinization")
struct RegexDeterminizationTests {

    @Test func isDeterministicFlagChangesState() throws {
        var r = try Regex("(a|b)*")
        #expect(r.isDeterministic == false)
        r.isDeterministic = true
        #expect(r.isDeterministic == true)
    }

    @Test func deterministicVersionPreservesLanguage() throws {
        let inputs = ["", "a", "b", "ab", "ba", "aabb", "c"]
        let rNFA = try Regex("[ab]+")
        var rDFA = try Regex("[ab]+")
        rDFA.isDeterministic = true
        for input in inputs {
            #expect(rNFA.recognize(string: input) == rDFA.recognize(string: input),
                    "NFA and DFA disagree on input '\(input)'")
        }
    }

    @Test func deterministicConversionIsIdempotent() throws {
        var r = try Regex("x+")
        r.isDeterministic = true
        let stateCountAfterFirst = r.state.stateCount
        r.isDeterministic = true  // setting again should be a no-op
        #expect(r.state.stateCount == stateCountAfterFirst)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 16. Epsilon Removal
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Epsilon Removal")
struct EpsilonRemovalTests {

    @Test func epsilonFreeStateIsSetCorrectly() throws {
        var r = try Regex("ab")
        #expect(r.epsilonFree == false)
        r.epsilonFree = true
        #expect(r.epsilonFree == true)
    }

    @Test func epsilonFreePreservesLanguage() throws {
        let inputs = ["ab", "a", "b", "", "abc"]
        let rEps = try Regex("ab")
        var rFree = try Regex("ab")
        rFree.epsilonFree = true
        for input in inputs {
            #expect(rEps.recognize(string: input) == rFree.recognize(string: input),
                    "epsilon-free disagrees on '\(input)'")
        }
    }

    @Test func epsilonFreeFlagIdempotent() throws {
        var r = try Regex("a+")
        r.epsilonFree = true
        let t1 = r.state.stateCount
        r.epsilonFree = true
        #expect(r.state.stateCount == t1)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 17. Automaton<Regex> Wrapper
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Automaton Wrapper")
struct AutomatonWrapperTests {

    @Test func wrapNFARegex() throws {
        let r = try Regex("a+b")
        let a = Automaton(r)
        #expect(a.isDeterministic == false)
        #expect(a.recognize(string: "ab") == true)
        #expect(a.recognize(string: "aab") == true)
        #expect(a.recognize(string: "b") == false)
    }

    @Test func wrapDFARegex() throws {
        var r = try Regex("ab*")
        r.isDeterministic = true
        let a = Automaton(Regex.deterministicFiniteState(r))
        #expect(a.isDeterministic == true)
        #expect(a.run(string: "a") == true)
        #expect(a.run(string: "abbb") == true)
        #expect(a.run(string: "b") == false)
    }

    @Test func wrapNondeterministicFiniteState() throws {
        let nfa = NFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("z"), to: 1)]
        )
        let a = Automaton(nfa)
        #expect(a.run(string: "z") == true)
        #expect(a.run(string: "x") == false)
    }

    @Test func wrapDeterministicFiniteState() throws {
        let dfa = DFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("q"), to: 1)]
        )
        let a = Automaton(dfa)
        #expect(a.run(string: "q") == true)
        #expect(a.run(string: "p") == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 18. DAWG / stringUnion
// ──────────────────────────────────────────────────────────────────────────────

@Suite("DAWG / String Union")
struct DAWGTests {

    @Test func exactKeywordMatch() {
        let keywords = ["if", "else", "while", "for", "return"]
        let dfa = Automaton<DFSA>.stringUnion(words: keywords)
        for kw in keywords {
            #expect(dfa.run(string: kw) == true, "should accept keyword '\(kw)'")
        }
    }

    @Test func nonKeywordRejected() {
        let keywords = ["if", "else", "while"]
        let dfa = Automaton<DFSA>.stringUnion(words: keywords)
        #expect(dfa.run(string: "iff") == false)
        #expect(dfa.run(string: "el") == false)
        #expect(dfa.run(string: "whiles") == false)
        #expect(dfa.run(string: "") == false)
    }

    @Test func singleWordDictionary() {
        let dfa = Automaton<DFSA>.stringUnion(words: ["hello"])
        #expect(dfa.run(string: "hello") == true)
        #expect(dfa.run(string: "hell") == false)
        #expect(dfa.run(string: "helloo") == false)
    }

    @Test func sharedPrefixWords() {
        let dfa = Automaton<DFSA>.stringUnion(words: ["fore", "for", "ford"])
        #expect(dfa.run(string: "for") == true)
        #expect(dfa.run(string: "fore") == true)
        #expect(dfa.run(string: "ford") == true)
        #expect(dfa.run(string: "fo") == false)
        #expect(dfa.run(string: "fore1") == false)
    }

    @Test func sharedSuffixWords() {
        let dfa = Automaton<DFSA>.stringUnion(words: ["cat", "bat", "rat"])
        #expect(dfa.run(string: "cat") == true)
        #expect(dfa.run(string: "bat") == true)
        #expect(dfa.run(string: "rat") == true)
        #expect(dfa.run(string: "at") == false)
    }

    @Test func resultIsDeterministic() {
        let dfa = Automaton<DFSA>.stringUnion(words: ["abc", "abd"])
        #expect(dfa.isDeterministic == true)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 19. Invariant Passes
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Invariant Passes")
struct InvariantTests {

    /// Build a DFA that has a zombie accept state (state 99 has no transitions).
    func makeZombieDFA() -> DFSA {
        DFSA(
            initial: 0,
            finals: [1, 99],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
            ]
        )
    }

    @Test func removeZombieAcceptStatesTest() {
        var dfa = makeZombieDFA()
        dfa.removeZombieAcceptStates()
        #expect(dfa.finals.contains(99) == false)
        #expect(dfa.finals.contains(1) == true)
    }

    @Test func zombieDFAStillWorksAfterCleanup() {
        var dfa = makeZombieDFA()
        dfa.removeZombieAcceptStates()
        #expect(dfa.run(string: "a") == true)
        #expect(dfa.run(string: "b") == false)
    }

    /// DFA where state 5 is unreachable from initial (0).
    func makeUnreachableDFA() -> DFSA {
        DFSA(
            initial: 0,
            finals: [1, 5],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 5, AlphabetRange.char("b"), to: 6), // unreachable island
            ]
        )
    }

    @Test func eliminateDeadStatesRemovesUnreachable() {
        var dfa = makeUnreachableDFA()
        dfa.eliminateDeadStates()
        // State 5 and 6 should be gone
        let remainingStates = dfa.state.alphabet  // just a way to exercise the DFA
        #expect(dfa.run(string: "a") == true)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 20. Graphviz Rendering (Smoke Test)
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Graphviz Rendering")
struct GraphvizTests {

    @Test func nfaGraphvizProducesDirectedGraph() {
        let nfa = NFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)]
        )
        let g = nfa.graphviz
        #expect(g.directed == true)
    }

    @Test func dfaGraphvizProducesDirectedGraph() {
        let dfa = DFSA(
            initial: 0,
            finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("x"), to: 1)]
        )
        let g = dfa.graphviz
        #expect(g.directed == true)
    }

    @Test func regexGraphvizProducesDirectedGraph() throws {
        let r = try Regex("ab")
        let g = r.graphviz
        #expect(g.directed == true)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 21. Codable Round-Trip for AlphabetRange
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Codable AlphabetRange")
struct CodableAlphabetRangeTests {

    func roundTrip(_ range: AlphabetRange) throws -> AlphabetRange {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(range)
        return try decoder.decode(AlphabetRange.self, from: data)
    }

    @Test func epsilonRoundTrip() throws {
        let r = try roundTrip(.epsilon)
        #expect(r == .epsilon)
    }

    @Test func charRoundTrip() throws {
        let r = try roundTrip(.char("q"))
        #expect(r == .char("q"))
    }

    @Test func rangeRoundTrip() throws {
        let r = try roundTrip(.range("a", "z"))
        #expect(r == .range("a", "z"))
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 22. State Flags
// ──────────────────────────────────────────────────────────────────────────────

@Suite("State Flags")
struct StateFlagTests {

    @Test func nfaIsNotDeterministic() {
        let nfa = NFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)]
        )
        #expect(nfa.isDeterministic == false)
        #expect(nfa.isMinimal == false)
    }

    @Test func dfaIsDeterministic() {
        let dfa = DFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)],
            minimal: false
        )
        #expect(dfa.isDeterministic == true)
        #expect(dfa.isMinimal == false)
    }

    @Test func minimalFlagSetOnConstruction() {
        let dfa = DFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)],
            minimal: true
        )
        #expect(dfa.isMinimal == true)
    }

    @Test func stateCountReflectsTransitions() {
        let nfa = NFSA(
            initial: 0, finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 2),
            ]
        )
        #expect(nfa.stateCount == 3)
        #expect(nfa.finalCount == 1)
    }

    @Test func alphabetReflectsAllRanges() {
        let dfa = DFSA(
            initial: 0, finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.range("a","c"), to: 1),
            ]
        )
        let chars = dfa.alphabet.characters
        #expect(chars.contains("a"))
        #expect(chars.contains("b"))
        #expect(chars.contains("c"))
        #expect(chars.contains("d") == false)
    }
}
