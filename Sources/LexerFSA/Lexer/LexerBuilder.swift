//
//  LexerBuilder.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/20.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

/// This component iterates through your grammar rules, parses the regexes, builds individual NFAs,
/// and stitches them together.

/// Key Considerations for Your Integration
/// Keyword vs. Identifier Conflict:
/// If you have a keyword if and an identifier rule [a-z]+, the string if matches both.
/// Resolution via Automata: Give the keyword rule priority = 0 and the identifier
/// rule priority = 1. When the NFA is converted to DFA, the accepting state for if will
/// naturally inherit the keyword's priority.
/// Alternative (Simpler): Only define identifiers, numbers, and symbols in the Lexer Automata.
/// Let the Automata emit Identifier("if"). Then, run a post-processing mapping function that
/// transforms Identifier("if") into Keyword("if"). (This makes the DFA much smaller).
///
/// DFA Minimization: Thompson’s construction + subset construction generates large DFAs.
/// If you haven't already, ensure you run Hopcroft's algorithm or Brzozowski's algorithm
/// to minimize the DFA before passing it to Lexer.
/// Swift String Performance: Because Swift's String is Unicode-safe, input.index(after:)
/// traverses variable-width grapheme clusters, which is perfectly correct for modern parsing,
/// but slightly slower. If your language is strictly ASCII, you can gain massive performance
/// by operating on input.utf8 arrays instead.

#if false

public class LexerBuilder {
    private var rules: [LexerRule] = []
    
    public func addRule(_ rule: LexerRule) {
        rules.append(rule)
    }
    
    public func build() -> Lexer {
        // 1. Create a master start state for the Union NFA
        let masterStartState = NFAState()
        var skippedTypes: Set<AnyHashable> = []
        
        // 2. Build individual NFAs and link them
        for rule in rules {
            if rule.isSkipped { skippedTypes.insert(rule.tokenType) }
            
            // Assume RegexEngine is your existing module
            let ruleNFA = RegexEngine.buildNFA(from: rule.pattern)
            
            // Tag the accepting state(s) of this specific NFA
            for acceptState in ruleNFA.acceptingStates {
                acceptState.isAccepting = true
                acceptState.tokenType = rule.tokenType
                acceptState.priority = rule.priority
            }
            
            // Add an ε-transition from the master start state to the rule's start state
            masterStartState.addEpsilonTransition(to: ruleNFA.startState)
        }
        
        let combinedNFA = NFA(startState: masterStartState)
        
        // 3. Convert to DFA using your existing subset construction.
        // Ensure your subset construction calls `resolveAcceptingState` as defined above.
        let compiledDFA = DFA(from: combinedNFA)
        
        return Lexer(dfa: compiledDFA, skippedTypes: skippedTypes)
    }
}

#endif
