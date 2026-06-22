import Testing
@testable import LexerFSA

//  Test suite for the Antimirov partial-derivative construction
//  (Antimirov.swift, PartialDerivative.swift) and the Brzozowski
//  double-reversal minimization it uses (BrzozowskiMinimize.swift).
//
//  Organised in four layers, mirroring RegexNodeTests.swift's structure for
//  the Berry-Sethi redesign:
//
//    1. Unit tests of `nullable` and `partialDerivative` against hand-built
//       `Expression` values — no parser, no `Regex`, no DFA.
//    2. Unit tests of `reverseAutomaton` / `brzozowskiMinimize` against a
//       hand-built automaton with known redundant states.
//    3. End-to-end tests through the public `Regex(..., method: .derivative)`
//       API, covering every `Expression` variant.
//    4. Cross-checks against the other two construction methods (Thompson,
//       BerrySethi) — same language, every input agrees — and a state-count
//       comparison against the pre-existing Hopcroft minimization
//       (`DFSA.minimize()`): two different algorithms computing minimal-ish
//       DFAs for the same language should never have Antimirov's true
//       minimum exceed Hopcroft's result (see the comment on
//       `antimirovStateCountNeverExceedsHopcroftMinimizedBerrySethi` for why
//       that's an inequality, not an equality, in this codebase).
//

// MARK: - Helpers

/// Returns true if the given regex (built with Antimirov) accepts `s`.
private func am(_ pattern: String, accepts s: String, flags: SyntaxOptions = .basic) throws -> Bool {
    let r = try Regex(pattern, method: .derivative, flags: flags)
    return r.recognize(string: s)
}

/// Returns true if the given regex (built with Berry-Sethi) accepts `s`,
/// used as a reference oracle (see BerrySethiTests.swift).
private func bs(_ pattern: String, accepts s: String, flags: SyntaxOptions = .basic) throws -> Bool {
    let r = try Regex(pattern, method: .berrySethi, flags: flags)
    return r.recognize(string: s)
}

/// Returns true if the given regex (built with Thompson + powerset) accepts `s`.
private func th(_ pattern: String, accepts s: String, flags: SyntaxOptions = .basic) throws -> Bool {
    var r = try Regex(pattern, method: .thompson, flags: flags)
    r.isDeterministic = true
    return r.recognize(string: s)
}

/// Number of distinct states in `r`'s current automaton (NFA or DFA alike).
private func stateCount(of r: Regex) -> Int {
    switch r.state {
    case let .nfa(initial, _, transitions, _):
        return transitions.states().union([initial]).count
    case let .dfa(initial, _, transitions, _, _):
        return transitions.states().union([initial]).count
    }
}

/// Hopcroft-minimizes a copy of `r`'s automaton via `DFSA.minimize()`
/// (Minimize.swift) and returns its state count, as an independent
/// minimization oracle to compare against Antimirov's Brzozowski
/// minimization. Returns `nil` if `r`'s automaton isn't a DFA.
private func hopcroftMinimizedStateCount(of r: Regex) -> Int? {
    guard case let .dfa(initial, finals, transitions, _, _) = r.state else { return nil }
    var dfsa = DFSA(initial: initial, finals: finals, transitions: transitions)
    dfsa.minimize()
    guard case let .dfa(i2, _, t2, _, _) = dfsa.state else { return nil }
    return t2.states().union([i2]).count
}

// MARK: - 1. nullable — hand-built Expression trees

@Test func nullableLeafCases() {
    #expect(!nullable(.empty))             // the empty language
    #expect(nullable(.string("")))         // ε
    #expect(!nullable(.string("a")))
    #expect(!nullable(.char("a")))
    #expect(!nullable(.charRange("a", "z")))
    #expect(!nullable(.anyChar))
    #expect(nullable(.anyString))
}

