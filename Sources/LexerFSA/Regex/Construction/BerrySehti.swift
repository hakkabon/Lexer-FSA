//
//  RegexBerrySehti.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/03.
//  Copyright © 2020 hakkabon software. All rights reserved.
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
// │ 2. Build a positional parse tree in one pass over the Expression AST.   │
// │    Every leaf gets a unique integer position 1…N from a local counter.  │
// │    Record position → Expression in leafExpressions simultaneously.      │
// │                                                                         │
// │ 3. Compute nullable, firstpos, lastpos bottom-up (postorder).           │
// │                                                                         │
// │ 4. Compute followpos top-down (preorder):                               │
// │    • Con(c1, c2): ∀ p ∈ lastpos(c1): followpos(p) ∪= firstpos(c2)       │
// │    • Rep(c):      ∀ p ∈ lastpos(c):  followpos(p) ∪= firstpos(c)        │
// │    • Or, Opt:     children inherit the node's own follow set.           │
// │                                                                         │
// │ 5. DFA construction directly from followpos:                            │
// │    initState = firstpos(root)                                           │
// │    while unmarked DFA state S exists:                                   │
// │      for each symbol a ≠ # in the alphabet:                             │
// │        U = ⋃ followpos(p) for p ∈ S that match a                        │
// │        if U ≠ ∅: add transition S --a→ U                                │
// │    S is accepting iff N ∈ S                                             │
// └─────────────────────────────────────────────────────────────────────────┘
//
// Bugs fixed vs the original implementation
// ──────────────────────────────────────────
// BUG 1 — Counter.shared collision (critical)
//   Leaf.init() calls Counter.shared(), advancing the global singleton.
//   The original lookup table was keyed 1…N via zip(1...count, chars), but
//   leaf.pos values were whatever the shared counter happened to be — so
//   lookup[leaf.pos] always returned nil and every DFA transition was silently
//   dropped.  Fix: assign leaf.pos from a private, instance-local counter that
//   starts at 0 for every BerrySethi instance.
//
// BUG 2 — '#' sentinel not parsed as .empty (critical)
//   RegexParser.parseSimpleExpression() only recognises '#' as Expression.empty
//   when flags.contains(.empty).  The original code forwarded the caller's flags
//   unchanged, so '#' was parsed as a literal character — the augmented sentinel
//   was lost.  Fix: always enable .empty when constructing the augmented parser.
//
// BUG 3 — Root node never visited by postorder/preorder (critical)
//   ParseNode.postorder calls apply(self) only when self.parent != nil.
//   The root node has no parent, so its nullable/firstpos/lastpos are never
//   computed and root.first stays empty — the DFA's initial state was always
//   the empty set, producing an automaton that rejects every string.
//   Fix: wrap the real root in a phantom parent node so the traversal visits it.
//
// BUG 4 — Wrong followpos rule for Con (logic error)
//   The original code propagated firstpos(c2) into children[0].follow directly,
//   conflating the node-level follow set with the per-position followpos table.
//   Fix: apply the textbook rule — ∀ p ∈ lastpos(c1): followpos(p) ∪= firstpos(c2).
//
// BUG 5 — Leaf-count vs position-count mismatch (critical)
//   The original code built the parse tree via unparse() and the lookup table
//   via positional() (raw character counting).  For character ranges [a-z] the
//   string contributes ≥ 3 raw characters but only 1 Leaf node; for .string("abc")
//   the string has 3 raw characters but only 1 Leaf.  Fix: build the tree and
//   fill leafExpressions in a single pass over the Expression AST.
//
// BUG 6 — .string(s) creates one Leaf for multiple characters
//   A string literal like "abc" needs three independent positions.  Fix: expand
//   .string(s) into nested Con nodes of single .char leaves.

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
        var leafExpressions: [Int: Expression] = [:]

        /// All input characters that appear in the expression (excludes # sentinel).
        var alphabet: Set<Character> = []

        /// followpos(p) for each leaf position p.
        var followpos: [Int: Set<Int>] = [:]

        // Local leaf-position counter (BUG 1 fix)
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

        // MARK: – Initialiser (BUG 2 fix)

        init(expression: String, flags: SyntaxOptions) {
            // Always enable .empty so the parser recognises '#' as Expression.empty.
            // Without this flag '#' is consumed as a plain character by parseCharExp().
            let augmentedFlags = flags.union(.empty)
            parser = RegexParser(expression: expression + "#", augmentedFlags)
        }

        mutating func construct() throws -> State<Regex> {

            // Parse the augmented expression r#.
            self.expression = try parser.parse()

            // Build the positional parse tree.
            // `realRoot` is the Con(r, Leaf(#)) node whose first/last we need.
            // We wrap it in a phantom parent so the traversal visits it (BUG 3 fix).
            let realRoot = buildPositionalTree(self.expression)
            let phantom  = ParseNode()
            phantom.addChild(realRoot)

            // nullable, firstpos, lastpos (bottom-up postorder).
            // phantom.postorder visits realRoot because realRoot.parent = phantom ≠ nil.
            phantom.postorder { node in
                switch node {
                case is Or:
                    node.nullable = node.children[0].nullable || node.children[1].nullable
                    node.first    = node.children[0].first.union(node.children[1].first)
                    node.last     = node.children[0].last.union(node.children[1].last)
                case is Con:
                    node.nullable = node.children[0].nullable && node.children[1].nullable
                    node.first    = node.children[0].nullable
                        ? node.children[0].first.union(node.children[1].first)
                        : node.children[0].first
                    node.last     = node.children[1].nullable
                        ? node.children[0].last.union(node.children[1].last)
                        : node.children[1].last
                case is Opt:
                    node.nullable = true
                    node.first    = node.children[0].first
                    node.last     = node.children[0].last
                case is Rep:
                    node.nullable = true
                    node.first    = node.children[0].first
                    node.last     = node.children[0].last
                case is Leaf:
                    node.nullable = false
                    node.first    = [node.pos]
                    node.last     = [node.pos]
                default:
                    fatalError("BerrySethi postorder: unhandled ParseNode type \(type(of: node))")
                }
            }

            // followpos (top-down preorder, BUG 4 fix).
            //
            // The correct Con rule: for every p in lastpos(c1), followpos(p) ∪= firstpos(c2).
            // The original code set children[0].follow ∪= children[1].first which confused
            // the node-level follow propagation with the per-position followpos table.
            //
            // phantom.preorder applies the closure to phantom first (apply(phantom)), but
            // phantom is not Or/Con/Opt/Rep/Leaf — it falls through to `default` which we
            // handle as a no-op below.  All real nodes are visited correctly.
            phantom.preorder { node in
                switch node {
                case is Or:
                    node.children[0].follow.formUnion(node.follow)
                    node.children[1].follow.formUnion(node.follow)

                case is Con:
                    // c2 always inherits Con's follow.
                    node.children[1].follow.formUnion(node.follow)
                    // ∀ p ∈ lastpos(c1): followpos(p) ∪= firstpos(c2)
                    for p in node.children[0].last {
                        followpos[p, default: []].formUnion(node.children[1].first)
                        // If c2 is nullable, p also inherits Con's own follow.
                        if node.children[1].nullable {
                            followpos[p, default: []].formUnion(node.follow)
                        }
                    }
                    // c1 inherits Con's follow only when c2 is nullable.
                    if node.children[1].nullable {
                        node.children[0].follow.formUnion(node.follow)
                    }

                case is Opt:
                    node.children[0].follow.formUnion(node.follow)

                case is Rep:
                    // Back-edge: ∀ p ∈ lastpos(Rep): followpos(p) ∪= firstpos(Rep)
                    for p in node.last {
                        followpos[p, default: []].formUnion(node.first)
                    }
                    node.children[0].follow.formUnion(node.follow)

                case is Leaf:
                    // Leaves receive their follow set from their parent's rule above.
                    // Accumulate it now into the followpos table.
                    followpos[node.pos, default: []].formUnion(node.follow)

                default:
                    break   // phantom root — no action needed
                }
            }

            if debug {
                print("=== Berry-Sethi: positions ===")
                for (pos, expr) in leafExpressions.sorted(by: { $0.key < $1.key }) {
                    print("  \(pos): \(expr.description)")
                }
                print("alphabet: \(alphabet.sorted())")
                print("firstpos(root): \(realRoot.first.sorted())")
                print("lastpos(root):  \(realRoot.last.sorted())")
                print("followpos:")
                for (p, fps) in followpos.sorted(by: { $0.key < $1.key }) {
                    print("  followpos(\(p)) = \(fps.sorted())")
                }
            }

            // DFA construction directly from followpos sets.
            return buildDFA(root: realRoot)
        }

        // MARK: – Positional parse tree construction (BUG 5 & 6 fix)
        //
        // We walk the Expression AST once and atomically:
        //   • create the corresponding ParseNode,
        //   • assign the next local position to every leaf,
        //   • record the leaf's Expression in leafExpressions.
        //
        // This guarantees the parse tree positions and the lookup table are
        // always perfectly aligned — regardless of character ranges, string
        // literals, or any other multi-character Expression.

        private mutating func buildPositionalTree(_ expr: Expression) -> ParseNode {
            switch expr {

            case let .union(e1, e2):
                let node = Or()
                node.addChild(buildPositionalTree(e1))
                node.addChild(buildPositionalTree(e2))
                return node

            case let .concatenation(e1, e2):
                let node = Con()
                node.addChild(buildPositionalTree(e1))
                node.addChild(buildPositionalTree(e2))
                return node

            case let .optional(e):
                let node = Opt()
                node.addChild(buildPositionalTree(e))
                return node

            case let .repeat(e):
                let node = Rep()
                node.addChild(buildPositionalTree(e))
                return node

            // Derived repetition operators: expand to primitives so each copy
            // of the sub-expression gets independent positions.
            case let .repeatMin(e, n):
                return buildPositionalTree(expandRepeatMin(e, n: n))

            case let .repeatMinMax(e, n, m):
                return buildPositionalTree(expandRepeatMinMax(e, n: n, m: m))

            // ── Leaf cases ──────────────────────────────────────────────────

            case let .char(ch):
                alphabet.insert(ch)
                return makeLeaf(expr)

            case let .charRange(lo, hi):
                // One leaf position covering the entire range.
                // Expand the range into `alphabet` so the DFA loop can test
                // individual characters against this position via leafMatches().
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
                // BUG 6 fix: a string literal is a chain of single-character positions.
                // Expanding it into nested Con nodes gives every character its own
                // independent position, matching the theoretical requirement.
                guard !s.isEmpty else {
                    // ε — model as Opt(dummy) so nullable=true, firstpos=∅.
                    let opt   = Opt()
                    let dummy = makeLeaf(.char("\0"))   // never matched; not in alphabet
                    opt.addChild(dummy)
                    return opt
                }
                let chars = Array(s)
                if chars.count == 1 { return buildPositionalTree(.char(chars[0])) }
                var result = buildPositionalTree(.char(chars[0]))
                for i in 1 ..< chars.count {
                    let con = Con()
                    con.addChild(result)
                    con.addChild(buildPositionalTree(.char(chars[i])))
                    result = con
                }
                return result

            case .anyString:
                return buildPositionalTree(.repeat(.anyChar))

            case let .interval(lo, hi, digits):
                return buildPositionalTree(expandInterval(lo: lo, hi: hi, digits: digits))

            case .empty:
                // The '#' sentinel.  Deliberately NOT added to `alphabet`.
                return makeLeaf(expr)
            }
        }

        // MARK: – Leaf factory

        private mutating func makeLeaf(_ expr: Expression) -> Leaf {
            let leaf = Leaf(expr)          // Leaf.init() sets pos via Counter.shared;
            leaf.pos = nextLeafPos()       // we override with our local counter.
            leafExpressions[leaf.pos] = expr
            return leaf
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

        private mutating func buildDFA(root: ParseNode) -> State<Regex> {
            let sentinelPos  = leafCounter          // the # position is the highest one
            let initPositions = root.first
            _ = dfaStateID(for: initPositions)      // state 0 = initial

            var worklist: [Set<Int>] = [initPositions]
            var visited   = Set<Set<Int>>()
            var dfaFinals = Set<Int>()
            var dfaTrans  = Set<Transition>()

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
                initial:     dfaStateID(for: initPositions),
                finals:      dfaFinals,
                transitions: dfaTrans,
                minimal:     false,
                tokenMap:    [:]
            )
        }

        // MARK: – Leaf-to-character matching

        /// Returns true iff the leaf at position `p` accepts the character `ch`.
        /// Delegates to the stored Expression rather than a separate lookup table
        /// so range expressions are handled correctly and there is no
        /// position-alignment risk.
        private func leafMatches(position p: Int, character ch: Character) -> Bool {
            guard let expr = leafExpressions[p] else { return false }
            switch expr {
            case let .char(c):           return c == ch
            case let .charRange(lo, hi): return lo <= ch && ch <= hi
            case .anyChar:               return true
            case .anyString:             return true
            case .empty:                 return false   // '#' sentinel — never matched
            case let .string(s):         return s.count == 1 && s.first == ch
            default:                     return false
            }
        }
    }
}
