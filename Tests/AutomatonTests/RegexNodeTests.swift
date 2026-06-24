import Testing
@testable import LexerFSA

//  Tests for the `RegexNode` value-type AST that replaced the `ParseNode`
//  class hierarchy in the Berry-Sethi construction, and for the attribute /
//  followpos functions defined over it (`computeAttributes`,
//  `computeFollowPos`, `computeAttributesAndFollowPos`).
//
//  Organised in three layers:
//    1. Unit tests against hand-built `RegexNode` trees — no parser, no
//       `Regex`, no DFA. These pin down each case's textbook definition in
//       isolation and double as executable documentation of the new type.
//    2. A cross-check that the production O(n) traversal
//       (`computeAttributesAndFollowPos`) agrees with the textbook-literal
//       O(n²) reference (`computeAttributes` + `computeFollowPos`) on a range
//       of tree shapes, so the two can never silently drift apart.
//    3. End-to-end regressions, through the public `Regex` API, for the two
//       behavioural changes the redesign makes: `a?` has no dedicated `Opt`
//       node any more, and the empty string has no dummy leaf any more.
//

// MARK: - 1. computeAttributes — leaf-level cases

@Test func attributesOfEmptyAreNullableWithNoPositions() {
    let attrs = computeAttributes(for: .empty)
    #expect(attrs.nullable)
    #expect(attrs.firstpos.isEmpty)
    #expect(attrs.lastpos.isEmpty)
}

@Test func attributesOfSymbolAreItsOwnPosition() {
    let attrs = computeAttributes(for: .symbol("x", id: 7))
    #expect(!attrs.nullable)
    #expect(attrs.firstpos == [7])
    #expect(attrs.lastpos == [7])
}

// MARK: - 2. computeAttributes — structural cases

@Test func alternationUnionsBothSidesAndIsNullableIfEitherSideIs() {
    let tree = RegexNode.alternation(.symbol("a", id: 1), .symbol("b", id: 2))
    let attrs = computeAttributes(for: tree)
    #expect(!attrs.nullable)
    #expect(attrs.firstpos == [1, 2])
    #expect(attrs.lastpos == [1, 2])
}

@Test func alternationWithEmptyBranchIsNullable() {
    // This is exactly how `a?` is encoded now: alternation(a, .empty).
    let tree = RegexNode.alternation(.symbol("a", id: 1), .empty)
    let attrs = computeAttributes(for: tree)
    #expect(attrs.nullable, "a|ε must be nullable, the same as a dedicated Opt node would be")
    #expect(attrs.firstpos == [1])
    #expect(attrs.lastpos == [1])
}

@Test func concatOfTwoMandatorySymbolsIsNotNullable() {
    let tree = RegexNode.concat(.symbol("a", id: 1), .symbol("b", id: 2))
    let attrs = computeAttributes(for: tree)
    #expect(!attrs.nullable)
    #expect(attrs.firstpos == [1])   // left is not nullable -> firstpos(left) only
    #expect(attrs.lastpos == [2])    // right is not nullable -> lastpos(right) only
}

@Test func concatWhereLeftIsNullablePullsRightIntoFirstpos() {
    // (a?)b  ==  alternation(a, ε) · b
    let left = RegexNode.alternation(.symbol("a", id: 1), .empty)
    let tree = RegexNode.concat(left, .symbol("b", id: 2))
    let attrs = computeAttributes(for: tree)
    #expect(!attrs.nullable)               // right ("b") is mandatory
    #expect(attrs.firstpos == [1, 2])      // left nullable -> firstpos(left) ∪ firstpos(right)
    #expect(attrs.lastpos == [2])          // right not nullable -> lastpos(right) only
}

@Test func concatWhereRightIsNullablePullsLeftIntoLastpos() {
    // a(b?)  ==  a · alternation(b, ε)
    let right = RegexNode.alternation(.symbol("b", id: 2), .empty)
    let tree = RegexNode.concat(.symbol("a", id: 1), right)
    let attrs = computeAttributes(for: tree)
    #expect(!attrs.nullable)               // left ("a") is mandatory
    #expect(attrs.firstpos == [1])         // left not nullable -> firstpos(left) only
    #expect(attrs.lastpos == [1, 2])       // right nullable -> lastpos(left) ∪ lastpos(right)
}

@Test func concatOfTwoNullableSidesIsNullable() {
    let left = RegexNode.alternation(.symbol("a", id: 1), .empty)
    let right = RegexNode.alternation(.symbol("b", id: 2), .empty)
    let attrs = computeAttributes(for: .concat(left, right))
    #expect(attrs.nullable)
}

