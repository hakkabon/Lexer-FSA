//
//  SyntaxOptions.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/05.
//

import Foundation

/// Syntax options that enable/disable certain optional parts of the regular expression syntax.
public struct SyntaxOptions: OptionSet {
    public let rawValue: Int
    
    public static let empty = SyntaxOptions(rawValue: 1 << 0)          // empty language (#)
    public static let anyString = SyntaxOptions(rawValue: 1 << 1)      // anystring (@)
    public static let automaton = SyntaxOptions(rawValue: 1 << 2)      // named automata (<identifier>)
    public static let interval = SyntaxOptions(rawValue: 1 << 3)       // numerical intervals (<n-m>)
    
    /// Syntax options frequently used.
    public static let basic: SyntaxOptions = [.empty, .anyString, .interval]
    public static let all: SyntaxOptions = [.empty, .anyString, .automaton, .interval]
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
