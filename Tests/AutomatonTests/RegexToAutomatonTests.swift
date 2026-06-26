import Testing
@testable import LexerFSA


@Test
func testNilString() throws {
    let a = try Regex.nondeterministicFiniteState(Regex("#", method: .thompson, flags: .all))   // empty language
    try #require(a.isEmpty)
}

@Test("Empty source string is rejected rather than silently meaning ε or ∅")
func testEmptyString() throws {
    // A bare empty pattern is ambiguous -- does the caller mean the empty
    // string (ε, spelled `()`), the empty language (∅, spelled `#` when the
    // `.empty` flag is enabled), or did they simply forget to supply a
    // pattern? Rather than guessing, the parser rejects it outright.
    #expect(throws: Regex.RegexParser.ParseError.self) {
        _ = try Regex("")
    }
}

@Test("testSimpleString")
func testSimpleString() throws {
    var r = try Regex("0")
    r.isDeterministic = true
    let a = Regex.deterministicFiniteState(r)
    try #require(a.stateCount == 2)
}

@Test("testSimpleString2")
func testSimpleString2() throws {
    var r = try Regex("01")
    r.isDeterministic = true
    let a = Regex.deterministicFiniteState(r)
    try #require(a.stateCount == 3)
}

