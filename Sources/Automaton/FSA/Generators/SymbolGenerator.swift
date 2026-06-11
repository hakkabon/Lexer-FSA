//
//  SymbolGenerator.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/25.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

public struct SymbolGenerator {
    
    static let characters = """
    abcdefghijklmnopqrstuvwxyz\
    ABCDEFGHIJKLMNOPQRSTUVWXYZ
    """

    let chars = characters.map { $0 }
    
    public func random(length: Int) -> String {
        var str = ""
        for _ in 0..<length {
            str.append(chars.randomElement()!)
        }
        return str
    }

    public func substring(range: Range<Int>) -> String {
        return String(chars[0 ..< range.upperBound])
    }

    public func substring(range: ClosedRange<Int>) -> String {
        return String(chars[0 ... range.upperBound])
    }

    public func randomElement(range: Range<Int>) -> Character {
        return chars[0 ..< range.upperBound].randomElement()!
    }

    public func randomElement(range: ClosedRange<Int>) -> Character {
        return chars[0 ... range.upperBound].randomElement()!
    }
}