@Test func starIsAlwaysNullableRegardlessOfOperand() {
    let tree = RegexNode.star(.symbol("a", id: 1))
    let attrs = computeAttributes(for: tree)
    #expect(attrs.nullable)
    #expect(attrs.firstpos == [1])
    #expect(attrs.lastpos == [1])
}

// MARK: - 3. computeFollowPos — hand-built trees

@Test func followPosOfConcatAddsRightFirstposToLeftLastpos() {
    let tree = RegexNode.concat(.symbol("a", id: 1), .symbol("b", id: 2))
    var table: [Int: Set<Int>] = [:]
    computeFollowPos(for: tree, followTable: &table)
    #expect(table[1] == [2])
    #expect(table[2] == nil)
}

@Test func followPosOfStarAddsOwnFirstposToOwnLastposBackEdge() {
    let tree = RegexNode.star(.symbol("a", id: 1))
    var table: [Int: Set<Int>] = [:]
    computeFollowPos(for: tree, followTable: &table)
    #expect(table[1] == [1], "Kleene star must create a back-edge: followpos(1) ∪= firstpos(1)")
}

@Test func followPosOfAlternationAddsNothingDirectlyButRecursesIntoChildren() {
    // (a*)|(b*) — the alternation itself contributes no followpos entries,
    // but each star branch still gets its own back-edge.
    let tree = RegexNode.alternation(.star(.symbol("a", id: 1)), .star(.symbol("b", id: 2)))
    var table: [Int: Set<Int>] = [:]
    computeFollowPos(for: tree, followTable: &table)
    #expect(table[1] == [1])
    #expect(table[2] == [2])
}

@Test func followPosOfClassicAhoExample() {
    // (a|b)*abb, positions assigned left-to-right as in Aho §3.9:
    //   1:a 2:b (inside the star)  3:a  4:b  5:b
    let star = RegexNode.star(.alternation(.symbol("a", id: 1), .symbol("b", id: 2)))
    let tail = RegexNode.concat(.symbol("a", id: 3), .concat(.symbol("b", id: 4), .symbol("b", id: 5)))
    let tree = RegexNode.concat(star, tail)

    var table: [Int: Set<Int>] = [:]
    computeFollowPos(for: tree, followTable: &table)

    // Textbook followpos sets for this exact example.
    #expect(table[1] == [1, 2, 3])
    #expect(table[2] == [1, 2, 3])
    #expect(table[3] == [4])
    #expect(table[4] == [5])
    #expect(table[5] == nil)
}

// MARK: - 4. computeAttributesAndFollowPos — parity with the naive reference
//
// `computeAttributesAndFollowPos` exists purely as an O(n) replacement for
// calling `computeAttributes` + `computeFollowPos`. These tests assert the
// two are interchangeable on every tree shape exercised elsewhere in this
// file, so the optimization can never silently diverge from the textbook
// definition it's standing in for.

private func assertParity(_ tree: RegexNode, sourceLocation: SourceLocation = #_sourceLocation) {
    var naive: [Int: Set<Int>] = [:]
    computeFollowPos(for: tree, followTable: &naive)
    let naiveAttrs = computeAttributes(for: tree)

    var optimized: [Int: Set<Int>] = [:]
    let optimizedAttrs = computeAttributesAndFollowPos(for: tree, into: &optimized)

    #expect(naive == optimized, "followpos tables diverged for \(tree)", sourceLocation: sourceLocation)
    #expect(naiveAttrs == optimizedAttrs, "attributes diverged for \(tree)", sourceLocation: sourceLocation)
}

@Test func parityOnClassicAhoExample() {
    let star = RegexNode.star(.alternation(.symbol("a", id: 1), .symbol("b", id: 2)))
    let tail = RegexNode.concat(.symbol("a", id: 3), .concat(.symbol("b", id: 4), .symbol("b", id: 5)))
    assertParity(.concat(star, tail))
}

@Test func parityOnNestedStarsAndAlternations() {
    // ((a|b)*c)|(d*e)
    let left = RegexNode.concat(.star(.alternation(.symbol("a", id: 1), .symbol("b", id: 2))), .symbol("c", id: 3))
    let right = RegexNode.concat(.star(.symbol("d", id: 4)), .symbol("e", id: 5))
    assertParity(.alternation(left, right))
}

@Test func parityOnOptionalEncoding() {
    // a?b?c — three different nullability combinations chained together.
    let a = RegexNode.alternation(.symbol("a", id: 1), .empty)
    let b = RegexNode.alternation(.symbol("b", id: 2), .empty)
    assertParity(.concat(a, .concat(b, .symbol("c", id: 3))))
}

