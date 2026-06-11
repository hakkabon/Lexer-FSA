//
//  ValmariState.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/19.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation
    
public struct ValmariState: CustomStringConvertible {
    var M: [Int] = []       // number of marked elements in set
    var W: [Int] = []       // sets with marked elements
    var w: Int = 0          // number of sets with marked elements
    
    var A: [Int] = []       // adjacent transitions
    var F: [Int] = []       // adjacent transitions
    var rr: Int = 0         // number of reached states
    
    public init() {
    }
    public var description: String {
        var s: String = ""
        s += "rr = \(rr)\n"
        s += "A = [" + A.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "F = [" + F.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "M = [" + M.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "W = [" + W.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "w = \(w)"
        return s
    }
}
