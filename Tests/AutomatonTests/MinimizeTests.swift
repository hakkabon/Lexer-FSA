// MinimizeTests.swift
// Tests for the token-class-aware Hopcroft minimization in Minimize.swift.
//
// Prior to this file, `minimize()` had NO test coverage anywhere in the
// package, despite being the newest, most algorithmically delicate piece
// of the token-tracking feature (README calls it "in progress").
//
// Coverage areas:
//  1. Plain structural minimization (merging language-equivalent states)
//  2. Token-class partitioning prevents merging states with DIFFERENT token classes
//  3. Token-class partitioning still allows merging states with the SAME token class
//  4. A realistic keyword-vs-identifier conflict (the classic scanner example)
//  5. A regression test for a previously-known minimization bug, now fixed (see below)

import Testing
@testable import LexerFSA


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 1. Same-token-class states ARE merged
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Minimize — Token-Aware Merging")
struct MinimizeTokenAwareMergingTests {

    @Test func sameTokenClassEquivalentStatesAreMerged() {
        // 0 -'a'-> 1 (final, tok)
        // 0 -'b'-> 2 (final, tok)
        // States 1 and 2 are language-equivalent (both accepting dead ends)
        // AND carry the *same* TokenClass, so they should be merged into one.
        let tok = TokenClass(id: 1, name: "PUNCT", priority: 1)
        var dfa = DFSA(
            initial: 0,
            finals: [1, 2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 0, AlphabetRange.char("b"), to: 2),
            ]
        )
        dfa.state.setTokenMap([1: tok, 2: tok])

        #expect(dfa.stateCount == 3, "sanity check before minimizing")

        dfa.minimize()

        #expect(dfa.isMinimal == true)
        #expect(dfa.stateCount == 2, "states 1 and 2 should have merged")
        #expect(dfa.state.recognizeWithToken(string: "a") == tok)
        #expect(dfa.state.recognizeWithToken(string: "b") == tok)
    }

    @Test func distinctTokenClassesPreventMerging() {
        // Structurally identical to the test above, EXCEPT the two final
        // states carry two *different* token classes. A token-unaware
        // minimizer would merge them (they are language-equivalent); the
        // token-aware extension must keep them separate, or a multi-pattern
        // lexer would lose the ability to tell which pattern matched.
        let tokA = TokenClass(id: 1, name: "PLUS",  priority: 1)
        let tokB = TokenClass(id: 2, name: "MINUS", priority: 1)
        var dfa = DFSA(
            initial: 0,
            finals: [1, 2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("+"), to: 1),
                Transition(from: 0, AlphabetRange.char("-"), to: 2),
            ]
        )
        dfa.state.setTokenMap([1: tokA, 2: tokB])

        dfa.minimize()

        #expect(dfa.isMinimal == true)
        #expect(dfa.stateCount == 3, "differently-tagged states must NOT merge")
        #expect(dfa.state.recognizeWithToken(string: "+") == tokA)
        #expect(dfa.state.recognizeWithToken(string: "-") == tokB)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 2. Realistic multi-pattern lexer scenario: keyword vs. identifier
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Minimize — Keyword vs. Identifier (Dragon Book conflict)")
struct MinimizeKeywordIdentifierTests {

    /// Builds the determinized, token-tagged DFA for the classic
    /// `"if"` (KEYWORD, priority 1) vs. `[a-z]+` (IDENTIFIER, priority 10)
    /// scanner conflict, *without* relying on the broken `Automaton.union`.
    ///
    /// NFA shape (states chosen to be obviously disjoint by construction,
    /// not by relying on `Counter.shared`):
    ///   0 --ε--> 1 --'i'--> 2 --'f'--> 3 (final, KEYWORD)
    ///   0 --ε--> 4 --[a-z]--> 5 (final, IDENTIFIER), 5 --[a-z]--> 5
    func buildKeywordVsIdentifierDFA() -> DFSA {
        let keyword    = TokenClass(id: 1, name: "KEYWORD",    priority: 1)
        let identifier = TokenClass(id: 2, name: "IDENTIFIER", priority: 10)

        var state: State<NFSA> = .nfa(
            initial: 0,
            finals: [3, 5],
            transitions: [
                Transition(from: 0, AlphabetRange.epsilon, to: 1),
                Transition(from: 0, AlphabetRange.epsilon, to: 4),
                Transition(from: 1, AlphabetRange.char("i"), to: 2),
                Transition(from: 2, AlphabetRange.char("f"), to: 3),
                Transition(from: 4, AlphabetRange.range("a", "z"), to: 5),
                Transition(from: 5, AlphabetRange.range("a", "z"), to: 5),
            ],
            tokenMap: [3: keyword, 5: identifier]
        )
        state.determinize()

        // `determinize()` mutates the SAME value into a `.dfa` payload, but
        // the static type is still `State<NFSA>` — `minimize()` only exists
        // on `State<DFSA>` / `DFSA`. This manual re-wrap is the "type-juggling
        // tax" called out in the review write-up: the very same runtime data
        // has to be repackaged under a different nominal type before the next
        // pipeline stage is even callable.
        guard case let .dfa(initial, finals, transitions, _, tokenMap) = state else {
            fatalError("determinize() did not produce a .dfa payload")
        }
        var dfa = DFSA(initial: initial, finals: finals, transitions: transitions)
        dfa.state.setTokenMap(tokenMap)
        return dfa
    }

