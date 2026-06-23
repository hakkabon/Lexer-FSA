import Testing
@testable import LexerFSA

#if false

@Test(.disabled("distinction between empty language and epsilon"))
func testNilString() throws {
    let s: String? = nil
    let a = try Automaton(Regex.nondeterministicFiniteState(Regex(s!)))
    try #require(a)
}

@Test(.disabled("distinction between empty language and epsilon"))
func testEmptyString() throws {
    let a = try Automaton(Regex.nondeterministicFiniteState(Regex("")))
    print("\(a)")
    try #require(a)
}


@Test(.disabled("testSimpleString"))
func testSimpleString() throws {
    var r = try Regex("0")
    r.isDeterministic = true
    let a = Automaton(Regex.deterministicFiniteState(r))
    try #require(a)
}

@Test(.disabled("testSimpleString2"))
func testSimpleString2() throws {
    var r = try Regex("01")
    r.isDeterministic = true
    let a = Automaton(Regex.deterministicFiniteState(r))
    try #require(a)
}

#endif
