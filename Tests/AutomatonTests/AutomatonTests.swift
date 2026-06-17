import Testing
@testable import Automaton


// Create use-cases for unions minimize on/off with marker overlapping
// Create use-cases for merge conflicts and conflict resolving

@Test
func testFloatLexemes() async throws {
    let FLOAT = "[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?";
    var automaton = Automaton(try Regex(FLOAT))
    
    // minimizing is optional
//    automaton.minimize()
    
    #expect(automaton.recognize(string: "123456"), "valid lexeme '123456'")
    #expect(automaton.recognize(string: "123.45"), "valid lexeme '123.45'")
    #expect(automaton.recognize(string: "-0.123e-6"), "valid lexeme '-0.123e-6'")
}

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
        let a = Automaton<NFSA>(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)],
            tokenMap: [1: tokA])
        // "b"
        let b = Automaton<NFSA>(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("b"), to: 1)],
            tokenMap: [1: tokB])

        let u = Automaton<NFSA>.union(a: a, b: b)

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
        let ifNfa = Automaton<NFSA>(
            initial: 0, finals: [2],
            transitions: [
                Transition(from: 0, AlphabetRange.char("i"), to: 1),
                Transition(from: 1, AlphabetRange.char("f"), to: 2),
            ],
            tokenMap: [2: kw])
        // NFA for [a-z]+  (just "a"-"z" then a self-loop on the final)
        let identNfa = Automaton<NFSA>(
            initial: 0, finals: [1],
            transitions: [
                Transition(from: 0, AlphabetRange.range("a","z"), to: 1),
                Transition(from: 1, AlphabetRange.range("a","z"), to: 1),
            ],
            tokenMap: [1: ident])

        let u = Automaton<NFSA>.union(list: [ifNfa, identNfa])

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
        let a = Automaton<NFSA>(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)])
        let b = Automaton<NFSA>(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("b"), to: 1)])

        let u1 = Automaton<NFSA>.union(a: a, b: b)
        let u2 = Automaton<NFSA>.union(a: a, b: b)
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

        let a = Automaton<DFSA>(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("a"), to: 1)],
            minimal: false, tokenMap: [1: tokA])
        let b = Automaton<DFSA>(
            initial: 0, finals: [1],
            transitions: [Transition(from: 0, AlphabetRange.char("b"), to: 1)],
            minimal: false, tokenMap: [1: tokB])

        let u = Automaton<DFSA>.union(a: a, b: b)

        #expect(u.run(string: "a") == true)
        #expect(u.run(string: "b") == true)
        #expect(u.run(string: "c") == false)

        // After determinize, the union DFA's token map should still resolve.
        #expect(u.recognizeWithToken(string: "a") == tokA)
        #expect(u.recognizeWithToken(string: "b") == tokB)
        #expect(u.recognizeWithToken(string: "c") == nil)
    }
}

// Important use-case: This how the parser uses the Automaton.

#if false

@Test
func testRegexUnion() async throws {
    // Define token classes for the automaton.
    let STRING = "[a-zA-Z]+"
    let NUM = "[+-]?([0-9])+"
    let FLOAT = "[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?";
    
    var list: [Automaton<Regex>] = []
    // Adding tags per regex not possible, ie. .mark(1) .mark(2) .mark(3).
    list.append( Automaton(try Regex(STRING)) )
    list.append( Automaton(try Regex(NUM)) )
    list.append( Automaton(try Regex(FLOAT)) )
    let automaton = Automaton.union(list: list)

    // Determinize is optional.
    automaton.isDeterminized = true

    // Minimizing is optional.
    automaton.minimize()

    // This executes as expected.
    #expect(automaton.recognize(string: "abba"), "valid lexeme 'abba'");
    #expect(automaton.recognize(string: "123456"), "valid lexeme '123456'");
    #expect(automaton.recognize(string: "123.45"), "valid lexeme '123.45'");
    #expect(automaton.recognize(string: "-0.123e-6"), "valid lexeme '-0.123e-6'");
    
    // But how-to identify the token class recognized without doing some fancy
    // book-keeping over the final states in the Finite State Automaton.
}

#endif
