//
//  PartialDerivative.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/22.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

//  Pure functions implementing Antimirov's partial-derivative calculus
//  directly over `Expression` — the same syntax tree the parser already
//  produces. Unlike Berry-Sethi (RegexNode.swift), this method needs no
//  separate position-tree representation at all: derivatives are taken
//  directly against the syntax, and a fresh `Expression` is the result.
//
//  Background
//  ──────────
//  Brzozowski (1964) defined the derivative of a regular expression `e`
//  with respect to a symbol `c`, written `∂e/∂c`, as a single expression
//  denoting "what `e` becomes after consuming one leading `c`". Used naively
//  that way, the derivative of e.g. a long alternation keeps re-folding
//  results back through `.union`, and telling whether two derivative
//  expressions denote the same language again needs an equivalence check
//  (Brzozowski's original algorithm handles this with ACI-equivalence
//  classes — associativity, commutativity, idempotence of `|`).
//
//  Antimirov (1995) instead defines the *partial* derivative, `pd(e, c)`, as
//  a *set* of expressions: distribute the alternation across the set up
//  front, and take the derivative of each disjunct on its own, rather than
//  folding the results back into one `.union` chain. The key theorem is
//  that the collection of all partial-derivative sets reachable from a
//  fixed `e` is finite — bounded by the number of symbol occurrences in
//  `e` — which gives a deterministic automaton directly: each state IS one
//  `Set<Expression>`, and two states denote the same set of terms iff
//  they're `==`. Swift's synthesized `Hashable`/`Equatable` for `Expression`
//  (it already derives this, see Expression.swift) does the ACI-equivalence
//  bookkeeping for free; no canonical form or extra equivalence check is
//  needed anywhere in this file.
//
//  See Antimirov.swift for how a `Set<Expression>` worklist turns this into
//  an actual DFA, and BrzozowskiMinimize.swift for how that DFA is then
//  minimized (a *different* algorithm than this file's partial derivatives,
//  despite sharing Brzozowski's name — see the note there).
//

// MARK: - Nullability

/// Returns `true` iff `e` can match the empty string.
///
/// `repeatMin`/`repeatMinMax`/`interval` defer to the same expansion
/// (`expandRepeatMin` etc., in Expression+Desugar.swift) that `BerrySethi`
/// uses to build its position tree, rather than re-deriving their
/// nullability rules by hand here. The naive-looking direct rule for
/// `e{n,m}` — "nullable iff n == 0" — is actually wrong when `e` itself is
/// nullable (e.g. `(a?){2,4}` is nullable for any n), and deferring to the
/// expansion sidesteps having to get that right twice in two different
/// files.
public func nullable(_ e: Expression) -> Bool {
    switch e {
    case let .union(e1, e2):
        return nullable(e1) || nullable(e2)
    case let .concatenation(e1, e2):
        return nullable(e1) && nullable(e2)
    case .optional:
        return true
    case .repeat:
        return true
    case let .repeatMin(e, n):
        return nullable(expandRepeatMin(e, n: n))
    case let .repeatMinMax(e, n, m):
        return nullable(expandRepeatMinMax(e, n: n, m: m))
    case .charRange:
        return false
    case .char:
        return false
    case .anyChar:
        return false
    case let .string(s):
        return s.isEmpty
    case .anyString:
        return true
    case let .interval(lo, hi, digits):
        return nullable(expandInterval(lo: lo, hi: hi, digits: digits))
    case .empty:
        return false   // the empty *language* (matches nothing, not even ε)
    }
}

// MARK: - Smart concatenation

/// Concatenation with the algebraic identities applied eagerly, so partial-
/// derivative terms don't accumulate dead weight as they're threaded through
/// repeated concatenation:
///   0·e = e·0 = 0     (concatenating with the empty language is impossible)
///   ε·e = e·ε = e     (concatenating with the empty string is a no-op)
func smartConcat(_ e1: Expression, _ e2: Expression) -> Expression {
    if e1 == .empty || e2 == .empty { return .empty }
    if e1 == .string("") { return e2 }
    if e2 == .string("") { return e1 }
    return .concatenation(e1, e2)
}

// MARK: - Partial derivatives

