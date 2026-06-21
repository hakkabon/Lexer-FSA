//
//  BinarySearch.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/19.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

func binarySearch<T: Comparable>(_ array: Array<T>, _ element: T) -> Int? {
    var lower = 0
    var upper = array.count - 1

    while true {
        let index = (lower + upper)/2
        if array[index] == element {
            return index
        } else if lower > upper {
            return nil
        } else {
            if array[index] > element {
                upper = index - 1
            } else {
                lower = index + 1
            }
        }
    }
}