    @Test func determinizationAloneResolvesTheKeywordConflict() {
        let dfa = buildKeywordVsIdentifierDFA()
        #expect(dfa.state.recognizeWithToken(string: "if") == TokenClass(id: 1, name: "KEYWORD", priority: 1))
        #expect(dfa.state.recognizeWithToken(string: "i")  == TokenClass(id: 2, name: "IDENTIFIER", priority: 10))
        #expect(dfa.state.recognizeWithToken(string: "iff") == TokenClass(id: 2, name: "IDENTIFIER", priority: 10))
        #expect(dfa.state.recognizeWithToken(string: "ifx") == TokenClass(id: 2, name: "IDENTIFIER", priority: 10))
    }

    @Test func minimizeDoesNotCollapseTheKeywordDistinction() {
        // After determinization there are 4 reachable DFA states. The state
        // reached by exactly "if" (tagged KEYWORD) is *language-equivalent*
        // to the "matched ≥1 identifier letters" state (tagged IDENTIFIER):
        // from either one, every continuation is accepted forever, so a
        // plain, token-unaware Hopcroft minimizer would merge them — which
        // would silently destroy the ability to recognize "if" as a keyword
        // at all. The token-aware partitioning must keep them apart.
        var dfa = buildKeywordVsIdentifierDFA()
        let beforeCount = dfa.stateCount
        #expect(beforeCount == 4)

        dfa.minimize()

        // No collapsing across the KEYWORD/IDENTIFIER boundary is expected
        // here — see write-up: this is intentional, not a missed optimization.
        #expect(dfa.stateCount == 4)
        #expect(dfa.isMinimal == true)

        #expect(dfa.state.recognizeWithToken(string: "if")  == TokenClass(id: 1, name: "KEYWORD", priority: 1))
        #expect(dfa.state.recognizeWithToken(string: "i")   == TokenClass(id: 2, name: "IDENTIFIER", priority: 10))
        #expect(dfa.state.recognizeWithToken(string: "iff") == TokenClass(id: 2, name: "IDENTIFIER", priority: 10))
        #expect(dfa.state.recognizeWithToken(string: "ifx") == TokenClass(id: 2, name: "IDENTIFIER", priority: 10))
        #expect(dfa.state.recognizeWithToken(string: "xyz") == nil)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Regression: untagged accepting states ARE merged when equivalent
// ──────────────────────────────────────────────────────────────────────────────

@Suite("Minimize — Regression Tests")
struct MinimizeKnownIssueTests {

    /// FIXED: `Minimize.swift` used to put every accepting state *without* a
    /// `TokenClass` into its own singleton partition block:
    ///
    ///     } else {
    ///         partitions.insert([s])   // one block PER untagged state
    ///     }
    ///
    /// Hopcroft's algorithm only ever splits blocks, never merges them, so
    /// two ordinary, language-equivalent, untagged accepting states could
    /// never be merged -- i.e. plain (non-lexer) DFA minimization was
    /// effectively a no-op for accepting states.
    ///
    /// The fix groups all untagged accepting states into ONE shared initial
    /// block, mirroring how non-accepting states are already handled, so
    /// refinement can still split them apart when they're genuinely
    /// distinguishable, but is free to leave them merged when they're not.
    @Test func equivalentAcceptingStatesWithoutTokenClassesAreMerged() {
        // DFA for `a|b`: states 1 and 2 are both accepting dead ends with
        // no TokenClass tagged at all — textbook-minimal merges them.
        var dfa = DFSA(
            initial: 0,
            finals: [1, 2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("a"), to: 1),
                Transition(from: 0, AlphabetRange.char("b"), to: 2),
            ]
        )

        dfa.minimize()

        // Mathematically minimal is 2 states (0, and merged {1,2}).
        #expect(dfa.stateCount == 2)
        #expect(dfa.isMinimal == true)

        // Recognition still works correctly post-minimization.
        #expect(dfa.run(string: "a") == true)
        #expect(dfa.run(string: "b") == true)
        #expect(dfa.run(string: "c") == false)
    }

    /// Sanity check that `minimize()` is a safe no-op when the runtime
    /// payload is `.nfa` — exercising the documented guard directly. Note
    /// this is only reachable at all because `State<T>`'s cases are public
    /// regardless of `T` (see write-up §B): nothing prevents constructing
    /// an `.nfa` payload inside a nominally-`DFSA`-typed value.
    @Test func minimizeIsNoOpOnNfaPayload() {
        var dfa = DFSA(initial: 0, finals: [1], transitions: [
            Transition(from: 0, AlphabetRange.char("a"), to: 1),
        ])
        // Forcibly install an `.nfa` payload despite the nominal DFSA type —
        // this is exactly the loophole described in the write-up.
        dfa.state = State<DFSA>.nfa(initial: 0, finals: [1], transitions: [
            Transition(from: 0, AlphabetRange.char("a"), to: 1),
        ], tokenMap: [:])

        dfa.minimize()

        // The guard `guard case .dfa(...) = state else { return }` should
        // make this a no-op rather than crash or silently corrupt state.
        #expect(dfa.isDeterministic == false, "payload is still .nfa — minimize() must not have touched it")
    }
}
