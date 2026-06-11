import Testing
@testable import Automaton


// Create use-cases for unions minimize on/off with marker overlapping
// Create use-cases for merge conflicts and conflict resolving

@Test
func testFloatLexemes() async throws {
    let FLOAT = "[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?";
    var automaton = Automaton(try Regex(FLOAT))
    
    // minimizing is optional
//    automaton.minimize()
    
    #expect(automaton.recognize(string: "123456"), "valid lexeme '123456'")
    #expect(automaton.recognize(string: "123.45"), "valid lexeme '123.45'")
    #expect(automaton.recognize(string: "-0.123e-6"), "valid lexeme '-0.123e-6'")
}

// Important use-case: This how the parser uses the Automaton.
@Test
func testRegexUnion() async throws {
    // Define token classes for the automaton.
    let STRING = "[a-zA-Z]+"
    let NUM = "[+-]?([0-9])+"
    let FLOAT = "[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?";
    
    var list: [Automaton<Regex>] = []
    // Adding tags per regex not possible, ie. .mark(1) .mark(2) .mark(3).
    list.append( Automaton(try Regex(STRING)) )
    list.append( Automaton(try Regex(NUM)) )
    list.append( Automaton(try Regex(FLOAT)) )
    let automaton = Automaton.union(list: list)

    // Determinize is optional.
    automaton.isDeterminized = true

    // Minimizing is optional.
    automaton.minimize()

    // This executes as expected.
    #expect(automaton.recognize(string: "abba"), "valid lexeme 'abba'");
    #expect(automaton.recognize(string: "123456"), "valid lexeme '123456'");
    #expect(automaton.recognize(string: "123.45"), "valid lexeme '123.45'");
    #expect(automaton.recognize(string: "-0.123e-6"), "valid lexeme '-0.123e-6'");
    
    // But how-to identify the token class recognized without doing some fancy
    // book-keeping over the final states in the Finite State Automaton.
}
    
