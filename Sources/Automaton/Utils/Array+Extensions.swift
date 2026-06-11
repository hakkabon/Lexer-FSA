//
//  Array+Extensions.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/07/03.
//

import Foundation

/// Enable lexicographical order for arrays.
extension Array: Comparable where Element: Comparable {

    public static func < (lhs: [Element], rhs: [Element]) -> Bool {
        for (leftElement, rightElement) in zip(lhs, rhs) {
            if leftElement < rightElement {
                return true
            } else if leftElement > rightElement {
                return false
            }
        }
        return lhs.count < rhs.count
    }
}
