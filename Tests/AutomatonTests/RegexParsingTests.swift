import Testing
@testable import Automaton

@Test
func testRegexOption() async throws {
    let r = try Regex("[+-]?")
    #expect(r.description == "((+|-))?")
}

@Test
func testRegexRange() async throws {
    let r = try Regex("[0-9]")
    #expect(r.description == "[0-9]")
}

@Test
func testRegexRepeat() async throws {
    let r = try Regex("[0-9]*")
    #expect(r.description == "([0-9])*")
}

@Test
func testRegexRepeatMin() async throws {
    let r = try Regex("[0-9]+")
    #expect(r.description == "([0-9]){1,}")
}

@Test
func testRegexOther() async throws {
    let r1 = try Regex("[-+]?[0-9]*")
    #expect(r1.description == "((-|+))?([0-9])*")

    let r2 = try Regex("[-+]?[0-9]+")
    #expect(r2.description == "((-|+))?([0-9]){1,}")

    let r3 = try Regex("0|1|2|3|4|5|6|7|8|9")
    #expect(r3.description == "(0|(1|(2|(3|(4|(5|(6|(7|(8|9)))))))))")

    let r4 = try Regex("(0|1|2|3|4|5|6|7|8|9)*")
    #expect(r4.description == "((0|(1|(2|(3|(4|(5|(6|(7|(8|9))))))))))*")

    let r5 = try Regex("[a-zA-Z]")
    #expect(r5.description == "([a-z]|[A-Z])")

    let r6 = try Regex("ab*ba")
    #expect(r6.description == "a(b)*ba")

    let r7 = try Regex("(ab)*")
    #expect(r7.description == "(ab)*")

    let r8 = try Regex("(ab)*ba")
    #expect(r8.description == "(ab)*ba")

    let r9 = try Regex("a(ab)*b")
    #expect(r9.description == "a(ab)*b")

    // Dragon book example
    let r10 = try Regex("(a|b)*abb")
    #expect(r10.description == "((a|b))*abb")
}

@Test
func testIdentifier() async throws {
    let r = try Regex("[a-zA-Z]([a-zA-Z]|[0-9])*")
    #expect(r.description == "([a-z]|[A-Z])((([a-z]|[A-Z])|[0-9]))*")
}

@Test
func testInt() async throws {
    let r = try Regex("[+-]?([0-9])+")
    #expect(r.description == "((+|-))?([0-9]){1,}")
}
    
@Test
func testFloat() async throws {
    let r = try Regex("[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?")
    #expect(r.description == "((-|+))?([0-9])*(.)?([0-9]){1,}((e|E)((-|+))?([0-9]){1,})?")
}
