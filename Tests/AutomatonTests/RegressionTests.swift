// RegressionTests.swift
// Locks in correct behavior for a few areas that Technical.md records as
// having been buggy in earlier revisions (isEmpty always false, epsilon
// matching every character, reachableStates returning only one-hop
// neighbours). All three are fixed in the current source — these tests
// exist so a future refactor can't silently reintroduce them.

import Testing
@testable import Automaton


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - isEmpty
// ──────────────────────────────────────────────────────────────────────────────

@Suite("isEmpty")
struct IsEmptyTests {

    @Test func freshlyConstructedNFAIsNotConsideredEmpty() {
        let nfa = NFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)]
        )
        #expect(nfa.isEmpty == false)
    }

    @Test func nfaWithNoFinalsAndNoTransitionsIsEmpty() {
        let nfa = NFSA(initial: 0, finals: [], transitions: [])
        #expect(nfa.isEmpty == true)
    }

    @Test func dfaWithNoFinalsAndNoTransitionsIsEmpty() {
        let dfa = DFSA(initial: 0, finals: [], transitions: [])
        #expect(dfa.isEmpty == true)
    }

    @Test func dfaWithTransitionsButNoFinalsIsNotEmpty() {
        // Has structure (a transition) even though nothing is accepting yet —
        // `isEmpty` is defined as "no finals AND no transitions", so this
        // should NOT count as empty.
        let dfa = DFSA(
            initial: 0, finals: [],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)]
        )
        #expect(dfa.isEmpty == false)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - reachableStates — full transitive closure, not just one hop
// ──────────────────────────────────────────────────────────────────────────────

@Suite("reachableStates — transitive closure")
struct ReachableStatesTransitiveTests {

    @Test func nfaReachabilityFollowsMultipleHops() {
        // 0 -a-> 1 -b-> 2 -c-> 3   (chain of 3 hops)
        // 9 -z-> 10                (disconnected island; must NOT be reachable from 0)
        let nfa = NFSA(
            initial: 0,
            finals: [3],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 2),
                Transition(from: 2, AlphabetRange.char("c"), to: 3),
                Transition(from: 9, AlphabetRange.char("z"), to: 10),
            ]
        )
        let reachable = nfa.reachableStates(from: 0)
        #expect(reachable == Set([0, 1, 2, 3]), "must include every hop transitively, not just the first")
        #expect(!reachable.contains(9))
        #expect(!reachable.contains(10))
    }

    @Test func dfaReachabilityFollowsMultipleHops() {
        let dfa = DFSA(
            initial: 0,
            finals: [4],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 2),
                Transition(from: 2, AlphabetRange.char("c"), to: 3),
                Transition(from: 3, AlphabetRange.char("d"), to: 4),
                Transition(from: 8, AlphabetRange.char("z"), to: 9),
            ]
        )
        let reachable = dfa.reachableStates(from: 0)
        #expect(reachable == Set([0, 1, 2, 3, 4]))
        #expect(!reachable.contains(8))
        #expect(!reachable.contains(9))
    }

    @Test func reachabilityHandlesCyclesWithoutLooping() {
        // 0 -a-> 1 -b-> 0  (cycle) plus 1 -c-> 2 (final, off the cycle)
        let nfa = NFSA(
            initial: 0,
            finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 1, AlphabetRange.char("b"), to: 0),
                Transition(from: 1, AlphabetRange.char("c"), to: 2),
            ]
        )
        let reachable = nfa.reachableStates(from: 0)
        #expect(reachable == Set([0, 1, 2]))
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Transition.inAlphabet — epsilon must never match a real character
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Transition.inAlphabet — epsilon handling")
struct TransitionEpsilonHandlingTests {

    @Test func epsilonTransitionMatchesNoSingleCharacter() {
        let eps = Transition(from: 0, AlphabetRange.epsilon, to: 1)
        #expect(eps.inAlphabet(char: "a") == false)
        #expect(eps.inAlphabet(char: "\0") == false)
    }

    @Test func epsilonTransitionMatchesNoCharacterRange() {
        let eps = Transition(from: 0, AlphabetRange.epsilon, to: 1)
        #expect(eps.inAlphabet("a", "z") == false)
    }

    @Test func charAndRangeTransitionsStillMatchNormally() {
        let charT  = Transition(from: 0, AlphabetRange.char("x"), to: 1)
        let rangeT = Transition(from: 0, AlphabetRange.range("a", "f"), to: 1)
        #expect(charT.inAlphabet(char: "x") == true)
        #expect(charT.inAlphabet(char: "y") == false)
        #expect(rangeT.inAlphabet(char: "c") == true)
        #expect(rangeT.inAlphabet(char: "z") == false)
    }
}
