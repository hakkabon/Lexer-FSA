import Testing
@testable import LexerFSA

#if false

// Automaton has been removed - Use Lexer or LexerBuilder instead.

@Test
func testPascalSymbols() async throws {
    
    let symbols = [
        "for", "downto", "file", "<=", "<>", "CHARACTER_STRING", "packed",
        "function", "forward", "REALNUMBER", "program", "IDENTIFIER",
        "with", "procedure", "external", ">=", "repeat", "(", ")", "type",
        "*", "+", ",", "-", ".", "/", "nil", "record", "goto", "of", "set",
        ":", ";", "<", "=", ">", "case", "or", "DIGSEQ", "and", "extern",
        "array", "while", "**", "do", "var", "[", "]", "^", "DomainType",
        "label", "else", "begin", "until", "to", "div", "const", "otherwise",
        "not", "mod", "..", "then", "if", "->", ":=", "end", "in"
    ]
    let automaton = Automaton.stringUnion(words: symbols)

    #expect(automaton.run(string: "123456") == false)
    #expect(automaton.run(string: "<") == true)
    #expect(automaton.run(string: "<=") == true)
    #expect(automaton.run(string: "->") == true)
    #expect(automaton.run(string: "IDENTIFIER") == true)
    #expect(automaton.run(string: "file") == true)
    #expect(automaton.run(string: "files") == false)
    #expect(automaton.run(string: "CHARACTER_STRINGS") == false)
    #expect(automaton.run(string: "CHARACTER_STRING") == true)
}

#endif
