//
//  RegexParser.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/05/27.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension Regex {
    ///
    /// Note that the definition of Regular Expression here is different compared to what most
    /// people expect form Regular Expressions in general. The usage leaning towards set theory found
    /// in most CS books dealing with Automata theory.
    /// The implementation supports the standar regular expression operations (concatenation, union,
    /// Kleene star) and a number of non-standard ones (intersection, complement, etc.)
    ///
    /// Regular expressions are built from the following abstract syntax:
    ///     regex        : unionexp
    ///     unionexp     : interexp '|' unionexp       (union)
    ///                  | interexp
    ///     interexp     : concatexp '&' interexp      (intersection)                   [OPTIONAL]
    ///                  | concatexp
    ///     concatexp    : repeatexp concatexp         (concatenation)
    ///                  | repeatexp
    ///     repeatexp    : repeatexp '?'               (zero or one occurrence)
    ///                  | repeatexp '*'               (zero or more occurrences)
    ///                  | repeatexp '+'               (one or more occurrences)
    ///                  | repeatexp '{' n '}'         (n occurrences)
    ///                  | repeatexp '{' n ',' '}'     (n or more occurrences)
    ///                  | repeatexp '{' n ',' m '}'   (n to m occurrences, including both)
    ///                  | charclassexp
    ///     charclassexp : '[' charclasses ']'         (character class)
    ///                  | '[' '^' charclasses ']'     (negated character class)
    ///                  | simpleexp
    ///     charclasses  : charclass charclasses
    ///                  | charclass
    ///     charclass    : charexp '-' charexp         (character range, including end-points)
    ///                  | charexp
    ///     simpleexp    : charexp
    ///                  | '.'                         (any single character)
    ///                  | '#'                         (the empty language)             [OPTIONAL]
    ///                  | '@'                         (any string)                     [OPTIONAL]
    ///                  | " <Unicode string> "        (a string)
    ///                  | '(' ')'                     (the empty string)
    ///                  | '(' unionexp ')'            (precedence override)
    ///                  | '<' <identifier> '>'        (named automaton)                [OPTIONAL]
    ///                  | '<' n '-' m '>'             (numerical interval)             [OPTIONAL]
    ///     charexp      : <Unicode character>         (a single non-reserved character)
    ///                  | '\' <Unicode character>     (a single character)
    ///
    ///     where
    ///     n            : "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
    ///     m            : "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
    ///
    /// The productions marked [OPTIONAL] are only allowed if specified by the syntax flags passed
    /// to the Regex constructor. The reserved characters used in the (enabled) syntax must be escaped
    /// with backslash (\) or double-quotes ("..."). (In contrast to other regex syntaxes, this is
    /// required also in character classes.) Be aware that dash (-) has a special meaning in charclass
    /// expressions. An identifier is a string not containing right angle bracket (>) or dash (-).
    /// Numerical intervals are specified by non-negative decimal integers and include both end points,
    /// and if n and m have the same number of digits, then the conforming strings must have that length,
    /// i.e. prefixed by 0's.
    struct RegexParser {
        
        /// Ill-formed expressions reported during parsing of regular expressions.
        enum ParseError: Swift.Error {
            case expectedInteger(Character,Int)
            case unexpectedCharacter(Character,Character,Int)
            case intervalSyntaxError(Int)
            case illegalIdentifier(Character,Int)
            case illegalSyntax(Int)
        }

        /// The source code as a list of characters that is read one by one from start to end.
        private let string: String

        // Syntax flags.
        var flags: SyntaxOptions

        /// The current scanning position (index) in the source code.
        private var index: String.Index

        /// Returns current character
        var current: Character {
            assert(self.index < string.endIndex)
            return string[self.index]
        }

        /// Are there additional characters beyond `current`.
        var more: Bool {
            return index < string.endIndex
        }

        init(expression source: String, _ flags: SyntaxOptions) {
            self.string = source
            self.flags = flags
            self.index = source.startIndex
        }

        /// Advances index pointer one step forward.
        mutating func nextIndex() {
            index = string.index(after: index)
        }

        /// Matches given character against first lookahead character.
        func peek(_ s: String) -> Bool {
            return more ? s.contains(current) : false
        }

        /// Advance the code stream past all characters which match a given definition,
        /// and return them concatenated as a String.
        /// - Parameter matches: A function which defines which characters "match"
        /// - Returns: the string mached
        mutating func parse(while condition:(Character) -> Bool) -> String {
            var lexeme = ""
            while more && condition(current) { 
                lexeme += String(current)
                nextIndex()
            }
            return lexeme
        }
        
        /// Matches given character against current character.
        /// if matched current token is consumed
        mutating func match(_ ch: Character) -> Bool {
            if !more { return false }
            if current == ch {
                nextIndex()
                return true
            }
            return false
        }
        
        func count(before index: String.Index) -> Int {
            return string[..<index].count
        }
        
        func has(pattern s: String) -> Bool {
            return string[index...].contains(s)
         }

        mutating func parse() throws -> Expression {
            return try parseUnion()
        }

        mutating func parseUnion() throws -> Expression {
            let e = try parseConcatenation() //parseIntersection()
            if match("|") {
                return .union(e, try parseUnion())
            }
            return e
        }
        
        mutating func parseIntersection() throws -> Expression {
            let e = try parseConcatenation()
            if match("&") {
//                return .intersection(e, try parseIntersection())      // Assuming .intersection exists in your AST
                throw ParseError.illegalSyntax(count(before: index))    // remove this when .intersection(expression,expression) implemented
            }
            return e
        }

        mutating func parseConcatenation() throws -> Expression {
            let e = try parseRepetition()
            if more && !peek(")|&") { // <-- Added '&' here
                return .concatenation(e, try parseConcatenation())
            }
            return e
        }
        
        mutating func parseRepetition() throws -> Expression {
            var e = try parseCharClassExp()
            while peek("?*+{") {
                if match("?") { e = .optional(e) }
                else if match("*") { e = .`repeat`(e) }
                else if match("+") { e = .repeatMin(e, 1) }
                else if match("{") {
                    var start = index
                    let number = parse(while: { "0123456789".contains($0) })
                    if start == index { throw ParseError.expectedInteger(current, count(before: index)) }
                    let n = Int(number) ?? 0
                    var m = -1
                    if match(",") {
                        start = index
                        let number = parse(while: { "0123456789".contains($0) })
                        if (start != index) { m = Int(number) ?? 0 }
                    } else {
                        m = n
                    }
                    if !match("}") { throw ParseError.unexpectedCharacter("}", current, count(before: index)) }
                    if m == -1 { e = .repeatMin(e, n) }
                    else { e = .repeatMinMax(e, n, m) }
                }
            }
            return e
        }

        mutating func parseCharClassExp() throws -> Expression {
            if match("[") {
                let negate = match("^")
                let e = try parseCharClasses()
                if !match("]") { throw ParseError.unexpectedCharacter("]", current, count(before: index)) }
                // Let the backend handle the negation of these specific characters
//                return negate ? .negatedClass(e) : e      //
                return e                                    // remove this when .negatedClass() implemented
            }
            return try parseSimpleExpression()
        }
                
        mutating func parseCharClasses() throws -> Expression {
            var e = try parseCharClass()
            while more && !peek("]") {
                e = .union(e, try parseCharClass())
            }
            return e
        }
        
        mutating func parseCharClass() throws -> Expression {
            let c = try parseCharExp()
            if match("-") {
                if peek("]") { return .union(.char(c), .char("-")) }
                else { return .charRange(c, try parseCharExp()) }
             }
            else { return .char(c) }
        }
        
        mutating func parseSimpleExpression() throws -> Expression {
            if match(".") { return .anyChar }
            else if flags.contains(.empty) && match("#") { return .empty }
            else if flags.contains(.anyString) && match("@") { return .anyString }
            else if match("'") {
                let start = index
                _ = parse(while: { !"'".contains($0) })
                if !match("'") { throw ParseError.unexpectedCharacter("'", current, count(before: index)) }
                return .string(String(string[start..<index]))
            } else if match("(") {
                if match(")") { return .string("") }
                let e = try parseUnion()
                if !match(")") { throw ParseError.unexpectedCharacter(")", current, count(before: index)) }
                return e
            } else if (flags.contains(.automaton) || flags.contains(.interval)) && match("<") {
                let start = index
                _ = parse(while: { !">".contains($0) })
                if !match(">") { throw ParseError.unexpectedCharacter(">", current, count(before: index)) }
                let s = String(string[start..<string.index(before: index)])
                if let i = s.firstIndex(of: "-") {
                    if !flags.contains(.interval) { throw ParseError.illegalIdentifier("-", count(before: index)-1) }
                    do {
                        if i == s.startIndex || i == s.endIndex { throw ParseError.illegalSyntax(count(before: index)) }
                        let smin = s[..<i]
                        let smax = s[string.index(after: i)...]
                        var imin = Int(smin) ?? 0
                        var imax = Int(smax) ?? 0
                        var digits = 0
                        if smin.count == smax.count { digits = smin.count }
                        else { digits = 0 }
                        if imin > imax {
                            let t = imin
                            imin = imax
                            imax = t
                        }
                        return .interval(imin, imax, digits)
                    } catch {
                        throw ParseError.intervalSyntaxError(count(before: index)-1)
                    }
                } else {
                    if !flags.contains(.automaton) { throw ParseError.intervalSyntaxError(count(before: index)-1) }
                    return.string(s)
                }
            }
            return try .char(parseCharExp())
        }

        /// Returns current character
        mutating func parseAny() -> Character {
            let ch = current
            nextIndex()
            return ch
        }

        mutating func parseCharExp() throws -> Character {
            if match("\\") {
                let c = parseAny()
                switch c {
                case "n": return "\n"
                case "t": return "\t"
                case "r": return "\r"
                case "\\": return "\\"
                case "\"": return "\""
                // Add \uXXXX unicode handling here later if you wish
                default: return c // E.g., \* simply returns *
                }
            }
            return parseAny()
        }
    }
}
