//
//  Graphvizable.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/04.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation
import GraphViz

extension State: Graphvizable {

    /// Returns the automaton rendered as a directed `GraphViz.Graph`.
    ///
    /// States are renumbered 0…n−1 for compact output. Final states are drawn
    /// with a double-circle shape; when a final state carries a `TokenClass` its
    /// name is appended to the node label so token classes are visible in the
    /// rendered diagram. An invisible `point`-shaped node with an arrow marks
    /// the initial state.
    public var graphviz: GraphViz.Graph {
        var graph = Graph(directed: true, strict: false)
        graph.rankDirection = .leftToRight

        switch self {

        case let .nfa(initial, finals, transitions, tokenMap):
            let states    = transitions.states().sorted()
            let n         = states.count
            let numbering = Dictionary(uniqueKeysWithValues: zip(states, 0..<n))

            var lookup: [Int: Node] = [:]
            for s in states {
                let id    = numbering[s] ?? 0
                let label = tokenMap[s].map { "\(id)\n\($0.name)" } ?? "\(id)"
                var node  = Node(label)
                node.shape = finals.contains(s) ? .doublecircle : .circle
                node.root  = s == initial ? true : false
                lookup[s]  = node
            }
            graph.append(contentsOf: lookup.values)

            for tr in transitions {
                if let from = lookup[tr.source], let to = lookup[tr.target] {
                    var edge = GraphViz.Edge(from: from, to: to)
                    edge.exteriorLabel = "\(tr.alphabetRange)"
                    graph.append(edge)
                }
            }

            // Initial-state arrow.
            if let startNode = lookup[initial] {
                var arrow = Node("start")
                arrow.shape = .point
                graph.append(arrow)
                graph.append(GraphViz.Edge(from: arrow, to: startNode))
            }

        case let .dfa(initial, finals, transitions, _, tokenMap):
            let states    = transitions.states().sorted()
            let n         = states.count
            let numbering = Dictionary(uniqueKeysWithValues: zip(states, 0..<n))

            var lookup: [Int: Node] = [:]
            for s in states {
                let id    = numbering[s] ?? 0
                let label = tokenMap[s].map { "\(id)\n\($0.name)" } ?? "\(id)"
                var node  = Node(label)
                node.shape = finals.contains(s) ? .doublecircle : .circle
                node.root  = s == initial ? true : false
                lookup[s]  = node
            }
            graph.append(contentsOf: lookup.values)

            for tr in transitions {
                if let from = lookup[tr.source], let to = lookup[tr.target] {
                    var edge = GraphViz.Edge(from: from, to: to)
                    edge.exteriorLabel = "\(tr.alphabetRange)"
                    graph.append(edge)
                }
            }

            // Initial-state arrow.
            if let startNode = lookup[initial] {
                var arrow = Node("start")
                arrow.shape = .point
                graph.append(arrow)
                graph.append(GraphViz.Edge(from: arrow, to: startNode))
            }
        }

        return graph
    }
}
