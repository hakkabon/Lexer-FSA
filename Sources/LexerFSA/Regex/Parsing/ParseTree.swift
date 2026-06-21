//
//  ParseTree.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/07/19.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

/// This is used  in the BerrySethi construction mentod.
extension Regex {

    public class ParseNode: CustomStringConvertible {
        public var pos: Int = 0
        public var nullable: Bool = false
        public var first: Set<Int> = Set<Int>()
        public var last: Set<Int> = Set<Int>()
        public var follow: Set<Int> = Set<Int>()

        public weak var parent: ParseNode?
        public var children = [ParseNode]()
        public var isLeaf: Bool { return children.count == 0 }
         
        /// Number generator.
        ///
        /// Local to this `ParseNode` instance. Replaces the old
        /// `Counter.shared` singleton so build results are reproducible
        /// (and so different ParseNode trees don't interleave their IDs).
        let sequence = Counter()

        public init() {}

        public func addChild(_ node: ParseNode) {
            children.append(node)
            node.parent = self
        }

        public var description: String {
            var s: String = ""
            if !children.isEmpty {
                s += children.map { $0.description }.joined(separator: ", ")
            }
            return s
        }

        public var positionState: String {
            var s = "\(type(of: self)) "
            s += "pos: \(pos) "
            s += "nullable: \(nullable) "
            s += "first: \(setNotation(first)) "
            s += "last: \(setNotation(last)) "
            s += "follow: \(setNotation(follow))"
            return s
        }

        public func preorder(traversal apply: (ParseNode) -> Void) {
            if parent != nil {
                apply(self)
            }
            for node in children {
            switch node {
                case is Or:
                    apply(node)
                    assert(node.children.count == 2)
                    node.children[0].preorder(traversal: apply)
                    node.children[1].preorder(traversal: apply)
                case is Con:
                    apply(node)
                    assert(node.children.count == 2)
                    node.children[0].preorder(traversal: apply)
                    node.children[1].preorder(traversal: apply)
                case is Opt:
                    apply(node)
                    assert(node.children.count == 1)
                    node.children[0].preorder(traversal: apply)
                case is Rep:
                    apply(node)
                    assert(node.children.count == 1)
                    node.children[0].preorder(traversal: apply)
                case is Leaf:
                    apply(node)
                default:
                    fatalError()
                }
            }
        }

        public func postorder(traversal apply: (ParseNode) -> Void) {
            for node in children {
                switch node {
                case is Or:
                    assert(node.children.count == 2)
                    node.children[0].postorder(traversal: apply)
                    node.children[1].postorder(traversal: apply)
                    apply(node)
                case is Con:
                    assert(node.children.count == 2)
                    node.children[0].postorder(traversal: apply)
                    node.children[1].postorder(traversal: apply)
                    apply(node)
                case is Opt:
                    assert(node.children.count == 1)
                    node.children[0].postorder(traversal: apply)
                    apply(node)
                case is Rep:
                    assert(node.children.count == 1)
                    node.children[0].postorder(traversal: apply)
                    apply(node)
                case is Leaf:
                    apply(node)
                default:
                    fatalError()
                }
            }
            if parent != nil {
                apply(self)
            }
        }
    }

    public class Or: ParseNode {
        public override init() { super.init() }
        public override var description: String { return "OR" }
    }

    public class Con: ParseNode {
        public override init() { super.init() }
        public override var description: String { return "Con" }
    }

    public class Opt: ParseNode {
        public override init() { super.init() }
        public override var description: String { return "Opt" }
    }

    public class Rep: ParseNode {
        public override init() { super.init(); }
        public override var description: String { return "Rep" }
    }

    public class Leaf: ParseNode {
        var leaf: Expression = .empty
        init(_ leaf: Expression) {
            super.init()
            self.pos = sequence()
            self.leaf = leaf
        }
        public override var description: String { return leaf.description }
    }
}
