//
//  PrettyPrint.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2021/03/27.
//

import Foundation

public func tupleNotation<U: Comparable,V>(_ dict: Dictionary<U,V>) -> String {
    var s = ""
    s += "("
    let ks = dict.keys.sorted()
    let keyList = ks.map { "\($0):" }
    let valueList = ks.map { "\(dict[$0]!)" }
    let kvList = Array(zip(keyList, valueList))
    let list = kvList.map { "\($0.0) \($0.1)" }
    s += list.joined(separator: ", ")
    s += ")"
    return s
}

public func setNotation<T>(_ set: Set<T>) -> String {
    return  "{" + set.map { "\($0)" }.joined(separator: ",") + "}"
}

public func setNotation<T>(_ list: [T]) -> String {
    return  "{" + list.map { "\($0)" }.joined(separator: ",") + "}"
}
