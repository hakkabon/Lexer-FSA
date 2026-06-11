//
//  RegularExpression.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2026/02/08.
//  Copyright © 2026 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz

/// Available Construction methods (algorithm) for Regular Languages.
public enum ConstructionMethod {
    case thompson       // Thompson, recursive ϵ-automata asssembly.
    case berrySethi     // Berry-Sethi, first, last, follow sets and parse tree construction.
//    case derivative     // Brzozowski, derivatives of expressions, almost minimal.
}

/// Construction contract of Regular Languages.
/// All construction methods of Regular Languages have conform to this contract.
public protocol RegularLanguageBuilder {
    /// The parsed regular expression.
    var expression: Expression { get }
    
    /// Return parsed regular expression as a flattened String.
//    var flattened: String { get }

    /// Regular Language construction method.
    mutating func construct() throws -> State<Regex>
}

///
public protocol RegularLanguage: RegularLanguageRecognition, RegularLanguageTransform {
    /// Actual type value of the RegularLanguage.
    associatedtype Subtype
    
    /// Internal finite state of automaton.
    var state: State<Subtype> { get set }
    
    /// Regular Expression builder using one of the above methods for construction.
    var builder: RegularLanguageBuilder { get set }
    
    /// Regular Expression builder method for construction.
    var method: ConstructionMethod { get set }

    /// Query deterministic state of Automaton or set it explicitly.
    var isDeterministic: Bool { get set }

    /// Indicates if `Automaton` is mininal or not.
    var isMinimal: Bool { get }

    /// Query epsilon state of Automaton or set it explicitly.
    var epsilonFree: Bool { get set }

    /// Regular Expression initializer.
    init(_ expression: String, method: ConstructionMethod, flags: SyntaxOptions) throws
}

public protocol RegularLanguageRecognition {
    
    /// NFA move(A,ch).
    func move(state: Int, symbol: Character, over transitions: Set<Transition>) -> Set<Int>

    /// DFA step(A,ch).
    func step(_ state: Int, symbol: Character, over transitions: Set<Transition>) -> Int?

    /// This approach simulates the NFA directly building each DFA state on demand.
    func recognize(string s: String) -> Bool
}

public protocol RegularLanguageTransform {

    /// Remove ε from Regular Language
    mutating func removeEps(initial: Int, finals: Set<Int>, transitions: Set<Transition>) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>)

    /// An NFA made deterministic by the powerset construction.
    mutating func powerset(initial: Int, finals: Set<Int>, transitions: Set<Transition>) -> (initial: Int, finals: Set<Int>, transitions: Set<Transition>)
}
