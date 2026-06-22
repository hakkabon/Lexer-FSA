//
//  Expression+Desugar.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/22.
//

import Foundation

//  Pure, stateless functions that expand the *derived* `Expression` operators
//  — `{n,}`, `{n,m}`, and numerical intervals — into the small set of
//  primitive operators (`union`, `concatenation`, `optional`, `repeat`,
//  `char`, `string`, `empty`) that every construction method has to handle
//  directly.
//
//  These were originally three `private func`s living inside
//  `BerrySethi` (see git history). They never read or wrote any of
//  `BerrySethi`'s instance state — they only pattern-match their
//  `Expression` argument — so nesting them inside that one struct bought
//  nothing, and a second construction method that needs the exact same
//  expansion (`Antimirov`, see PartialDerivative.swift) would otherwise have
//  had to keep its own, independently-written copy in sync by hand. Two
//  copies of "what does `a{2,5}` expand to" is exactly the kind of thing
//  that quietly drifts apart after one of them gets a bug fix the other
//  doesn't — so there is now exactly one copy, used by both.
//

/// e{n,}  →  e·e·…·e·e*   (n mandatory copies followed by Kleene star)
func expandRepeatMin(_ e: Expression, n: Int) -> Expression {
    var result: Expression = .repeat(e)
    for _ in 0 ..< n { result = .concatenation(e, result) }
    return result
}

/// e{n,m}  →  e·…·e·e?·…·e?   (n required, then m−n optional)
func expandRepeatMinMax(_ e: Expression, n: Int, m: Int) -> Expression {
    guard n <= m else { return .string("") }
    var parts: [Expression] = Array(repeating: e, count: n)
    parts += Array(repeating: .optional(e), count: m - n)
    guard !parts.isEmpty else { return .string("") }
    return parts.dropFirst().reduce(parts[0]) { .concatenation($0, $1) }
}

/// Expands a numerical interval into a union of decimal literal strings.
func expandInterval(lo: Int, hi: Int, digits: Int) -> Expression {
    let exprs: [Expression] = (lo ... hi).map { n in
        let s = digits > 0
            ? String(n).leftPadding(toLength: digits, withPad: "0")
            : String(n)
        return stringToExpression(s)
    }
    guard !exprs.isEmpty else { return .string("") }
    return exprs.dropFirst().reduce(exprs[0]) { .union($0, $1) }
}

/// Builds a `.concatenation` chain of `.char` leaves for a literal string.
func stringToExpression(_ s: String) -> Expression {
    let chars = Array(s)
    guard !chars.isEmpty else { return .string("") }
    return chars.dropFirst().reduce(.char(chars[0])) { .concatenation($0, .char($1)) }
}
