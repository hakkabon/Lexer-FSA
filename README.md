# Lexer-FSA

A Swift package providing a complete **Finite State Automaton** (FSA) library designed for use as a lexer in parser pipelines. It supports both Nondeterministic (NFA) and Deterministic (DFA) automata, regular expression compilation via three construction algorithms, two independent DFA minimization algorithms, Graphviz visualization, and **Token Class Tracking** for direct integration into lexer frontends.

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)  
[![Platforms](https://img.shields.io/badge/platforms-macOS%2011%20%7C%20iOS%2012-blue.svg)](https://developer.apple.com/swift/)  
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)  

---

## Features

- **Lexer builder** — `LexerBuilder` combines multiple regex patterns, each tagged with a token class, into a single maximal-munch scanner
- **NFA and DFA** — first-class, type-safe representations backed by a single `State<T>` enum
- **Regular expressions** — compile regex strings to automata via Thompson's construction, Berry-Sethi's position automaton, or Antimirov's partial-derivative automaton
- **Powerset (subset) construction** — determinize any NFA into an equivalent DFA, with token-class priority resolution
- **DFA minimization** — two independent algorithms: token-class-aware Hopcroft partition refinement (`DFSA.minimize()`, in progress), and Brzozowski's double-reversal algorithm
- **Token tracking** — extended state maps final states to `TokenClass` values; designed for multi-pattern lexers
- **DAWG / trie union** — build a minimal DFA from a set of literal strings using a Directed Acyclic Word Graph
- **Alphabet intervals** — transitions carry compact character ranges, not flat character sets
- **Graphviz rendering** — every automaton exposes a `graphviz` property for DOT-format visualization
- **Random automaton generation** — `GenerateOptions`-driven NFA/DFA generators for testing and benchmarking
- **Support ADTs** — `Stack`, `Queue`, `BitArray`, and `BinarySearch` bundled in the package

---

## Quick Start

### 1 — Build a multi-pattern lexer (the typical use case)

```swift
import LexerFSA

let identifierToken = TokenClass(id: 1, name: "IDENTIFIER", priority: 10)
let keywordToken    = TokenClass(id: 2, name: "KEYWORD",    priority: 1)
let numberToken     = TokenClass(id: 3, name: "NUMBER",     priority: 5)

var builder = LexerBuilder()
builder.addRule(pattern: "[a-zA-Z_][a-zA-Z0-9_]*", token: identifierToken)
builder.addRule(pattern: "if|else|while|for",      token: keywordToken)
builder.addRule(pattern: "[0-9]+",                 token: numberToken)
builder.addSkip(" ")  // Skip whitespace

let lexer = try builder.build()

// Tokenize a source buffer
if case .success(let tokens) = lexer.tokenize("if x123 else") {
    for token in tokens {
        print("\(token.tokenClass.name): \(String(token.lexeme))")
    }
    // Output:
    // KEYWORD: if
    // IDENTIFIER: x123
    // KEYWORD: else
}
```

### 2 — Compile a regular expression and recognize strings

```swift
import LexerFSA

// Compile using Thompson's construction (default)
let re = try Regex("[a-zA-Z][a-zA-Z0-9_]*")

// Recognize a string against the NFA
print(re.recognize(string: "myVar"))    // true
print(re.recognize(string: "3bad"))     // false
```

Three construction methods are available, selected via `method:`:

```swift
try Regex(pattern)                              // Thompson's ε-NFA assembly (default)
try Regex(pattern, method: .berrySethi)        // Berry-Sethi position automaton (direct-to-DFA)
try Regex(pattern, method: .derivative)        // Antimirov partial derivatives + Brzozowski minimization
```

`.derivative` is the only one of the three that returns an already-**minimal** DFA directly from `construct()` — no separate minimization pass is needed:

```swift
let r = try Regex("(a|b)*abb", method: .derivative)
print(r.isMinimal)   // true
```

### 3 — Work with an NFA directly

```swift
var nfa = NFSA(
    initial: 0,
    finals: [2],
    transitions: [
        Transition(from: 0, AlphabetRange.char("a"), to: 1),
        Transition(from: 1, AlphabetRange.epsilon,   to: 2),
        Transition(from: 1, AlphabetRange.char("b"), to: 1),
    ]
)

print(nfa.run(string: "a"))    // true
print(nfa.run(string: "ab"))   // true
print(nfa.run(string: "b"))    // false
```

### 4 — Determinize an NFA into a DFA

```swift
nfa.determinize()   // mutates nfa.state from .nfa to .dfa
print(nfa.isDeterministic)  // true
```

### 5 — Token-class tracking (direct query)

```swift
let identToken = TokenClass(id: 1, name: "IDENTIFIER", priority: 10)
let kwToken    = TokenClass(id: 2, name: "KEYWORD",    priority: 1)

// Build NFA with token map on its final states
var nfa = NFSA(
    initial: 0,
    finals: [3, 5],
    transitions: [ /* ... */ ]
)
nfa.state.setTokenMap([3: identToken, 5: kwToken])

// Query which token class an input matches
if let tok = nfa.state.recognizeWithToken(string: "if") {
    print(tok.name)  // KEYWORD
}
```

### 6 — Build a minimal DFA from a word list (DAWG)

```swift
let keywords = ["if", "else", "while", "for", "return"]
let dfa = DFSA.stringUnion(words: keywords)
print(dfa.run(string: "while"))   // true
print(dfa.run(string: "whirl"))   // false
```

### 7 — Visualize with Graphviz

```swift
let re = try Regex("ab*c")
let dot = re.graphviz   // GraphViz.Graph
// Render to SVG, PNG, etc. using the GraphViz library
```

---

## Package Structure

```
Sources/LexerFSA/
├── Lexer/
│   ├── Lexer.swift                  # Maximal-munch scanning over a DFA
│   └── LexerBuilder.swift           # Builder for multi-pattern lexers
├── FSA/
│   ├── FSA.swift                    # FSA protocol + default implementations
│   ├── DFSA.swift                   # DFSA struct (deterministic automaton)
│   ├── DFSA+Operations.swift        # Union and string-union for DFSAs
│   ├── NFSA.swift                   # NFSA struct (nondeterministic automaton)
│   ├── NFSA+Operations.swift        # Union convenience for NFSAs
│   ├── State/
│   │   ├── State.swift              # Core State<T> enum — NFA/DFA + token map
│   │   ├── State+Union.swift        # NFA union at the State level
│   │   ├── Invariant.swift          # Dead-state removal, reduce, zombie cleanup
│   │   └── Graphvizable.swift       # DOT/Graphviz rendering
│   ├── Transitions/
│   │   ├── AlphabetRange.swift      # .epsilon / .char / .range cases
│   │   ├── Transition.swift         # Transition struct (source, range, target)
│   │   └── Alphabet.swift           # Interval-based alphabet representation
│   ├── Determinize/
│   │   └── Determinize.swift        # Powerset construction with token-map propagation
│   ├── Minimize/
│   │   ├── Minimize.swift           # Token-class-aware Hopcroft minimization
│   │   └── BrzozowskiMinimize.swift # Double-reversal minimization
│   └── Generators/
│       ├── DeterministicGenerator.swift
│       ├── NondeterministicGenerator.swift
│       ├── Options.swift
│       └── SymbolGenerator.swift
├── Regex/
│   ├── Regex.swift                  # Regex struct — main entry point
│   ├── RegexRecognize.swift         # Recognition helpers
│   ├── SyntaxOptions.swift          # SyntaxOptions flags
│   ├── Expression.swift             # AST node types (parser output)
│   ├── Expression+Desugar.swift     # Shared expansion of {n,}/{n,m}/<lo-hi> syntax
│   ├── RegularLanguage/
│   │   └── RegularLanguage.swift    # RegularLanguageBuilder protocol, ConstructionMethod
│   ├── Construction/
│   │   ├── Thompson.swift           # Thompson's ε-NFA construction
│   │   ├── BerrySehti.swift         # Berry-Sethi position automaton (direct-to-DFA)
│   │   ├── Antimirov.swift          # Antimirov partial-derivative automaton + Brzozowski minimization
│   │   └── PartialDerivative.swift  # nullable/partialDerivative/concreteAlphabet utilities
│   ├── Minimize/
│   │   └── BrzozowskiMinimize.swift # Double-reversal minimization for Regex
│   └── Parsing/
│       ├── RegexParser.swift        # Recursive-descent regex parser
│       └── RegexNode.swift          # AST nodes for Berry-Sethi construction
├── DAWG/
│   └── TrieBuilder.swift            # Trie-to-DAWG minimization
├── ADTs/
│   ├── Stack.swift
│   ├── Queue.swift
│   ├── BitArray.swift
│   ├── BinarySearch.swift
│   └── Tuple.swift
└── Utils/
    ├── Array+Extensions.swift
    ├── Character+Extensions.swift
    ├── Coding+Extensions.swift
    ├── Counter.swift
    ├── Dictionary+Extensions.swift
    ├── PrettyPrint.swift
    ├── StatePair.swift
    ├── String+Extensions.swift
    └── StringProtocol+Extensions.swift
```

---

## Regex Syntax

| Construct | Syntax | Example |  
|---|---|---|  
| Literal character | `a` | `a` matches `"a"` |  
| Concatenation | `ab` | `ab` matches `"ab"` |  
| Alternation | `a\|b` | `a\|b` matches `"a"` or `"b"` |  
| Kleene star | `a*` | `a*` matches `""`, `"a"`, `"aa"`, … |  
| One or more | `a+` | `a+` matches `"a"`, `"aa"`, … |  
| Optional | `a?` | `a?` matches `""` or `"a"` |  
| Bounded repeat | `a{n,}`, `a{n,m}` | `a{2,3}` matches `"aa"` or `"aaa"` |  
| Grouping | `(ab)*` | `(ab)*` matches `""`, `"ab"`, `"abab"`, … |  
| Character class | `[a-z]` | `[a-z]` matches any lowercase letter |  
| Character union | `[aeiou]` | matches any vowel |  
| Any character | `.` | matches any single character |  
| Any string | `@` | matches any string, including `""` (requires `SyntaxOptions.anyString`) |  
| Numerical interval | `<lo-hi>` | `<0-9>` matches `"0"`…`"9"` (requires `SyntaxOptions.interval`) |  
| Empty language | `#` | matches nothing at all, not even `""` (requires `SyntaxOptions.empty`) |  
| Escape | `\\.` | matches a literal `.` |  

---

## Architecture Notes

The central abstraction is `State<T>`, a generic enum with two cases (`.nfa` and `.dfa`) parameterized by a phantom type `T` that constrains which protocol extensions are visible on a given instance. `NFSA`, `DFSA`, and `Regex` each carry a `State<Self>` as their stored property and expose the full NFA or DFA API through conditional extensions.

The token tracking feature adds a `tokenMap: [Int: TokenClass]` field to both enum cases. When the powerset construction runs, it propagates the highest-priority token class from the set of NFA accepting states that map to each new DFA state — directly implementing the **longest match / maximal munch** rule used in scanner generators.

### Lexer Builder

`LexerBuilder` is the idiomatic API for assembling multi-pattern lexers:

```swift
var builder = LexerBuilder()
builder.addRule(pattern: "[0-9]+", token: numberToken)
builder.addRule(pattern: "[a-z]+", token: identToken)
builder.addSkip("\\s+")  // Regex for whitespace

let lexer = try builder.build()  // Returns a Lexer wrapping a DFA
```

The builder collects each rule as a `Regex`, unions them all into a single NFA, determinizes the union (resolving token priorities via Hopcroft), minimizes the result, and wraps it in a `Lexer` that performs maximal-munch scanning.

### Three regex constructions, one contract

`Thompson`, `BerrySethi`, and `Antimirov` all conform to `RegularLanguageBuilder` and are free to represent the expression however suits the algorithm:

- **Thompson** assembles an ε-NFA recursively, one fragment per sub-expression, glued together with ε-transitions. Determinism is a separate step.
- **Berry-Sethi** builds a *position* automaton directly: it labels every leaf of the expression with a unique position, computes `firstpos`/`lastpos`/`followpos` over an immutable `RegexNode` tree, and turns the resulting `followpos` table straight into a DFA.
- **Antimirov** builds a *partial-derivative* automaton: each DFA state IS a `Set<Expression>` of the partial derivatives reachable so far, starting from `{ pattern }`. This is deterministic by construction and is then run through Brzozowski's double-reversal algorithm to guarantee minimality.

### Two independent DFA minimizers

`DFSA.minimize()` is Hopcroft's partition-refinement algorithm, written with multi-pattern lexer DFAs in mind: token-class-aware to ensure states representing different tokens are never merged.

`brzozowskiMinimize(initial:finals:transitions:)` is a completely independent algorithm — reverse, determinize, reverse, determinize — reusing the package's existing NFA subset construction. It has no notion of token classes, so it always reaches the true minimum for plain acceptance.

---

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/hakkabon/Lexer-FSA.git", branch: "main"),
],
targets: [
    .target(
        name: "YourTarget", 
        dependencies: [
            .product(name: "LexerFSA", package: "Lexer-FSA"),
        ]
    ),
]
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.
