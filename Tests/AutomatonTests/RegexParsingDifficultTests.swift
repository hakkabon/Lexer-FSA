import Testing
@testable import LexerFSA

/// When testing parsers, the "difficult parts" are usually:
/// 
/// Operator Precedence (ensuring a|bc* doesn't become (a|b)c*).
/// Right-Associativity (ensuring abc nests properly).
/// Quantifier Edge Cases (like {3}, {3,}, and {3,5}).
/// Syntax Errors (ensuring malformed strings throw the right error instead of crashing).

@Suite("Regex Parser Tests")
struct RegexParserTests {
    
    // MARK: - 1. Operator Precedence & Associativity
    
    @Test("Precedence: Union vs. Concatenation vs. Repetition")
    func precedence() throws {
        // Regex: a|bc*
        // Expected: a | (b · (c*))
        var parser = Regex.RegexParser(expression: "a|bc*", .basic)
        let ast = try parser.parse()
        
        let expected: Expression = .union(
            .char("a"),
            .concatenation(
                .char("b"),
                .`repeat`(.char("c"))
            )
        )
        
        #expect(ast == expected)
    }

    @Test("Right-Associativity in Concatenation")
    func rightAssociativity() throws {
        // Regex: abc
        // Expected: a · (b · c)  <-- Based on your parser's recursive design
        var parser = Regex.RegexParser(expression: "abc", .basic)
        let ast = try parser.parse()
        
        let expected: Expression = .concatenation(
            .char("a"),
            .concatenation(.char("b"), .char("c"))
        )
        
        #expect(ast == expected)
    }

    // MARK: - 2. Complex Quantifiers
    
    @Test(
        "Quantifiers {n}, {n,}, and {n,m}",
        arguments: [
            ("a{3}",   Expression.repeatMinMax(.char("a"), 3, 3)),
            ("a{3,}",  Expression.repeatMin(.char("a"), 3)),
            ("a{3,5}", Expression.repeatMinMax(.char("a"), 3, 5))
        ]
    )
    func quantifiers(regex: String, expected: Expression) throws {
        var parser = Regex.RegexParser(expression: regex, .basic)
        let ast = try parser.parse()
        #expect(ast == expected)
    }

    // MARK: - 3. Character Classes & Escapes
    
    @Test("Character Classes and Ranges")
    func charClasses() throws {
        // Regex: [a-zA-Z]
        // Expected: ('a'-'z') | ('A'-'Z')
        var parser = Regex.RegexParser(expression: "[a-zA-Z]", .basic)
        let ast = try parser.parse()
        
        let expected: Expression = .union(
            .charRange("a", "z"),
            .charRange("A", "Z")
        )
        
        #expect(ast == expected)
    }
    
    @Test("Escape Sequences")
    func escapeSequences() throws {
        // Regex: \n\t\*
        // Note: Assumes you implemented the `switch` statement fix in `parseCharExp`
        var parser = Regex.RegexParser(expression: #"\n\t\*"#, .basic)
        let ast = try parser.parse()
        
        let expected: Expression = .concatenation(
            .char("\n"),
            .concatenation(.char("\t"), .char("*"))
        )
        
        #expect(ast == expected)
    }

    // MARK: - 4. Non-Standard Grammar Features
    
    @Test("Numerical Intervals")
    func intervals() throws {
        // Regex: <1-100>
        // Expect: interval(imin: 1, imax: 100, digits: 0)
        var parser = Regex.RegexParser(expression: "<1-100>", .all)
        let ast = try parser.parse()
        
        #expect(ast == .interval(1, 100, 0))
    }
    
    @Test("Padded Numerical Intervals")
    func paddedIntervals() throws {
        // Regex: <001-100>
        // Expect: digits = 3 (since smin.count == smax.count)
        var parser = Regex.RegexParser(expression: "<001-100>", .all)
        let ast = try parser.parse()
        
        #expect(ast == .interval(1, 100, 3))
    }

    // MARK: - 5. Error Handling (Unhappy Paths)
    
    @Test(
        "Expected Parser Errors",
        arguments: [
            "a{",       // Missing number/brace
            "[a-z",     // Unclosed character class
            "<10-20",   // Unclosed interval
            "a|(",      // Unclosed group
            "\"unclosed string" // Missing closing quote
        ]
    )
    func parserErrors(malformedRegex: String) {
        var parser = Regex.RegexParser(expression: malformedRegex, .all)
        
        // #expect(throws:) ensures that parsing these strings throws an error
        // without crashing the test runner.
        #expect(throws: Regex.RegexParser.ParseError.self) {
            _ = try parser.parse()
        }
    }
}
