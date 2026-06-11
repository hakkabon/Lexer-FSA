//
//  TrieBuilder.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2021/01/18.
//

import Foundation

let counter = Counter.shared

/// Implements trie construction and postorder minimization given a list of words.
/// Returns: The initial state (root) of the automaton.
/// Remarks: Uses a register of states.
public class TrieBuilder {

    var root = TrieNode()
    var previous: [Character] = []
    var register: [TrieNode:TrieNode] = [:]

    public init() {        
    }
    
    public func minimize() {
        root = minimmize(root: root)
    }
    
    // Merge isomorphic subtrees (subgraphs) bottom up.
    private func minimmize(root node: TrieNode) -> TrieNode {
        for edge in node.edges /*.sorted(by: { $0.key < $1.key }) */ {
            node.setTarget(for: edge.key, target: minimmize(root: edge.value))
        }
        return setOrRegister(node: node)
    }

    func setOrRegister(node: TrieNode) -> TrieNode {
        if let n = register[node] {
            return n
        } else {
            register[node] = node
            return node
        }
    }

    public func insert(word: String) {
        return insert(characters: Array(word))
    }

    private func nodeCount(node: TrieNode, visitor: @escaping (() -> Void), visited: inout Set<Int>) {
        if !visited.contains(node.id) {
            visitor()
            visited.insert(node.id)
        }
        for edge in node.edges {
            nodeCount(node: edge.value, visitor: visitor, visited: &visited)
        }
    }
    
    private func insert(characters: [Character]) {
        guard !characters.isEmpty else { return }
        //assert(previous.count > 0 ? String(previous) < String(characters) : true, "Input must be sorted")
        previous = characters
        
        var node = root
        for character in characters {
            if let child = node.edges[character] {
                node = child
            } else {
                // new transition with label character to node.
                let target = TrieNode()
                node.insertEdge(with: character, to: target)
                node = target
            }
        }
        guard node != root else { return }
        previous = characters
        node.final = true
    }
}

class TrieNode {
    var id: Int = counter()
    var edges: [Character:TrieNode] = [:]
    var final: Bool = false
    
    func insertEdge(with label: Character, to node: TrieNode) {
        edges[label] = node
    }

    func setTarget(for label: Character, target node: TrieNode) {
        if let _ = edges.updateValue(node, forKey: label) {
        }
    }
}

extension TrieNode: Hashable {
    public func hash(into hasher: inout Hasher) {
        func hash(into hasher: inout Hasher) {
            hasher.combine(final)
            hasher.combine(edges)
        }
    }
}

extension TrieNode: Equatable {
    static public func == (lhs: TrieNode, rhs: TrieNode) -> Bool {
        return lhs.final == rhs.final && lhs.edges == rhs.edges
    }
}
