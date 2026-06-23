//
//  BerrySethiTests.swift
//  AutomatonTests
//
//  Comprehensive test suite for the Berry-Sethi (Glushkov / Direct) DFA
//  construction, verifying correctness of:
//
//    • nullable / firstpos / lastpos / followpos computation
//    • DFA state and transition construction
//    • recognition of strings in the described language
//    • parity with the Thompson construction for the same expressions
//    • all Expression variants (char, charRange, anyChar, string, repeat,
//      optional, repeatMin, repeatMinMax, union, concatenation)
//

import Testing
@testable import LexerFSA

// MARK: - Helper

/// Returns true if the given regex (built with Berry-Sethi) accepts `s`.
private func bs(_ pattern: String, accepts s: String, flags: SyntaxOptions = .basic) throws -> Bool {
    let r = try Regex(pattern, method: .berrySethi, flags: flags)
    return r.recognize(string: s)
}

/// Returns true if the given regex (built with Thompson + powerset) accepts `s`,
/// used as a reference oracle.
private func th(_ pattern: String, accepts s: String, flags: SyntaxOptions = .basic) throws -> Bool {
    var r = try Regex(pattern, method: .thompson, flags: flags)
    r.isDeterministic = true          // convert NFA → DFA
    return r.recognize(string: s)
}

// MARK: - 1. Single-character expressions

@Test func singleCharAccepted() throws {
    #expect(try bs("a", accepts: "a"))
}

@Test func singleCharRejectedEmpty() throws {
    #expect(try !bs("a", accepts: ""))
}

@Test func singleCharRejectedWrong() throws {
    #expect(try !bs("a", accepts: "b"))
}

@Test func singleCharRejectedTooLong() throws {
    #expect(try !bs("a", accepts: "aa"))
}

// MARK: - 2. Concatenation

@Test func concatTwoChars() throws {
    #expect(try  bs("ab", accepts: "ab"))
    #expect(try !bs("ab", accepts: "a"))
    #expect(try !bs("ab", accepts: "b"))
    #expect(try !bs("ab", accepts: "ba"))
    #expect(try !bs("ab", accepts: "abc"))
}

@Test func concatThreeChars() throws {
    #expect(try  bs("abc", accepts: "abc"))
    #expect(try !bs("abc", accepts: "ab"))
    #expect(try !bs("abc", accepts: "abcd"))
}

// MARK: - 3. Union

@Test func unionTwoChars() throws {
    #expect(try  bs("a|b", accepts: "a"))
    #expect(try  bs("a|b", accepts: "b"))
    #expect(try !bs("a|b", accepts: "c"))
    #expect(try !bs("a|b", accepts: "ab"))
}

