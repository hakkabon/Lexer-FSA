import Testing
@testable import LexerFSA

// NFA/DFA union with token-class tracking, and the realistic "parser
// front-end" use case those operations exist for. Originally written
// against the `Automaton<Type>` container, which has since been removed —
// `NFSA`/`DFSA` are used directly (NFSA.union/DFSA.union mirror the old
// Automaton<Type>.union API), and the parser-facing use case at the bottom
// is now demonstrated via `LexerBuilder` rather than `Automaton<Regex>`.

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - NFA Union with Token Tracking (§3.3)
// ──────────────────────────────────────────────────────────────────────────────

@Suite("NFA Union with Token Tracking")
struct NFAUnionTests {

    /// Two trivial NFAs, one for "a" tagged A and one for "b" tagged B,
    /// unioned and queried via `recognizeWithToken`.
    @Test func unionOfTwoNFAsAcceptsBothLanguages() {
        let tokA = TokenClass(id: 1, name: "A", priority: 1)
        let tokB = TokenClass(id: 2, name: "B", priority: 1)

        // "a"
        let a = NFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)],
            tokenMap: [1: tokA])
        // "b"
        let b = NFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("b"), to: 1)],
            tokenMap: [1: tokB])

        let u = NFSA.union(a, b)

        #expect(u.run(string: "a") == true)
        #expect(u.run(string: "b") == true)
        #expect(u.run(string: "c") == false)
        #expect(u.run(string: "ab") == false)

        #expect(u.recognizeWithToken(string: "a") == tokA)
        #expect(u.recognizeWithToken(string: "b") == tokB)
        #expect(u.recognizeWithToken(string: "c") == nil)
    }

    @Test func unionOfListPreservesAllTokenClasses() {
        let kw   = TokenClass(id: 1, name: "KW",   priority: 1)
        let ident = TokenClass(id: 2, name: "IDENT", priority: 10)

        // NFA for "if"
        let ifNfa = NFSA(
            initial: 0, finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("i"), to: 1),
                Transition(from: 1, AlphabetRange.char("f"), to: 2),
            ],
            tokenMap: [2: kw])
        // NFA for [a-z]+  (just "a"-"z" then a self-loop on the final)
        let identNfa = NFSA(
            initial: 0, finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.range("a","z"), to: 1),
                Transition(from: 1, AlphabetRange.range("a","z"), to: 1),
            ],
            tokenMap: [1: ident])

        let u = NFSA.union([ifNfa, identNfa])

        // Both patterns accept; "if" is ambiguous and the lower-priority
        // (priority=1) keyword should win after determinization. Here we
        // are still on the NFA, so recognizeWithToken uses the NFA's
        // highest-priority resolution among active accepting states.
        #expect(u.run(string: "if") == true)
        #expect(u.run(string: "abc") == true)
        #expect(u.run(string: "123") == false)

        // The NFA path should still resolve "if" to KW (lower priority integer).
        let r = u.recognizeWithToken(string: "if")
        #expect(r == kw)
        // And a plain identifier should resolve to IDENT.
        #expect(u.recognizeWithToken(string: "abc") == ident)
    }

    @Test func unionIsReproducibleAcrossCalls() {
        // Building the same union twice must produce identical state-id
        // assignments, since the union now uses a local counter rather
        // than the global Counter.shared singleton.
        let a = NFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)])
        let b = NFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("b"), to: 1)])

        let u1 = NFSA.union(a, b)
        let u2 = NFSA.union(a, b)
        // the order of output differs, otherwise same data
        #expect(u1.description == u2.description)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - DFA Union (delegates to NFA union + determinize)
// ──────────────────────────────────────────────────────────────────────────────

@Suite("DFA Union (via NFA + determinize)")
struct DFAUnionTests {

    @Test func unionOfTwoDFAsAcceptsBothLanguages() {
        let tokA = TokenClass(id: 1, name: "A", priority: 1)
        let tokB = TokenClass(id: 2, name: "B", priority: 1)

        let a = DFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)],
            minimal: false, tokenMap: [1: tokA])
        let b = DFSA(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("b"), to: 1)],
            minimal: false, tokenMap: [1: tokB])

        let u = DFSA.union(a, b)

        #expect(u.run(string: "a") == true)
        #expect(u.run(string: "b") == true)
        #expect(u.run(string: "c") == false)

        // After determinize, the union DFA's token map should still resolve.
        #expect(u.recognizeWithToken(string: "a") == tokA)
        #expect(u.recognizeWithToken(string: "b") == tokB)
        #expect(u.recognizeWithToken(string: "c") == nil)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - The Realistic Parser-Frontend Use Case
// ──────────────────────────────────────────────────────────────────────────────
//
// This is how a parser actually assembles a multi-pattern lexer: register
// each token's pattern with a `LexerBuilder`, then `build()` once. The old
// version of this test built the equivalent by hand with
// `Automaton<Regex>` and explicitly called out, in a trailing comment, that
// there was no way to identify *which* pattern matched without "fancy
// book-keeping over the final states" — that gap is exactly what
// `TokenClass`/`recognizeWithToken` below close.

@Test
func testRegexUnion() async throws {
    let stringTok = TokenClass(id: 1, name: "STRING", priority: 10)
    let numTok    = TokenClass(id: 2, name: "NUM",    priority: 10)
    let floatTok  = TokenClass(id: 3, name: "FLOAT",  priority: 5)

    let STRING = "[a-zA-Z]+"
    let NUM = "[+-]?([0-9])+"
    let FLOAT = "[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?"

    var builder = LexerBuilder()
    builder.addRule(pattern: STRING, token: stringTok)
    builder.addRule(pattern: NUM, token: numTok)
    builder.addRule(pattern: FLOAT, token: floatTok)
    let lexer = try builder.build()

    #expect(lexer.dfa.run(string: "abba"), "valid lexeme 'abba'")
    #expect(lexer.dfa.run(string: "123456"), "valid lexeme '123456'")
    #expect(lexer.dfa.run(string: "123.45"), "valid lexeme '123.45'")
    #expect(lexer.dfa.run(string: "-0.123e-6"), "valid lexeme '-0.123e-6'")

    // Unambiguous lexemes resolve to their expected token class with no
    // extra bookkeeping required from the caller.
    #expect(lexer.dfa.recognizeWithToken(string: "abba") == stringTok)
    #expect(lexer.dfa.recognizeWithToken(string: "123.45") == floatTok)
    #expect(lexer.dfa.recognizeWithToken(string: "-0.123e-6") == floatTok)
    // "123456" is ambiguous between NUM and FLOAT (FLOAT's fractional and
    // exponent parts are both optional); FLOAT's lower priority integer
    // wins the determinizer's conflict resolution.
    #expect(lexer.dfa.recognizeWithToken(string: "123456") == floatTok)
}
