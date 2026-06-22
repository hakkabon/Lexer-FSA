//
//  Antimirov.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/16.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

// Antimirov Partial-Derivative Construction, then Brzozowski Minimization
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │ Algorithm                                                               │
// │                                                                         │
// │ 1. Parse the expression — no augmentation needed; see below.            │
// │                                                                         │
// │ 2. Build the partial-derivative automaton directly: each DFA state IS   │
// │    a `Set<Expression>` of partial-derivative terms (see                 │
// │    PartialDerivative.swift), starting from the singleton set            │
// │    `{ root }`.                                                          │
// │      initState = { root }                                               │
// │      while unmarked state S = Set<Expression> exists:                   │
// │        for each symbol a in the concrete alphabet of root:              │
// │          U = ⋃ partialDerivative(t, a) for t ∈ S, dead terms dropped    │
// │          if U ≠ ∅: add transition S --a→ U                              │
// │      S is accepting iff some t ∈ S is nullable(t)                       │
// │                                                                         │
// │ 3. The result of step 2 is already deterministic by construction (each  │
// │    state IS one term-set; there's no separate subset-construction step  │
// │    over it), but it is not necessarily *minimal* — two different        │
// │    term-sets can still denote the same residual language. Brzozowski's  │
// │    double-reversal algorithm (BrzozowskiMinimize.swift) collapses       │
// │    those, and the result really is the minimal DFA — `construct()`      │
// │    returns it tagged `minimal: true`, unlike `Thompson`/`BerrySethi`.   │
// └─────────────────────────────────────────────────────────────────────────┘
//
// Why no '#' sentinel
// ───────────────────
// `BerrySethi` parses the *augmented* expression `r#`, because a position
// automaton's only way to recognise "we're in an accepting state" is to ask
// whether the current set of leaf positions contains the position of a
// dedicated sentinel leaf. A derivative automaton needs no such trick:
// acceptance of a state `S: Set<Expression>` is decided directly by asking
// whether `S` contains a nullable term — i.e. whether *one of the residual
// expressions still to be matched* can itself match the empty string. That
// question is already well-defined for the plain, un-augmented expression,
// so `Antimirov.init` parses `expression` exactly as written, with no
// trailing `#` appended. (`Thompson` doesn't augment either, for the
// analogous reason: an ε-NFA just designates an explicit accepting state.)
// One visible consequence: `Antimirov(...).expression` — and therefore
// `Regex(..., method: .derivative).description` — reflects the pattern
// exactly as the caller wrote it, with no sentinel leaking into it.
//
// Why no Counter.shared
// ──────────────────────
// As with `BerrySethi`'s redesign, DFA-state ids come from a counter local
// to this single `construct()` call (`stateID`/`nextID`, scoped inside
// `buildPartialDerivativeAutomaton`), not the package-wide `Counter.shared`
// also used by `Thompson`/`RegexPowerset`. Two `Regex` values built from
// `Antimirov`, or one built right after a `Thompson` run, must not observe
// each other's state numbering.

extension Regex {

    struct Antimirov: RegularLanguageBuilder {

        let debug = false

        // RegularLanguageBuilder
        var expression: Expression = .empty

        // Parser
        var parser: RegexParser

        init(expression: String, flags: SyntaxOptions) {
            // No '#' augmentation — see "Why no '#' sentinel" above.
            parser = RegexParser(expression: expression, flags)
        }

        mutating func construct() throws -> State<Regex> {
            self.expression = try parser.parse()

            let alphabet = concreteAlphabet(of: self.expression)
            let raw = buildPartialDerivativeAutomaton(root: self.expression, alphabet: alphabet)

            if debug {
                let stateCount = raw.transitions.states().union([raw.initial]).count
                print("=== Antimirov: partial-derivative DFA (pre-minimization) ===")
                print("states: \(stateCount), finals: \(raw.finals.sorted())")
            }

            // Deterministic by construction, but not necessarily minimal —
            // see "Algorithm" step 3 above.
            let minimal = brzozowskiMinimize(initial: raw.initial, finals: raw.finals, transitions: raw.transitions)

            if debug {
                let stateCount = minimal.transitions.states().union([minimal.initial]).count
                print("=== Antimirov: after Brzozowski minimization ===")
                print("states: \(stateCount), finals: \(minimal.finals.sorted())")
            }

            return .dfa(
                initial: minimal.initial,
                finals: minimal.finals,
                transitions: minimal.transitions,
                minimal: true,
                tokenMap: [:]
            )
        }

        /// Builds the deterministic partial-derivative automaton: each state
        /// IS a `Set<Expression>` of partial-derivative terms, discovered by
        /// a worklist starting from the singleton set `{ root }`.
        private func buildPartialDerivativeAutomaton(
            root: Expression,
            alphabet: Set<Character>
        ) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>) {

            var stateID: [Set<Expression>: Int] = [:]
            var nextID = 0
            func id(for terms: Set<Expression>) -> Int {
                if let existing = stateID[terms] { return existing }
                let newID = nextID
                nextID += 1
                stateID[terms] = newID
                return newID
            }

            let initialTerms: Set<Expression> = [root]
            let initial = id(for: initialTerms)

            var worklist: [Set<Expression>] = [initialTerms]
            var visited = Set<Set<Expression>>()
            var finals = Set<Int>()
            var transitions = Set<Transition>()

            while !worklist.isEmpty {
                let terms = worklist.removeFirst()
                guard visited.insert(terms).inserted else { continue }

                let from = id(for: terms)
                if terms.contains(where: nullable) {
                    finals.insert(from)
                }

                for ch in alphabet {
                    // ⋃_{t ∈ terms} pd(t, ch). Terms that collapsed to the
                    // empty language (e.g. from a pattern that itself
                    // concatenates with '#', the empty-language literal) are
                    // dropped here: they can never become nullable and can
                    // never produce a further derivative (`partialDerivative`
                    // always returns `[]` for `.empty`), so keeping them
                    // around would only inflate state sets without changing
                    // which strings are accepted.
                    var next = Set<Expression>()
                    for t in terms {
                        next.formUnion(partialDerivative(t, withRespectTo: ch))
                    }
                    next = next.filter { $0 != .empty }
                    guard !next.isEmpty else { continue }

                    let to = id(for: next)
                    transitions.insert(Transition(from: from, .char(ch), to: to))
                    if !visited.contains(next) { worklist.append(next) }
                }
            }

            return (initial, finals, transitions)
        }
    }
}
