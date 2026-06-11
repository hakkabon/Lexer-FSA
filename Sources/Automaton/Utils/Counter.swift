//
//  Alphabet.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2021/01/18.
//

import Foundation

public class Counter {
    
    public class var shared: Counter { return sharedInstance }

    private static var sharedInstance: Counter = {
        let counter = Counter()
        return counter
    }()
    private var count: Int = 0
    private init() {}

    public func callAsFunction(increment: Int = 1) -> Int {
        count += increment
        return count
    }
}
