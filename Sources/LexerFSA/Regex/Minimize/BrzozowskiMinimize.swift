//
//  BrzozowskiMinimize.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/22.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

//  Brzozowski's (1962) double-reversal minimization: for any
//  initially-connected automaton A (every state reachable from `initial` —
//  true of every automaton this package builds, since they're all
//  constructed by a worklist starting at the initial state),
//
//      minimal(A)  =  determinize(reverse(determinize(reverse(A))))
//
//  Reversing an automaton flips every transition and swaps the roles of
//  "initial" and "final": a fresh synthetic state becomes the new initial
//  state, with an ε-edge to every old final state, and the old initial
//  state becomes the new (unique) final state. Determinizing that reversed
//  automaton with the ordinary subset construction then does two things at
//  once:
//    • merges any states that are indistinguishable when looked at
//      *backward* from acceptance — which is exactly the condition for two
//      states to be merge-equivalent;
//    • discards every state that isn't reachable in the reversed automaton,
//      which is exactly the set of states that could never reach an
//      accepting state in the original (the "dead" states).
//  Doing this twice yields the unique minimal DFA, with no separate
//  dead-state-trimming pass or explicit equivalence-class computation
//  required — the two reversals and determinizations do both jobs as a side
//  effect of just being subset constructions.
//
//  Note this is a *different* algorithm from `DFSA.minimize()`
//  (Minimize.swift), which is Hopcroft's partition-refinement algorithm. The
//  two are independent implementations of the same specification (the
//  minimal DFA for a given language is unique up to state renaming), which
//  is exactly what makes them useful as a cross-check on each other — see
//  `bothMinimizersAgreeOnStateCount` in AntimirovTests.swift.
//
//  This file reuses the package's existing, already-tested subset
//  construction (`NFSA.determinize()`, in FSA/Determinize/Determinize.swift)
//  rather than re-deriving it, and introduces no global mutable counter:
//  the only fresh id needed (the synthetic reversed-initial state) is
//  computed locally from the automaton's own state set, each time it's
//  needed.
//

/// Reverses an automaton: every transition `p --a--> q` becomes `q --a--> p`,
/// a fresh synthetic initial state gets an ε-edge to every old final state,
/// and the old initial state becomes the new (unique) final state.
func reverseAutomaton(initial: Int, finals: Set<Int>, transitions: Set<Transition>) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>) {
    let allStates = transitions.states().union([initial]).union(finals)
    let syntheticInitial = (allStates.max() ?? -1) + 1

    var reversed = transitions.reversed()
    for f in finals {
        reversed.insert(Transition(from: syntheticInitial, AlphabetRange.epsilon, to: f))
    }
    return (syntheticInitial, [initial], reversed)
}

/// Brzozowski's double-reversal minimization.
///
/// - Precondition: every state reachable via `transitions` is reachable
///   from `initial`. This holds for every automaton built by this package
///   (Thompson, BerrySethi, Antimirov all grow their transition sets from a
///   worklist seeded with their own initial state), so callers within this
///   package never need to trim unreachable states first.
func brzozowskiMinimize(initial: Int, finals: Set<Int>, transitions: Set<Transition>) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>) {

    func reverseThenDeterminize(_ initial: Int, _ finals: Set<Int>, _ transitions: Set<Transition>) -> (Int, Set<Int>, Set<Transition>) {
        let r = reverseAutomaton(initial: initial, finals: finals, transitions: transitions)
        var nfsa = NFSA(initial: r.initial, finals: r.finals, transitions: r.transitions)
        nfsa.determinize()
        guard case let .dfa(i, f, t, _, _) = nfsa.state else {
            // determinize() only declines to act if it's handed a `.dfa`
            // already, which `NFSA.init` never produces — kept as a safe
            // fallback rather than force-unwrapping the pattern match.
            return (r.initial, r.finals, r.transitions)
        }
        return (i, f, t)
    }

    let (i1, f1, t1) = reverseThenDeterminize(initial, finals, transitions)
    let (i2, f2, t2) = reverseThenDeterminize(i1, f1, t1)
    return (initial: i2, finals: f2, transitions: t2)
}