@Test func nullableStructuralCases() {
    #expect(nullable(.union(.char("a"), .string(""))))
    #expect(!nullable(.union(.char("a"), .char("b"))))
    #expect(nullable(.concatenation(.string(""), .string(""))))
    #expect(!nullable(.concatenation(.char("a"), .string(""))))
    #expect(nullable(.optional(.char("a"))))
    #expect(nullable(.repeat(.char("a"))))
}

@Test func nullableRepeatMinDefersToNullabilityOfOperand() {
    // a{2,} is not nullable (a isn't)...
    #expect(!nullable(.repeatMin(.char("a"), 2)))
    // ...but (a?){2,} IS nullable, because each of the 2 mandatory copies
    // can itself match ε. This is exactly the case a naive "nullable iff
    // n == 0" rule gets wrong — see the comment on `nullable` in
    // PartialDerivative.swift.
    #expect(nullable(.repeatMin(.optional(.char("a")), 2)))
}

@Test func nullableRepeatMinMaxDefersToNullabilityOfOperand() {
    #expect(nullable(.repeatMinMax(.char("a"), 0, 3)))               // n == 0
    #expect(!nullable(.repeatMinMax(.char("a"), 2, 3)))              // n > 0, a not nullable
    #expect(nullable(.repeatMinMax(.optional(.char("a")), 2, 3)))    // n > 0, but operand nullable
}

@Test func nullableIntervalIsNeverNullable() {
    // Every expansion of an interval is at least one decimal digit long.
    #expect(!nullable(.interval(0, 9, 0)))
    #expect(!nullable(.interval(0, 0, 0)))
}

// MARK: - 2. partialDerivative — hand-built Expression trees

@Test func partialDerivativeOfDeadEndsIsEmpty() {
    #expect(partialDerivative(.empty, withRespectTo: "a").isEmpty)
    #expect(partialDerivative(.string(""), withRespectTo: "a").isEmpty)
    #expect(partialDerivative(.char("a"), withRespectTo: "b").isEmpty)
}

@Test func partialDerivativeOfMatchingCharIsEpsilon() {
    #expect(partialDerivative(.char("a"), withRespectTo: "a") == [.string("")])
}

@Test func partialDerivativeOfCharRange() {
    let range = Expression.charRange("a", "z")
    #expect(partialDerivative(range, withRespectTo: "m") == [.string("")])
    #expect(partialDerivative(range, withRespectTo: "M").isEmpty)
}

@Test func partialDerivativeOfAnyCharIsAlwaysEpsilon() {
    #expect(partialDerivative(.anyChar, withRespectTo: "x") == [.string("")])
    #expect(partialDerivative(.anyChar, withRespectTo: "!") == [.string("")])
}

@Test func partialDerivativeOfStringPeelsOneCharacter() {
    #expect(partialDerivative(.string("abc"), withRespectTo: "a") == [.string("bc")])
    #expect(partialDerivative(.string("abc"), withRespectTo: "b").isEmpty)
}

@Test func partialDerivativeOfUnionIsUnionOfDerivatives() {
    let e = Expression.union(.char("a"), .char("b"))
    #expect(partialDerivative(e, withRespectTo: "a") == [.string("")])
    #expect(partialDerivative(e, withRespectTo: "b") == [.string("")])
    #expect(partialDerivative(e, withRespectTo: "c").isEmpty)
}

@Test func partialDerivativeOfOptionalMatchesItsOperand() {
    let e = Expression.optional(.char("a"))
    #expect(partialDerivative(e, withRespectTo: "a") == partialDerivative(.char("a"), withRespectTo: "a"))
}

@Test func partialDerivativeOfConcatenationStaysOnLeftWhileItIsMandatory() {
    // "ab": derivative w.r.t. 'a' leaves "b" to match; w.r.t. anything else, dead.
    let e = Expression.concatenation(.char("a"), .char("b"))
    #expect(partialDerivative(e, withRespectTo: "a") == [.string("b")])
    #expect(partialDerivative(e, withRespectTo: "b").isEmpty)
}

