//
//  RegexNode.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/21.
//

//
//  RegexNode.swift
//  Automaton
//
//  Replaces the former class-based `ParseNode` / `Or` / `Con` / `Opt` / `Rep` /
//  `Leaf` hierarchy (see git history) with a single immutable, indirect value
//  type plus pure functions over it. Used exclusively by the Berry-Sethi
//  (Glushkov / position-DFA) construction in `BerrySethi.swift`.
//
//  Why a value type instead of a class hierarchy
//  ──────────────────────────────────────────────
//  The old design stored `nullable` / `first` / `last` / `follow` as *mutable
//  vars* directly on each node, computed them via two separate tree
//  traversals (postorder for attributes, preorder for followpos), and used
//  `weak var parent` plus a "phantom root" node purely so the traversal would
//  visit the real root (it only applied its closure when `parent != nil`).
//  Every one of those mechanisms was a distinct source of bugs:
//
//    • mutable per-node state          → stale/aliased values if a node is
//                                         visited more than once or reused
//    • dynamic `is Or` / `is Con` checks with a `fatalError()` default
//                                       → a missed case is a runtime crash,
//                                         not a compile error
//    • `weak var parent` + phantom root → the entire root-attributes-never-
//                                         computed bug class
//    • two passes with an intermediate "node.follow" field
//                                       → conflating node-level follow
//                                         propagation with the per-position
//                                         followpos table (this is exactly
//                                         what caused the historical Con-rule
//                                         bug)
//
//  `RegexNode` is `Equatable`, carries no identity, and `computeAttributes` /
//  `computeFollowPos` are pure functions: given a node they return a fresh
//  value, full stop. There is no parent pointer to maintain and therefore no
//  "did the traversal actually reach the root" question to get wrong — calling
//  `computeAttributes(for: root)` IS the answer for the root, unconditionally.
//
//  Note there is also no `.optional` case. `a?` is represented as
//  `.alternation(a, .empty)` (i.e. `a|ε`), which `computeAttributes` already
//  handles correctly for `.alternation` with no extra constructor, and so no
//  extra case for every switch in this file or in `BerrySethi` to keep in
//  sync. One fewer constructor than `ParseNode` had (no `Opt`), and one
//  fewer place a future case could be forgotten.
//
public indirect enum RegexNode: Equatable {
    case empty
    case symbol(Character, id: Int)
    case concat(RegexNode, RegexNode)
    case alternation(RegexNode, RegexNode)
    case star(RegexNode)
}

extension RegexNode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "ε"
        case let .symbol(ch, id):
            return "\(ch)#\(id)"
        case let .concat(l, r):
            return "(\(l.description)\(r.description))"
        case let .alternation(l, r):
            return "(\(l.description)|\(r.description))"
        case let .star(e):
            return "(\(e.description))*"
        }
    }
}

// MARK: - Syntax Attributes

public struct SyntaxAttributes: Equatable {
    let nullable: Bool
    let firstpos: Set<Int>
    let lastpos: Set<Int>
}

/// Recursively calculates, using Swift's switch statements and pattern matching,
/// whether the node can match the empty string (nullable), the positions that
/// can start a match (firstpos), and the positions that can end a match
/// (lastpos).
///
/// - Note: This is the textbook, one-definition-per-case formulation (Aho, Lam,
///   Sethi & Ullman §3.9). It is kept around as the reference implementation —
///   it is what the unit tests check the optimized traversal *against* — but
///   it is **not** what `BerrySethi.construct()` uses internally. See
///   `computeAttributesAndFollowPos(for:into:)` below for why.
public func computeAttributes(for node: RegexNode) -> SyntaxAttributes {
    switch node {
    case .empty:
        return SyntaxAttributes(nullable: true, firstpos: [], lastpos: [])

    case .symbol(_, let id):
        return SyntaxAttributes(nullable: false, firstpos: [id], lastpos: [id])

    case .alternation(let left, let right):
        let leftAttr = computeAttributes(for: left)
        let rightAttr = computeAttributes(for: right)
        return SyntaxAttributes(
            nullable: leftAttr.nullable || rightAttr.nullable,
            firstpos: leftAttr.firstpos.union(rightAttr.firstpos),
            lastpos: leftAttr.lastpos.union(rightAttr.lastpos)
        )

    case .concat(let left, let right):
        let leftAttr = computeAttributes(for: left)
        let rightAttr = computeAttributes(for: right)
        let firstpos = leftAttr.nullable ? leftAttr.firstpos.union(rightAttr.firstpos) : leftAttr.firstpos
        let lastpos = rightAttr.nullable ? leftAttr.lastpos.union(rightAttr.lastpos) : rightAttr.lastpos
        return SyntaxAttributes(
            nullable: leftAttr.nullable && rightAttr.nullable,
            firstpos: firstpos,
            lastpos: lastpos
        )

    case .star(let operand):
        let opAttr = computeAttributes(for: operand)
        return SyntaxAttributes(
            nullable: true,
            firstpos: opAttr.firstpos,
            lastpos: opAttr.lastpos
        )
    }
}