@Test func unionMultiple() throws {
    let pat = "a|b|c|d"
    for ch in "abcd" { #expect(try bs(pat, accepts: String(ch))) }
    #expect(try !bs(pat, accepts: "e"))
}

// MARK: - 4. Kleene star (repeat)

@Test func kleeneStarEmpty() throws {
    // a* must accept the empty string
    #expect(try bs("a*", accepts: ""))
}

@Test func kleeneStarSingle() throws {
    #expect(try bs("a*", accepts: "a"))
}

@Test func kleeneStarMultiple() throws {
    #expect(try bs("a*", accepts: "aaaa"))
}

@Test func kleeneStarWrongChar() throws {
    #expect(try !bs("a*", accepts: "b"))
}

@Test func kleeneStarMixed() throws {
    // (a|b)* accepts any string over {a,b}
    #expect(try  bs("(a|b)*", accepts: ""))
    #expect(try  bs("(a|b)*", accepts: "a"))
    #expect(try  bs("(a|b)*", accepts: "bababab"))
    #expect(try !bs("(a|b)*", accepts: "c"))
    #expect(try !bs("(a|b)*", accepts: "abc"))
}

// MARK: - 5. Optional (zero or one)

@Test func optionalAcceptsEmpty() throws {
    #expect(try  bs("a?", accepts: ""))
    #expect(try  bs("a?", accepts: "a"))
    #expect(try !bs("a?", accepts: "aa"))
    #expect(try !bs("a?", accepts: "b"))
}

// MARK: - 6. repeatMin (one-or-more / n-or-more)

@Test func plusOneOrMore() throws {
    #expect(try !bs("a+", accepts: ""))
    #expect(try  bs("a+", accepts: "a"))
    #expect(try  bs("a+", accepts: "aaa"))
    #expect(try !bs("a+", accepts: "b"))
}

@Test func repeatMin2() throws {
    // a{2,} — at least two a's
    #expect(try !bs("a{2,}", accepts: ""))
    #expect(try !bs("a{2,}", accepts: "a"))
    #expect(try  bs("a{2,}", accepts: "aa"))
    #expect(try  bs("a{2,}", accepts: "aaaa"))
}

// MARK: - 7. repeatMinMax (bounded repetition)

@Test func repeatExact() throws {
    // a{3,3} — exactly three a's
    #expect(try !bs("a{3,3}", accepts: "aa"))
    #expect(try  bs("a{3,3}", accepts: "aaa"))
    #expect(try !bs("a{3,3}", accepts: "aaaa"))
}

@Test func repeatRange() throws {
    // a{2,4} — two to four a's
    #expect(try !bs("a{2,4}", accepts: "a"))
    #expect(try  bs("a{2,4}", accepts: "aa"))
    #expect(try  bs("a{2,4}", accepts: "aaa"))
    #expect(try  bs("a{2,4}", accepts: "aaaa"))
    #expect(try !bs("a{2,4}", accepts: "aaaaa"))
}

// MARK: - 8. Character ranges

@Test func charRangeLowercase() throws {
    #expect(try  bs("[a-z]", accepts: "a"))
    #expect(try  bs("[a-z]", accepts: "m"))
    #expect(try  bs("[a-z]", accepts: "z"))
    #expect(try !bs("[a-z]", accepts: "A"))
    #expect(try !bs("[a-z]", accepts: "1"))
}

@Test func charRangeDigits() throws {
    let pat = "[0-9]"
    for d in "0123456789" { #expect(try bs(pat, accepts: String(d))) }
    #expect(try !bs(pat, accepts: "a"))
}

@Test func charRangeInStar() throws {
    // [a-z]* matches any lowercase word
    #expect(try  bs("[a-z]*", accepts: ""))
    #expect(try  bs("[a-z]*", accepts: "hello"))
    #expect(try !bs("[a-z]*", accepts: "Hello"))
}

// MARK: - 9. anyChar (dot)

@Test func anyCharSingle() throws {
    #expect(try  bs(".", accepts: "a"))
    #expect(try  bs(".", accepts: "z"))
    #expect(try !bs(".", accepts: ""))
    #expect(try !bs(".", accepts: "ab"))
}

@Test func anyCharInConcat() throws {
    // a.b — any character sandwiched between a and b
    #expect(try  bs("a.b", accepts: "axb"))
    #expect(try  bs("a.b", accepts: "a b"))
    #expect(try !bs("a.b", accepts: "ab"))
    #expect(try !bs("a.b", accepts: "axbc"))
}

// MARK: - 10. Complex / compound patterns

@Test func identifierPattern() throws {
    // Simple identifier: letter followed by letters or digits.
    // [a-z]([a-z]|[0-9])*
    let pat = "[a-z]([a-z]|[0-9])*"
    #expect(try  bs(pat, accepts: "x"))
    #expect(try  bs(pat, accepts: "abc"))
    #expect(try  bs(pat, accepts: "a1b2"))
    #expect(try !bs(pat, accepts: "1abc"))
    #expect(try !bs(pat, accepts: ""))
}

@Test func floatPattern() throws {
    // Simplified float: digit+ . digit+
    let pat = "[0-9]+.[0-9]+"
    #expect(try  bs(pat, accepts: "3.14"))
    #expect(try  bs(pat, accepts: "0.0"))
    #expect(try !bs(pat, accepts: "3"))
    #expect(try !bs(pat, accepts: ".14"))
    #expect(try !bs(pat, accepts: "3."))
}

@Test func keywordPattern() throws {
    // (if|else|while)
    let pat = "(if|else|while)"
    #expect(try  bs(pat, accepts: "if"))
    #expect(try  bs(pat, accepts: "else"))
    #expect(try  bs(pat, accepts: "while"))
    #expect(try !bs(pat, accepts: "for"))
    #expect(try !bs(pat, accepts: "iff"))
}

@Test func nestedRepeat() throws {
    // (ab)* — even-length strings of alternating a and b
    #expect(try  bs("(ab)*", accepts: ""))
    #expect(try  bs("(ab)*", accepts: "ab"))
    #expect(try  bs("(ab)*", accepts: "abab"))
    #expect(try !bs("(ab)*", accepts: "a"))
    #expect(try !bs("(ab)*", accepts: "aba"))
    #expect(try !bs("(ab)*", accepts: "b"))
}

// MARK: - 11. Parity with Thompson construction
//
// For each pattern we verify that BerrySethi and Thompson agree on every test
// string.  This catches sign errors in followpos without needing to inspect
// internal DFA structure.

@Test func paritySimpleChars() throws {
    let strings = ["", "a", "b", "ab", "aa", "ba"]
    for s in strings {
        #expect(try bs("a",   accepts: s) == th("a",   accepts: s), "a / \"\(s)\"")
        #expect(try bs("ab",  accepts: s) == th("ab",  accepts: s), "ab / \"\(s)\"")
        #expect(try bs("a|b", accepts: s) == th("a|b", accepts: s), "a|b / \"\(s)\"")
    }
}

@Test func parityKleene() throws {
    let strings = ["", "a", "aa", "aaa", "b", "ab"]
    for s in strings {
        #expect(try bs("a*", accepts: s) == th("a*", accepts: s), "a* / \"\(s)\"")
        #expect(try bs("a+", accepts: s) == th("a+", accepts: s), "a+ / \"\(s)\"")
        #expect(try bs("a?", accepts: s) == th("a?", accepts: s), "a? / \"\(s)\"")
    }
}

@Test func parityComplex() throws {
    let strings = ["", "a", "b", "ab", "ba", "aab", "abb", "abc", "abab"]
    let patterns = ["(a|b)*", "(ab)+", "a(b|c)*", "(a|b)(a|b)"]
    for pat in patterns {
        for s in strings {
            let bsResult = try bs(pat, accepts: s)
            let thResult = try th(pat, accepts: s)
            #expect(bsResult == thResult, "\(pat) / \"\(s)\": BS=\(bsResult) TH=\(thResult)")
        }
    }
}

@Test func parityCharRanges() throws {
    let strings = ["", "a", "z", "A", "0", "9", "abc", "a1"]
    let patterns = ["[a-z]", "[0-9]", "[a-z]+", "[a-z][0-9]"]
    for pat in patterns {
        for s in strings {
            let bsResult = try bs(pat, accepts: s)
            let thResult = try th(pat, accepts: s)
            #expect(bsResult == thResult, "\(pat) / \"\(s)\": BS=\(bsResult) TH=\(thResult)")
        }
    }
}

// MARK: - 12. DFA structure sanity checks

@Test func dfaHasInitialState() throws {
    let r = try Regex("a|b", method: .berrySethi)
    if case let .dfa(initial, _, _, _, _) = r.state {
        #expect(initial == 0)   // initial DFA state must be 0
    } else {
        Issue.record("Berry-Sethi did not produce a DFA state")
    }
}

@Test func dfaHasFinalStates() throws {
    let r = try Regex("ab", method: .berrySethi)
    if case let .dfa(_, finals, _, _, _) = r.state {
        #expect(!finals.isEmpty, "DFA must have at least one final state")
    } else {
        Issue.record("Berry-Sethi did not produce a DFA state")
    }
}

@Test func dfaHasTransitions() throws {
    let r = try Regex("a|b", method: .berrySethi)
    if case let .dfa(_, _, transitions, _, _) = r.state {
        #expect(!transitions.isEmpty, "DFA must have transitions for 'a|b'")
    } else {
        Issue.record("Berry-Sethi did not produce a DFA state")
    }
}

@Test func dfaIsDeterministic() throws {
    // Verify there is at most one transition per (state, symbol) pair.
    let r = try Regex("(a|b)*abb", method: .berrySethi)
    if case let .dfa(_, _, transitions, _, _) = r.state {
        var seen: [Int: Set<Character>] = [:]
        for t in transitions {
            if case .char(let ch) = t.alphabetRange {
                var chars = seen[t.source, default: []]
                #expect(!chars.contains(ch),
                    "DFA has two transitions on '\(ch)' from state \(t.source)")
                chars.insert(ch)
                seen[t.source] = chars
            }
        }
    } else {
        Issue.record("Berry-Sethi did not produce a DFA state")
    }
}

// MARK: - 13. Classic textbook example (Aho §3.9)

@Test func classicAhoCatDotStarAbb2() throws {
    // (a|b)*abb — the textbook Berry-Sethi / position-DFA example.
    // The minimal DFA has 4 states.
    let pat = "(a|b)*abb"
    let accept = ["abb", "aabb", "babb", "aababb", "ababbb"]
    let reject = ["", "a", "ab", "abba", "abbc", "b", "ba", "bb"]

    for s in accept { #expect(try  bs(pat, accepts: s), "should accept \"\(s)\"") }
    for s in reject { #expect(try !bs(pat, accepts: s), "should reject \"\(s)\"") }
}

// MARK: - 14. Regression: position counter must be independent of Thompson

@Test func counterIndependenceFromThompson() throws {
    // Build a Thompson automaton first to advance Counter.shared.
    _ = try Regex("xyz", method: .thompson)
    _ = try Regex("abc", method: .thompson)

    // Now build a Berry-Sethi automaton.  If it shares the counter its leaf
    // positions will be garbage and recognition will always fail.
    #expect(try  bs("hello", accepts: "hello"))
    #expect(try !bs("hello", accepts: "world"))
}

@Test func counterIndependenceMultipleBerrySethi() throws {
    // Two successive Berry-Sethi instances must each use their own counter
    // starting from 1, not from wherever the shared counter happens to be.
    #expect(try  bs("ab", accepts: "ab"))
    #expect(try  bs("ab", accepts: "ab"))
    #expect(try  bs("cd", accepts: "cd"))
    #expect(try !bs("ab", accepts: "cd"))
}
