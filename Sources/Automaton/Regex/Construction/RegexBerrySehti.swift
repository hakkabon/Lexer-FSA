//
//  RegexBerrySehti.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/03.
//

import Foundation

// Berry-Sethi construction method, aka Glushkov method, or Direct method.
// 1. Compile regular expression.
// 2. Transform NFA to DFA by Parse Tree construction.
extension Regex {

    struct BerrySethi: RegularLanguageBuilder {
        
        let debug = true

        // Regex string parser.
        var parser: RegexParser

        /// The parsed regular expression.
        var expression: Expression = .empty

        /// Local language positions.
        var positions: [Character] = []
        var lookup: [Int:Character] = [:]
        var alphabet: Set<Character> = Set()
        var followpos: [Int:Set<Int>] = [:]
        var leaves: [ParseNode] = []

        // Mapping from NFA states to their corresponding DFA state.
        var Dstates = Dictionary<Set<Int>, Int>()

        /// Number generator.
        let state = Counter.shared
            
        // Parse tree of augmented regular expression.
        var parsetree: ParseNode = ParseNode()

        func positional(_ s: String, metasymbols: Set<String>) -> [Character] {
            let positions = s.filter { !metasymbols.contains(String($0)) }
            return Array(positions)
        }

        init(expression: String, flags: SyntaxOptions) {
            let augmentedExpression = expression + "#"
            parser = RegexParser(expression: augmentedExpression, flags)
            positions = positional(augmentedExpression, metasymbols: Set(Metasymbol.allCases.map { "\($0.rawValue)" } ))
            lookup = Dictionary(uniqueKeysWithValues: zip(1...positions.count,positions))
            alphabet = Set<Character>(lookup.values)
        }

        mutating func construct() throws -> State<Regex> {
            self.expression = try parser.parse()

            // this is a VERY unnecessary operation.
            self.unparse(expression, &parsetree)

            // nullable set calculations and collect all leaves.
            parsetree.postorder { (node) in
                switch node {
                case is Or:
                    node.nullable = node.children[0].nullable || node.children[1].nullable
                case is Con:
                    node.nullable = node.children[0].nullable && node.children[1].nullable
                case is Opt:
                    node.nullable = true
                case is Rep:
                    node.nullable = true
                case is Leaf:
                    node.nullable = false
                    leaves.append( node )
                default:
                    fatalError()
                }
            }

            // first and last set combined calculations.
            parsetree.postorder { (node) in
                switch node {
                case is Or:
                    node.first.formUnion( node.children[0].first )
                    node.first.formUnion( node.children[1].first )
                    node.last.formUnion( node.children[0].last )
                    node.last.formUnion( node.children[1].last )
                case is Con:
                    node.first.formUnion( node.children[0].first )
                    if node.children[0].nullable {
                        node.first.formUnion( node.children[1].first )
                    }
                    node.last.formUnion( node.children[1].last )
                    if node.children[1].nullable {
                        node.last.formUnion( node.children[0].last )
                    }
                case is Opt:
                    node.first.formUnion( node.children[0].first )
                    node.last.formUnion( node.children[0].last )
                case is Rep:
                    node.first.formUnion( node.children[0].first )
                    node.last.formUnion( node.children[0].last )
                case is Leaf:
                    node.first.insert( node.pos )
                    node.last.insert( node.pos )
                default:
                    fatalError()
                }
            }

            // follow set calculations.
            parsetree.preorder { (node) in
                switch node {
                case is Or:
                    node.children[0].follow.formUnion(node.follow)
                    node.children[1].follow.formUnion(node.follow)
                case is Con:
                    node.children[1].follow.formUnion( node.follow )
                    node.children[0].follow.formUnion( node.children[1].first )
                    if node.children[1].nullable {
                        node.children[0].follow.formUnion( node.follow )
                    }
                case is Opt:
                    node.children[0].follow.formUnion( node.follow )
                case is Rep:
                    node.children[0].follow.formUnion( node.follow )
                    node.children[0].follow.formUnion( node.children[0].first )
                case is Leaf: break
                default:
                    fatalError()
                }
            }

            // setup followpos(p) for all leaves.
            for leaf in leaves {
                followpos[leaf.pos] = leaf.follow
            }

            if debug { parsetree.preorder { print($0.positionState) } }
            if debug {
                print("leaves(p) and followpos(p): ")
                for leaf in leaves {
                     print(leaf.positionState)
                }
            }

            // initial state
            let q0 = 0
            
            // all transitions from the initial state
            var transitions = Set<Transition>()
            for state in parsetree.children[0].first {
                let t = Transition(from: q0, AlphabetRange.char(lookup[state]!), to: state)
                transitions.insert(t)
            }

            // remaining transitions - need leave objects!!!
            for state in leaves {
                for nextState in state.follow {
                    if nextState == positions.count { continue }
                    let t = Transition(from: state.pos, AlphabetRange.char(lookup[nextState]!), to: nextState)
                    transitions.insert(t)
                }
            }
            
            // final states
            var finals = Set<Int>()
            for state in parsetree.children[0].last {
                finals.insert(state)
            }
            
            if debug { print("> initial = \(q0) finals = \(setNotation(finals))") }
            if debug { print("> transitions : \(setNotation(transitions))") }

            //return .nfa(q0, finals, transitions)
            
            return powerset()
        }