/// Computes the followpos table.
///
/// The core of the Berry-Sethi construction is the followpos function, which
/// dictates what positions can immediately follow another position in the
/// regular expression.
///
/// - Warning: **Performance.** This formulation calls `computeAttributes(for:)`
///   on every subtree at every level of `computeFollowPos`'s own recursion.
///   `computeAttributes` is itself O(size of subtree), so the total cost here
///   is O(n²) in the size of the expression — for a long concatenation chain
///   (a multi-character keyword, an identifier pattern with several
///   alternatives, etc. — exactly the shapes a lexer's token grammar tends to
///   produce) this is quadratic blow-up for no algorithmic reason: every
///   attribute is already fully determined by its immediate children's
///   attributes, so it never needs to be recomputed once known.
///   `BerrySethi.construct()` therefore does **not** call this function; it
///   uses `computeAttributesAndFollowPos(for:into:)`, a single bottom-up pass
///   that computes attributes once and threads them through the followpos
///   computation as it goes, giving the same result in O(n). This function is
///   kept as the clear, textbook-literal reference — and the test suite
///   cross-checks the two against each other — but is not on the
///   construction's hot path.
public func computeFollowPos(for node: RegexNode, followTable: inout [Int: Set<Int>]) {
    switch node {
    case .concat(let left, let right):
        computeFollowPos(for: left, followTable: &followTable)
        computeFollowPos(for: right, followTable: &followTable)

        let leftLast = computeAttributes(for: left).lastpos
        let rightFirst = computeAttributes(for: right).firstpos

        for pos in leftLast {
            followTable[pos, default: []].formUnion(rightFirst)
        }

    case .star(let operand):
        computeFollowPos(for: operand, followTable: &followTable)
        let opAttr = computeAttributes(for: operand)
        for pos in opAttr.lastpos {
            followTable[pos, default: []].formUnion(opAttr.firstpos)
        }

    case .alternation(let left, let right):
        computeFollowPos(for: left, followTable: &followTable)
        computeFollowPos(for: right, followTable: &followTable)

    case .empty, .symbol:
        break
    }
}

/// Single bottom-up pass that computes `SyntaxAttributes` for `node` **and**
/// accumulates `followTable` along the way, in O(n) total.
///
/// This is `computeAttributes` and `computeFollowPos` fused into one
/// recursion: each call computes its children's attributes exactly once (by
/// recursing), immediately applies the followpos rule for `.concat` / `.star`
/// using those freshly-computed values, and returns the combined attributes
/// upward — nothing is ever recomputed. The case-by-case logic is identical to
/// the two functions above; only the control flow changes (one traversal
/// instead of two, no repeated `computeAttributes` calls).
///
/// This is the function `BerrySethi.construct()` actually calls.
func computeAttributesAndFollowPos(
    for node: RegexNode,
    into followTable: inout [Int: Set<Int>]
) -> SyntaxAttributes {
    switch node {
    case .empty:
        return SyntaxAttributes(nullable: true, firstpos: [], lastpos: [])

    case .symbol(_, let id):
        return SyntaxAttributes(nullable: false, firstpos: [id], lastpos: [id])

    case .alternation(let left, let right):
        let leftAttr = computeAttributesAndFollowPos(for: left, into: &followTable)
        let rightAttr = computeAttributesAndFollowPos(for: right, into: &followTable)
        return SyntaxAttributes(
            nullable: leftAttr.nullable || rightAttr.nullable,
            firstpos: leftAttr.firstpos.union(rightAttr.firstpos),
            lastpos: leftAttr.lastpos.union(rightAttr.lastpos)
        )

    case .concat(let left, let right):
        let leftAttr = computeAttributesAndFollowPos(for: left, into: &followTable)
        let rightAttr = computeAttributesAndFollowPos(for: right, into: &followTable)

        // ∀ p ∈ lastpos(left): followpos(p) ∪= firstpos(right)
        for pos in leftAttr.lastpos {
            followTable[pos, default: []].formUnion(rightAttr.firstpos)
        }

        let firstpos = leftAttr.nullable ? leftAttr.firstpos.union(rightAttr.firstpos) : leftAttr.firstpos
        let lastpos = rightAttr.nullable ? leftAttr.lastpos.union(rightAttr.lastpos) : rightAttr.lastpos
        return SyntaxAttributes(
            nullable: leftAttr.nullable && rightAttr.nullable,
            firstpos: firstpos,
            lastpos: lastpos
        )

    case .star(let operand):
        let opAttr = computeAttributesAndFollowPos(for: operand, into: &followTable)
        // ∀ p ∈ lastpos(operand): followpos(p) ∪= firstpos(operand)   (back-edge)
        for pos in opAttr.lastpos {
            followTable[pos, default: []].formUnion(opAttr.firstpos)
        }
        return SyntaxAttributes(nullable: true, firstpos: opAttr.firstpos, lastpos: opAttr.lastpos)
    }
}
