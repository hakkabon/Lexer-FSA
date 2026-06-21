//
//  Lexer.swift
//  lexer-fsa
//
//  Created by code review on 2026/06/17.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

// MARK: - Token Tracking for Lexer Output

/// A token emitted by `Lexer`: the token class plus the slice of the source
/// string it consumed and the source position at which it began.
public struct Token: Equatable {
    /// The resolved token class (lowest-priority-integer accepting state).
    public let tokenClass: TokenClass
    /// The lexeme text matched by the token.
    public let lexeme: Substring
    /// Scalar offset of the first character of `lexeme` in the source string.
    public let startOffset: Int
    /// Scalar offset one past the last character of `lexeme`.
    public let endOffset: Int

    public init(tokenClass: TokenClass, lexeme: Substring, startOffset: Int, endOffset: Int) {
        self.tokenClass = tokenClass
        self.lexeme = lexeme
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

/// Reasons a lexer may stop producing tokens.
public enum LexerError: Error, Equatable {
    /// The scanner reached a character it cannot extend any accepting path
    /// from, before reaching the next accepting state. `offset` is the
    /// scalar offset of the offending character.
    case unexpectedCharacter(offset: Int)
    /// The source is non-empty but no rule accepts even a single character.
    case noMatch(offset: Int)
}

// MARK: - Lexer

/// A streaming lexer over a deterministic finite-state automaton.
///
/// `Lexer` implements the **maximal-munch** (longest-match) rule used by
/// scanner generators such as lex/flex:
///
///   1. Begin at the current source offset and the DFA's initial state.
///   2. Consume characters one at a time, walking the DFA's transition
///      function. Whenever an accepting state is reached, remember it
///      along with the offset at which it was reached ("last accept").
///   3. Stop when either the input is exhausted or the DFA has no
///      transition for the next character.
///   4. If a last-accept was recorded, emit a token for the slice
///      `[start .. lastAcceptOffset]`, look up its `TokenClass` in the
///      DFA's `tokenMap`, advance the source offset to `lastAcceptOffset`,
///      and continue.
///   5. If no last-accept was recorded, the scanner is stuck — emit
///      `.unexpectedCharacter(offset:)` or `.noMatch(offset:)` and stop.
///
/// Whitespace / comments are handled by attaching a low-priority `SKIP`
/// `TokenClass` to the corresponding pattern, then dropping those tokens
/// from the output stream of the parser.
///
/// **Requirement**: the input `Automaton<DFSA>` must be deterministic.
/// NFA-only automata cannot be lexed (the maximal-munch loop assumes
/// `step(state:symbol:)` returns at most one successor). Use
/// `automaton.determinize()` (on NFSA) or `regex.isDeterministic = true`
/// before constructing the lexer.
public struct Lexer {

    /// The deterministic automaton this lexer drives.
    public let dfa: Automaton<DFSA>

    /// Creates a lexer over the given DFA. The DFA must already be
    /// deterministic; constructing a lexer over an NFA is a programmer
    /// error and will trap at the first call to `nextToken`.
    public init(_ dfa: Automaton<DFSA>) {
        self.dfa = dfa
    }

    /// Convenience initializer over an already-deterministic Regex.
    /// Setting `regex.isDeterministic = true` before passing the regex
    /// ensures the underlying state is `.dfa`. If the regex is still
    /// non-deterministic, the lexer is still constructed but
    /// `nextToken` will not be able to advance — every call will return
    /// `.noMatch` or `.unexpectedCharacter`.
    public init(_ regex: Regex) {
        switch regex.state {
        case let .nfa(initial, finals, transitions, tokenMap):
            // Non-deterministic regex; accept construction for
            // diagnostics-friendly failure rather than trapping here.
            self.dfa = Automaton<DFSA>(DFSA(
                initial: initial, finals: finals,
                transitions: transitions, minimal: false,
                tokenMap: tokenMap))
        case let .dfa(initial, finals, transitions, minimal, tokenMap):
            self.dfa = Automaton<DFSA>(DFSA(
                initial: initial, finals: finals,
                transitions: transitions, minimal: minimal,
                tokenMap: tokenMap))
        }
    }

    // MARK: - Single-token API

    /// Attempts to read the next token from `source` starting at `offset`.
    ///
    /// On success, returns the token *and* the new source offset (the
    /// position immediately after the consumed lexeme). On failure,
    /// returns a `LexerError` indicating where the lexer got stuck.
    ///
    /// - Parameters:
    ///   - source: the source text being lexed.
    ///   - offset: the scalar offset at which to begin scanning.
    /// - Returns: the token and the offset of the next unread character.
    public func nextToken(in source: String, from offset: Int) -> Result<Token, LexerError> {
        let scalars = source.unicodeScalars
        guard offset <= scalars.count else {
            return .failure(.noMatch(offset: offset))
        }
        if offset == scalars.count {
            // Nothing to scan — no token to emit.
            return .failure(.noMatch(offset: offset))
        }
        return scan(source: source, from: offset)
    }

    /// Scans the entire source into a token array, stopping at the first
    /// lexer error.
    ///
    /// Useful for batch lexing where the source is known to be valid.
    /// For streaming use, call `nextToken(in:from:)` in a loop.
    public func tokenize(_ source: String) -> Result<[Token], LexerError> {
        var tokens: [Token] = []
        var offset = 0
        let total = source.unicodeScalars.count
        while offset < total {
            switch nextToken(in: source, from: offset) {
            case .success(let token):
                tokens.append(token)
                offset = token.endOffset
            case .failure(let err):
                return .failure(err)
            }
        }
        return .success(tokens)
    }

    // MARK: - Internals

    /// Core maximal-munch scan. Walks the DFA from `initial`, remembering
    /// the most recent accepting state and the offset at which it was
    /// reached. Stops when either the source is exhausted or `step`
    /// returns `nil` for the next character.
    private func scan(source: String, from startOffset: Int) -> Result<Token, LexerError> {
        let scalars = source.unicodeScalars
        var scalarIndex = scalars.index(scalars.startIndex, offsetBy: startOffset)

        var current = dfa.initial
        // If the initial state is itself accepting (matches ε), record it
        // as the trivial last-accept at offset `startOffset`.
        var lastAccept: (state: Int, scalarOffset: Int)? =
            dfa.isFinal(state: current) ? (current, startOffset) : nil
        var consumed = startOffset

        while scalarIndex < scalars.endIndex {
            let ch = Character(scalars[scalarIndex])
            guard let next = dfa.step(state: current, symbol: ch) else {
                // No outgoing transition. Either emit the last accept
                // (longest match) or signal an error.
                break
            }
            current = next
            scalarIndex = scalars.index(after: scalarIndex)
            consumed += 1
            if dfa.isFinal(state: current) {
                lastAccept = (current, consumed)
            }
        }

        guard let (finalState, endOffset) = lastAccept else {
            // We consumed at least one character but never reached an
            // accepting state.
            return .failure(startOffset == consumed
                ? .noMatch(offset: startOffset)
                : .unexpectedCharacter(offset: startOffset))
        }

        guard let tokenClass = dfa.tokenClass(for: finalState) else {
            // An accepting state with no token class attached is a
            // programmer error in the DFA's construction. Treat it as a
            // scan failure rather than crash.
            return .failure(.noMatch(offset: startOffset))
        }

        // Slice the lexeme out of the source.
        let startScalarIdx = scalars.index(scalars.startIndex, offsetBy: startOffset)
        let endScalarIdx   = scalars.index(scalars.startIndex, offsetBy: endOffset)
        let lexeme = source[startScalarIdx..<endScalarIdx]

        return .success(Token(
            tokenClass: tokenClass,
            lexeme: lexeme,
            startOffset: startOffset,
            endOffset: endOffset))
    }
}
