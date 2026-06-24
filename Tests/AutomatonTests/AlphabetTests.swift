import Testing
@testable import LexerFSA

@Test("Test Merge Alphabet Intervals - 1")
func testMergeAlphabet_1() async throws {
    let intervals = [Interval("m","z"),Interval("0","9"),Interval("_"),Interval("!")]
    let alphabet = Alphabet(intervals, true) // do merge intervals
    #expect(alphabet.characters.count == 26, "[Alphabet] length error");
    #expect(alphabet.characterClasses.count == 4, "[Alphabet] character classes error");
}

@Test("Test Merge Alphabet Intervals - 2")
func testMergeAlphabet_2() async throws {
    let intervals = [Interval("m","z"),Interval("0","9"),Interval("c"),Interval("h","j"),
                     Interval("A","Z"),Interval("a"),Interval("a","k"),Interval("b"),
                     Interval("_"),Interval("!"),Interval("j","o")]
    
    let alphabet = Alphabet(intervals, true) // do merge intervals
    #expect(alphabet.characters.count == 64, "[Alphabet] length error");
    #expect(alphabet.characterClasses.count == 5, "[Alphabet] character classes error");
}

@Test("Test Merge Alphabet Intervals - 3")
func testMergeAlphabet_3() async throws {
    let intervals = [Interval("m","z"),Interval("0","9"),Interval("c"),Interval("h","j"),
                     Interval("A","Z"),Interval("a"),Interval("a","k"),Interval("b"),
                     Interval("_"),Interval("!"),Interval("j","o")]
    
    let alphabet = Alphabet(intervals, true) // do merge intervals
    #expect(alphabet.characters.count == 64, "[Alphabet] length error") // 26+26+10+1+1 = 64
    #expect(alphabet.characterClasses.count == 5, "[Alphabet] character classes error")
}
