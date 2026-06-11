//
//  Graphvizable.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/04.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz

extension State: Graphvizable {

    /// Output internal representation in graphviz format. States are not re-numbered.
    /// Note that the states are always re-numbered.
    public var graphviz: GraphViz.Graph {
        var graph: GraphViz.Graph = Graph(directed: true, strict: false)
        graph.rankDirection = .leftToRight
        
        switch self {
        case let .nfa(initial,finals,transitions):
            let states = transitions.states().sorted()
            let n = states.count
            var nodes: [Node] = []
            let numbering: [Int:Int] = Dictionary(uniqueKeysWithValues: zip(states,0..<n))
            nodes = states.map { Node("\(numbering[$0] ?? 0)") }

            var lookup: [Int:Node] = Dictionary(uniqueKeysWithValues: zip(states, nodes))
            for s in states {
                if var node = lookup[s] {
                    node.shape = finals.contains(s) ? .doublecircle : .circle
                    node.root = s == initial ? true : false
                    lookup[s] = node
                }
            }
            graph.append(contentsOf: lookup.values)
            for tr in transitions {
                var edge = GraphViz.Edge(from: lookup[tr.source]!, to: lookup[tr.target]!)
                edge.exteriorLabel = "\(tr.alphabetRange)"
                graph.append(edge)
            }
            if let start = states.first(where: { $0 == initial }) {
                if let node = lookup[start] {
                    var s = Node("start")
                    s.shape = .point
                    graph.append(s)
                    graph.append(GraphViz.Edge(from: s, to: node))
                }
            }
            return graph
            
        case let .dfa(initial,finals,transitions,_):
            let states = transitions.states().sorted()
            let n = states.count
            var nodes: [Node] = []
            let numbering: [Int:Int] = Dictionary(uniqueKeysWithValues: zip(states,0..<n))
            nodes = states.map { Node("\(numbering[$0] ?? 0)") }
            var lookup: [Int:Node] = Dictionary(uniqueKeysWithValues: zip(states, nodes))
            for s in states {
                if var node = lookup[s] {
                    node.shape = finals.contains(s) ? .doublecircle : .circle
                    node.root = s == initial ? true : false
                    lookup[s] = node
                }
            }
            graph.append(contentsOf: lookup.values)
            for tr in transitions {
                var edge = GraphViz.Edge(from: lookup[tr.source]!, to: lookup[tr.target]!)
                edge.exteriorLabel = "\(tr.alphabetRange)"
                graph.append(edge)
            }
            if let start = states.first(where: { $0 == initial }) {
                if let node = lookup[start] {
                    var s = Node("start")
                    s.shape = .point
                    graph.append(s)
                    graph.append(GraphViz.Edge(from: s, to: node))
                }
            }
            return graph
        }
    }
}