@Test func partialDerivativeOfConcatenationFallsThroughWhenLeftIsNullable() {
    // "a?b": derivative w.r.t. 'b' must also reach past the optional "a?".
    let e = Expression.concatenation(.optional(.char("a")), .char("b"))
    #expect(partialDerivative(e, withRespectTo: "b").contains(.string("")))
}

@Test func partialDerivativeOfStarReintroducesTheUnderivedStar() {
    // ∂(a*)/∂a = { a* }, with the *original*, un-derived a* as the
    // continuation — that self-reference is the back-edge that makes the
    // star loop.
    let star = Expression.repeat(.char("a"))
    #expect(partialDerivative(star, withRespectTo: "a") == [star])
    #expect(partialDerivative(star, withRespectTo: "b").isEmpty)
}

@Test func partialDerivativeNeverReturnsADeadEmptyLanguageTerm() {
    // By convention (see PartialDerivative.swift) a derivative that "goes
    // nowhere" is the *absence* of a term, never a literal `.empty` member.
    for e: Expression in [.empty, .char("a"), .string(""), .charRange("a", "z"), .anyChar] {
        for ch: Character in ["a", "z", "!"] {
            #expect(!partialDerivative(e, withRespectTo: ch).contains(.empty))
        }
    }
}

@Test func smartConcatAppliesAlgebraicIdentities() {
    #expect(smartConcat(.empty, .char("a")) == .empty)
    #expect(smartConcat(.char("a"), .empty) == .empty)
    #expect(smartConcat(.string(""), .char("a")) == .char("a"))
    #expect(smartConcat(.char("a"), .string("")) == .char("a"))
    #expect(smartConcat(.char("a"), .char("b")) == .concatenation(.char("a"), .char("b")))
}

@Test func partialDerivativeCanProduceALiteralDeadEmptyTermViaSmartConcat() {
    // "a#" (a, then the empty-language literal): one step through 'a'
    // leaves smartConcat(ε, .empty) == .empty as the *only* candidate
    // continuation — a literal `.empty` member of the returned set. This is
    // exactly the situation `Antimirov`'s construction loop filters back
    // out (`next.filter { $0 != .empty }`) before turning the result into a
    // DFA state; this test is the witness for why that filter exists.
    let e = Expression.concatenation(.char("a"), .empty)
    #expect(partialDerivative(e, withRespectTo: "a") == [.empty])
}

@Test func concreteAlphabetCollectsLiteralCharactersOnly() {
    let e = Expression.union(.char("a"), .concatenation(.char("b"), .string("cd")))
    #expect(concreteAlphabet(of: e) == Set("abcd"))
}

@Test func concreteAlphabetOfIntervalIsDecimalDigits() {
    #expect(concreteAlphabet(of: .interval(0, 999, 0)) == Set("0123456789"))
}

// MARK: - 3. Brzozowski minimization — hand-built automata

@Test func brzozowskiMinimizationCollapsesEquivalentStates() {
    // A DFA for the language {"a", "b"}: states 1 and 2 are reached by
    // different symbols but are themselves behaviourally identical — both
    // accepting, neither with any further outgoing transition, so neither
    // can be distinguished from the other by any continuation of the input.
    // The minimal DFA has exactly 2 states (start, accept); state 2 is
    // redundant with state 1 and must be collapsed into it.
    let transitions: Set<Transition> = [
        Transition(from: 0, .char("a"), to: 1),
        Transition(from: 0, .char("b"), to: 2),
    ]
    let result = brzozowskiMinimize(initial: 0, finals: [1, 2], transitions: transitions)
    let minimizedStateCount = result.transitions.states().union([result.initial]).count
    #expect(minimizedStateCount == 2)
}

@Test func brzozowskiMinimizationOfEmptyLanguageHasOneState() {
    // No final states at all: the minimal DFA accepting the empty language
    // is a single non-accepting state with no transitions.
    let result = brzozowskiMinimize(initial: 0, finals: [], transitions: [])
    #expect(result.finals.isEmpty)
    #expect(result.transitions.isEmpty)
}

