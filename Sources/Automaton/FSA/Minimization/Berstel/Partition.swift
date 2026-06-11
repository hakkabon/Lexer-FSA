//
//  Partition.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/09.
//

import Foundation

/// Implements partitioning consecutive integers (0..<n) into arbitrary blocks,
/// so that the partitioning equivalence is maintained among the blocks, i.e. P = ⋃ blocks[i].
/// The array classes[i] maps a state to a specific blocks[i].
/// The array blocks[classes[i]] gives the states associated with a specific blocks[i].
/// The array nodes gives the location of a specific state in its block.
public struct Partition : CustomStringConvertible {
    
    var classes: [Int] = []                         // mapping index -> block, i.e. classes[i]
    var cardinality: [Int] = []                     // cardinality of each blocks[i], i.e. cardinality[classes[i]]
    var blocks: [Int:LinkedList<Int>] = [:]         // states in each blocks[i], i.e. blocks[classes[i]]
    var nodes: [LinkedList<Int>.Node] = []          // mapping node[i] (node[classes[i]]) to element in list
    
    /// Next free (partition) block, and current number partitions
    /// is equal to count-1.
    var count: Int

    /// Size of partition
    public private(set) var Q: Int = 0

    /// Creates the partition with one class, with name 0, containing list [0,...,n-1]
    /// ```
    /// let p = Partition(7)
    /// // results in
    /// 0 : 6 5 4 3 2 1 0
    /// ```
    public init(n: Int) {
        precondition(n>=0, "n must not be a negative number.")
        Q = n
        classes = [Int](repeating: 0, count: n)
        cardinality = [Int](repeating: 0, count: n)
        
        for i in 0..<n { blocks[i] = LinkedList<Int>() }
        for i in 0..<n {
            let node = LinkedList<Int>.Node(value: i)
            blocks[0]?.append(node)
            nodes.append(node)
        }
        count = 1
        cardinality[0] = n
    }
    
    /// Creates a partition according to the class names given in the array.
    /// ```
    /// let p = Partition([0, 3, 1, 0, 2, 1, 0])
    /// // results in
    /// 0 : 6 3 0
    /// 1 : 5 2
    /// 2 : 4
    /// 3 : 1
    /// ```
    public init(_ classes: [Int]) {
        self.init(n: classes.count)
        precondition(classes.allSatisfy { 0 <= $0 && $0 < classes.count }, "all values must be < | classes |.")
        
        if let n = classes.max(), n>0 {
            count = n+1
        }

        for (i, blockNumber) in classes.enumerated() {
            if blockNumber > 0 {
                transfer(q: i, source: 0, target: blockNumber)
            }
        }
        assert(count <= Q)
    }

    /// Transfers q from the source class to target class.
    /// - Parameters:
    ///   - q: state id
    ///   - source: source block number of state
    ///   - target: target block number of block transfer of state
    private mutating func transfer(q: Int, source: Int, target: Int, transfer chunk: Bool = false) {
        let node = nodes[q]
        cardinality[source] -= 1
        blocks[source]?.remove(node: node)
        blocks[target]?.insert(node, at: 0)
        cardinality[target] += 1
        classes[q] = target
    }
    
    /// Transfers q from the class src to the class dest.
    public mutating func transfer(state q: Int, target block: Int) {
        precondition(block<Q, "target block \(block) must not exceed the number of states.")
        
        let source = classes[q]
        let increase = cardinality[count] == 0 ? count + 1 : count
        transfer(q: q, source: source, target: block)
        count = increase
        assert(count <= Q)
    }
    
    /// Breaks the class src using the block list.
    /// ```
    /// // given the initial partition, p
    /// 0 : 6 5 4 3 2 1 0
    /// p.splitClass([5,3], 0)
    /// // results in
    /// 0 : 6 4 2 1 0
    /// 1 : 3 5
    /// ```
    public mutating func splitClass(_ index: Int, target elements: [Int]) {
        precondition(cardinality[index] > 1, "cannot split class with 1 element.")
        guard elements.count > 0 else { return }
        let increase = cardinality[count] == 0 ? count + 1 : count
        for value in elements {
            transfer(q: value, source: index, target: count)
        }
        count = increase
        assert(count <= Q)
    }
    
    public var description: String {
        var s = ""
        s += "[" + classes.map { "\($0)" }.joined(separator: ", ") + "] "
        s += "("
        let keys = blocks.keys.sorted()
        let keyList = keys.map { "\($0):" }
        let valueList = keys.map { "\(blocks[$0]!)" }
        let kvList = Array(zip(keyList, valueList))
        let list = kvList.map { "\($0.0) \($0.1)" }
        s += list.joined(separator: ", ")
        s += ", next: \(count)"
        s += ")"
        return s
    }
}
