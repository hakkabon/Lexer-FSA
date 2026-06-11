import Testing
@testable import Automaton

/*
@Test
func testNilString() throws {
    let s: String? = nil
    let a = try Automaton(Regex.nondeterministicFiniteState(Regex(s!)))
    try #require(a)
}

@Test
func testEmptyString() throws {
    let a = try Automaton(Regex.nondeterministicFiniteState(Regex("")))
    print("\(a)")
    try #require(a)
}
*/

@Test
func testSimpleString() throws {
    var r = try Regex("0")
    r.isDeterministic = true
    let a = Automaton(Regex.deterministicFiniteState(r))
    try #require(a)
}

@Test
func testSimpleString2() throws {
    var r = try Regex("01")
    r.isDeterministic = true
    let a = Automaton(Regex.deterministicFiniteState(r))
    try #require(a)
}