        mutating func powerset() -> State<Regex> {
            var finals = Set<Int>()
            var transitions = Set<Transition>()

            let initStates = parsetree.children[0].first
            if debug { print("initial state : \(setNotation(initStates))") }
            var unmarked: [Set<Int>] = [initStates]
            var DFAstates: Set<Set<Int>> = []
            
            // firstpos(root) where root is the root of the syntax tree for (r)#.
            let initial = collectSets(nfaStates: parsetree.children[0].first)
            
            // as long as there is an unmarked state T in Dstates.
            while !unmarked.isEmpty {
                // get S.
                let states = unmarked.removeFirst()

                // collect new DFA state.
                DFAstates.insert(states)
                
                // get state S in Dstates.
                let state = collectSets(nfaStates: states)
                
                // S is a final state if it contains the position of #.
                if states.contains(where: { $0 == positions.count }) {
                    finals.insert(state)
                }
                
                // states
                for a in alphabet {
                    // let s1,...,sn be positions in S such that the symbol at position p is a.
                    var s = Set(lookup.allKeys(for: a))
                    s = s.intersection(states)
                    if debug { print("alphabet states: \(s)") }

                    // let nextS be the union of followpos(p) such that symbol at position p is a.
                    let nextS = s.reduce(Set<Int>(), { $0.union( followpos[$1]! ) })
                    if debug { print("> next state: \(setNotation(nextS))") }

                    // Skip empty states.
                    if nextS.isEmpty { continue }

                    // get state nextS in Dstates.
                    let dfaState = collectSets(nfaStates: nextS)

                    // Dtran[S,a] := nextS
                    transitions.insert(Transition(from: state, .char(a), to: dfaState))
                    
                    // add nextS as an unmarked state if not contained in the set of DFA states.
                    if !DFAstates.contains(nextS) {
                        unmarked.append(nextS)
                    }
                }
            }
            return .dfa(initial: initial, finals: finals, transitions: transitions, minimal: false)
        }

        mutating func collectSets(nfaStates: Set<Int>) -> Int {
            if let state = Dstates[nfaStates] {
                return state
            } else {
                let dstate: Int = state()
                Dstates[nfaStates] = dstate
                return dstate
            }
        }
        
        func unparse(_ expression: Expression, _ parent: inout ParseNode) {
            switch expression {
            case let .union(e1,e2):
                var or: ParseNode = Or()
                parent.addChild(or)
                unparse(e1,&or)
                unparse(e2,&or)
            case let .concatenation(e1,e2):
                var con: ParseNode = Con()
                parent.addChild(con)
                unparse(e1,&con)
                unparse(e2,&con)
            case let .optional(e):
                var opt: ParseNode = Opt()
                parent.addChild(opt)
                unparse(e,&opt)
            case let .repeat(e):
                var rep: ParseNode = Rep()
                parent.addChild(rep)
                unparse(e,&rep)
            case let .repeatMin(e,_):
                var rep: ParseNode = Rep()
                parent.addChild(rep)
                unparse(e,&rep)
            case let .repeatMinMax(e,_,_):
                var rep: ParseNode = Rep()
                parent.addChild(rep)
                unparse(e,&rep)
            case let .charRange(from,to):
                parent.addChild(Leaf(.charRange(from,to)))
            case let .char(ch):
                parent.addChild(Leaf(.char(ch)))
            case .anyChar:
                parent.addChild(Leaf(.anyChar))
            case let .string(s):
                parent.addChild(Leaf(.string(s)))
            case .anyString:
                parent.addChild(Leaf(.anyString))
            case let .interval(min,max,digits):
                parent.addChild(Leaf(.interval(min,max,digits)))
            case .empty:
                parent.addChild(Leaf(.empty))
            }
        }
    }
}
