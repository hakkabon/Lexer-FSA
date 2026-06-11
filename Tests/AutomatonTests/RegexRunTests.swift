import Testing
@testable import Automaton

// This construct is not implemented!
//@Test
//func testEmpty() async throws {
//    for mode in [false, true] {
//        let automaton = try Regex("")
//        #expect(automaton.test("", deterministic: mode), "should accept empty string")
//        #expect(automaton.test("0", deterministic: mode) == false)
//    }
//}

@Test
func testSingleLiteral() async throws {
    let automaton = try Regex("1")
    #expect(automaton.recognize(string: "1"), "should accept single literal as the expression")
    #expect(automaton.recognize(string: "") == false)
    #expect(automaton.recognize(string: "0") == false)
}

@Test
func testStrings() async throws {
    let expr = "10101"
    let re = try Regex("10101")
    #expect(re.recognize(string: expr), "should accept original building expression")
    #expect(re.recognize(string: "") == false)
    #expect(re.recognize(string: "101011") == false)
    #expect(re.recognize(string: "1010") == false)
}

@Test
func testUnionOnSingleLiteral() async throws {
    let re = try Regex("1|0")
    #expect(re.recognize(string: "0"), "should accept one of the two patterns")
    #expect(re.recognize(string: "1"), "should accept another one of the two patterns")
    #expect(re.recognize(string: "10") == false)
    #expect(re.recognize(string: "01") == false)
    #expect(re.recognize(string: "") == false)
}

@Test
func testUnionOnMultipleStrings() async throws {
    let re = try Regex("101|0011|1110")
    #expect(re.recognize(string: "101"))
    #expect(re.recognize(string: "0011"))
    #expect(re.recognize(string: "1110"))
    #expect(re.recognize(string: "1") == false)
    #expect(re.recognize(string: "0") == false)
    #expect(re.recognize(string: "100") == false)
    #expect(re.recognize(string: "00") == false)
    #expect(re.recognize(string: "1111") == false)
}

@Test
func testClosure() async throws {
    let re = try Regex("01*0")
    #expect(re.recognize(string: "00"))
    #expect(re.recognize(string: "010"))
    #expect(re.recognize(string: "0110"))
    #expect(re.recognize(string: "01110"))
    #expect(re.recognize(string: "011") == false)
    #expect(re.recognize(string: "1") == false)
    #expect(re.recognize(string: "01101") == false)
}

@Test
func testBrackets() async throws {
    let re = try Regex("1(01)*")
    #expect(re.recognize(string: "1"))
    #expect(re.recognize(string: "101"))
    #expect(re.recognize(string: "10101"))
    #expect(re.recognize(string: "1010101"))
    #expect(re.recognize(string: "10") == false)
    #expect(re.recognize(string: "01") == false)
    #expect(re.recognize(string: "1010") == false)
    #expect(re.recognize(string: "1011") == false)
    #expect(re.recognize(string: "1010100") == false)
}

@Test
func testMultipleOfThree() async throws {
    // Denotes the set of binary numbers that are multiples of 3.
    let re = try Regex("(0|(1(01*(00)*0)*1)*)*")
    #expect(re.recognize(string: ""))
    #expect(re.recognize(string: "0"))
    #expect(re.recognize(string: "00"))
    #expect(re.recognize(string: "11"))
    #expect(re.recognize(string: "000"))
    #expect(re.recognize(string: "011"))
    #expect(re.recognize(string: "110"))
    #expect(re.recognize(string: "0000"))
    #expect(re.recognize(string: "0011"))
    #expect(re.recognize(string: "0110"))
    #expect(re.recognize(string: "1001"))
    #expect(re.recognize(string: "1100"))
    #expect(re.recognize(string: "1111"))
    #expect(re.recognize(string: "00000"))
    #expect(re.recognize(string: "0011110100001000111111"))
    
    #expect(re.recognize(string: "1") == false)
    #expect(re.recognize(string: "10") == false)
    #expect(re.recognize(string: "100") == false)
    #expect(re.recognize(string: "101") == false)
    #expect(re.recognize(string: "1010") == false)
    #expect(re.recognize(string: "0111") == false)
    #expect(re.recognize(string: "1101") == false)
}

@Test
func testSimpleRegex() async throws {
    let re = try Regex("ab*ba")
    #expect(re.recognize(string: "aba"), "valid lexeme 'ab*ba' - error")
    #expect(re.recognize(string: "abba"), "valid lexeme 'ab*ba' - error")
    #expect(re.recognize(string: "abbbbbbbba"), "valid lexeme 'ab*ba' - error")
}

@Test
func testExampleDragonRegex() async throws {
    let re = try Regex("(a|b)*abb")
    #expect(re.recognize(string: "abb"), "valid lexeme '(a|b)*abb'")
    #expect(re.recognize(string: "aabb"), "valid lexeme '(a|b)*abb'")
    #expect(re.recognize(string: "babb"), "valid lexeme '(a|b)*abb'")
    #expect(re.recognize(string: "aaaabbbbbbabbaabb"), "valid lexeme '(a|b)*abb'")
}