@Test func brzozowskiMinimizationOfEmptyStringLanguageHasOneAcceptingState() {
    // A single state that's both initial and accepting: the language { ε }.
    let result = brzozowskiMinimize(initial: 0, finals: [0], transitions: [])
    #expect(result.finals.contains(result.initial))
    #expect(result.transitions.isEmpty)
}

// MARK: - 4. End-to-end, through the public Regex API

@Test func singleCharacter() throws {
    #expect(try am("a", accepts: "a"))
    #expect(try !am("a", accepts: ""))
    #expect(try !am("a", accepts: "b"))
    #expect(try !am("a", accepts: "aa"))
}

@Test func concatenation() throws {
    #expect(try am("ab", accepts: "ab"))
    #expect(try !am("ab", accepts: "a"))
    #expect(try !am("ab", accepts: "ba"))
}

@Test func union() throws {
    #expect(try am("a|b", accepts: "a"))
    #expect(try am("a|b", accepts: "b"))
    #expect(try !am("a|b", accepts: "c"))
}

@Test func star() throws {
    for s in ["", "a", "aa", "aaaa"] { #expect(try am("a*", accepts: s)) }
    #expect(try !am("a*", accepts: "b"))
    #expect(try !am("a*", accepts: "ab"))
}

@Test func optionalEncoding() throws {
    #expect(try am("a?", accepts: ""))
    #expect(try am("a?", accepts: "a"))
    #expect(try !am("a?", accepts: "aa"))
}

@Test func charRange() throws {
    #expect(try am("[a-z]", accepts: "m"))
    #expect(try !am("[a-z]", accepts: "M"))
}

@Test func anyCharMatchesExactlyOneCharacter() throws {
    #expect(try am(".", accepts: "x"))
    #expect(try !am(".", accepts: ""))
    #expect(try !am(".", accepts: "xy"))
}

@Test func anyStringMatchesArbitraryLength() throws {
    for s in ["", "x", "hello world"] { #expect(try am("@", accepts: s)) }
}

@Test func repeatMinAtLeastN() throws {
    #expect(try !am("a{2,}", accepts: "a"))
    #expect(try am("a{2,}", accepts: "aa"))
    #expect(try am("a{2,}", accepts: "aaaa"))
}

@Test func repeatMinMaxBoundedRange() throws {
    #expect(try !am("a{2,3}", accepts: "a"))
    #expect(try am("a{2,3}", accepts: "aa"))
    #expect(try am("a{2,3}", accepts: "aaa"))
    #expect(try !am("a{2,3}", accepts: "aaaa"))
}

@Test func numericInterval() throws {
    #expect(try am("<0-9>", accepts: "5"))
    #expect(try !am("<0-9>", accepts: "10"))
    #expect(try am("<10-12>", accepts: "11"))
}

@Test func classicAhoCatDotStarAbb() throws {
    // (a|b)*abb — the running example throughout BerrySethiTests.swift.
    let pattern = "(a|b)*abb"
    for s in ["abb", "aabb", "babb", "ababb"] { #expect(try am(pattern, accepts: s)) }
    for s in ["", "ab", "abbb", "abab"] { #expect(try !am(pattern, accepts: s)) }
}

@Test func emptyLanguageLiteralMakesConcatenationUnmatchable() throws {
    // '#' is the empty-language literal (enabled by default via
    // SyntaxOptions.basic); concatenating with it must make the whole
    // pattern unmatchable, regardless of what's on either side.
    #expect(try !am("a#b", accepts: ""))
    #expect(try !am("a#b", accepts: "ab"))
    #expect(try !am("a#b", accepts: "a"))

    // "a#" specifically drives the construction loop through the
    // dead-term-filtering step exercised at the unit level by
    // `partialDerivativeCanProduceALiteralDeadEmptyTermViaSmartConcat` above.
    #expect(try !am("a#", accepts: ""))
    #expect(try !am("a#", accepts: "a"))
}

@Test func antimirovExpressionHasNoLeakedSentinel() throws {
    // Unlike BerrySethi (which parses the augmented "pattern#"), Antimirov
    // parses the pattern exactly as written — see "Why no '#' sentinel" in
    // Antimirov.swift.
    var builder = Regex.Antimirov(expression: "ab", flags: .basic)
    let parsed = try builder.construct()
    _ = parsed
    #expect(builder.expression == .concatenation(.char("a"), .char("b")))
}

// MARK: - 5. Cross-checks against Thompson and Berry-Sethi

private let crossCheckPatterns: [(pattern: String, samples: [String])] = [
    ("a", ["", "a", "b", "aa"]),
    ("ab", ["", "a", "ab", "ba", "abc"]),
    ("a|b", ["a", "b", "c", "ab"]),
    ("a*", ["", "a", "aa", "aaa", "b"]),
    ("a?", ["", "a", "aa"]),
    ("(a|b)*abb", ["abb", "aabb", "ababb", "ab", "", "abbb"]),
    ("a{2,3}", ["a", "aa", "aaa", "aaaa"]),
    ("a{2,}", ["a", "aa", "aaaaa"]),
    ("[a-z]", ["a", "m", "z", "A", "0"]),
    (".", ["a", "", "ab"]),
]

@Test func antimirovAgreesWithBerrySethiAndThompson() throws {
    for (pattern, samples) in crossCheckPatterns {
        for s in samples {
            let derivative = try am(pattern, accepts: s)
            let berrySethi = try bs(pattern, accepts: s)
            let thompson = try th(pattern, accepts: s)
            #expect(derivative == berrySethi, "pattern \"\(pattern)\", input \"\(s)\": derivative=\(derivative) berrySethi=\(berrySethi)")
            #expect(derivative == thompson, "pattern \"\(pattern)\", input \"\(s)\": derivative=\(derivative) thompson=\(thompson)")
        }
    }
}

// MARK: - 6. Minimality

@Test func antimirovAlwaysReturnsAMinimalDFA() throws {
    for (pattern, _) in crossCheckPatterns {
        let r = try Regex(pattern, method: .derivative)
        #expect(r.isMinimal, "Antimirov-constructed regex for \"\(pattern)\" should be tagged minimal")
    }
}

@Test func antimirovStateCountNeverExceedsHopcroftMinimizedBerrySethi() throws {
    // Brzozowski's double-reversal algorithm (used internally by Antimirov)
    // always reaches the true Myhill-Nerode minimum for a partial DFA.
    // `DFSA.minimize()` (Hopcroft, pre-existing) is *also* a correct
    // minimizer, but it deliberately keeps every untagged accepting state in
    // its own singleton partition up front — appropriate for its primary use
    // case (a lexer DFA, where each accepting state represents a different
    // token class and must never be merged with another), but it means
    // Hopcroft's result here is not guaranteed to be the *global* minimum
    // for a plain, token-free regex match — only ever a partition refinement
    // of it, which can have the same number of states or more, never fewer.
    // So the only invariant safe to assert across the two is an inequality,
    // not equality: Antimirov's count is always ≤ Hopcroft's.
    for (pattern, _) in crossCheckPatterns {
        let viaAntimirov = try Regex(pattern, method: .derivative)
        let viaBerrySethi = try Regex(pattern, method: .berrySethi)

        let antimirovStateCount = stateCount(of: viaAntimirov)
        guard let berrySethiMinimizedCount = hopcroftMinimizedStateCount(of: viaBerrySethi) else {
            Issue.record("expected a DFA for pattern \"\(pattern)\"")
            continue
        }
        #expect(antimirovStateCount <= berrySethiMinimizedCount,
                "pattern \"\(pattern)\": Antimirov+Brzozowski gave \(antimirovStateCount) states, BerrySethi+Hopcroft gave \(berrySethiMinimizedCount) — Antimirov's true minimum should never be larger")
    }
}
