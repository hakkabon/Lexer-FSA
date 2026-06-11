//
//  Options.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2020/06/27.
//  Copyright © 2020 hakkabon software. All rights reserved.
//

import Foundation

public struct GenerateOptions {
    public var strategy: Strategy = .nfaStrategy(.simple)
    public var states: Int = 10
    public var finals: Int = 2
    public var symbols: Int = 2
    public var density: Float = 0.05
    
    public init() {}
}

/// Generator construction strategies.
public enum Strategy {
    case nfaStrategy(NfaConstruction)
    case dfaStrategy(DfaConstruction)
}

public enum NfaConstruction {
    case standard
    case simple
}

public enum DfaConstruction {
    case bridged
    case simple
}
