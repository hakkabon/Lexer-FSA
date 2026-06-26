# Lexer-FSA — Technical Reference

This document gives an in-depth account of the design, data structures, algorithms, and in-progress work that make up the Lexer-FSA Swift package. It is aimed at contributors and integrators who need to understand the internals rather than just the public API.

---

## Table of Contents

1. [Formal Background](#1-formal-background)
2. [Core Abstraction — `State<T>`](#2-core-abstraction--statet)
3. [Protocol Hierarchy](#3-protocol-hierarchy)
4. [Transitions and Alphabet](#4-transitions-and-alphabet)
5. [NFA Simulation](#5-nfa-simulation)
6. [DFA Simulation](#6-dfa-simulation)
7. [Regular Expression Compilation](#7-regular-expression-compilation)
8. [Powerset (Subset) Construction](#8-powerset-subset-construction)
9. [DFA Minimization](#9-dfa-minimization)
10. [Automaton Invariants](#10-automaton-invariants)
11. [Extended State — Token Tracking](#11-extended-state--token-tracking)
12. [DAWG / String Union](#12-dawg--string-union)
13. [Graphviz Rendering](#13-graphviz-rendering)
14. [Random Automaton Generation](#14-random-automaton-generation)
15. [Known Issues and Improvement Areas](#15-known-issues-and-improvement-areas)

---

## 1. Formal Background

A **Nondeterministic Finite Automaton** (NFA) is the 5-tuple (Q, Σ, Δ, q₀, F) where:

- Q — finite set of states
- Σ — finite input alphabet
- Δ : Q × (Σ ∪ {ε}) → 𝒫(Q) — transition function returning a *set* of successor states
- q₀ ∈ Q — unique initial state
- F ⊆ Q — set of accepting (final) states

A **Deterministic Finite Automaton** (DFA) replaces Δ with δ : Q × Σ → Q, guaranteeing at most one successor per (state, symbol) pair and eliminating ε-transitions. DFAs and NFAs accept exactly the same class of languages — the **regular languages**.

Lexer-FSA models both representations in a single `State<T>` enum, using Swift's phantom-type mechanism to enforce that NFA-only operations (e.g., `epsClosure`) and DFA-only operations (e.g., `minimize`) are statically scoped to the correct automaton kind.

---

## 2. Core Abstraction — `State<T>`

### 2.1 Declaration

```swift
public enum State<T> {
    case nfa(
        initial: Int,
        finals: Set<Int>,
        transitions: Set<Transition>,
        tokenMap: [Int: TokenClass]
    )
    case dfa(
        initial: Int,
        finals: Set<Int>,
        transitions: Set<Transition>,
        minimal: Bool,
        tokenMap: [Int: TokenClass]
    )
}
```

States are identified by plain `Int` values. The automaton's topology is encoded entirely inside `Set<Transition>`, from which the reachable state set Q and alphabet Σ can both be derived. Keeping Q implicit (rather than as a separate stored field) avoids the classic "orphan state" problem where Q and the transition set fall out of sync.

The `tokenMap` field is the result of the extended-state migration. It maps each **final state** to the `TokenClass` it represents. States not in the map are accepting states without a class (which can occur during intermediate construction steps).

### 2.2 Phantom-type dispatch

The type parameter `T` is never stored at runtime — it exists purely to steer Swift's conditional-extension resolution. Three concrete parameter types are used:

| `T` | Used by | Meaning |
|---|---|---|
| `NFSA` | `NFSA` struct | NFA-specific extensions are in scope |
| `DFSA` | `DFSA` struct | DFA-specific extensions are in scope |
| `Regex` | `Regex` struct | Both NFA and DFA paths are in scope; the `Regex` type manages its own determinism flag |

This design means that calling `epsClosure` on a `State<DFSA>` is a **compile-time error**, not a runtime guard. The approach is analogous to Swift's typed-throws or to the "newtype" pattern in Haskell.

### 2.3 Value semantics

`State<T>` is an enum, and `NFSA`, `DFSA`, and `Regex` are all structs. Every mutation (adding a transition, determinizing, minimizing) produces a new value. Because `Set<Transition>` can be large, Swift's copy-on-write semantics for `Set` keeps the cost reasonable in practice.

---

## 3. Protocol Hierarchy

```
FSA                         (isEmpty, isDeterministic, isMinimal, initial, finals,
│                            alphabet, stateCount, finalCount, isFinal, isInitial)
├── Nondeterministic        (run, epsClosure, step→Set, successor→Set,
│                            predecessors→Set, isSuccessor, reachableStates,
│                            addTransition, add, determinize, generate)
├── Deterministic           (run, step→Int?, successor→Int?,
│                            predecessors→Set, isSuccessor, reachableStates,
│                            generate, minimize, isEquivalent)
└── Regular                 (run, step)

RegularLanguage             (state, builder, method, isDeterministic, isMinimal,
│   : RegularLanguageRecognition    epsilonFree, init)
│   : RegularLanguageTransform
│
├── RegularLanguageRecognition  (move, step, recognize)
└── RegularLanguageTransform    (removeEps, powerset)
```

`AutomataOperation` (implemented on `DFSA`) adds the static factory methods `union(a:b:)`, `union(list:)`, and `stringUnion(words:)`.

The split between `Nondeterministic` and `Deterministic` mirrors the mathematical distinction: `step` returns `Set<Int>` for NFAs (multiple successors possible) but `Int?` for DFAs (at most one successor). Protocol-level enforcement prevents accidental misuse, e.g., treating an NFA step result as a single state.

---

## 4. Transitions and Alphabet

### 4.1 `AlphabetRange`

```swift
public enum AlphabetRange {
    case epsilon
    case char(Character)
    case range(Character, Character)   // closed interval [lower, upper]
}
```

Storing character ranges rather than individual characters keeps the transition set small for automata over large alphabets (e.g., Unicode letter classes). `AlphabetRange` conforms to `Equatable`, `Comparable`, `Hashable`, and `Codable`.

The `contains(character:)` helper centralises membership testing and is used by both the NFA simulation (`move`) and DFA simulation (`step`).

`AlphabetEpsRange` is a parallel enum that duplicates the same three cases. It exists as a legacy artefact; the two types should be unified (see §15).

### 4.2 `Transition`

```swift
public struct Transition {
    let source: Int
    let alphabetRange: AlphabetRange
    let target: Int
}
```

`Transition` is a value type that participates in `Set<Transition>` via `Hashable` and `Equatable`. Its `Comparable` conformance orders by `(source, alphabetRange, target)`, which is required by the interval-merging algorithm in `reduce()`.

The `inAlphabet(char:)` and `inAlphabet(_:_:)` methods perform membership tests against the stored range. Note that `inAlphabet` on an `.epsilon` transition returns `true` unconditionally — this is correct for the ε-closure computation but creates a semantic hazard in other contexts (see §15).

`Set<Transition>` is extended with helpers:
- `alphabet()` — collects all non-ε ranges and builds an `Alphabet`
- `states()` — returns the set of all states mentioned as source or target
- `forwardMap()` — builds a `[Int: [Int]]` adjacency list for BFS
- `reversed()` — flips all transitions (used in reverse reachability)

### 4.3 `Alphabet`

`Alphabet` holds a `Set<Interval>` plus a flat `[Character]` array and a `[Character: Int]` index map. The flat array is built once during initialisation by expanding every interval into its constituent Unicode scalar values. The `characters` property is what the powerset construction iterates over to enumerate the input alphabet. Binary search via `BinarySearch` is available for O(log n) character-to-index lookup.

---

## 5. NFA Simulation

Simulation of `NFSA` follows the standard two-step loop:

```
states ← ε-closure({q₀})
for each character ch in input:
    states ← ε-closure( ⋃_{q ∈ states} move(q, ch) )
    if states = ∅: reject
accept iff states ∩ F ≠ ∅
```

**ε-closure** (`epsClosure(state:over:)`) uses an iterative stack-based DFS to collect all states reachable from a seed via zero or more ε-transitions. A `Set<Int>` tracks visited states to prevent cycles.

**move** returns the set of states reachable from a given state via a given symbol, ignoring ε-edges.

The `run(string:)` method on `State<NFSA>` is the canonical simulation entry point.

### Complexity

- `epsClosure`: O(|Q| + |Δ|) per call.
- Full simulation of string s: O(|s| · |Q| · |Δ|) in the worst case.
- Practical cost is much lower because the active state set is sparse.

---

## 6. DFA Simulation

DFA simulation is a simple linear scan:

```
state ← q₀
for each character ch in input:
    state ← δ(state, ch)
    if δ undefined: reject
accept iff state ∈ F
```

`step(state:symbol:over:)` on `State<DFSA>` filters the transition set to the current source state and returns the first matching target. Because the transition set is stored as an unordered `Set`, lookup is O(|Δ_state|) — the out-degree of the current state. For large automata a hash-indexed transition table would reduce this to O(1) (see §15).

`successor(source:symbol:)` and `predecessors(target:symbol:)` expose the forward and reverse image of the transition function for use by the minimization algorithm.

`reachableStates(from:)` currently returns only **direct** successors (one-hop), not the transitive closure. This is inconsistent with its documentation, which promises the full reachable set (see §15).

---

## 7. Regular Expression Compilation

### 7.1 Parsing

`RegexParser` is a recursive-descent parser that consumes a regex string and builds an `Expression` AST. `SyntaxOptions` flags gate optional syntax constructs (e.g., extended character classes). The parser handles:

- Literals and escaped characters
- `|` (alternation)
- `*` (Kleene star), `+` (one-or-more), `?` (optional)
- `{n,}`, `{n,m}` (bounded repetition)
- `(…)` grouping
- `[…]` character classes with ranges
- `.` (any character), `@` (any string), `<lo-hi>` (numerical interval), `#` (empty language) — each gated by its own `SyntaxOptions` flag

The resulting `Expression` tree is shared by all three construction backends below. `{n,}`, `{n,m}`, and `<lo-hi>` are not primitive in any of the three — each construction method expands them into the primitive forms (`union`, `concatenation`, `optional`, `repeat`, `char`, `string`, `empty`) using the same shared functions in `Expression+Desugar.swift`, so all three agree by construction on what e.g. `a{2,5}` means.

### 7.2 Thompson's Construction

`Thompson` (`Construction/Thompson.swift`, selectable via `ConstructionMethod.thompson`) implements the classical McNaughton–Yamada–Thompson algorithm. It walks the `Expression` AST recursively and builds NFA fragments following the structural rules:

| Expression form | NFA fragment |
|---|---|
| ε | Single ε-transition from start to accept |
| literal `a` | One state, one `char(a)` transition |
| `e₁ · e₂` | Concatenation: accept of e₁ ε-links to start of e₂ |
| `e₁ \| e₂` | New start with ε-edges to both; both accepts ε-link to new accept |
| `e*` | New start/accept; ε-loop back; ε-bypass |
| `e+` | Concatenation of e with e* |

This produces an ε-NFA with O(|expression|) states and transitions. The resulting `State<Regex>` is `.nfa(...)`.

### 7.3 Berry-Sethi Construction

`BerrySethi` (`Construction/BerrySethi.swift`, selectable via `ConstructionMethod.berrySethi`) implements the Glushkov / Berry-Sethi position automaton:

1. Parse the *augmented* expression `r#` — the trailing `#` sentinel gets the highest leaf position, and is the only mechanism this method has for detecting acceptance (see 7.4 for why Antimirov needs no such trick).
2. Build a positional tree, `RegexNode` (`Construction/RegexNode.swift`) — an immutable, indirect value enum (`empty` / `symbol(Character, id:)` / `concat` / `alternation` / `star`), one leaf per symbol occurrence, atomically with a `leafExpressions: [Int: Expression]` table recording what each leaf actually matches (needed because a single `RegexNode.symbol` can't carry a full character range or "any character" — `leafExpressions` is the authoritative lookup for matching; the `Character` `RegexNode.symbol` carries is cosmetic, used only for `description`/debug output).
3. Compute **nullable**, **firstpos**, **lastpos**, and **followpos** together in one bottom-up O(n) pass (`computeAttributesAndFollowPos`). A textbook two-function formulation (`computeAttributes` + `computeFollowPos`) is also provided and kept as the test suite's reference oracle, but is O(n²) — it recomputes `computeAttributes` on every subtree at every level of `computeFollowPos`'s own recursion — so it is not on `construct()`'s hot path.
4. Build the DFA directly from `followpos`: states are sets of leaf positions; a state is accepting iff it contains the sentinel's position.

The resulting automaton is ε-free and deterministic by construction — no NFA, no powerset step, ever — with exactly |expression| + 1 leaf positions (one per symbol occurrence plus the sentinel).

`RegexNode` deliberately has no `Opt`-equivalent case: `a?` is represented as `alternation(a, .empty)` (`a|ε`), which the existing `.alternation` rule already handles correctly with no extra case anywhere. It also has no dummy "never-matched" leaf for the empty string: `.string("")` maps directly to `RegexNode.empty` (nullable, `firstpos = lastpos = ∅`, no leaf consumed at all) rather than a placeholder character chosen not to collide with the real alphabet.

### 7.4 Antimirov Partial-Derivative Construction

`Antimirov` (`Construction/Antimirov.swift`, selectable via `ConstructionMethod.derivative`) implements Antimirov's (1995) partial-derivative automaton, then minimizes it.

**Background.** Brzozowski (1964) defined the derivative of a regular expression `e` with respect to a symbol `c`, written `∂e/∂c`, as a single expression denoting "what `e` becomes after consuming one leading `c`". Used directly that way, the derivative of an alternation keeps re-folding results back through `|`, and telling whether two derivative expressions denote the same language again needs an ACI-equivalence check (associativity, commutativity, idempotence of `|`). Antimirov's refinement is to define the *partial* derivative, `pd(e, c)`, as a *set* of expressions instead: distribute the alternation across the set up front, and take the derivative of each disjunct on its own, rather than folding the results back into one expression. The set of all partial derivatives reachable from a fixed `e` is finite — bounded by the number of symbol occurrences in `e` — which gives a deterministic automaton directly: each state IS one `Set<Expression>`, and `Expression`'s synthesized `Hashable`/`Equatable` conformance (it is `indirect enum Expression: Hashable`, see `Expression.swift`) does the ACI bookkeeping for free, with no canonical form or extra equivalence check needed anywhere.

**Nullable and partialDerivative** (`Construction/PartialDerivative.swift`) are pure functions over `Expression`:

| Expression form | `nullable(e)` | `partialDerivative(e, c)` |
|---|---|---|
| `#` (empty language) | `false` | `∅` |
| `ε` (`""`) | `true` | `∅` |
| literal `a` | `false` | `{ε}` if `c == a`, else `∅` |
| `[lo-hi]` | `false` | `{ε}` if `lo ≤ c ≤ hi`, else `∅` |
| `.` (any char) | `false` | `{ε}` |
| `s` (string) | `s.isEmpty` | `{tail(s)}` if `s` starts with `c`, else `∅` |
| `e₁ \| e₂` | `nullable(e₁) ∨ nullable(e₂)` | `pd(e₁,c) ∪ pd(e₂,c)` |
| `e₁ · e₂` | `nullable(e₁) ∧ nullable(e₂)` | `{t·e₂ \| t ∈ pd(e₁,c)} ∪ (pd(e₂,c)` if `nullable(e₁))` |
| `e?` | `true` | `pd(e,c)` (≡ `e\|ε`, and `pd(ε,c) = ∅`) |
| `e*` | `true` | `{t·e* \| t ∈ pd(e,c)}` — the *un-derived* `e*` is the continuation; this self-reference is the back-edge that makes the star loop |

`repeatMin`/`repeatMinMax`/`interval`/`anyString` all defer to the same `Expression+Desugar.swift` expansion Berry-Sethi uses rather than re-deriving their own nullability/derivative rules — `nullable(e{n,m})` is `n == 0 ∨ nullable(e)`, not simply `n == 0`, which a hand-rolled rule can easily get wrong (e.g. `(a?){2,4}` is nullable for any `n`).

`·` above is `smartConcat`, concatenation with the algebraic identities `0·e = e·0 = 0` and `ε·e = e·ε = e` applied eagerly, so derivative terms don't accumulate dead weight as they're threaded through repeated concatenation. By convention, a derivative that "goes nowhere" is the *absence* of a term from the returned set, never a literal `.empty` (the zero/empty-language expression) member — though `smartConcat` can still introduce one if the original pattern itself concatenates with `#` (e.g. `a#`); `Antimirov`'s construction loop filters any such dead terms back out before turning a result into a DFA state.

**Construction loop**: starting from the singleton state `{ pattern }`, repeatedly compute `⋃ pd(t, c)` over every term `t` in the current state and every character `c` in the pattern's concrete alphabet (`concreteAlphabet(of:)`, the same printable-ASCII-for-any-char convention Berry-Sethi uses), adding a transition to whichever new term-set results, until no new states appear. A state is accepting iff it contains a `nullable` term.

This is deterministic by construction for the same structural reason Berry-Sethi's is — there is no separate subset-construction step laid on top — but **no `#` sentinel is needed**: acceptance is decided directly by asking whether the current set of residual expressions contains one that can itself match ε. Concretely, `Antimirov.init` parses the pattern exactly as written, with nothing appended, so `Antimirov(...).expression` — and therefore `Regex(..., method: .derivative).description`, which unparses `builder.expression` — reflects the caller's pattern with no sentinel leaking into it. Contrast `Regex(..., method: .berrySethi).description`, which unparses the *augmented* `r#` and so always shows a trailing `#`.

The partial-derivative automaton is deterministic but not necessarily *minimal*: two different term-sets can still denote the same residual language. `construct()` therefore runs the result through `brzozowskiMinimize` (§9.2) before returning, and tags it `minimal: true` — the only one of the three construction methods that returns a provably minimal DFA directly.

### 7.5 Epsilon Removal

`removeEps(initial:finals:transitions:)` on `Regex` applies Algorithm 1.5.2 from Skut et al. to eliminate ε-transitions from a Thompson NFA:

1. Compute ε-closure of every non-ε transition target.
2. Redirect the transition to each state in the closure.
3. Any state whose ε-closure intersects F becomes a new final state.

### 7.6 Determinization in Regex context

Setting `regex.isDeterministic = true` triggers the powerset construction via `powerset(initial:finals:transitions:)` in `RegexPowerset.swift`. The result replaces `self.state` with a `.dfa(...)` value.

---

## 8. Powerset (Subset) Construction

Two implementations of the powerset construction exist:

**Legacy (in `RegexPowerset.swift`)** — operates on plain `NfaTuple` and returns a `DfaTuple`, with no token map awareness. Used by the `Regex` type when `isDeterministic` is set.

**Token-tracking (in `Determinize/Determinize.swift`)** — the newer implementation on `State<NFSA>.determinize()` (`NFSA` is the current name of what this document elsewhere calls the nondeterministic finite-state type). It adds token map propagation:

```
dfaState s ← ε-closure({q₀})
for each NFA state set S not yet processed:
    for each symbol a ∈ Σ:
        T ← ε-closure( ⋃_{q ∈ S} move(q, a) )
        if T ≠ ∅:
            create DFA state for T if new
            add transition (S, a, T)
    if S ∩ F ≠ ∅:
        dfaFinals.insert(id(S))
        dfaTokenMap[id(S)] ← highest-priority token in S ∩ F
```

The **priority resolution** picks the `TokenClass` with the lowest `priority` integer value among all accepting NFA states in the set — implementing the scanner convention that a keyword pattern (priority 1) beats a generic identifier pattern (priority 10) when both patterns match the same string.

### Known issue in current implementation — RESOLVED

This section previously described a variable-shadowing compile error in `Determinize.swift`'s subset-construction loop (a `let` accidentally shadowing the outer DFA-state-id counter `var`). The current source (confirmed while implementing §7.4/§9.2) uses distinct names — `nextId` for the counter, `targetDfaState` for the per-iteration lookup result — and has no such shadowing. See also §15.1, which describes the same historical issue.

---

## 9. DFA Minimization

Two independent algorithms are available.

### 9.1 Hopcroft's Algorithm (token-class aware)

`Minimize/Minimize.swift` implements **Hopcroft's algorithm** extended with token-class awareness on `DFSA`.

#### Standard Hopcroft's algorithm

The classical algorithm partitions Q into equivalence classes of indistinguishable states:

1. Initial partition: `{F, Q \ F}`.
2. Maintain a worklist of "splitter" sets.
3. For each splitter P and each symbol a, split any partition block B into `B ∩ δ⁻¹(P, a)` and `B \ δ⁻¹(P, a)`.
4. When the worklist is empty, each block is a single equivalence class.
5. Build the minimized DFA using one representative per block.

#### Token-class extension

States that accept *different* token classes must never be merged, even if they are otherwise indistinguishable. The implementation enforces this by creating a separate initial partition block for each distinct `TokenClass` rather than a single block for all of F:

```
Initial partitions:
  { Q \ F }                          — non-accepting
  { states with TokenClass A }        — one block per distinct token class
  { states with TokenClass B }
  ...
  { accepting states without any token class }  — one block each
```

A consequence worth calling out explicitly: an accepting state with **no** token class is placed in its *own* singleton block, not grouped with other untagged accepting states. Partition refinement can only ever split a block, never merge two different initial blocks back together — so two untagged accepting states that happen to be genuinely language-equivalent are *never* merged by this algorithm. This is the right behaviour for its primary use case (a multi-pattern lexer DFA, where every accepting state is really supposed to represent a distinct token), but it means `DFSA.minimize()` is not guaranteed to reach the *global* minimum for a plain, token-free regex match — only ever a partition refinement of it, which can have the same number of states or more, never fewer. See 9.2 for the algorithm that does guarantee the global minimum, and `AntimirovTests.swift`'s `antimirovStateCountNeverExceedsHopcroftMinimizedBerrySethi` for a test that exploits exactly this asymmetry as a (one-directional) cross-check.

### 9.2 Brzozowski's Double-Reversal Algorithm

`brzozowskiMinimize(initial:finals:transitions:)` (`Minimize/BrzozowskiMinimize.swift`) is a second, independent minimizer, used internally by the Antimirov construction (§7.4) and available standalone. For any initially-connected automaton A (every state reachable from `initial` — true of every automaton this package builds, since all three regex constructions grow their transition sets from a worklist seeded at their own initial state):

```
minimal(A) = determinize(reverse(determinize(reverse(A))))
```

Reversing an automaton flips every transition and swaps the roles of "initial" and "final": a fresh synthetic state becomes the new initial state with an ε-edge to every old final state, and the old initial state becomes the new (unique) final state (`reverseAutomaton`). Determinizing that reversed automaton with the ordinary subset construction does two things as a side effect of just being a subset construction:

- it merges states that are indistinguishable looking *backward* from acceptance — exactly the condition for two states to be language-equivalent;
- it discards states unreachable in the reversed automaton — exactly the states that could never reach an accepting state in the original ("dead" states).

Doing this twice yields the unique minimal DFA, with no separate dead-state-trimming pass or explicit equivalence-class computation required. The implementation reuses the package's existing, already-tested subset construction (`NFSA.determinize()`, §8) for the "determinize" half rather than re-deriving it, and introduces no global mutable counter — the only fresh state id needed (the synthetic reversed-initial state) is computed locally from the automaton's own state set each time it's needed, the same instance-local-counter discipline `BerrySethi` and `Antimirov` both follow (§15.13 notes where the rest of the codebase still relies on `Counter.shared`).

Unlike Hopcroft's algorithm above, this minimizer has no notion of token classes, so it always reaches the true Myhill-Nerode minimum for plain acceptance — which is exactly why `Antimirov.construct()` uses it and tags its result `minimal: true`.

### Known issue in current implementation

`Minimize.swift` previously referenced `transition.range` instead of `transition.alphabetRange` (a typo that would have prevented the file from compiling); the current source already uses `transition.alphabetRange` throughout. See §15 for the status of other entries in that catalogue, several of which predate this and other rounds of bug fixes and are similarly out of date.

---

## 10. Automaton Invariants

The `Invariant.swift` extension on `Deterministic` defines a suite of normalization passes that are called as `invariant()`:

### `removeZombieAcceptStates()`

Removes from `finals` any state that does not appear in the transition set at all. These "zombie" states arise from manual construction errors or file-parsing artefacts.

### `eliminateDeadStates()`

Performs forward-reachability BFS from the initial state and removes any state (and all of its transitions) that is unreachable from q₀.

### `removeDeadTransitions()`

Performs forward reachability a second time and removes transitions that lead to states from which no final state is reachable (dead/trap states). Uses `forwardMap()` for efficient iteration.

### `reduce()`

Merges overlapping or adjacent character-range transitions with the same source and target into a single `.range(lower, upper)` transition. Requires the transition set to be sorted (by `(source, alphabetRange, target)`). Uses a stack-based sweep:

1. Push the first transition.
2. For each subsequent transition, if it has the same endpoints and its range overlaps the stack top, widen the top's upper bound.
3. Otherwise push the transition.

This keeps the transition set in its most compact form after construction operations.

### Where should `invariant()` run?

None of `removeZombieAcceptStates()`, `eliminateDeadStates()`, `removeDeadTransitions()`, `reduce()`,
or the bundled `invariant()` itself are currently called anywhere in the construction pipeline — they're
implemented and unit-tested in isolation, but every entry point (`Thompson.construct()`,
`BerrySethi.construct()`, `Antimirov.construct()`, `determinize()`, `minimize()`) hands back its raw
result without ever invoking them. That's worth fixing deliberately rather than by blanket-calling
`invariant()` everywhere, because the four passes aren't equally appropriate at every point in an
automaton's lifetime:

1. **Right after raw NFA/DFA construction (Thompson / BerrySethi / Antimirov), before the result is
   handed back to the caller.** This is where `removeZombieAcceptStates()` earns its keep. The `#`
   (empty-language) construction is a legitimate example: its whole point is a final state that is
   *deliberately* unreachable, so the raw construction is exactly the kind of place a zombie final state
   can show up by design, not just by accident. (This audit found and fixed the one concrete case of that —
   see "Known issues" below — by having `Thompson.construct()` not emit the zombie final state in the
   first place, which is preferable to constructing it and immediately stripping it back out. But the next
   construction method, or the next bug in this one, won't necessarily get that same care, so running
   `removeZombieAcceptStates()` here as a safety net is still worthwhile defense in depth.) `eliminateDeadStates()`
   is mostly redundant here for NFAs built bottom-up by these particular algorithms (they only ever wire up
   states they just created, so there's nothing unreachable to prune) — but it's cheap insurance against a
   future construction method that doesn't have that property.

2. **Right after `determinize()`.** The powerset construction only ever visits state-sets reachable from
   the initial closure, so `eliminateDeadStates()` is a guaranteed no-op here. `reduce()`, on the other hand,
   is genuinely valuable at exactly this point: subset construction commonly produces several adjacent or
   overlapping `.range` transitions out of the same DFA state (one per equivalence class that happened to
   land on the same target), and `reduce()` is precisely the pass that coalesces those into the fewest
   possible wide ranges. Since `determinize()`'s result is by definition already a `DFSA`, calling the full
   `invariant()` bundle here (not just `reduce()` in isolation) is the natural choice — `removeZombieAcceptStates()`
   and `eliminateDeadStates()` are cheap no-ops on a determinize() result, and `removeDeadTransitions()` will
   still usefully prune any trap states inherited from a source NFA that itself had dead branches.

3. **Right before `minimize()` partitions.** Hopcroft's refinement assumes every state it's handed is
   pulling its weight; a dead/trap state sitting in the initial "non-accepting" block doesn't *break*
   the algorithm, but it does waste partition-refinement work and can leave the "minimized" result larger
   than the true Myhill-Nerode minimum if the input DFA wasn't already dead-state-free. Calling
   `eliminateDeadStates()` + `removeDeadTransitions()` as the very first thing `minimize()` does — before
   building the initial partition — guards against that regardless of how the DFA arrived (hand-built,
   deserialized, or freshly determinized).

4. **After any manual editing of states/transitions** (constructing a `DFSA`/`NFSA` directly through its
   memberwise initializer, or a hypothetical "load from a serialized/DOT representation" feature). This is
   the case the existing header comment in `DFSA+Invariant.swift` already calls out, and it's the one case
   where the library genuinely can't apply the fix automatically — there's no single call site to intercept,
   since the caller is bypassing the construction/transformation API entirely. The right answer there is
   simply: call `invariant()` yourself afterward, the way the doc comment already says.

In short: (1) and (4) are about a *single construction method* not handing back a state that violates its
own invariants, so those are best fixed in the specific construction code (as this audit did for Thompson's
`#` case) rather than papered over by always running cleanup afterward. (2) and (3) are about *transformations*
(`determinize()`, `minimize()`) that take an already-valid automaton as input and should leave the result at
least as clean as it found it — those are the two automatic call sites this report recommends wiring in.

---

## 11. Extended State — Token Tracking

### Motivation

A lexer built on a single multi-pattern DFA must, after reaching an accepting state, know *which* pattern was matched. The classical approach is to annotate final states with a token class during construction and carry that annotation through every transformation.

### `TokenClass`

```swift
public struct TokenClass: Hashable, Codable {
    public let id: Int
    public let name: String
    public let priority: Int  // lower = higher priority
}
```

`TokenClass` is a simple value type. The `priority` field resolves ambiguity: when two patterns both match (e.g., the keyword `"if"` and the identifier pattern `[a-z]+`), the pattern with the numerically lower priority wins. This directly encodes the **first-rule-wins** convention used by lex/flex.

### Storage

The `tokenMap: [Int: TokenClass]` stored inside each `State<T>` case maps final-state identifiers to their `TokenClass`. Non-final states are simply absent from the map. Mutating access goes through `setTokenMap(_:)`, which reconstructs the enum case with the new map while preserving all other fields.

### `recognizeWithToken(string:)`

This method combines simulation with token lookup:

1. Run `runAndGetFinalState(string:)` — identical to `run` but returns the accepting state integer instead of a Bool.
2. Look up the state in `tokenMap`.

For NFAs, `runAndGetFinalState` resolves ambiguity among multiple active accepting states by choosing the one with the minimum `priority` value.

### Migration status

The migration has been applied to:
- `State<T>` — storage and accessors ✓
- `Determinize.swift` — powerset construction propagates token map (has the shadowing bug described in §8) ✗
- `Minimize.swift` — Hopcroft respects token class partitions (has the `.range` typo described in §9) ✗
- `NFSA` initializer — still uses the tokenMap-less overload ✗
- `Automaton<T>` initializers — strip the token map when wrapping ✗
- `Graphvizable` — does not render token class labels on final states ✗

---

## 12. DAWG / String Union

`TrieBuilder` builds a trie from a sorted list of strings, then applies Daciuk's incremental minimization algorithm to produce a **Directed Acyclic Word Graph** (DAWG). Shared suffixes are merged, yielding the minimal DFA for the given finite set of words.

`DFSA.stringUnion(words:)` wraps this: it inserts all words, calls `builder.minimize()`, then traverses the trie to collect `finals` and `transitions` into a `DFSA`.

This is the most efficient way to build a keyword-recognition automaton: the result is already minimal and deterministic, with no need for a subsequent powerset or Hopcroft pass.

---

## 13. Graphviz Rendering

Every concrete automaton type and `State<T>` itself conforms to the `Graphvizable` protocol:

```swift
protocol Graphvizable {
    var graphviz: Graph { get }
}
```

The implementation in `Graphvizable.swift` renumbers states 0…n-1 for compact output, assigns `doublecircle` shape to final states and `circle` to others, renders a `point`-shaped pseudo-node with an arrow into the initial state, and labels each edge with its `AlphabetRange` description.

**Missing feature**: the token class name is not rendered as part of the final-state label. A useful extension would be to append the `TokenClass.name` to the node label for tagged final states.

---

## 14. Random Automaton Generation

`DeterministicGenerator` and `NondeterministicGenerator` (in `FSA/Generators/`) produce randomly structured automata guided by a `GenerateOptions` struct. The DFA generator uses a "bridge" strategy that guarantees:

- All states are reachable from the initial state.
- All states can reach at least one final state.
- Each (state, symbol) pair has at most one outgoing transition (DFA invariant).

`SymbolGenerator` handles random selection from the alphabet defined in `GenerateOptions`.

These generators are primarily useful for randomized testing and benchmarking minimization or determinization pipelines.

---

## 15. Known Issues and Improvement Areas

This section catalogues bugs, incomplete work, and design issues found during the audit, ordered from blocking to cosmetic.

> **Note on currency**: this catalogue was assembled in one audit pass and has not been fully re-verified since. Several rounds of fixes have landed since some entries were written — 15.2 and 15.12 below are confirmed resolved in the current source as of the Antimirov implementation (§7.4) — but the remaining entries have not all been individually re-checked against the current code. Treat this section as a historical record to verify against the current source, not a guaranteed-current bug list.

### 15.1 ~~Shadowed counter variable in `Determinize.swift`~~ — RESOLVED

**Location**: `Determinize/Determinize.swift`.

This entry originally described `let nextDfaState: Int` shadowing an outer `var nextDfaState: Int = 0` counter, causing a compile error. The current source uses distinct names throughout (`nextId` for the counter, `targetDfaState` for the per-iteration result) — confirmed while implementing §7.4/§9.2 — and has no such shadowing. No action needed.

### 15.2 ~~`transition.range` typo in `Minimize.swift`~~ — RESOLVED

**Location**: `Minimize/Minimize.swift`.

This entry originally described `.char(let c)` being pattern-matched against a nonexistent `transition.range` property instead of `transition.alphabetRange`, which would have prevented the file from compiling. The current source already uses `transition.alphabetRange` throughout (confirmed while implementing §7.4/§9.2) — no action needed.

### 15.3 ~~`AlphabetEpsRange` duplicates `AlphabetRange`~~ — RESOLVED

`AlphabetRange` already has an `.epsilon` case. `AlphabetEpsRange` is an exact structural copy and is not referenced anywhere in the current codebase. It should be deleted.

### 15.4 ~~`reachableStates(from:)` returns only direct successors~~ — RESOLVED

**Location**: `State.swift` (T-agnostic extension), lines 241-252.

**Status**: FALSE POSITIVE ✅ — The current implementation is CORRECT.

**Current Implementation**:
```swift
public func reachableStates(from source: Int) -> Set<Int> {
    let transitions = fields.transitions
    var visited = Set<Int>([source])
    var queue = [source]
    while !queue.isEmpty {
        let current = queue.removeFirst()
        for t in transitions where t.source == current {
            if visited.insert(t.target).inserted { queue.append(t.target) }
        }
    }
    return visited
}
```

**What was the issue**: The Technical.md description referenced old code that returned only direct successors via a simple filter/map. This code is no longer in the repository.

**Current behavior**: The implementation uses a proper **BFS (Breadth-First Search)** algorithm that correctly computes all transitively reachable states:
1. Initialize visited set with source state
2. Use queue for BFS exploration
3. For each state in queue, find all outgoing transitions
4. Add unvisited successors to both visited set and queue
5. Return all visited states when queue is empty

**Verification**: For any graph reachable states are computed transitively, not just direct successors.

Example: Graph `0 → 1 → 2 → 3` returns `{0,1,2,3}`, not just `{1}`.

**Note**: The issue description in Technical.md was outdated and referenced code that had already been fixed. No further action needed — the implementation is correct and matches its documented contract.

### 15.5 ~~`isEmpty` always returns `false`~~ — RESOLVED

**Location**: `State.swift`, `isEmpty` computed property.

```swift
public var isEmpty: Bool {
    return false
}
```

The commented-out `.empty` case from the old design was never ported to the new design. The property should return `true` when both `finals` and `transitions` are empty (i.e., the automaton accepts no string, not even ε).

**Fix**:

```swift
public var isEmpty: Bool {
    switch self {
    case let .nfa(_, finals, transitions, _):
        return finals.isEmpty && transitions.isEmpty
    case let .dfa(_, finals, transitions, _, _):
        return finals.isEmpty && transitions.isEmpty
    }
}
```

### 15.6 ~~`isEquivalent` always returns `false`~~ — RESOLVED

**Location**: `State.swift` (DFSA extension), lines 650-754.

**What was broken**: The method returned `false` immediately, with disabled BFS code referencing undefined variables.

**Fix implemented** (June 2026): Full BFS-based equivalence checking algorithm:
- Algorithm: Two DFAs are equivalent iff they accept the same language
- Approach: BFS from `(initial[self], initial[other])`, verifying:
  1. Both states in each visited pair are accepting or both are non-accepting
  2. For all symbols in the union of both alphabets, successors are equivalent
  3. Both DFAs have successors on a symbol or both don't
- Implementation: Builds closure of reachable pairs, correctly handling character ranges
- Returns `true` when all reachable pairs are equivalent

**Status**: RESOLVED ✅ (fully functional equivalence checking for minimization verification)

### 15.7 ~~`Automaton.union(list:)` is a stub~~ — RESOLVED

**Location**: `Operations.swift`, `union(list:)`.

```swift
public static func union(list: [Automaton]) -> Automaton {
    return Automaton(initial: 0, finals: Set<Int>(), transitions: Set<Transition>(), minimal: false)
}
```

The commented-out block shows the intended approach (introduce a new start state with ε-transitions to each sub-automaton's start state). This is the key operation for building a multi-pattern lexer and should be prioritized alongside the token tracking work.

**Suggested approach**:
1. Renumber each sub-automaton's states to be disjoint using `Counter.shared`.
2. Create a fresh initial state.
3. Add ε-transitions from the fresh initial to each sub-automaton's initial state.
4. Take the union of all transition sets and final sets.
5. Propagate token maps from each component.

### 15.8 ~~`Automaton<T>` initializers strip the token map~~ — RESOLVED 

**Location**: `Automaton.swift`, all three `init` overloads.

All three constructors pattern-match against the old 4-tuple `.nfa`/`.dfa` cases (without `tokenMap`) and would need updating to pass through the token map. Until this is done, wrapping a token-tagged FSA in `Automaton<T>` silently discards all token class information.

### 15.9 ~~`Graphvizable` does not render token class labels~~ — RESOLVED

**Location**: `Graphvizable.swift`, lines 12-94.

**What was the issue**: Final states in Graphviz output marked with `doublecircle` but token class names not shown.

**Current state**: RESOLVED ✅ — Code already renders token class labels:
- Line 35 (NFA case): `let label = tokenMap[s].map { "\(id)\n\($0.name)" } ?? "\(id)"`
- Line 67 (DFA case): `let label = tokenMap[s].map { "\(id)\n\($0.name)" } ?? "\(id)"`

When a final state carries a `TokenClass`, its name is appended to the node label (with newline separation from state ID), making token classes visible in rendered diagrams. No action needed.

### 15.10 ~~`inAlphabet(char:)` returns `true` for ε-transitions~~ — RESOLVED

**Location**: `Transition.swift`, lines 57-83.

**What was the issue**: `.epsilon` transition returning `true` from `inAlphabet`, appearing to match every input character.

**Current state**: RESOLVED ✅ — Code correctly returns `false` for `.epsilon`:
- Line 59: `case .epsilon: return false`
- Line 77: `case .epsilon: return false` (in range variant)

Documentation (lines 52-54) explicitly notes: "Returns `false` for `.epsilon` transitions; the ε-closure computation should pattern-match on `.epsilon` directly rather than calling this method."

The fix ensures epsilon transitions are excluded from alphabet membership checks, preventing silent incorrect results at non-ε-closure call sites. No action needed.

### 15.11 ~~`step(state:symbol:over:)` on DFA uses `Set.first` without determinism guarantee~~ — RESOLVED

**Location**: `State.swift`, lines 510-530 and 555-575.

**What was the issue**: Methods `step()` and `successor()` used `.first` on a Set of potential successors without verifying the DFA invariant (at most one successor per state/symbol pair).

**Fix implemented** (June 2026): Added `precondition` checks in both methods:

```swift
precondition(nextStates.count <= 1,
    "DFA invariant violation: state \(state) has \(nextStates.count) successors on '\(symbol)' (expected ≤ 1)")
return nextStates.first
```

**How it works**:
- In a correctly constructed DFA, there is at most one successor per state/symbol pair
- During intermediate construction (before `invariant()` is called), multiple transitions may exist
- The precondition immediately surfaces violations in debug builds
- In release builds, the check is optimized away per Swift semantics

**Status**: RESOLVED ✅ (DFA invariant now validated with immediate failure on violations)

### 15.12 ~~DFA `minimize()` is stubbed out on `State<T>` itself~~ — RESOLVED

**Location**: `State.swift`, `minimize()` inside the `extension State where T == DFSA` block.

This entry originally described `minimize()` as a commented-out stub at the `State<T>` level, separate from (and not delegating to) the real implementation in `Minimize.swift`. The current source's `State where T == DFSA` extension wraps the call site's `(initial, finals, transitions)` into a fresh `DFSA`, invokes the real Hopcroft minimization on it, and writes the result back to `self` — it is a working delegation, not a stub. `NFSA/DFSA.minimize()` calls through to it the same way. No action needed.

### 15.13 ~~Typos in identifiers and comments~~ — RESOLVED

- ~~File name: `FIniteStateProtocol.swift` — capital `I` in `FInite`. (Note: no file by this name exists in the current source tree; the FSA protocol now lives in `FSA.swift`. Re-verify before acting on this entry.)~~ - RESOLVED
- ~~Comment: `"autmaton"` (missing 'o') appears in several places.~~ - RESOLVED 
- ~~`BerrySehti.swift` (`Construction/BerrySehti.swift`) — the algorithm name is Berry-Sethi; "Sehti" is a misspelling.~~ - RESOLVED 
- ~~`ConstructionMethod.berrySethi` — inconsistently named `berrySethi` in code but `BerrySethi`/`BerrySehti` in file and type names.~~ - RESOLVED 
- ~~`generateOptions` → should be `GenerateOptions` consistently.~~ - RESOLVED

### 15.14 Transition table representation is O(|Δ|) per lookup

All step functions iterate over `Set<Transition>` filtered by source state. For automata with hundreds of states and a large alphabet, this is O(|Δ|) per character. A nested dictionary `[Int: [Character: Int]]` (state → symbol → target) would reduce DFA simulation to O(1) amortized per character, at the cost of higher memory usage. A two-level array `[[Int]]` indexed by renumbered states and alphabet positions is the classic representation and would also improve cache locality.

### 15.15 ~~`RegexParser` crashes instead of throwing on truncated/malformed input~~ — RESOLVED

**Location**: `Regex/Parsing/RegexParser.swift`.

`current` is a computed property guarded by `assert(self.index < string.endIndex)`. Several call sites — the `{n,m}` quantifier's "did we find a digit" / "did we find the closing brace" checks, the unclosed-`[...]`, unclosed-`(...)`, and unclosed-`<...>` checks, the string-literal closing-delimiter check, and `parseSimpleExpression`'s final char-expression fallback — accessed `current` to build an error message *after* a failed `match()`, without first checking whether input remained (`more`). For any pattern that runs out of input exactly at one of these points (`"a{"`, `"[a-z"`, `"<10-20"`, `"a|("`, an unterminated string), this asserted/crashed instead of throwing a `ParseError`, which is why the `RegexParsingDifficultTests.parserErrors` stress test was disabled.

**Fix**: added a new `ParseError.unexpectedEndOfInput(Int)` case, and every such call site now checks `more` first and throws that case instead of touching `current` when input is exhausted. The disabled test is re-enabled.

As a related fix in the same file: the string-literal delimiter was `'...'` (single quote) in the implementation but documented (and escape-handled, via the `\"` case in `parseCharExp`) as `"..."` (double quote) — the grammar comment at the top of the file has always said `" <Unicode string> "`. The delimiter now matches the documented grammar.

### 15.16 ~~Thompson's `empty()` conflates the empty language (∅) with the empty string (ε)~~ — RESOLVED

**Location**: `Regex/Construction/Thompson.swift`.

`empty()` built a single-state automaton (`start == terminal`, no transitions) and was used for *both* `case .empty: return empty()` (compiling the `#` / empty-language syntax) *and* as the zero-repetitions base case inside `repeatMinMax`. A single-state automaton with no transitions, where that one state is both initial and final, accepts exactly `{ε}` — correct for the second use, wrong for the first: every other construction method in the codebase (`nullable(.empty)` in `PartialDerivative.swift`, the `'#' sentinel` check in `BerrySethi.swift`) treats `Expression.empty` as ∅ (matches nothing, not even ε), consistent with the regex grammar's own documentation of `#`.

**Fix**: split into two functions — `epsilon()` (the old behaviour, kept for the `repeatMinMax` base case) and `emptyLanguage()` (a genuinely disjoint start/terminal pair with no transitions between them, so the terminal is unreachable and the automaton's language is truly ∅). `Thompson.compile()`'s `.empty` case now calls `emptyLanguage()`.

A disjoint, unreachable terminal state still gets wrapped into `finals` by `construct()`'s `Set<Int>([enfa.1])`, though, which would make the result a "zombie final state" automaton rather than a clean `finals: []` one. `construct()` was adjusted to only include the terminal in `finals` when it's actually reachable (`enfa.1 == enfa.0`, the ε case, or `enfa.2.states().contains(enfa.1)`, the normal case) — see §10 ("Where should `invariant()` run?") for why this was fixed locally rather than by calling `removeZombieAcceptStates()` after the fact.

The two disabled tests in `RegexToAutomatonTests.swift` (`testNilString`, `testEmptyString`) are re-enabled — the former now passes outright, the latter was rewritten to lock in a deliberate decision (see 15.18 below) rather than testing the ∅/ε distinction directly.

### 15.17 ~~Thompson's `repeatMinMax` (`{n,m}`) builds the wrong automaton~~ — RESOLVED

**Location**: `Regex/Construction/Thompson.swift`, `repeatMinMax(automaton:n:m:)`.

The previous implementation built `n` mandatory copies plus a `repeat()` (Kleene star) in one branch, then *unconditionally overwrote* that list — discarding the mandatory copies — with `(m-n)` mandatory copies plus a single trailing `optional()` whenever `m > n`. For `a{2,4}` this compiled to `a·a·a·a?` ("at least 3, at most 4 a's") instead of `a·a·a?·a?` ("2 to 4 a's"); for `a{0,3}` it discarded the empty/epsilon base case entirely and compiled to `a·a·a·a?` ("at least 3"), accepting nothing in the intended 0–3 range. Crucially, no existing test exercised actual *recognition* against a bounded quantifier (`RegexCompileTests.swift`'s `testSomething3`/`testSomething4` only check the re-rendered AST string), so this shipped silently.

**Fix**: rewritten to match the already-correct `expandRepeatMinMax` in `Expression+Desugar.swift` (used by BerrySethi/Antimirov): `n` mandatory copies followed by `(m-n)` *independently* `optional()` copies, concatenated together, with the `n == m == 0` case falling back to `epsilon()`. New recognition tests (`testBoundedRepeatExact`, `testBoundedRepeatRange`, `testBoundedRepeatZeroToM`, `testBoundedRepeatExactlyZero` in `RegexRunTests.swift`) cover this going forward.

### 15.18 ~~Thompson's `makeInterval` is an unimplemented stub~~ — RESOLVED

**Location**: `Regex/Construction/Thompson.swift`, `makeInterval(min:max:digits:)`.

The implementation computed the zero-padded `min`/`max` strings, assigned them to `_` (discarding them), and returned `ThompsonAutomata(state(), state(), Set<Transition>())` — two fresh, disjoint states with no transitions between them, unconditionally. That shape is exactly the empty-language automaton (see 15.16): a Thompson-constructed numerical interval like `<1-100>` matched nothing at all, regardless of the requested bounds. No existing test caught this because the only interval coverage (`RegexCompileTests.swift`'s `testSomething2`) checks the AST's `description`, not recognition, and no other construction method shares this code path (Antimirov/BerrySethi instead go through the already-correct `expandInterval` in `Expression+Desugar.swift`).

**Fix**: implemented properly — builds one string-literal automaton per value in `min...max` (padded to `digits` width when padding was requested, mirroring `expandInterval`'s own logic), and unions them all together. New recognition tests (`testIntervalRecognition`, `testPaddedIntervalRecognition` in `RegexRunTests.swift`) cover this going forward.

This is also the resolution referenced in 15.16 for `testEmptyString`: rather than guessing whether a bare, zero-character pattern (`Regex("")`) should mean ε or ∅, the parser now rejects it outright as invalid syntax (`ParseError.unexpectedEndOfInput`, via 15.15's fix) — callers write `()` for ε or `#` for ∅ explicitly. `RegexToAutomatonTests.testEmptyString` and a stale, contradictory commented-out test in `RegexRunTests.swift` (which had wanted the opposite behaviour, and was marked "not implemented") are both updated to reflect this.

### 15.19 ~~`Minimize.swift` never merges untagged accepting states~~ — RESOLVED

**Location**: `FSA/Minimize/Minimize.swift`, the initial-partition construction inside `minimize()`.

Every accepting state without a `TokenClass` was placed into its own singleton partition block (`partitions.append([s])`, once per state) rather than one shared block. Hopcroft's algorithm only ever *splits* blocks during refinement, never merges them, so two accepting states that don't carry a token class — i.e. plain, non-lexer DFA minimization — could never be merged even when they were genuinely language-equivalent. `isMinimal` was still set to `true` afterward despite the result not being minimal.

**Fix**: untagged accepting states are now collected into one shared initial block, exactly mirroring how non-accepting states are already handled; refinement is still free to split the block apart for states that are actually distinguishable. `MinimizeTests.swift`'s `equivalentAcceptingStatesWithoutTokenClassesAreMerged` (previously documenting the bug as `..._knownBug`) is updated to lock in the corrected behaviour.

### 15.20 ~~`Package.swift`'s test target can't find its own sources~~ — RESOLVED

**Location**: `Package.swift`, the `.testTarget(name: "LexerFSATests", ...)` declaration.

SwiftPM resolves a target's source directory by convention — `Tests/<target name>/` — unless an explicit `path:` is given. The manifest declared the test target as `LexerFSATests` with no `path:` override, but the actual test sources live under `Tests/AutomatonTests/` (presumably left over from an earlier test-target rename that didn't update the manifest to match). Building or testing this package from the command line (`swift build` / `swift test`) should fail outright at package-graph resolution, before any of this catalogue's other issues even get a chance to matter; Xcode hits the identical resolution logic, so it isn't a command-line-only problem.

**Fix**: added `path: "Tests/AutomatonTests"` to the test target declaration.
