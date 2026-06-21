import Testing
@testable import LexerFSA

@Test
func testSimpleRepeat1() throws {
    let r = try Regex("(ab)*")
    #expect(r.recognize(string: "abababab"), "'(ab)*' accepts'abababab'")
}

@Test
func testSimpleRepeat2() throws {
    let r = try Regex("(ab)*ba")
    #expect(r.recognize(string: "abba"), "'(ab)*ba' accepts `abba`")
}

@Test
func testSimpleRepeat3() throws {
    let r = try Regex("ab*ba")
    #expect(r.recognize(string: "abba"), "'ab*ba' accepts `abba`")
}

@Test
func testSimpleRepeat4() throws {
    let r = try Regex("(a|b)*")
    #expect(r.recognize(string: "aaaabb"), "'(ab)*(ba)*' accepts `aaaabb`")
}

@Test
func testSimpleRepeat5() throws {
    let r = try Regex("(ab)*(ba)*")
    #expect(r.recognize(string: "ababbababa"), "'(ab)*(ba)*' accepts `ababbababa`")
}
