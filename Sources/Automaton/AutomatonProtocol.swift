//
//  AutomatonProtocol.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/16.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation

/// This is Work In Progress
protocol AutomataOperation {

    /// Actual type value of the Finite State Automaton.
    associatedtype Subtype

    /// Operations that do belong here are, just to name a few.
    func complement() -> Automaton<Subtype>
    func minus(_ automaton: Automaton<Subtype>) -> Automaton<Subtype>
    func intersection(with automaton: Automaton<Subtype>) -> Automaton<Subtype>
    func reverse() -> Automaton<Subtype>
    func reduce() -> Automaton<Subtype>

    // static functions 
    func union(of automaton: Automaton<Subtype>) -> Automaton<Subtype>
    static func union(a: Automaton<Subtype>, b: Automaton<Subtype>) -> Automaton<Subtype>
    static func union(list: [Automaton<Subtype>]) -> Automaton<Subtype>

    // Useful or not?
    func getCommonPrefix(_ automaton: Automaton<Subtype>) -> String

    // Directed Acyclic Word Graph - DAWG interface
    static func stringUnion(words: [String]) -> Automaton<Subtype>

    func isTotal() -> Bool
    func isFinite() -> Bool
    func getShortestExample() -> String
    func getStrings(_ automaton: Automaton<Subtype>, length: Int) -> Set<String>

    func isEquivalent(to automaton: Automaton<Subtype>) -> Bool
    func isSubset(of automaton: Automaton<Subtype>) -> Bool
}
