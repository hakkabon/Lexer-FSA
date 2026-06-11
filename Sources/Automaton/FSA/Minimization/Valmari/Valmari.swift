//
//  Valmari.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/07.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension State where T == DeterministicFiniteState {

    /// Minimizes the given automaton using Valmari's algorithm.
    /// Contains mysterious BUGS!
    func minimizeValmari(dfa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) -> DfaTuple {
        var nn: Int = 0                 // number of states
        var mm: Int = 0                 // number of transitions
        var ll: Int = 0                 // number of labels
        var q0: Int = 0                 // initial state
        var ff: Int = 0                 // number of final states
        var final = Set<Int>()          // final states
        var T: [Int] = []               // tails of transitions
        var L: [AlphabetRange] = []     // labels of transitions
        var H: [Int] = []               // heads of transitions
        let debug: Bool = true
        
        func setup(deterministic fsa: (initial: Int, finals: Set<Int>, transitions: Set<Transition>)) {
            let states = fsa.transitions.states()
            q0 = fsa.initial
            nn = states.count
            mm = fsa.transitions.count
            ll = fsa.transitions.count
            fsa.finals.forEach { final.insert($0) }
            ff = fsa.finals.count
            
            // split transitions in 'tails', 'labels', and 'heads'
            T = [Int](repeating: 0, count: mm)
            H = [Int](repeating: 0, count: mm)
            for (i,t) in fsa.transitions.sorted().enumerated() {
                T[i] = t.source
                L.append(t.alphabetRange)
                H[i] = t.target
            }
        }

        func makeAdjacent(_ K: inout [Int]) {
            (0...nn).forEach { tw.F[$0] = 0 }
            (0..<mm).forEach { tw.F[K[$0]] += 1 }
            (0..<nn).forEach { tw.F[$0+1] += tw.F[$0] }
            (0..<mm).reversed().forEach { i in
                tw.F[K[i]] -= 1
                tw.A[tw.F[K[i]]] = i
            }
        }

        func reach(_ q: Int) {
            let i: Int = B.L[q]
            if i >= tw.rr {
                B.E[i] = B.E[tw.rr]
                B.L[B.E[i]] = i
                B.E[tw.rr] = q
                B.L[q] = tw.rr
                tw.rr += 1
            }
        }

        func removeUnreachable(_ T: inout [Int], _ H: inout [Int]) {
            makeAdjacent(&T)
            var i = 0
            while i < tw.rr { // loop range is mutating - very ugly!
                for j in tw.F[B.E[i]]..<tw.F[B.E[i]+1] {
                    reach(H[tw.A[j]])
                }
                i += 1
            }
            var j: Int = 0
            for t in 0..<mm {
                if B.L[T[t]] < tw.rr {
                    H[j] = H[t]
                    L[j] = L[t]
                    T[j] = T[t]
                    j += 1
                }
            }
            mm = j
            B.P[0] = tw.rr
            tw.rr = 0
        }

        // defer { invariant() }
        
        setup(deterministic: dfa)
        var tw = ValmariState()
        tw.A = [Int](repeating: 0, count: mm)
        tw.F = [Int](repeating: 0, count: nn + 1)
        var B = ValmariPartition(nn)

        // Remove states that cannot be reached from the initial state,
        // and from which final states cannot be reached.
        reach(q0)
        removeUnreachable(&T, &H)

        // Process the final states.
        for q in final {
            if B.L[q] < B.P[0] {
                reach(q)
            }
        }
        ff = tw.rr
        removeUnreachable(&H, &T)
        
        // Make initial partition
        tw.W = [Int](repeating: 0, count: mm+1)
        tw.M = [Int](repeating: 0, count: mm+1)
        tw.M[0] = ff
        if ff > 0 {
            tw.W[tw.w] = 0
            tw.w += 1
            B.split(state: &tw)
        }
        
        // Make transition partition
        var C = ValmariPartition(mm)
        if mm > 0 {
            C.E.sort(by: { L[$0] < L[$1] } )
            C.z = 0
            tw.M[0] = 0
            var a = L[C.E[0]]
            for i in 0..<mm {
                let t = C.E[i]
                if L[t] != a {
                    a = L[t]
                    C.P[C.z] = i
                    C.z += 1
                    C.F[C.z] = i
                    tw.M[C.z] = 0
                }
                C.S[t] = C.z
                C.L[t] = i
            }
            C.P[C.z] = mm
            C.z += 1
        }

        // Split blocks and cords
        makeAdjacent(&H)

        for c in 0..<C.z {
            for i in C.F[c]..<C.P[c] {
                B.mark(state: &tw, e: T[C.E[i]])
            }
            B.split(state: &tw)
            for b in 0..<B.z {
                for i in B.F[b]..<B.P[b] {
                    for j in tw.F[B.E[i]]..<tw.F[B.E[i]+1] {
                        C.mark(state: &tw, e: tw.A[j])
                    }
                }
                C.split(state: &tw)
            }
        }
        
        // Accumulate all final, or accept, states.
        var finals = Set<Int>()
        (0..<B.z).forEach { if B.F[$0] < ff { finals.insert($0) } }

        // Create new transitions.
        var transitions = Set<Transition>()
        (0..<mm).forEach { (i) in
            if B.L[T[i]] == B.F[B.S[T[i]]]  {
                transitions.insert(Transition(from: B.S[T[i]], L[i], to: B.S[H[i]]))
            }
        }

        if debug {
            // Count the numbers of transitions and final states in the result
            let mo: Int = (0..<mm).reduce(0, { $0 + (B.L[T[$1]] == B.F[B.S[T[$1]]] ? 1 : 0) })
            let fo: Int = (0..<B.z).reduce(0, { $0 + (B.F[$1] < ff ? 1 : 0) })

            print("Result: \(B.z) \(mo) \(B.S[q0]) \(fo)")
            for t in 0..<mm {
                if B.L[T[t]] == B.F[B.S[T[t]]]  {
                    print("\(B.S[T[t]]) \(L[t]) \(B.S[H[t]])")
                }
            }
            for b in 0..<B.z {
                print("\(b) \(B.F[b] < ff ? " [accept]" : " [reject]")")
            }
        }
        
        // Return the minimized finite state atomaton.
        return (initial: B.S[q0], finals: finals, transitions: transitions, minimal: true)
    }
}