@Test func parityOnDeepConcatenationChain() {
    // This is the shape (a long flat concatenation, as produced by a string
    // literal or keyword) that makes the naive formulation quadratic. Parity
    // here is the load-bearing assertion that the O(n) fast path computes
    // exactly the same followpos table as the textbook definition, not an
    // approximation of it.
    var tree = RegexNode.symbol("a", id: 1)
    for i in 2 ... 80 {
        tree = .concat(tree, .symbol("a", id: i))
    }
    assertParity(tree)
}

// MARK: - 5. RegexNode is a genuine value type

@Test func structurallyIdenticalTreesAreEqual() {
    let t1 = RegexNode.concat(.symbol("a", id: 1), .star(.symbol("b", id: 2)))
    let t2 = RegexNode.concat(.symbol("a", id: 1), .star(.symbol("b", id: 2)))
    #expect(t1 == t2, "two independently-built trees with the same shape and positions must be equal")
}

@Test func treesDifferingOnlyInPositionAreNotEqual() {
    let t1 = RegexNode.symbol("a", id: 1)
    let t2 = RegexNode.symbol("a", id: 2)
    #expect(t1 != t2)
}

// MARK: - 6. The sentinel leaf vs. structural epsilon — the bug class this
// redesign must not reintroduce. See the "Design notes" in BerrySethi.swift.

@Test func structuralEmptyContributesNoPosition() {
    // If `.empty` were ever used to model the augmented '#' sentinel
    // (instead of a `.symbol` leaf), this is the assertion that would fail:
    // `.empty` never appears in any firstpos/lastpos set.
    let attrs = computeAttributes(for: .empty)
    #expect(attrs.firstpos.isEmpty)
    #expect(attrs.lastpos.isEmpty)
}

@Test func sentinelLeafReachesRootFirstposThroughANullableOptionalBranch() {
    // Mirrors exactly how BerrySethi.buildRegexNode encodes the augmented
    // expression "a?#": optional(a) -> alternation(a, .empty), followed by
    // concat with the sentinel, which is a real `.symbol` leaf.
    let optionalA = RegexNode.alternation(.symbol("a", id: 1), .empty)
    let sentinel = RegexNode.symbol("#", id: 2)
    let tree = RegexNode.concat(optionalA, sentinel)

    let attrs = computeAttributes(for: tree)

    #expect(!attrs.nullable, "the sentinel itself is mandatory, so the whole augmented expression is not nullable")
    #expect(attrs.firstpos.contains(2),
            "firstpos(root) must reach the sentinel so the DFA's initial state is accepting for empty input")
    #expect(attrs.lastpos == [2])
}

// MARK: - 7. End-to-end regressions through the public Regex API

@Test func emptyStringLiteralIsTransparentInConcatenation() throws {
    // "()" parses to Expression.string(""), which buildRegexNode now maps
    // directly to RegexNode.empty (previously a dummy, never-matched leaf
    // wrapped in an Opt node). It must be completely transparent.
    let r = try Regex("a()b", method: .berrySethi)
    #expect(r.recognize(string: "ab"))
    #expect(!r.recognize(string: "a"))
    #expect(!r.recognize(string: "b"))
    #expect(!r.recognize(string: "abb"))
}

@Test func zeroToZeroRepetitionMatchesOnlyEmptyString() throws {
    // a{0,0} expands to Expression.string(""), exercising the same
    // RegexNode.empty path as the test above via a different syntax.
    let r = try Regex("a{0,0}", method: .berrySethi)
    #expect(r.recognize(string: ""))
    #expect(!r.recognize(string: "a"))
}

@Test func optionalChainStillBehavesWithoutADedicatedOptNode() throws {
    // a?b?c? — three chained optionals, each encoded as alternation(_, .empty)
    // rather than a dedicated Opt node. All 2^3 combinations must work.
    let r = try Regex("a?b?c?", method: .berrySethi)
    for s in ["", "a", "b", "c", "ab", "ac", "bc", "abc"] {
        #expect(r.recognize(string: s), "should accept \"\(s)\"")
    }
    for s in ["ba", "cab", "abcd", "aa"] {
        #expect(!r.recognize(string: s), "should reject \"\(s)\"")
    }
}

@Test func longLiteralStringConstructsAndMatchesExactly() throws {
    // Exercises a deep, flat concatenation chain end-to-end through the
    // public API — the shape that motivated replacing the naive
    // computeAttributes-inside-computeFollowPos formulation with the O(n)
    // single-pass version used internally by BerrySethi.construct().
    let keyword = String((0 ..< 60).map { Character(UnicodeScalar(97 + $0 % 26)!) })
    let r = try Regex(keyword, method: .berrySethi)
    #expect(r.recognize(string: keyword))
    #expect(!r.recognize(string: String(keyword.dropLast())))
    #expect(!r.recognize(string: keyword + "x"))
}
