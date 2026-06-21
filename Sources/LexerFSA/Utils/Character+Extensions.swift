//
//  Character+Extensions.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2021/03/27.
//  Copyright © 2021 hakkabon software. All rights reserved.
//

import Foundation

// https://stackoverflow.com/questions/49041598/making-swift-class-with-character-or-character-based-property-codable
extension Character: Codable {

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let string = try container.decode(String.self)
        guard !string.isEmpty else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Decoder expected a Character but found an empty string.")
        }
        guard string.count == 1 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Decoder expected a Character but found a string: \(string)")
        }
        self = string[string.startIndex]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(String(self))
    }
}
