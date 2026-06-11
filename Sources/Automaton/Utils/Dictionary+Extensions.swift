//
//  Dictionary+Extensions.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/05.
//

import Foundation

extension Dictionary where Value: Equatable {

    func allKeys(for value: Value) -> [Key] {
        return self.filter { $1 == value }.map { $0.0 }
    }
}
