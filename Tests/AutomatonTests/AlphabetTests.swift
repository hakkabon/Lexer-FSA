import Testing
@testable import Automaton

@Test
func testPrintAlphabet() async throws {
    let intervals = [Interval("m","z"),Interval("0","9"),Interval("_"),Interval("!")]
    let alphabet = Alphabet(intervals, true) // no interval merge
    #expect(alphabet.characters.count == 26, "[Alphabet] length error");
    #expect(alphabet.characterClasses.count == 4, "[Alphabet] character classes error");
}

@Test
func testAlphabet() async throws {
    let intervals = [Interval("m","z"),Interval("0","9"),Interval("c"),Interval("h","j"),
                     Interval("A","Z"),Interval("a"),Interval("a","k"),Interval("b"),
                     Interval("_"),Interval("!"),Interval("j","o")]
    
    let alphabet = Alphabet(intervals, true) // no interval merge
    #expect(alphabet.characters.count == 64, "[Alphabet] length error");
    #expect(alphabet.characterClasses.count == 5, "[Alphabet] character classes error");
}

@Test
func testAlphabetMerge() async throws {
    let intervals = [Interval("m","z"),Interval("0","9"),Interval("c"),Interval("h","j"),
                     Interval("A","Z"),Interval("a"),Interval("a","k"),Interval("b"),
                     Interval("_"),Interval("!"),Interval("j","o")]
    
    let alphabet = Alphabet(intervals, true) // do interval merge
    #expect(alphabet.characters.count == 64, "[Alphabet] length error")           // 26+26+10+1+1 = 64
    #expect(alphabet.characterClasses.count == 5, "[Alphabet] character classes error")
}