/// Antimirov's partial derivative of `e` with respect to the character `c`:
/// the set of expressions denoting "what's left to match after consuming a
/// leading `c`".
///
/// By convention, a derivative that "goes nowhere" is represented by the
/// *absence* of a term from the returned set, not by including `.empty` (the
/// empty-language expression) as a member of it — every base case below
/// returns `[]` rather than `[.empty]`. `smartConcat` can still introduce a
/// literal `.empty` term if the original expression itself concatenates with
/// the empty language (e.g. the pattern `a#b`, which matches nothing); see
/// `Antimirov.swift`'s construction loop for where such dead terms are
/// filtered back out when assembling each DFA state.
public func partialDerivative(_ e: Expression, withRespectTo c: Character) -> Set<Expression> {
    switch e {
    case .empty:
        return []                                  // ∂(0)/∂c = ∅

    case let .string(s) where s.isEmpty:
        return []                                  // ∂(ε)/∂c = ∅

    case let .char(ch):
        return ch == c ? [.string("")] : []

    case let .charRange(lo, hi):
        return (lo <= c && c <= hi) ? [.string("")] : []

    case .anyChar:
        return [.string("")]

    case let .string(s):
        // s = c₀c₁…cₖ. One step consumes c₀ (if it matches) and leaves the
        // remaining suffix as a literal string.
        guard let first = s.first, first == c else { return [] }
        return [.string(String(s.dropFirst()))]

    case let .union(e1, e2):
        return partialDerivative(e1, withRespectTo: c).union(partialDerivative(e2, withRespectTo: c))

    case let .optional(e):
        // a? ≡ a|ε, and ∂(ε)/∂c contributes nothing.
        return partialDerivative(e, withRespectTo: c)

    case let .repeat(e):
        // ∂(e*)/∂c = ∂(e)/∂c · e*  — note the *un-derived* e* reappears as
        // the continuation: this is the back-edge that makes the star loop.
        return Set(partialDerivative(e, withRespectTo: c).map { smartConcat($0, .repeat(e)) })

    case let .concatenation(e1, e2):
        // ∂(e1·e2)/∂c = (∂(e1)/∂c · e2)  ∪  (∂(e2)/∂c, but only if e1 is nullable)
        var result = Set(partialDerivative(e1, withRespectTo: c).map { smartConcat($0, e2) })
        if nullable(e1) {
            result.formUnion(partialDerivative(e2, withRespectTo: c))
        }
        return result

    case .anyString:
        // @ ≡ (.)* — deferring to that expansion (rather than special-casing
        // @ directly) keeps this file's case list matching BerrySethi's.
        return partialDerivative(.repeat(.anyChar), withRespectTo: c)

    case let .repeatMin(e, n):
        return partialDerivative(expandRepeatMin(e, n: n), withRespectTo: c)

    case let .repeatMinMax(e, n, m):
        return partialDerivative(expandRepeatMinMax(e, n: n, m: m), withRespectTo: c)

    case let .interval(lo, hi, digits):
        return partialDerivative(expandInterval(lo: lo, hi: hi, digits: digits), withRespectTo: c)
    }
}

// MARK: - Concrete alphabet

/// Collects the set of literal characters `e` can actually consume, so the
/// construction loop in `Antimirov.swift` knows which characters are worth
/// trying `partialDerivative(_:withRespectTo:)` against at each state.
///
/// Mirrors the same printable-ASCII convention `BerrySethi.buildRegexNode`
/// already uses for `.anyChar`/`.anyString` (0x20…0x7E), so the two
/// construction methods agree on what "any character" means. `repeatMin` /
/// `repeatMinMax` recurse into their operand directly rather than via their
/// (potentially much larger, or even unbounded for `interval`) expansion —
/// the expansion only ever introduces characters already present in the
/// operand, or decimal digits for `.interval`, so there is no need to
/// materialize it just to collect an alphabet.
func concreteAlphabet(of e: Expression) -> Set<Character> {
    switch e {
    case let .union(e1, e2):
        return concreteAlphabet(of: e1).union(concreteAlphabet(of: e2))
    case let .concatenation(e1, e2):
        return concreteAlphabet(of: e1).union(concreteAlphabet(of: e2))
    case let .optional(e):
        return concreteAlphabet(of: e)
    case let .repeat(e):
        return concreteAlphabet(of: e)
    case let .repeatMin(e, _):
        return concreteAlphabet(of: e)
    case let .repeatMinMax(e, _, _):
        return concreteAlphabet(of: e)
    case let .charRange(lo, hi):
        guard let loV = lo.unicodeScalars.first?.value,
              let hiV = hi.unicodeScalars.first?.value, loV <= hiV else { return [] }
        return Set((loV ... hiV).compactMap { Unicode.Scalar($0).map(Character.init) })
    case let .char(ch):
        return [ch]
    case .anyChar, .anyString:
        return Set((UInt32(0x20) ... UInt32(0x7E)).compactMap { Unicode.Scalar($0).map(Character.init) })
    case let .string(s):
        return Set(s)
    case .interval:
        return Set("0123456789")
    case .empty:
        return []
    }
}
