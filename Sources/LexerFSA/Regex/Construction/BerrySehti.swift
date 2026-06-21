//
//  RegexBerrySehti.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/03.
//

import Foundation

// Berry-Sethi / Glushkov / Direct Construction
//
// Transforms a regular expression directly into a position DFA without ever
// creating ε-transitions or an intermediate NFA.
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │ Algorithm (Aho, Lam, Sethi & Ullman §3.9 – "From a Regular Expression   │
// │ to a DFA")                                                              │
// │                                                                         │
// │ 1. Augment: append the # sentinel to form the augmented expression r#.  │
// │    The # leaf receives the highest position N.                          │
// │                                                                         │
// │ 2. Build a positional tree (`RegexNode`) in one pass over the           │
// │    Expression AST. Every leaf gets a unique integer position 1…N from a │
// │    local counter. Record position → Expression in leafExpressions       │
// │    simultaneously.                                                      │
// │                                                                         │
// │ 3. Compute nullable, firstpos, lastpos AND followpos together, bottom-  │
// │    up, in a single O(n) pass (`computeAttributesAndFollowPos`).         │
// │                                                                         │
// │ 4. DFA construction directly from followpos:                            │
// │    initState = firstpos(root)                                           │
// │    while unmarked DFA state S exists:                                   │
// │      for each symbol a ≠ # in the alphabet:                             │
// │        U = ⋃ followpos(p) for p ∈ S that match a                        │
// │        if U ≠ ∅: add transition S --a→ U                                │
// │    S is accepting iff N ∈ S                                             │
// └─────────────────────────────────────────────────────────────────────────┘
//
// Design notes — migration from `ParseNode` to `RegexNode`
// ──────────────────────────────────────────────────────────
// The parse tree used to be a class hierarchy (`ParseNode` / `Or` / `Con` /
// `Opt` / `Rep` / `Leaf`, see git history) with mutable per-node attribute
// fields, a `weak var parent`, and two separate traversals (postorder for
// nullable/first/last, preorder for followpos) glued together by a "phantom
// root" node that existed solely to dodge a `parent != nil` guard. It is now
// `RegexNode` (see RegexNode.swift): an immutable, indirect value enum, plus
// pure functions over it. Three things changed as a direct result:
//
//   • No `Opt` case. `a?` is built as `.alternation(a, .empty)` (`a|ε`).
//     `.alternation`'s existing rule already produces the right
//     nullable/firstpos/lastpos for this with no extra logic anywhere.
//
//   • No dummy "never matched" leaf for the empty string. The old code
//     modelled `.string("")` with an `Opt` wrapping a `Leaf` carrying a
//     sentinel character ("\0") specifically chosen not to collide with the
//     real alphabet. `RegexNode.empty` already means exactly
//     nullable/firstpos=∅/lastpos=∅ with **no** leaf at all, so
//     `.string("")` now maps directly to `.empty` — no placeholder character,
//     no position consumed, nothing to accidentally match.
//
//   • Attributes and followpos are computed in one O(n) traversal
//     (`computeAttributesAndFollowPos`, in RegexNode.swift) instead of two.
//     There is no per-node mutable `follow` field threading state between a
//     preorder pass and the followpos table — the `.concat` case applies the
//     textbook rule directly, which also removes any possibility of
//     reintroducing the historical bug where a node-level "follow" set got
//     conflated with the per-position followpos table.
//
// One thing that did *not* change, and is worth calling out explicitly: the
// augmented `#` sentinel is still represented as a genuine *leaf* (a
// `RegexNode.symbol` with its own position) and is recorded under
// `Expression.empty` in `leafExpressions` — it is emphatically **not**
// `RegexNode.empty`. `RegexNode.empty` is the structural epsilon described
// above (no position, vanishes from every firstpos/lastpos set).
// Conflating the two would silently reproduce "the DFA never has a final
// state" — the new design doesn't prevent that mistake by construction, it
// only makes it a single, clearly-commented call site (`makeLeaf(expr)` in
// the `.empty` case of `buildRegexNode`) instead of a half-page reference
// counting fix. `dfaHasFinalStates` / `classicAhoCatDotStarAbb` etc. in the
// test suite guard against this regressing.
//
// Bugs inherited (and still fixed) from the previous implementation
// ───────────────────────────────────────────────────────────────────
// These were genuine logic bugs independent of which tree representation is
// used, so the fixes carry over unchanged:
//
//   • Leaf positions come from a private, instance-local counter, not
//     `Counter.shared` — two `BerrySethi` instances (or a `BerrySethi` run
//     after a `Thompson` run, which also used `Counter.shared`) must not
//     observe each other's leaf numbering.
//   • The augmented parser always enables `.empty` so `#` is recognised as
//     `Expression.empty` rather than a literal character.
//   • `.string(s)` expands into a chain of single-character positions (one
//     `RegexNode.symbol` per character) rather than one leaf for the whole
//     string.
//   • The parse tree and `leafExpressions` lookup table are built in one pass
//     over the `Expression` AST so position numbering can never drift out of
//     sync with character ranges / strings / intervals, which contribute a
//     different number of raw characters than leaves.

extension Regex {

    struct BerrySethi: RegularLanguageBuilder {

        let debug = false

        // RegularLanguageBuilder
        var expression: Expression = .empty

        // Parser
        var parser: RegexParser

        // MARK: – Positional data

        /// Maps leaf position p (1-based) → the Expression at that leaf.
        /// Built atomically with the parse tree so positions are always aligned.
        /// This remains the single source of truth for *matching* — including
        /// for leaf kinds (ranges, anyChar, the sentinel) that `RegexNode.symbol`
        /// cannot represent precisely with its one `Character` payload. See
        /// `representativeCharacter(for:)` and `leafMatches(position:character:)`.
        var leafExpressions: [Int: Expression] = [:]

        /// All input characters that appear in the expression (excludes # sentinel).
        var alphabet: Set<Character> = []

        /// followpos(p) for each leaf position p.
        var followpos: [Int: Set<Int>] = [:]

        // Local leaf-position counter, independent of Counter.shared.
        private var leafCounter: Int = 0

        private mutating func nextLeafPos() -> Int {
            leafCounter += 1
            return leafCounter
        }

        // MARK: – DFA state registry

        /// Maps a frozen set of leaf positions → integer DFA-state label.
        /// The first call (for the initial position set) always returns 0.
        var dfaStateMap = Dictionary<Set<Int>, Int>()
        private var dfaStateCounter: Int = 0

        private mutating func dfaStateID(for positions: Set<Int>) -> Int {
            if let id = dfaStateMap[positions] { return id }
            let id = dfaStateCounter
            dfaStateCounter += 1
            dfaStateMap[positions] = id
            return id
        }

        // MARK: – Initialiser

        init(expression: String, flags: SyntaxOptions) {
            // Always enable .empty so the parser recognises '#' as Expression.empty.
            // Without this flag '#' is consumed as a plain character by parseCharExp().
            let augmentedFlags = flags.union(.empty)
            parser = RegexParser(expression: expression + "#", augmentedFlags)
        }

        mutating func construct() throws -> State<Regex> {

            // Parse the augmented expression r#.
            self.expression = try parser.parse()

            // Build the positional tree. No phantom parent node is needed: a
            // value type has no "this node has no parent" special case to
            // dodge, so `root`'s own attributes are simply the result of
            // calling the attribute function on it directly.
            let root = buildRegexNode(self.expression)

            // nullable, firstpos, lastpos AND followpos, computed together in
            // a single bottom-up O(n) pass. See RegexNode.swift for why this
            // is not the same as calling `computeAttributes` + `computeFollowPos`.
            let rootAttrs = computeAttributesAndFollowPos(for: root, into: &followpos)

            if debug {
                print("=== Berry-Sethi: positions ===")
                for (pos, expr) in leafExpressions.sorted(by: { $0.key < $1.key }) {
                    print("  \(pos): \(expr.description)")
                }
                print("alphabet: \(alphabet.sorted())")
                print("firstpos(root): \(rootAttrs.firstpos.sorted())")
                print("lastpos(root):  \(rootAttrs.lastpos.sorted())")
                print("followpos:")
                for (p, fps) in followpos.sorted(by: { $0.key < $1.key }) {
                    print("  followpos(\(p)) = \(fps.sorted())")
                }
            }

            // DFA construction directly from followpos sets.
            return buildDFA(initPositions: rootAttrs.firstpos)
        }

        // MARK: – Positional tree construction

        /// Walks the `Expression` AST once and atomically:
        ///   • builds the corresponding `RegexNode`,
        ///   • assigns the next local position to every leaf,
        ///   • records the leaf's `Expression` in `leafExpressions`.
        ///
        /// This guarantees the tree's leaf positions and the lookup table are
        /// always perfectly aligned — regardless of character ranges, string
        /// literals, or any other multi-character `Expression`.
        private mutating func buildRegexNode(_ expr: Expression) -> RegexNode {
            switch expr {

            case let .union(e1, e2):
                return .alternation(buildRegexNode(e1), buildRegexNode(e2))

            case let .concatenation(e1, e2):
                return .concat(buildRegexNode(e1), buildRegexNode(e2))

            case let .optional(e):
                // a? ≡ a|ε — see "Design notes" above. No dedicated leaf or
                // node kind is needed; `.alternation` with `.empty` already
                // has exactly the right nullable/firstpos/lastpos.
                return .alternation(buildRegexNode(e), .empty)

            case let .repeat(e):
                return .star(buildRegexNode(e))

            // Derived repetition operators: expand to primitives so each copy
            // of the sub-expression gets independent positions.
            case let .repeatMin(e, n):
                return buildRegexNode(expandRepeatMin(e, n: n))

            case let .repeatMinMax(e, n, m):
                return buildRegexNode(expandRepeatMinMax(e, n: n, m: m))

            // ── Leaf cases ──────────────────────────────────────────────────

            case let .char(ch):
                alphabet.insert(ch)
                return makeLeaf(expr)

            case let .charRange(lo, hi):
                // One leaf position covering the entire range. Expand the
                // range into `alphabet` so the DFA loop can test individual
                // characters against this position via leafMatches().
                if let loV = lo.unicodeScalars.first?.value,
                   let hiV = hi.unicodeScalars.first?.value, loV <= hiV {
                    for v in loV ... hiV {
                        if let s = Unicode.Scalar(v) { alphabet.insert(Character(s)) }
                    }
                }
                return makeLeaf(expr)

            case .anyChar:
                // Match any single character; expand printable ASCII into alphabet.
                for v in UInt32(0x20) ... UInt32(0x7E) {
                    if let s = Unicode.Scalar(v) { alphabet.insert(Character(s)) }
                }
                return makeLeaf(expr)

            case let .string(s):
                // A string literal is a chain of single-character positions.
                // Expanding it into nested `.concat` nodes gives every
                // character its own independent position, matching the
                // theoretical requirement.
                guard !s.isEmpty else {
                    // ε — modelled directly as `.empty`: nullable, firstpos =
                    // lastpos = ∅, no leaf/position consumed at all.
                    return .empty
                }
                let chars = Array(s)
                var result = buildRegexNode(.char(chars[0]))
                for i in 1 ..< chars.count {
                    result = .concat(result, buildRegexNode(.char(chars[i])))
                }
                return result

            case .anyString:
                return buildRegexNode(.repeat(.anyChar))

            case let .interval(lo, hi, digits):
                return buildRegexNode(expandInterval(lo: lo, hi: hi, digits: digits))

            case .empty:
                // The '#' sentinel (or an explicit empty-language literal).
                // This MUST become a real leaf with its own position — NOT
                // `RegexNode.empty`. See "Design notes" above.
                return makeLeaf(expr)
            }
        }

        // MARK: – Leaf factory

        private mutating func makeLeaf(_ expr: Expression) -> RegexNode {
            let pos = nextLeafPos()
            leafExpressions[pos] = expr
            return .symbol(representativeCharacter(for: expr), id: pos)
        }

        /// A cosmetic stand-in character for leaf kinds that aren't a single
        /// literal character (ranges, "any char", the sentinel).
        ///
        /// `RegexNode.symbol` carries exactly one `Character`, but several
        /// `Expression` leaf kinds (charRange, anyChar, the `#` sentinel) are
        /// not a single literal character. Matching never reads this value —
        /// `leafMatches(position:character:)` always consults
        /// `leafExpressions[id]`, which is the authoritative record of what a
        /// position actually matches. This function exists purely so
        /// `RegexNode.symbol`'s `description` stays readable in debug output.
        private func representativeCharacter(for expr: Expression) -> Character {
            switch expr {
            case let .char(ch): return ch
            case let .charRange(lo, _): return lo
            case .anyChar: return "."
            case .empty: return "#"
            default: return "?"
            }
        }

        // MARK: – Expansion helpers for derived operators

        /// e{n,}  →  e·e·…·e·e*   (n mandatory copies followed by Kleene star)
        private func expandRepeatMin(_ e: Expression, n: Int) -> Expression {
            var result: Expression = .repeat(e)
            for _ in 0 ..< n { result = .concatenation(e, result) }
            return result
        }

        /// e{n,m}  →  e·…·e·e?·…·e?   (n required, then m−n optional)
        private func expandRepeatMinMax(_ e: Expression, n: Int, m: Int) -> Expression {
            guard n <= m else { return .string("") }
            var parts: [Expression] = Array(repeating: e, count: n)
            parts += Array(repeating: .optional(e), count: m - n)
            guard !parts.isEmpty else { return .string("") }
            return parts.dropFirst().reduce(parts[0]) { .concatenation($0, $1) }
        }

        /// Expands a numerical interval into a union of decimal literal strings.
        private func expandInterval(lo: Int, hi: Int, digits: Int) -> Expression {
            let exprs: [Expression] = (lo ... hi).map { n in
                let s = digits > 0
                    ? String(n).leftPadding(toLength: digits, withPad: "0")
                    : String(n)
                return stringToExpression(s)
            }
            guard !exprs.isEmpty else { return .string("") }
            return exprs.dropFirst().reduce(exprs[0]) { .union($0, $1) }
        }

        private func stringToExpression(_ s: String) -> Expression {
            let chars = Array(s)
            guard !chars.isEmpty else { return .string("") }
            return chars.dropFirst().reduce(.char(chars[0])) { .concatenation($0, .char($1)) }
        }

        // MARK: – DFA construction from followpos

        private mutating func buildDFA(initPositions: Set<Int>) -> State<Regex> {
            let sentinelPos = leafCounter          // the # position is the highest one
            _ = dfaStateID(for: initPositions)      // state 0 = initial

            var worklist: [Set<Int>] = [initPositions]
            var visited = Set<Set<Int>>()
            var dfaFinals = Set<Int>()
            var dfaTrans = Set<Transition>()

            while !worklist.isEmpty {
                let positions = worklist.removeFirst()
                guard !visited.contains(positions) else { continue }
                visited.insert(positions)

                let from = dfaStateID(for: positions)

                // A DFA state containing the # sentinel position is accepting.
                if positions.contains(sentinelPos) {
                    dfaFinals.insert(from)
                }

                // For each input symbol a (# excluded), compute the follow set.
                for a in alphabet {
                    let matching = positions.filter { leafMatches(position: $0, character: a) }
                    guard !matching.isEmpty else { continue }

                    let next = matching.reduce(into: Set<Int>()) { acc, p in
                        acc.formUnion(followpos[p, default: []])
                    }
                    guard !next.isEmpty else { continue }

                    let to = dfaStateID(for: next)
                    dfaTrans.insert(Transition(from: from, .char(a), to: to))
                    if !visited.contains(next) { worklist.append(next) }
                }
            }

            if debug {
                print("=== Berry-Sethi: DFA ===")
                print("initial : \(dfaStateID(for: initPositions))")
                print("finals  : \(dfaFinals.sorted())")
                dfaTrans.sorted().forEach { print("  \($0)") }
            }

            return .dfa(
                initial: dfaStateID(for: initPositions),
                finals: dfaFinals,
                transitions: dfaTrans,
                minimal: false,
                tokenMap: [:]
            )
        }

        // MARK: – Leaf-to-character matching

        /// Returns true iff the leaf at position `p` accepts the character `ch`.
        /// Delegates to the stored Expression rather than to `RegexNode.symbol`'s
        /// cosmetic `Character` payload, so range expressions are handled
        /// correctly and there is no position-alignment risk.
        private func leafMatches(position p: Int, character ch: Character) -> Bool {
            guard let expr = leafExpressions[p] else { return false }
            switch expr {
            case let .char(c): return c == ch
            case let .charRange(lo, hi): return lo <= ch && ch <= hi
            case .anyChar: return true
            case .anyString: return true
            case .empty: return false   // '#' sentinel — never matched
            case let .string(s): return s.count == 1 && s.first == ch
            default: return false
            }
        }
    }
}
