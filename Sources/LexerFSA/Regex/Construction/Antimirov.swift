//
//  Antimirov.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2026/06/16.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation

extension Regex {
    
    struct Antimirov: RegularLanguageBuilder {
        var expression: Expression = .empty

        // Parser
        var parser: RegexParser

        init(expression: String, flags: SyntaxOptions) {
            // Always enable .empty so the parser recognises '#' as Expression.empty.
            // Without this flag '#' is consumed as a plain character by parseCharExp().
            let augmentedFlags = flags.union(.empty)
            parser = RegexParser(expression: expression + "#", augmentedFlags)
        }

        mutating func construct() throws -> State<Regex> {
            return .dfa(initial: 0, finals: Set(), transitions: Set<Transition>(), minimal: true, tokenMap: [:])
        }
    }
}
