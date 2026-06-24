import Testing
@testable import LexerFSA


@Test(.disabled("distinction between empty language and epsilon"))
func testNilString() throws {
    let a = try Regex.nondeterministicFiniteState(Regex("#", method: .thompson, flags: .all))   // empty language
    try #require(a.isEmpty)
}

@Test(.disabled("distinction between empty language and epsilon"))
func testEmptyString() throws {
    let a = try Regex.nondeterministicFiniteState(Regex(""))
    print("\(a)")
    try #require(a.isEmpty)
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

