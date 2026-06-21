// LexerPipelineTests.swift
// End-to-end exercise of the token-tracking feature as a multi-pattern
// lexer pipeline: several regular languages, each tagged with its own
// TokenClass, merged into one NFA, determinized, and queried.
//
// `Automaton<Type>.union(list:)` is a non-functional stub (see write-up),
// and `Regex` never threads a token map through its construction, so this
// suite builds the union manually — with deliberately disjoint, hand-picked
// state numbers (not `Counter.shared`) — to demonstrate the underlying FSA
// primitives correctly support the workflow the package is meant for, even
// though no public API currently assembles it for you.
//
// Coverage areas:
//  1. Three-pattern union (KEYWORD / IDENTIFIER / NUMBER) — priority resolution
//  2. The missing "scan a longer buffer into a token stream" capability

import Testing
@testable import LexerFSA


@Suite("Multi-Pattern Lexer Pipeline")
struct LexerPipelineTests {

    let keyword    = TokenClass(id: 1, name: "KEYWORD",    priority: 1)
    let identifier = TokenClass(id: 2, name: "IDENTIFIER", priority: 10)
    let number     = TokenClass(id: 3, name: "NUMBER",     priority: 5)

    /// Manually-unioned, token-tagged NFA for:
    ///   KEYWORD     "if"      (priority 1, wins ties)
    ///   IDENTIFIER  [a-z]+    (priority 10)
    ///   NUMBER      [0-9]+    (priority 5)
    ///
    /// State layout (disjoint by construction):
    ///   0 --ε--> 1 --'i'--> 2 --'f'--> 3            (final: KEYWORD)
    ///   0 --ε--> 4 --[a-z]--> 5 --[a-z]--> 5         (final: IDENTIFIER)
    ///   0 --ε--> 6 --[0-9]--> 7 --[0-9]--> 7         (final: NUMBER)
    func buildMergedLexerState() -> State<NFSA> {
        var state: State<NFSA> = .nfa(
            initial: 0,
            finals: [3, 5, 7],
            transitions: [
                Transition(from: 0, AlphabetRange.epsilon, to: 1),
                Transition(from: 0, AlphabetRange.epsilon, to: 4),
                Transition(from: 0, AlphabetRange.epsilon, to: 6),

                Transition(from: 1, AlphabetRange.char("i"), to: 2),
                Transition(from: 2, AlphabetRange.char("f"), to: 3),

                Transition(from: 4, AlphabetRange.range("a", "z"), to: 5),
                Transition(from: 5, AlphabetRange.range("a", "z"), to: 5),

                Transition(from: 6, AlphabetRange.range("0", "9"), to: 7),
                Transition(from: 7, AlphabetRange.range("0", "9"), to: 7),
            ],
            tokenMap: [3: keyword, 5: identifier, 7: number]
        )
        state.determinize()
        return state
    }

    @Test func keywordWinsOverIdentifierOnExactMatch() {
        let state = buildMergedLexerState()
        #expect(state.recognizeWithToken(string: "if") == keyword)
    }

    @Test func longerIdentifierIsNotMisclassifiedAsKeyword() {
        let state = buildMergedLexerState()
        #expect(state.recognizeWithToken(string: "iffy") == identifier)
        #expect(state.recognizeWithToken(string: "ifx") == identifier)
    }

    @Test func numberPatternMatchesIndependently() {
        let state = buildMergedLexerState()
        #expect(state.recognizeWithToken(string: "123") == number)
        #expect(state.recognizeWithToken(string: "0") == number)
    }

    @Test func emptyAndUnmatchedInputReturnNil() {
        let state = buildMergedLexerState()
        #expect(state.recognizeWithToken(string: "") == nil)
        #expect(state.recognizeWithToken(string: "_") == nil)
        #expect(state.recognizeWithToken(string: "12a") == nil)
    }

    /// This is the concrete demonstration of the gap described in the
    /// write-up (§G): `recognizeWithToken` can only classify a string that
    /// matches ONE compiled pattern *in its entirety*. A real lexer scanning
    /// a source buffer needs to split "if123" into the two tokens `if` and
    /// `123` via repeated longest-match-from-current-position; there is no
    /// API in this package that does that — the merged automaton correctly
    /// rejects the whole string instead, because no single pattern matches
    /// "if123" end to end.
    @Test func wholeStringRecognitionCannotSplitTwoAdjacentTokens() {
        let state = buildMergedLexerState()
        #expect(state.recognizeWithToken(string: "if123") == nil)
        #expect(state.recognizeWithToken(string: "x99") == nil)
    }
}


// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Ready to enable once `Automaton.union(list:)` and `Regex` token
//          threading are fixed (mirrors the existing #if false convention
//          in AutomatonTests.swift's `testRegexUnion`).
// ──────────────────────────────────────────────────────────────────────────────

#if false

@Test
func testRegexUnionWithTokenClasses() async throws {
    let identTok = TokenClass(id: 1, name: "IDENTIFIER", priority: 10)
    let numTok   = TokenClass(id: 2, name: "NUMBER",     priority: 5)

    var identifier = try Regex("[a-zA-Z]+")
    var num        = try Regex("[0-9]+")
    // Intended API: tag each compiled pattern with its token class before
    // unioning, and have the union/determinize pipeline propagate it.
    identifier.state.setTokenMap([identifier.state.finals.first!: identTok])
    num.state.setTokenMap([num.state.finals.first!: numTok])

    var automaton = Automaton.union(list: [Automaton(identifier), Automaton(num)])
    automaton.isDeterministic = true
    automaton.minimize()

    #expect(automaton.state.recognizeWithToken(string: "abba") == identTok)
    #expect(automaton.state.recognizeWithToken(string: "123") == numTok)
}

#endif
