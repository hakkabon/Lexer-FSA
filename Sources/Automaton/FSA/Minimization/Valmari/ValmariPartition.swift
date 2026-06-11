//
//  ValmariPartition.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/19.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

public struct ValmariPartition: CustomStringConvertible {
    var z: Int = 0
    var E: [Int] = []
    var L: [Int] = []
    var S: [Int] = []
    var F: [Int] = []
    var P: [Int] = []
    
    public init(_ n: Int) {
        z = n > 0 ? 1 : 0
        E = Array(0..<n)
        L = Array(0..<n)
        S = [Int](repeating: 0, count: n)
        F = [Int](repeating: 0, count: n)
        P = [Int](repeating: 0, count: n)
        if z > 0 {
            F[0] = 0
            P[0] = n
        }
    }

    public var description: String {
        var s: String = ""
        s += "---Partition------------------------\n"
        s += "z = \(z)\n"
        s += "E = [" + E.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "L = [" + L.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "S = [" + S.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "F = [" + F.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "P = [" + P.map { "\($0)" }.joined(separator: ",") + "]\n"
        s += "---Partition------------------------"
        return s
    }

    mutating func mark(state: inout ValmariState, e: Int) {
        let s = S[e]
        let i = L[e]
        let j = F[s] + state.M[s]
        E[i] = E[j]
        L[E[i]] = i
        E[j] = e
        L[e] = j
        if !(state.M[s] > 0) {
            state.M[s] += 1
            state.W[state.w] = s
            state.w += 1
        }
    }
    
    mutating func split(state: inout ValmariState) {
        while state.w > 0 {
            state.w -= 1
            let s = state.W[state.w]
            let j = F[s] + state.M[s]
            if j == P[s] {
                state.M[s] = 0
                continue
            }
            if state.M[s] <= P[s]-j {
                F[z] = F[s]
                F[s] = j
                P[z] = j
            } else {
                P[z] = P[s]
                P[s] = j
                F[z] = j
            }
            for i in F[z]..<P[z] {
                S[E[i]] = z
            }
            state.M[z] = 0
            state.M[s] = 0
            z += 1
        }
    }
}
