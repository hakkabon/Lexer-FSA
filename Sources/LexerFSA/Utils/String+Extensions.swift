//
//  String+Extensions.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/04.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

extension String {
  
    public func leftPadding(toLength: Int, withPad: String = " ") -> String {
        guard toLength > self.count else { return self }

        let padding = String(repeating: withPad, count: toLength - self.count)
        return padding + self
    }
}
